package com.dhwjdgh.prv_dashboard

import android.app.job.JobParameters
import android.app.job.JobService
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.OffsetDateTime
import java.time.ZoneId

class CalendarSyncJobService : JobService() {
    private var jobThread: Thread? = null

    override fun onStartJob(params: JobParameters?): Boolean {
        val year  = params?.extras?.getInt("year",  0) ?: 0
        val month = params?.extras?.getInt("month", 0) ?: 0
        if (year == 0 || month == 0) { jobFinished(params, false); return false }

        val ctx = applicationContext
        jobThread = Thread {
            try {
                val success = executeSyncInternal(ctx, year, month)
                if (success) {
                    ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                        .putLong("cal_synced_${year}_${month}", System.currentTimeMillis())
                        .apply()
                }
                val mgr = AppWidgetManager.getInstance(ctx)
                val ids = mgr.getAppWidgetIds(ComponentName(ctx, HomeWidgetProvider::class.java))
                for (id in ids) HomeWidgetProvider.updateWidget(ctx, mgr, id)
            } finally {
                jobFinished(params, false)
            }
        }.apply { start() }
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        jobThread?.interrupt()
        return true
    }

    companion object {
        private const val PREFS = "HomeWidgetPreferences"
        private const val TAG = "CalSync"
        private val isSyncing = java.util.concurrent.atomic.AtomicBoolean(false)

        private val EVENT_COLORS = mapOf(
            "1" to "#ff7986cb", "2" to "#ff33b679", "3" to "#ff8e24aa",
            "4" to "#ffe67c73", "5" to "#fff6c026", "6" to "#fff5511d",
            "7" to "#ff039be5", "8" to "#ff616161", "9" to "#ff3f51b5",
            "10" to "#ff0b8043", "11" to "#ffd50000"
        )
        private const val DEFAULT_COLOR = "#ff4285f4"

        fun executeSync(context: Context, year: Int, month: Int, onDone: () -> Unit = {}) {
            if (!isSyncing.compareAndSet(false, true)) {
                Log.d(TAG, "sync already in progress — skipping duplicate request")
                onDone()
                return
            }
            Thread {
                val success: Boolean
                try {
                    success = executeSyncInternal(context, year, month)
                    // API 호출이 실제로 성공했을 때만 타임스탬프 저장
                    if (success) {
                        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                            .putLong("cal_synced_${year}_${month}", System.currentTimeMillis())
                            .apply()
                    }
                } finally {
                    isSyncing.set(false)
                }
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
                for (id in ids) HomeWidgetProvider.updateWidget(context, mgr, id)
                onDone()
            }.start()
        }

        private fun executeSyncInternal(context: Context, year: Int, month: Int): Boolean {
            WidgetStrings.updateLocale(context)
            Log.d(TAG, "executeSyncInternal: $year/$month")
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (token.isNullOrEmpty()) {
                Log.e(TAG, "No token available — sync skipped")
                return false
            }

            var result = runCatching { syncCalendar(context, token!!, year, month) }
                .onSuccess { Log.d(TAG, "syncCalendar success: fetched=$it") }
                .getOrNull()

            if (result == null || !result) {
                Log.e(TAG, "syncCalendar failed or no data — invalidating stale token & retrying")
                // 만료된 캐시 토큰을 무효화(GoogleAuthUtil 내부 캐시에서 제거)한 뒤 새 토큰 발급
                TokenManager.invalidateToken(context, token!!)
                val freshT = freshToken(context)
                if (freshT != null) {
                    result = runCatching { syncCalendar(context, freshT, year, month) }
                        .onSuccess { Log.d(TAG, "syncCalendar retry success: fetched=$it") }
                        .onFailure { e2 -> Log.e(TAG, "syncCalendar retry failed: $e2") }
                        .getOrNull()
                    // 성공한 새 토큰을 캐시에 저장 → 다음 동기화부터 매번 401 반복하지 않음
                    if (result == true) {
                        TokenManager.writeCachedToken(context, freshT)
                        Log.d(TAG, "fresh token cached for next sync")
                    }
                }
            }
            return result == true
        }

        private fun readHiddenCalendars(context: Context): Set<String> {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = flutterPrefs.getString("flutter.g-cal-filter-hidden", null) ?: return emptySet()
            val listPrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
            val json = if (raw.startsWith(listPrefix)) raw.substring(listPrefix.length) else raw
            return try {
                val arr = org.json.JSONArray(json)
                (0 until arr.length()).map { arr.getString(it) }.toSet()
            } catch (e: Exception) {
                emptySet()
            }
        }

        // true = API 호출 성공 (0건 포함), false = 모든 API 호출 실패
        private fun syncCalendar(context: Context, token: String, year: Int, month: Int): Boolean {
            val calendars = fetchCalendarsCached(token, context)
            val hiddenCalendars = readHiddenCalendars(context)
            Log.d(TAG, "hiddenCalendars: $hiddenCalendars")

            val calList = if (calendars.isEmpty()) listOf(Pair("primary", DEFAULT_COLOR)) else calendars
            val visibleCals = calList.filter { !hiddenCalendars.contains(it.first) }

            val byDay = mutableMapOf<String, MutableList<EventItem>>()
            var fetchSucceeded = false

            for ((calId, calColor) in visibleCals) {
                runCatching {
                    val events = fetchEvents(token, calId, calColor, year, month)
                    fetchSucceeded = true  // 이 캘린더는 API 응답 성공
                    for (ev in events) {
                        byDay.getOrPut(ev.dayKey) { mutableListOf() }.add(ev)
                    }
                }.onFailure { Log.e(TAG, "fetchEvents failed for $calId: $it") }
            }

            // 모두 숨김 처리된 경우도 성공으로 간주 (쓸 데이터가 없는 게 정상)
            val succeeded = fetchSucceeded || visibleCals.isEmpty()
            if (!succeeded) {
                Log.e(TAG, "syncCalendar: all fetchEvents calls failed, not writing to prefs")
                return false
            }

            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val edit  = prefs.edit()

            val cal = java.util.Calendar.getInstance()
            cal.set(year, month - 1, 1)
            val daysInMonth = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)
            for (d in 1..daysInMonth) {
                val k = "%04d%02d%02d".format(year, month, d)
                edit.remove("cal_day_${k}_titles")
                edit.remove("cal_day_${k}_times")
                edit.remove("cal_day_${k}_ids")
                edit.remove("cal_day_${k}_colors")
            }

            for ((key, events) in byDay) {
                // 정렬 키를 Flutter updateCalendar와 동일하게 맞춘다(종일 먼저 → 실제
                // 시작 instant → id). 두 주체의 출력이 같아야 새로고침 시 깜빡임이 없다.
                events.sortWith(compareBy({ if (it.isAllDay) 0 else 1 }, { it.startMillis }, { it.id }))
                val take = events.take(25)
                edit.putString("cal_day_${key}_titles", take.joinToString("|") { it.title })
                edit.putString("cal_day_${key}_times",  take.joinToString("|") { it.time })
                edit.putString("cal_day_${key}_ids",    take.joinToString("|") { it.id })
                edit.putString("cal_day_${key}_colors", take.joinToString("|") { it.color })
            }
            edit.commit()
            Log.d(TAG, "syncCalendar written ${byDay.size} days to prefs")
            return true
        }

        private data class EventItem(val dayKey: String, val title: String, val time: String, val id: String, val color: String, val isAllDay: Boolean, val startMillis: Long)

        private fun fetchCalendarsCached(token: String, context: Context): List<Pair<String, String>> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val lastFetch = prefs.getLong("cal_list_fetched_at", 0L)
            val cached = prefs.getString("cal_list_cache", null)
            // 1시간 이내 캐시 유효
            if (cached != null && System.currentTimeMillis() - lastFetch < 60 * 60 * 1000L) {
                val result = mutableListOf<Pair<String, String>>()
                cached.split("\n").forEach { line ->
                    val parts = line.split("\t")
                    if (parts.size == 2) result.add(Pair(parts[0], parts[1]))
                }
                if (result.isNotEmpty()) {
                    Log.d(TAG, "using cached calendar list (${result.size} calendars)")
                    return result
                }
            }
            val result = fetchCalendars(token)
            if (result.isNotEmpty()) {
                prefs.edit()
                    .putString("cal_list_cache", result.joinToString("\n") { "${it.first}\t${it.second}" })
                    .putLong("cal_list_fetched_at", System.currentTimeMillis())
                    .apply()
            }
            return result
        }

        private fun fetchCalendars(token: String): List<Pair<String, String>> {
            val url = URL("https://www.googleapis.com/calendar/v3/users/me/calendarList?minAccessRole=reader")
            val body = doGet(token, url) ?: return emptyList()
            val items = JSONObject(body).optJSONArray("items") ?: return emptyList()
            val result = mutableListOf<Pair<String, String>>()
            for (i in 0 until items.length()) {
                val item  = items.getJSONObject(i)
                val id    = item.optString("id", "")
                val hex   = item.optString("backgroundColor", "#4285f4")
                val color = hexToArgb(hex)
                if (id.isNotEmpty()) result.add(Pair(id, color))
            }
            return result
        }

        private fun fetchEvents(token: String, calId: String, calColor: String, year: Int, month: Int): List<EventItem> {
            // 조회 구간을 기기 로컬 타임존 기준 월 경계로 계산해 UTC instant로 변환한다.
            // (UTC 자정으로 잡으면 KST(+9)에서 매월 1일 0~9시 일정이 누락됨 — 앱과 동일하게 맞춤)
            val zone = ZoneId.systemDefault()
            val monthStart = java.time.LocalDate.of(year, month, 1).atStartOfDay(zone)
            val timeMin = monthStart.toInstant().toString()
            val timeMax = monthStart.plusMonths(1).minusSeconds(1).toInstant().toString()

            val enc = java.net.URLEncoder.encode(calId, "UTF-8")
            val urlStr = "https://www.googleapis.com/calendar/v3/calendars/${enc}/events" +
                "?timeMin=${java.net.URLEncoder.encode(timeMin, "UTF-8")}" +
                "&timeMax=${java.net.URLEncoder.encode(timeMax, "UTF-8")}" +
                "&singleEvents=true&orderBy=startTime&maxResults=200"

            val body = doGet(token, URL(urlStr)) ?: return emptyList()
            val items = JSONObject(body).optJSONArray("items") ?: return emptyList()
            val result = mutableListOf<EventItem>()

            for (i in 0 until items.length()) {
                val item    = items.getJSONObject(i)
                val id      = item.optString("id", "")
                val summary = item.optString("summary", "").ifEmpty { WidgetStrings.noSubject }
                val colorId = item.optString("colorId", "")
                val color   = if (colorId.isNotEmpty()) EVENT_COLORS[colorId] ?: calColor else calColor

                val start   = item.optJSONObject("start") ?: continue
                val end     = item.optJSONObject("end")
                val dtStr   = start.optString("dateTime", "")
                val dateStr = start.optString("date", "")

                // 시작/마지막(포함) 날짜, 종일 여부, 시각 라벨, 정렬용 시작 millis 계산.
                var startDate: java.time.LocalDate? = null
                var lastDate: java.time.LocalDate? = null
                var isAllDay = false
                var timeLabel = ""
                var startMillis = 0L
                runCatching {
                    when {
                        dtStr.isNotEmpty() -> {
                            val zdt = OffsetDateTime.parse(dtStr).atZoneSameInstant(zone)
                            startDate = zdt.toLocalDate()
                            val eDt = end?.optString("dateTime", "") ?: ""
                            lastDate = if (eDt.isNotEmpty())
                                OffsetDateTime.parse(eDt).atZoneSameInstant(zone).toLocalDate() else startDate
                            isAllDay = false
                            timeLabel = "%02d:%02d".format(zdt.hour, zdt.minute)
                            startMillis = zdt.toInstant().toEpochMilli()
                        }
                        dateStr.length >= 10 -> {
                            val s = java.time.LocalDate.parse(dateStr)
                            startDate = s
                            val eDate = end?.optString("date", "") ?: ""
                            // 종일 end.date 는 exclusive → 마지막 포함일은 -1일
                            lastDate = if (eDate.length >= 10)
                                java.time.LocalDate.parse(eDate).minusDays(1) else s
                            isAllDay = true
                            timeLabel = WidgetStrings.allDay
                            startMillis = s.atStartOfDay(zone).toInstant().toEpochMilli()
                        }
                    }
                }
                val sDate = startDate ?: continue
                var lDate = lastDate ?: sDate
                if (lDate.isBefore(sDate)) lDate = sDate

                // 이 달 범위로 클램프해 걸친 모든 날에 하나씩 추가(여러 날 일정 반영)
                val monthFirst = java.time.LocalDate.of(year, month, 1)
                val monthLast = monthFirst.plusMonths(1).minusDays(1)
                var d = if (sDate.isBefore(monthFirst)) monthFirst else sDate
                val to = if (lDate.isAfter(monthLast)) monthLast else lDate
                while (!d.isAfter(to)) {
                    val k = "%04d%02d%02d".format(d.year, d.monthValue, d.dayOfMonth)
                    result.add(EventItem(k, summary, timeLabel, id, color, isAllDay, startMillis))
                    d = d.plusDays(1)
                }
            }
            return result
        }

        private fun doGet(token: String, url: URL): String? {
            var conn: HttpURLConnection? = null
            return try {
                conn = url.openConnection() as HttpURLConnection
                conn.setRequestProperty("Authorization", "Bearer $token")
                conn.connectTimeout = 15_000
                conn.readTimeout    = 15_000
                val code = conn.responseCode
                if (code in 200..299) {
                    conn.inputStream.bufferedReader().use { it.readText() }
                } else {
                    if (code == 401) throw Exception("HTTP 401")
                    null
                }
            } finally {
                conn?.disconnect()
            }
        }

        private fun hexToArgb(hex: String): String {
            val h = hex.trimStart('#').padStart(6, '0').take(6)
            return "#ff$h"
        }

        private fun readToken(context: Context): String? = TokenManager.readCachedToken(context)

        private fun freshToken(context: Context): String? =
            TokenManager.fetchFreshToken(context, "oauth2:https://www.googleapis.com/auth/calendar.readonly")
    }
}

