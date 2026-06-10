package com.dhwjdgh.prv_dashboard

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.Log
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
        val displayWidthDp = (context.resources.displayMetrics.widthPixels /
            context.resources.displayMetrics.density).toInt()
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val edit = prefs.edit()
        for (id in appWidgetIds) {
            val opts = appWidgetManager.getAppWidgetOptions(id)
            val ww = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 300)
            val wh = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 300)
            
            // 실제 측정 결과 Z플립 커버스크린 위젯의 해상도 수치가 홈스크린보다 더 크게 감지됨 (커버 W:438 H:352 vs 홈 W:315 H:289)
            // 따라서 가로가 415dp 이상이거나 세로가 320dp 이상인 위젯을 커버스크린 위젯으로 정확하게 판단
            val isCover = ww >= 415 || wh >= 320
            edit.putBoolean("widget_is_cover_$id", isCover)
            Log.d("HomeWidget", "onUpdate id=$id displayW=$displayWidthDp widgetW=$ww widgetH=$wh isCover=$isCover")
        }
        edit.apply()
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: android.os.Bundle) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val displayWidthDp = (context.resources.displayMetrics.widthPixels /
            context.resources.displayMetrics.density).toInt()
        val ww = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 300)
        val wh = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 300)
        
        val isCover = ww >= 415 || wh >= 320
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("widget_is_cover_$appWidgetId", isCover).apply()
        Log.d("HomeWidget", "optionsChanged id=$appWidgetId displayW=$displayWidthDp widgetW=$ww widgetH=$wh isCover=$isCover")
        updateWidget(context, appWidgetManager, appWidgetId)
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

                // 백그라운드 API 동기화 구동 (앱 켜짐 없음)
                val pendingResult = goAsync()
                TasksSyncJobService.executeComplete(context, taskId, true) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        MainActivity.activeChannel?.invokeMethod("taskCompleted", taskId)
                    }
                    pendingResult.finish()
                }
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

                // 백그라운드 API 동기화 구동 (앱 켜짐 없음)
                val pendingResult = goAsync()
                TasksSyncJobService.executeDelete(context, taskId) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        MainActivity.activeChannel?.invokeMethod("taskDeleted", taskId)
                    }
                    pendingResult.finish()
                }
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
                val pendingResult = goAsync()
                CalendarSyncJobService.executeSync(context, y, m) { pendingResult.finish() }
            }
            ACTION_CAL_NEXT_MONTH -> {
                var y = prefs.getInt("cal_display_year",  now().get(java.util.Calendar.YEAR))
                var m = prefs.getInt("cal_display_month", now().get(java.util.Calendar.MONTH) + 1)
                m++; if (m > 12) { m = 1; y++ }
                prefs.edit().putInt("cal_display_year", y).putInt("cal_display_month", m)
                    .putBoolean("cal_show_day_panel", false).apply()
                redraw(context)
                val pendingResult = goAsync()
                CalendarSyncJobService.executeSync(context, y, m) { pendingResult.finish() }
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
            ACTION_REFRESH_GMAIL -> {
                Log.d("HomeWidget", "REFRESH_GMAIL received")
                val pendingResult = goAsync()
                prefs.edit().putBoolean("gmail_scroll_to_top", true).apply()
                partiallySetBtnColor(context, R.id.gmail_refresh_btn, "#FFA000")
                GmailSyncJobService.executeSync(context) {
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
                    Log.d("HomeWidget", "sync done → updating ${ids.size} widget(s), gmail_count=${context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("gmail_count", -1)}")
                    partiallySetBtnColor(context, R.id.gmail_refresh_btn, "#4CAF50")
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        partiallySetBtnColor(context, R.id.gmail_refresh_btn, "#FFFFFF")
                    }, 1500)
                    for (id in ids) updateWidget(context, mgr, id)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        MainActivity.activeChannel?.invokeMethod("refreshData", null)
                    }
                    pendingResult.finish()
                }
            }
            ACTION_REFRESH_TASKS -> {
                val pendingResult = goAsync()
                partiallySetBtnColor(context, R.id.task_refresh_btn, "#FFA000")
                TasksSyncJobService.executeSync(context) {
                    val mgr = AppWidgetManager.getInstance(context)
                    val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
                    partiallySetBtnColor(context, R.id.task_refresh_btn, "#4CAF50")
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        partiallySetBtnColor(context, R.id.task_refresh_btn, "#FFFFFF")
                    }, 1500)
                    for (id in ids) updateWidget(context, mgr, id)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        MainActivity.activeChannel?.invokeMethod("refreshData", null)
                    }
                    pendingResult.finish()
                }
            }
            ACTION_REFRESH_CALENDAR -> {
                val y = prefs.getInt("cal_display_year",  now().get(java.util.Calendar.YEAR))
                val m = prefs.getInt("cal_display_month", now().get(java.util.Calendar.MONTH) + 1)
                val pendingResult = goAsync()
                partiallySetBtnColor(context, R.id.cal_refresh_btn, "#FFA000")
                CalendarSyncJobService.executeSync(context, y, m) {
                    partiallySetBtnColor(context, R.id.cal_refresh_btn, "#4CAF50")
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        partiallySetBtnColor(context, R.id.cal_refresh_btn, "#FFFFFF")
                    }, 1500)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        MainActivity.activeChannel?.invokeMethod("refreshData", null)
                    }
                    pendingResult.finish()
                }
            }
            ACTION_TASK_ITEM -> {
                val taskId    = intent.getStringExtra("task_id") ?: ""
                val taskIndex = intent.getIntExtra("task_index", -1)
                when (intent.getStringExtra("task_item_action")) {
                    "complete" -> {
                        if (taskIndex >= 0) {
                            prefs.edit().putString("task_${taskIndex}_done", "true").apply()
                        }
                        val mgr = AppWidgetManager.getInstance(context)
                        val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
                        ids.forEach { mgr.notifyAppWidgetViewDataChanged(it, R.id.task_list_view) }
                        redraw(context)
                        if (taskId.isNotEmpty()) {
                            val pendingResult = goAsync()
                            TasksSyncJobService.executeComplete(context, taskId, true) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    MainActivity.activeChannel?.invokeMethod("taskCompleted", taskId)
                                }
                                pendingResult.finish()
                            }
                        }
                    }
                    "delete" -> {
                        if (taskIndex >= 0) {
                            prefs.edit()
                                .putString("task_$taskIndex", "")
                                .putString("task_${taskIndex}_id", "")
                                .putString("task_${taskIndex}_done", "false")
                                .apply()
                        }
                        val mgr = AppWidgetManager.getInstance(context)
                        val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
                        ids.forEach { mgr.notifyAppWidgetViewDataChanged(it, R.id.task_list_view) }
                        redraw(context)
                        if (taskId.isNotEmpty()) {
                            val pendingResult = goAsync()
                            TasksSyncJobService.executeDelete(context, taskId) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    MainActivity.activeChannel?.invokeMethod("taskDeleted", taskId)
                                }
                                pendingResult.finish()
                            }
                        }
                    }
                    else -> {
                        context.startActivity(
                            Intent(context, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("tab", 0)
                            }
                        )
                    }
                }
            }
            ACTION_GMAIL_ITEM -> {
                when (intent.getStringExtra("gmail_item_action")) {
                    "delete" -> {
                        val emailId = intent.getStringExtra("email_id") ?: ""
                        val idx     = intent.getIntExtra("email_idx", -1)
                        deleteGmailItemLocal(context, prefs, idx)
                        redraw(context)
                        if (emailId.isNotEmpty()) {
                            val pendingResult = goAsync()
                            GmailSyncJobService.executeTrash(context, emailId) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post {
                                    MainActivity.activeChannel?.invokeMethod("gmailDeleted", emailId)
                                }
                                pendingResult.finish()
                            }
                        }
                    }
                    else -> {
                        val emailId = intent.getStringExtra("email_id") ?: ""
                        context.startActivity(
                            Intent(context, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("tab", 2)
                                if (emailId.isNotEmpty()) putExtra("email_id", emailId)
                            }
                        )
                    }
                }
            }
        }
    }

    companion object {
        private const val PREFS = "HomeWidgetPreferences"
        const val ACTION_COMPLETE_TASK   = "com.dhwjdgh.prv_dashboard.COMPLETE_TASK"
        const val ACTION_DELETE_TASK     = "com.dhwjdgh.prv_dashboard.DELETE_TASK"
        const val ACTION_TASK_ITEM       = "com.dhwjdgh.prv_dashboard.TASK_ITEM"
        const val ACTION_SWITCH_TAB      = "com.dhwjdgh.prv_dashboard.SWITCH_WIDGET_TAB"
        const val ACTION_CAL_PREV_MONTH  = "com.dhwjdgh.prv_dashboard.CAL_PREV_MONTH"
        const val ACTION_CAL_NEXT_MONTH  = "com.dhwjdgh.prv_dashboard.CAL_NEXT_MONTH"
        const val ACTION_CAL_SELECT_DATE = "com.dhwjdgh.prv_dashboard.CAL_SELECT_DATE"
        const val ACTION_CAL_BACK        = "com.dhwjdgh.prv_dashboard.CAL_BACK"
        const val ACTION_GMAIL_ITEM      = "com.dhwjdgh.prv_dashboard.GMAIL_ITEM"
        const val ACTION_REFRESH_GMAIL   = "com.dhwjdgh.prv_dashboard.REFRESH_GMAIL"
        const val ACTION_REFRESH_TASKS   = "com.dhwjdgh.prv_dashboard.REFRESH_TASKS"
        const val ACTION_REFRESH_CALENDAR = "com.dhwjdgh.prv_dashboard.REFRESH_CALENDAR"

        private val CELL_IDS = arrayOf(
            intArrayOf(R.id.c00, R.id.c01, R.id.c02, R.id.c03, R.id.c04, R.id.c05, R.id.c06),
            intArrayOf(R.id.c10, R.id.c11, R.id.c12, R.id.c13, R.id.c14, R.id.c15, R.id.c16),
            intArrayOf(R.id.c20, R.id.c21, R.id.c22, R.id.c23, R.id.c24, R.id.c25, R.id.c26),
            intArrayOf(R.id.c30, R.id.c31, R.id.c32, R.id.c33, R.id.c34, R.id.c35, R.id.c36),
            intArrayOf(R.id.c40, R.id.c41, R.id.c42, R.id.c43, R.id.c44, R.id.c45, R.id.c46),
            intArrayOf(R.id.c50, R.id.c51, R.id.c52, R.id.c53, R.id.c54, R.id.c55, R.id.c56),
        )

        private val WEEK_ROW_IDS = intArrayOf(
            R.id.cal_week_0, R.id.cal_week_1, R.id.cal_week_2,
            R.id.cal_week_3, R.id.cal_week_4, R.id.cal_week_5,
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

            // only bind the active tab — avoids 42-cell calendar render on every tab switch
            val opts = manager.getAppWidgetOptions(widgetId)
            val widgetWidth  = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,  300)
            val widgetHeight = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 300)
            
            // 실시간 및 SharedPreferences 다중 식별 적용
            val category = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_HOST_CATEGORY, -1)
            val isCoverDirect = widgetWidth >= 415 || widgetHeight >= 320
            val isCover = isCoverDirect || prefs.getBoolean("widget_is_cover_$widgetId", false)
            Log.d("HomeWidget", "updateWidget id=$widgetId w=$widgetWidth h=$widgetHeight isCoverDirect=$isCoverDirect isCover=$isCover")
            
            when (activeTab) {
                0 -> bindTasks(context, views, prefs, widgetWidth, widgetHeight, isCover)
                1 -> bindCalendar(context, views, prefs, widgetWidth, widgetHeight, isCover)
                2 -> bindGmail(context, views, prefs, widgetWidth, widgetHeight, isCover)
            }

            if (activeTab == 0) manager.notifyAppWidgetViewDataChanged(widgetId, R.id.task_list_view)
            if (activeTab == 2) manager.notifyAppWidgetViewDataChanged(widgetId, R.id.gmail_list_view)

            manager.updateAppWidget(widgetId, views)
        }

        // ─────────────────────────────────────────────────────────────────
        //  태스크 섹션
        // ─────────────────────────────────────────────────────────────────
        private fun bindTasks(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false) {
            val count = prefs.getString("task_count", "0")?.toIntOrNull() ?: 0
            val hasAny = (0 until count).any { i -> (prefs.getString("task_$i", "") ?: "").isNotEmpty() }

            if (hasAny) {
                views.setViewVisibility(R.id.task_list_view, View.VISIBLE)
                views.setViewVisibility(R.id.task_empty, View.GONE)
                val serviceIntent = Intent(context, TaskWidgetService::class.java)
                views.setRemoteAdapter(R.id.task_list_view, serviceIntent)
                val template = PendingIntent.getBroadcast(
                    context, 450,
                    Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_TASK_ITEM },
                    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setPendingIntentTemplate(R.id.task_list_view, template)
            } else {
                views.setViewVisibility(R.id.task_list_view, View.GONE)
                views.setViewVisibility(R.id.task_empty, View.VISIBLE)
            }

            val addSp = if (isCover) scaledSp(widgetWidth, widgetHeight, 15f, 17f) else scaledSp(widgetWidth, widgetHeight, 12f, 14f)
            views.setTextViewTextSize(R.id.task_add_btn, android.util.TypedValue.COMPLEX_UNIT_SP, addSp)
            views.setOnClickPendingIntent(R.id.task_add_btn, quickAddTaskIntent(context))
            views.setOnClickPendingIntent(R.id.task_launch_btn, openAppIntent(context, 0))
            views.setOnClickPendingIntent(R.id.task_refresh_btn, PendingIntent.getBroadcast(
                context, 150,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_REFRESH_TASKS },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
        }

        // ─────────────────────────────────────────────────────────────────
        //  캘린더 섹션
        // ─────────────────────────────────────────────────────────────────
        private fun bindCalendar(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false) {
            val showDayPanel = prefs.getBoolean("cal_show_day_panel", false)

            views.setViewVisibility(R.id.cal_grid_panel, if (!showDayPanel) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.cal_day_panel,  if (showDayPanel)  View.VISIBLE else View.GONE)

            if (showDayPanel) {
                bindCalendarDayPanel(context, views, prefs, widgetWidth, widgetHeight, isCover)
            } else {
                bindCalendarGrid(context, views, prefs, widgetWidth, widgetHeight, isCover)
            }
        }

        private fun bindCalendarGrid(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false) {
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
            views.setOnClickPendingIntent(R.id.cal_launch_btn, openAppIntent(context, 1))
            views.setOnClickPendingIntent(R.id.cal_refresh_btn, PendingIntent.getBroadcast(
                context, 704,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_REFRESH_CALENDAR },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            views.setOnClickPendingIntent(R.id.cal_add_btn, openAppWithActionIntent(context, "create_event"))

            val cal = java.util.Calendar.getInstance()
            cal.set(dispYear, dispMonth - 1, 1)
            val firstDow    = cal.get(java.util.Calendar.DAY_OF_WEEK) - 1
            val daysInMonth = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH)

            val neededRows = (firstDow + daysInMonth + 6) / 7
            for (r in 0..5) {
                views.setViewVisibility(WEEK_ROW_IDS[r], if (r < neededRows) View.VISIBLE else View.GONE)
            }
            Log.d("HomeWidget", "bindCalendarGrid isCover=$isCover w=$widgetWidth h=$widgetHeight neededRows=$neededRows")
            // 행 수에 따라 글씨 크기 자동 조정
            val rowFactor = 5f / neededRows
            val dateSp: Float
            val eventSp: Float
            if (isCover) {
                // 커버화면: 커버 스크린의 특성(화면 대비 dp 수치가 작음)을 감안하여
                // 비례방식이 아닌 눈으로 보기에 시원한 절대 비율의 큼직한 고정 폰트 크기 적용 (기존 10sp ➜ 16sp 상향)
                dateSp  = 13f * rowFactor
                eventSp = 16f * rowFactor
                Log.d("HomeWidget", "isCover fixed fonts dateSp=$dateSp eventSp=$eventSp")
            } else {
                dateSp  = scaledSp(widgetWidth, widgetHeight, 11f, 17f) * rowFactor
                eventSp = scaledSp(widgetWidth, widgetHeight, 8f, 13f) * rowFactor
            }

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

                        val dayColor = when {
                            isToday  -> Color.parseColor("#4285F4")
                            col == 0 -> Color.parseColor("#FF6B6B")
                            col == 6 -> Color.parseColor("#6B9FFF")
                            else     -> Color.parseColor("#D0D0E0")
                        }
                        ssb.setSpan(AbsoluteSizeSpan(dateSp.toInt(), true), 0, dayStr.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
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
                            val truncatedTitle = if (title.length > 5) title.substring(0, 4) + ".." else title
                            ssb.append(truncatedTitle)
                            val end = ssb.length

                            val colorStr = colors.getOrNull(i)
                            val eventColor = try {
                                if (!colorStr.isNullOrEmpty()) Color.parseColor(colorStr) else Color.parseColor("#60D8A0")
                            } catch (e: Exception) {
                                Color.parseColor("#60D8A0")
                            }

                            ssb.setSpan(AbsoluteSizeSpan(eventSp.toInt(), true), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                            ssb.setSpan(ForegroundColorSpan(eventColor), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        }

                        views.setTextViewText(cellId, ssb)
                        // 홈화면처럼 상단 중앙 정렬하여 일정 텍스트가 아래쪽 여백을 꽉 채우도록 처리
                        views.setInt(cellId, "setGravity", android.view.Gravity.TOP or android.view.Gravity.CENTER_HORIZONTAL)

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

        private fun bindCalendarDayPanel(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false) {
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
            dayRows.forEach { r ->
                views.setTextViewTextSize(r.title, android.util.TypedValue.COMPLEX_UNIT_SP, if (isCover) scaledSp(widgetWidth, widgetHeight, 15f, 17f) else scaledSp(widgetWidth, widgetHeight, 12f, 15f))
                views.setTextViewTextSize(r.time, android.util.TypedValue.COMPLEX_UNIT_SP, if (isCover) scaledSp(widgetWidth, widgetHeight, 13f, 15f) else scaledSp(widgetWidth, widgetHeight, 10f, 12f))
            }

            val backIntent = PendingIntent.getBroadcast(
                context, 703,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_CAL_BACK },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.cal_day_swipe_back, backIntent)
            views.setOnClickPendingIntent(R.id.cal_day_empty, backIntent)
        }

        // ─────────────────────────────────────────────────────────────────
        //  Gmail 섹션
        // ─────────────────────────────────────────────────────────────────
        private fun bindGmail(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false) {
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

                // Broadcast template → HomeWidgetProvider handles open/delete
                val template = PendingIntent.getBroadcast(
                    context, 350,
                    Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_GMAIL_ITEM },
                    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setPendingIntentTemplate(R.id.gmail_list_view, template)

                // 상단 스크롤 플래그 확인 및 스크롤 처리
                val scrollToTop = prefs.getBoolean("gmail_scroll_to_top", false)
                if (scrollToTop) {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                        views.setScrollPosition(R.id.gmail_list_view, 0)
                    }
                    prefs.edit().putBoolean("gmail_scroll_to_top", false).apply()
                }
            }

            // 앱 실행 숏컷 버튼
            views.setOnClickPendingIntent(R.id.gmail_launch_btn, openAppIntent(context, 2))
            // 새로고침 버튼 → GmailSyncJobService 스케줄
            views.setOnClickPendingIntent(R.id.gmail_refresh_btn, PendingIntent.getBroadcast(
                context, 460,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_REFRESH_GMAIL },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
            // compose 버튼 → 앱의 Gmail 작성 화면
            views.setOnClickPendingIntent(R.id.gmail_compose_btn, openAppWithActionIntent(context, "compose_email"))
            // 하단 스와이프 존: 탭 이동
            views.setOnClickPendingIntent(R.id.swipe_prev_gmail, switchTabIntent(context, 1))
            views.setOnClickPendingIntent(R.id.swipe_next_gmail, switchTabIntent(context, 0))
        }

        // 가로(클수록 큰 글씨) × 세로(짧을수록 작은 글씨) 두 제약 중 작은 쪽을 따름
        private fun scaledSp(widgetWidth: Int, widgetHeight: Int, spAtMin: Float, spAtMax: Float): Float {
            val tW = ((widgetWidth  - 250).toFloat() / 300f).coerceIn(0f, 1f)
            val tH = ((widgetHeight - 180).toFloat() / 220f).coerceIn(0f, 1f)
            return spAtMin + minOf(tW, tH) * (spAtMax - spAtMin)
        }

        private fun partiallySetBtnColor(context: Context, viewId: Int, colorHex: String) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
            val color = android.graphics.Color.parseColor(colorHex)
            for (id in ids) {
                val v = RemoteViews(context.packageName, R.layout.home_widget_layout)
                v.setTextColor(viewId, color)
                mgr.partiallyUpdateAppWidget(id, v)
            }
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
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        private fun deleteGmailItemLocal(
            context: Context,
            prefs: android.content.SharedPreferences,
            idx: Int
        ) {
            val count = try { prefs.getInt("gmail_count", 0) }
                        catch (e: ClassCastException) { prefs.getString("gmail_count","0")?.toIntOrNull() ?: 0 }
            if (idx < 0 || idx >= count) return

            val edit = prefs.edit()
            for (i in idx until count - 1) {
                edit.putString("gmail_${i}_sender",  prefs.getString("gmail_${i+1}_sender",  ""))
                edit.putString("gmail_${i}_time",    prefs.getString("gmail_${i+1}_time",    ""))
                edit.putString("gmail_${i}_subject", prefs.getString("gmail_${i+1}_subject", ""))
                edit.putString("gmail_${i}_unread",  prefs.getString("gmail_${i+1}_unread",  "false"))
                edit.putString("gmail_${i}_id",      prefs.getString("gmail_${i+1}_id",      ""))
            }
            val last = count - 1
            edit.putString("gmail_${last}_sender",  "")
            edit.putString("gmail_${last}_time",    "")
            edit.putString("gmail_${last}_subject", "")
            edit.putString("gmail_${last}_unread",  "false")
            edit.putString("gmail_${last}_id",      "")
            edit.putInt("gmail_count", last)
            edit.apply()
        }

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
