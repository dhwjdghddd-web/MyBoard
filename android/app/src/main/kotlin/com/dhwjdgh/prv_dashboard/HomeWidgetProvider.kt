package com.dhwjdgh.prv_dashboard

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.AbsoluteSizeSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.graphics.Typeface

class HomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        when (intent.action) {
            ACTION_COMPLETE_TASK -> {
                val taskId    = intent.getStringExtra("task_id") ?: return
                val taskIndex = intent.getIntExtra("task_index", -1)
                val current   = prefs.getString("pending_completions", "") ?: ""
                prefs.edit()
                    .putString("task_${taskIndex}_done", "true")
                    .putString("pending_completions", if (current.isEmpty()) taskId else "$current,$taskId")
                    .apply()
                redraw(context)
            }
            ACTION_DELETE_TASK -> {
                val taskId    = intent.getStringExtra("task_id") ?: return
                val taskIndex = intent.getIntExtra("task_index", -1)
                val current   = prefs.getString("pending_deletions", "") ?: ""
                prefs.edit()
                    .putString("pending_deletions", if (current.isEmpty()) taskId else "$current,$taskId")
                    .putString("task_$taskIndex", "")
                    .putString("task_${taskIndex}_id", "")
                    .putString("task_${taskIndex}_done", "false")
                    .apply()
                redraw(context)
            }
            ACTION_SWITCH_TAB -> {
                val tab = intent.getIntExtra("tab", 0)
                prefs.edit().putInt("active_widget_tab", tab).apply()
                redraw(context)
            }
            ACTION_CAL_PREV_MONTH -> {
                var y = prefs.getInt("cal_display_year",  now().get(java.util.Calendar.YEAR))
                var m = prefs.getInt("cal_display_month", now().get(java.util.Calendar.MONTH) + 1)
                m--; if (m < 1) { m = 12; y-- }
                prefs.edit().putInt("cal_display_year", y).putInt("cal_display_month", m)
                    .putBoolean("cal_show_day_panel", false).apply()
                redraw(context)
            }
            ACTION_CAL_NEXT_MONTH -> {
                var y = prefs.getInt("cal_display_year",  now().get(java.util.Calendar.YEAR))
                var m = prefs.getInt("cal_display_month", now().get(java.util.Calendar.MONTH) + 1)
                m++; if (m > 12) { m = 1; y++ }
                prefs.edit().putInt("cal_display_year", y).putInt("cal_display_month", m)
                    .putBoolean("cal_show_day_panel", false).apply()
                redraw(context)
            }
            ACTION_CAL_SELECT_DATE -> {
                val dateKey = intent.getStringExtra("date_key") ?: return
                prefs.edit().putBoolean("cal_show_day_panel", true)
                    .putString("cal_selected_date", dateKey).apply()
                redraw(context)
            }
            ACTION_CAL_BACK -> {
                prefs.edit().putBoolean("cal_show_day_panel", false).apply()
                redraw(context)
            }
        }
    }

    companion object {
        private const val PREFS = "HomeWidgetPreferences"
        const val ACTION_COMPLETE_TASK   = "com.dhwjdgh.prv_dashboard.COMPLETE_TASK"
        const val ACTION_DELETE_TASK     = "com.dhwjdgh.prv_dashboard.DELETE_TASK"
        const val ACTION_SWITCH_TAB      = "com.dhwjdgh.prv_dashboard.SWITCH_WIDGET_TAB"
        const val ACTION_CAL_PREV_MONTH  = "com.dhwjdgh.prv_dashboard.CAL_PREV_MONTH"
        const val ACTION_CAL_NEXT_MONTH  = "com.dhwjdgh.prv_dashboard.CAL_NEXT_MONTH"
        const val ACTION_CAL_SELECT_DATE = "com.dhwjdgh.prv_dashboard.CAL_SELECT_DATE"
        const val ACTION_CAL_BACK        = "com.dhwjdgh.prv_dashboard.CAL_BACK"

        private val CELL_IDS = arrayOf(
            intArrayOf(R.id.c00, R.id.c01, R.id.c02, R.id.c03, R.id.c04, R.id.c05, R.id.c06),
            intArrayOf(R.id.c10, R.id.c11, R.id.c12, R.id.c13, R.id.c14, R.id.c15, R.id.c16),
            intArrayOf(R.id.c20, R.id.c21, R.id.c22, R.id.c23, R.id.c24, R.id.c25, R.id.c26),
            intArrayOf(R.id.c30, R.id.c31, R.id.c32, R.id.c33, R.id.c34, R.id.c35, R.id.c36),
            intArrayOf(R.id.c40, R.id.c41, R.id.c42, R.id.c43, R.id.c44, R.id.c45, R.id.c46),
            intArrayOf(R.id.c50, R.id.c51, R.id.c52, R.id.c53, R.id.c54, R.id.c55, R.id.c56),
        )

        private fun now() = java.util.Calendar.getInstance()

        private fun redraw(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
            for (id in ids) updateWidget(context, mgr, id)
        }

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs     = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views     = RemoteViews(context.packageName, R.layout.home_widget_layout)
            val activeTab = prefs.getInt("active_widget_tab", 0)

            views.setViewVisibility(R.id.section_tasks,    if (activeTab == 0) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.section_calendar, if (activeTab == 1) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.section_gmail,    if (activeTab == 2) View.VISIBLE else View.GONE)

            val BLUE  = Color.parseColor("#4285F4")
            val GREEN = Color.parseColor("#0F9D58")
            val RED   = Color.parseColor("#EA4335")
            val DIM   = Color.parseColor("#9090A0")
            val DARK  = Color.parseColor("#2A2A3E")

            views.setTextColor(R.id.tab_tasks,    if (activeTab == 0) BLUE  else DIM)
            views.setTextColor(R.id.tab_calendar, if (activeTab == 1) GREEN else DIM)
            views.setTextColor(R.id.tab_gmail,    if (activeTab == 2) RED   else DIM)
            views.setInt(R.id.ind_tasks,    "setBackgroundColor", if (activeTab == 0) BLUE  else DARK)
            views.setInt(R.id.ind_calendar, "setBackgroundColor", if (activeTab == 1) GREEN else DARK)
            views.setInt(R.id.ind_gmail,    "setBackgroundColor", if (activeTab == 2) RED   else DARK)

            views.setOnClickPendingIntent(R.id.tab_tasks,    switchTabIntent(context, 0))
            views.setOnClickPendingIntent(R.id.tab_calendar, switchTabIntent(context, 1))
            views.setOnClickPendingIntent(R.id.tab_gmail,    switchTabIntent(context, 2))

            bindTasks(context, views, prefs)
            bindCalendar(context, views, prefs)
            bindGmail(context, views, prefs)

            manager.notifyAppWidgetViewDataChanged(widgetId, R.id.gmail_list_view)

            manager.updateAppWidget(widgetId, views)
        }

        // ─────────────────────────────────────────────────────────────────
        //  태스크 섹션
        // ─────────────────────────────────────────────────────────────────
        private fun bindTasks(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences) {
            data class TRow(val row: Int, val title: Int, val check: Int, val del: Int)
            val rows = listOf(
                TRow(R.id.task_row_0, R.id.task_title_0, R.id.task_check_0, R.id.task_delete_0),
                TRow(R.id.task_row_1, R.id.task_title_1, R.id.task_check_1, R.id.task_delete_1),
                TRow(R.id.task_row_2, R.id.task_title_2, R.id.task_check_2, R.id.task_delete_2),
            )
            var visible = 0
            for ((i, r) in rows.withIndex()) {
                val title  = prefs.getString("task_$i", "") ?: ""
                val done   = prefs.getString("task_${i}_done", "false") == "true"
                val taskId = prefs.getString("task_${i}_id", "") ?: ""
                if (title.isEmpty()) {
                    views.setViewVisibility(r.row, View.GONE)
                } else {
                    views.setViewVisibility(r.row, View.VISIBLE)
                    views.setTextViewText(r.title, title)
                    views.setTextColor(r.title, if (done) Color.parseColor("#606070") else Color.WHITE)
                    views.setTextViewText(r.check, if (done) "☑" else "☐")
                    views.setTextColor(r.check, if (done) Color.parseColor("#606070") else Color.parseColor("#4285F4"))
                    if (!done && taskId.isNotEmpty()) {
                        views.setOnClickPendingIntent(r.check, PendingIntent.getBroadcast(
                            context, 100 + i,
                            Intent(context, HomeWidgetProvider::class.java).apply {
                                action = ACTION_COMPLETE_TASK
                                putExtra("task_id", taskId); putExtra("task_index", i)
                            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        ))
                    }
                    if (taskId.isNotEmpty()) {
                        views.setOnClickPendingIntent(r.del, PendingIntent.getBroadcast(
                            context, 400 + i,
                            Intent(context, HomeWidgetProvider::class.java).apply {
                                action = ACTION_DELETE_TASK
                                putExtra("task_id", taskId); putExtra("task_index", i)
                            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        ))
                    }
                    views.setOnClickPendingIntent(r.row, openAppIntent(context, 0))
                    visible++
                }
            }
            views.setViewVisibility(R.id.task_empty, if (visible == 0) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(R.id.task_add_btn, quickAddTaskIntent(context))
        }

        // ─────────────────────────────────────────────────────────────────
        //  캘린더 섹션
        // ─────────────────────────────────────────────────────────────────
        private fun bindCalendar(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences) {
            val showDayPanel = prefs.getBoolean("cal_show_day_panel", false)

            views.setViewVisibility(R.id.cal_grid_panel, if (!showDayPanel) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.cal_day_panel,  if (showDayPanel)  View.VISIBLE else View.GONE)

            if (showDayPanel) {
                bindCalendarDayPanel(context, views, prefs)
            } else {
                bindCalendarGrid(context, views, prefs)
            }
        }

        private fun bindCalendarGrid(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences) {
            val actual      = now()
            val actualYear  = actual.get(java.util.Calendar.YEAR)
            val actualMonth = actual.get(java.util.Calendar.MONTH) + 1
            val actualToday = actual.get(java.util.Calendar.DAY_OF_MONTH)
            val dispYear    = prefs.getInt("cal_display_year",  actualYear)
            val dispMonth   = prefs.getInt("cal_display_month", actualMonth)

            val monthNames = arrayOf("","1월","2월","3월","4월","5월","6월","7월","8월","9월","10월","11월","12월")
            views.setTextViewText(R.id.cal_month_label, "${dispYear}년 ${monthNames[dispMonth]}")

            views.setOnClickPendingIntent(R.id.cal_prev, PendingIntent.getBroadcast(
                context, 700,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_CAL_PREV_MONTH },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            views.setOnClickPendingIntent(R.id.cal_next, PendingIntent.getBroadcast(
                context, 701,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_CAL_NEXT_MONTH },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            views.setOnClickPendingIntent(R.id.cal_add_btn, openAppWithActionIntent(context, "create_event"))

            val cal = java.util.Calendar.getInstance()
            cal.set(dispYear, dispMonth - 1, 1)
            val firstDow    = cal.get(java.util.Calendar.DAY_OF_WEEK) - 1
            val daysInMonth = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)

            for (row in 0..5) {
                for (col in 0..6) {
                    val idx    = row * 7 + col
                    val day    = idx - firstDow + 1
                    val cellId = CELL_IDS[row][col]

                    if (day < 1 || day > daysInMonth) {
                        views.setTextViewText(cellId, "")
                        views.setInt(cellId, "setBackgroundColor", Color.TRANSPARENT)
                    } else {
                        val isToday  = dispYear == actualYear && dispMonth == actualMonth && day == actualToday
                        
                        val dateKey = "%04d-%02d-%02d".format(dispYear, dispMonth, day)
                        val compactKey = "%04d%02d%02d".format(dispYear, dispMonth, day)
                        
                        val titlesRaw = prefs.getString("cal_day_${compactKey}_titles", "") ?: ""
                        val colorsRaw = prefs.getString("cal_day_${compactKey}_colors", "") ?: ""

                        val titles = if (titlesRaw.isEmpty()) emptyList() else titlesRaw.split("|")
                        val colors = if (colorsRaw.isEmpty()) emptyList() else colorsRaw.split("|")

                        val ssb = SpannableStringBuilder()
                        
                        // 1. 날짜 숫자 추가
                        val dayStr = day.toString()
                        ssb.append(dayStr)
                        
                        // 날짜 부분 스타일 지정 (10sp, 볼드여부, 요일별 색상)
                        val dayColor = when {
                            isToday  -> Color.WHITE
                            col == 0 -> Color.parseColor("#FF6B6B")
                            col == 6 -> Color.parseColor("#6B9FFF")
                            else     -> Color.parseColor("#D0D0E0")
                        }
                        ssb.setSpan(AbsoluteSizeSpan(10, true), 0, dayStr.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        ssb.setSpan(ForegroundColorSpan(dayColor), 0, dayStr.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        if (isToday) {
                            ssb.setSpan(StyleSpan(Typeface.BOLD), 0, dayStr.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        }

                        // 2. 일정 제목 추가 (최대 2개)
                        val displayTitles = titles.take(2)
                        for (i in displayTitles.indices) {
                            ssb.append("\n")
                            val start = ssb.length
                            val title = displayTitles[i]
                            // 너무 길면 4글자 + .. 처리 (셀 크기가 매우 좁음)
                            val truncatedTitle = if (title.length > 5) title.substring(0, 4) + ".." else title
                            ssb.append(truncatedTitle)
                            val end = ssb.length

                            val colorStr = colors.getOrNull(i)
                            val eventColor = try {
                                if (!colorStr.isNullOrEmpty()) Color.parseColor(colorStr) else Color.parseColor("#60D8A0")
                            } catch (e: Exception) {
                                Color.parseColor("#60D8A0")
                            }

                            ssb.setSpan(AbsoluteSizeSpan(7, true), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                            ssb.setSpan(ForegroundColorSpan(eventColor), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        }

                        views.setTextViewText(cellId, ssb)

                        if (isToday) views.setInt(cellId, "setBackgroundResource", R.drawable.cal_today_bg)
                        else         views.setInt(cellId, "setBackgroundColor", Color.TRANSPARENT)

                        // 날짜 탭 → 위젯 내 일정 패널로 전환 (앱 열지 않음)
                        views.setOnClickPendingIntent(cellId, PendingIntent.getBroadcast(
                            context, 800 + idx,
                            Intent(context, HomeWidgetProvider::class.java).apply {
                                action = ACTION_CAL_SELECT_DATE
                                putExtra("date_key", dateKey)
                            },
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        ))
                    }
                }
            }
        }

        private fun bindCalendarDayPanel(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences) {
            val dateKey = prefs.getString("cal_selected_date", "") ?: ""

            // 날짜 레이블 (MM/DD 요일 형식)
            val label = if (dateKey.length >= 10) {
                val m = dateKey.substring(5, 7).trimStart('0')
                val d = dateKey.substring(8, 10).trimStart('0')
                val dName = try {
                    val cal = java.util.Calendar.getInstance()
                    cal.set(dateKey.substring(0, 4).toInt(), dateKey.substring(5, 7).toInt() - 1, d.toInt())
                    arrayOf("일", "월", "화", "수", "목", "금", "토")[cal.get(java.util.Calendar.DAY_OF_WEEK) - 1]
                } catch (_: Exception) { "" }
                "${m}월 ${d}일 ($dName)"
            } else ""
            views.setTextViewText(R.id.cal_day_label, label)

            // 뒤로 버튼
            views.setOnClickPendingIntent(R.id.cal_back_btn, PendingIntent.getBroadcast(
                context, 702,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_CAL_BACK },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))

            // 일정 추가 → 앱 열기
            views.setOnClickPendingIntent(R.id.cal_day_add_btn,
                openCalendarDateAppIntent(context, dateKey))

            // 저장된 일정 데이터 로드 (compact key: cal_day_YYYYMMDD)
            val compactKey = dateKey.replace("-", "")
            val titlesRaw = prefs.getString("cal_day_${compactKey}_titles", "") ?: ""
            val timesRaw  = prefs.getString("cal_day_${compactKey}_times",  "") ?: ""
            val idsRaw    = prefs.getString("cal_day_${compactKey}_ids",    "") ?: ""
            val colorsRaw = prefs.getString("cal_day_${compactKey}_colors", "") ?: ""

            val titles = if (titlesRaw.isEmpty()) emptyList() else titlesRaw.split("|")
            val times  = if (timesRaw.isEmpty())  emptyList() else timesRaw.split("|")
            val ids    = if (idsRaw.isEmpty())     emptyList() else idsRaw.split("|")
            val colors = if (colorsRaw.isEmpty()) emptyList() else colorsRaw.split("|")

            data class DayRow(val row: Int, val time: Int, val title: Int, val colorBar: Int)
            val dayRows = listOf(
                DayRow(R.id.cal_day_row_0, R.id.cal_day_time_0, R.id.cal_day_title_0, R.id.cal_day_color_0),
                DayRow(R.id.cal_day_row_1, R.id.cal_day_time_1, R.id.cal_day_title_1, R.id.cal_day_color_1),
                DayRow(R.id.cal_day_row_2, R.id.cal_day_time_2, R.id.cal_day_title_2, R.id.cal_day_color_2),
                DayRow(R.id.cal_day_row_3, R.id.cal_day_time_3, R.id.cal_day_title_3, R.id.cal_day_color_3),
            )
            var visible = 0
            for ((i, r) in dayRows.withIndex()) {
                if (i < titles.size && titles[i].isNotEmpty()) {
                    views.setViewVisibility(r.row, View.VISIBLE)
                    views.setTextViewText(r.time, times.getOrElse(i) { "" })
                    views.setTextViewText(r.title, titles[i])
                    
                    val colorStr = colors.getOrNull(i)
                    val eventColor = try {
                        if (!colorStr.isNullOrEmpty()) Color.parseColor(colorStr) else Color.parseColor("#4285F4")
                    } catch (e: Exception) {
                        Color.parseColor("#4285F4")
                    }
                    views.setInt(r.colorBar, "setBackgroundColor", eventColor)

                    val evId = ids.getOrElse(i) { "" }
                    views.setOnClickPendingIntent(r.row,
                        if (evId.isNotEmpty()) openEventDetailIntent(context, evId, dateKey, i)
                        else openCalendarDateAppIntent(context, dateKey)
                    )
                    visible++
                } else {
                    views.setViewVisibility(r.row, View.GONE)
                }
            }
            views.setViewVisibility(R.id.cal_day_empty, if (visible == 0) View.VISIBLE else View.GONE)
        }

        // ─────────────────────────────────────────────────────────────────
        //  Gmail 섹션
        // ─────────────────────────────────────────────────────────────────
        private fun bindGmail(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences) {
            val count = try {
                prefs.getInt("gmail_count", 0)
            } catch (e: ClassCastException) {
                prefs.getString("gmail_count", "0")?.toIntOrNull() ?: 0
            }

            if (count == 0) {
                views.setViewVisibility(R.id.gmail_list_view, View.GONE)
                views.setViewVisibility(R.id.gmail_empty, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.gmail_list_view, View.VISIBLE)
                views.setViewVisibility(R.id.gmail_empty, View.GONE)

                // Bind ListView to RemoteViewsService
                val intent = Intent(context, GmailWidgetService::class.java)
                views.setRemoteAdapter(R.id.gmail_list_view, intent)

                // Bind PendingIntent template for list items
                val clickIntentTemplate = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val clickPendingIntentTemplate = PendingIntent.getActivity(
                    context,
                    350,
                    clickIntentTemplate,
                    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setPendingIntentTemplate(R.id.gmail_list_view, clickPendingIntentTemplate)
            }

            // compose 버튼 → 앱의 Gmail 작성 화면
            views.setOnClickPendingIntent(R.id.gmail_compose_btn, openAppWithActionIntent(context, "compose_email"))
        }

        // ─────────────────────────────────────────────────────────────────
        //  PendingIntent 팩토리
        // ─────────────────────────────────────────────────────────────────
        private fun switchTabIntent(context: Context, tab: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context, 200 + tab,
                Intent(context, HomeWidgetProvider::class.java).apply {
                    action = ACTION_SWITCH_TAB; putExtra("tab", tab)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun openAppIntent(context: Context, tab: Int): PendingIntent =
            PendingIntent.getActivity(
                context, tab,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("tab", tab)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun quickAddTaskIntent(context: Context): PendingIntent =
            PendingIntent.getActivity(
                context, 550,
                Intent(context, QuickAddTaskActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun openAppWithActionIntent(context: Context, action: String): PendingIntent =
            PendingIntent.getActivity(
                context, when (action) { "create_task" -> 500; "create_event" -> 501; "compose_email" -> 503; else -> 502 },
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("action", action)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun openCalendarDateAppIntent(context: Context, dateKey: String): PendingIntent =
            PendingIntent.getActivity(
                context, 850,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("date_key", dateKey)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun openEventDetailIntent(
            context: Context, eventId: String, dateKey: String, index: Int
        ): PendingIntent =
            PendingIntent.getActivity(
                context, 600 + index,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("event_id", eventId)
                    putExtra("date_key", dateKey)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun openEmailIntent(context: Context, emailId: String, index: Int): PendingIntent =
            PendingIntent.getActivity(
                context, 300 + index,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("tab", 2)
                    if (emailId.isNotEmpty()) putExtra("email_id", emailId)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
    }
}
