package com.dhwjdgh.prv_dashboard

import android.app.job.JobParameters
import android.app.job.JobService
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import com.google.android.gms.auth.api.signin.GoogleSignIn
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
            Log.d(TAG, "executeSyncInternal: $year/$month")
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (!token.isNullOrEmpty()) {
                var result = runCatching { syncCalendar(context, token!!, year, month) }
                    .onSuccess { Log.d(TAG, "syncCalendar success: fetched=$it") }
                    .getOrNull()
                if (result == null || !result) {
                    Log.e(TAG, "syncCalendar failed or no data — retrying with fresh token")
                    val freshT = freshToken(context)
                    if (freshT != null) {
                        result = runCatching { syncCalendar(context, freshT, year, month) }
                            .onSuccess { Log.d(TAG, "syncCalendar retry success: fetched=$it") }
                            .onFailure { e2 -> Log.e(TAG, "syncCalendar retry failed: $e2") }
                            .getOrNull()
                    }
                }
                return result == true
            } else {
                Log.e(TAG, "No token available — sync skipped")
                return false
            }
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
                events.sortWith(Comparator { a, b ->
                    val aAllDay = a.time == "종일"
                    val bAllDay = b.time == "종일"
                    if (aAllDay && !bAllDay) return@Comparator -1
                    if (!aAllDay && bAllDay) return@Comparator 1
                    a.time.compareTo(b.time)
                })
                val take = events.take(4)
                edit.putString("cal_day_${key}_titles", take.joinToString("|") { it.title })
                edit.putString("cal_day_${key}_times",  take.joinToString("|") { it.time })
                edit.putString("cal_day_${key}_ids",    take.joinToString("|") { it.id })
                edit.putString("cal_day_${key}_colors", take.joinToString("|") { it.color })
            }
            edit.commit()
            Log.d(TAG, "syncCalendar written ${byDay.size} days to prefs")
            return true
        }

        private data class EventItem(val dayKey: String, val title: String, val time: String, val id: String, val color: String)

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
            val cal = java.util.Calendar.getInstance()
            cal.set(year, month - 1, 1)
            val lastDay = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)
            val ym = "%04d-%02d".format(year, month)
            val timeMin = "${ym}-01T00:00:00Z"
            val timeMax = "${ym}-%02dT23:59:59Z".format(lastDay)

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
                val summary = item.optString("summary", "(제목 없음)")
                val colorId = item.optString("colorId", "")
                val color   = if (colorId.isNotEmpty()) EVENT_COLORS[colorId] ?: calColor else calColor

                val start   = item.optJSONObject("start") ?: continue
                val dtStr   = start.optString("dateTime", "")
                val dateStr = start.optString("date", "")

                val (dayKey, time) = when {
                    dtStr.isNotEmpty() -> runCatching {
                        val odt   = OffsetDateTime.parse(dtStr)
                        val local = odt.atZoneSameInstant(ZoneId.systemDefault()).toLocalDateTime()
                        val k = "%04d%02d%02d".format(local.year, local.monthValue, local.dayOfMonth)
                        Pair(k, "%02d:%02d".format(local.hour, local.minute))
                    }.getOrNull() ?: continue
                    dateStr.length >= 10 -> Pair(dateStr.replace("-", "").substring(0, 8), "종일")
                    else -> continue
                }
                result.add(EventItem(dayKey, summary, time, id, color))
            }
            return result
        }

        private fun doGet(token: String, url: URL): String? {
            val conn = url.openConnection() as HttpURLConnection
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.connectTimeout = 15_000
            conn.readTimeout    = 15_000
            val code = conn.responseCode
            return if (code in 200..299) {
                conn.inputStream.bufferedReader().use { it.readText() }.also { conn.disconnect() }
            } else {
                conn.disconnect()
                if (code == 401) throw Exception("HTTP 401")
                null
            }
        }

        private fun hexToArgb(hex: String): String {
            val h = hex.trimStart('#').padStart(6, '0').take(6)
            return "#ff$h"
        }

        private fun readToken(context: Context): String? = runCatching {
            val alias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
            EncryptedSharedPreferences.create(
                "FlutterSecureStorage", alias, context,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            ).getString("VGtWcmJHbHVaMjl1_access_token", null)
        }.getOrNull()

        private fun freshToken(context: Context): String? = runCatching {
            val acct = GoogleSignIn.getLastSignedInAccount(context) ?: return null
            val scope = "oauth2:https://www.googleapis.com/auth/calendar.readonly " +
                        "https://www.googleapis.com/auth/tasks " +
                        "https://www.googleapis.com/auth/gmail.modify"
            com.google.android.gms.auth.GoogleAuthUtil.getToken(context, acct.account!!, scope)
        }.getOrNull()
    }
}
