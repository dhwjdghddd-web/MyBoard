package com.dhwjdgh.prv_dashboard

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
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
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: android.os.Bundle) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        when (intent.action) {
            Intent.ACTION_LOCALE_CHANGED -> {
                // 시스템 언어 변경 시 위젯을 다시 그려 즉시 반영 (재설치 불필요)
                WidgetStrings.updateLocale(context)
                redraw(context)
            }
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
                partiallySetBtnColor(context, R.id.cal_prev, "#FFA000")
                val lastSync = prefs.getLong("cal_synced_${y}_${m}", 0L)
                val isCached = System.currentTimeMillis() - lastSync < 30 * 60 * 1000L
                if (isCached) {
                    redraw(context)
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        partiallySetBtnColor(context, R.id.cal_prev, "#A0A0B0")
                    }, 300)
                } else {
                    redraw(context)
                    val pendingResult = goAsync()
                    CalendarSyncJobService.executeSync(context, y, m) {
                        partiallySetBtnColor(context, R.id.cal_prev, "#A0A0B0")
                        pendingResult.finish()
                    }
                }
            }
            ACTION_CAL_NEXT_MONTH -> {
                var y = prefs.getInt("cal_display_year",  now().get(java.util.Calendar.YEAR))
                var m = prefs.getInt("cal_display_month", now().get(java.util.Calendar.MONTH) + 1)
                m++; if (m > 12) { m = 1; y++ }
                prefs.edit().putInt("cal_display_year", y).putInt("cal_display_month", m)
                    .putBoolean("cal_show_day_panel", false).apply()
                partiallySetBtnColor(context, R.id.cal_next, "#FFA000")
                val lastSync = prefs.getLong("cal_synced_${y}_${m}", 0L)
                val isCached = System.currentTimeMillis() - lastSync < 30 * 60 * 1000L
                if (isCached) {
                    redraw(context)
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        partiallySetBtnColor(context, R.id.cal_next, "#A0A0B0")
                    }, 300)
                } else {
                    redraw(context)
                    val pendingResult = goAsync()
                    CalendarSyncJobService.executeSync(context, y, m) {
                        partiallySetBtnColor(context, R.id.cal_next, "#A0A0B0")
                        pendingResult.finish()
                    }
                }
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
            ACTION_TOGGLE_DONE_TASKS -> {
                // 위젯 완료 할 일 표시 토글: pref 뒤집고 리스트 어댑터 재로드 + 위젯 갱신
                val cur = prefs.getBoolean("widget_show_completed", false)
                prefs.edit().putBoolean("widget_show_completed", !cur).apply()
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
                ids.forEach { mgr.notifyAppWidgetViewDataChanged(it, R.id.task_list_view) }
                redraw(context)
            }
            ACTION_REFRESH_CALENDAR -> {
                val y = prefs.getInt("cal_display_year",  now().get(java.util.Calendar.YEAR))
                val m = prefs.getInt("cal_display_month", now().get(java.util.Calendar.MONTH) + 1)
                val pendingResult = goAsync()
                partiallySetBtnColor(context, R.id.cal_refresh_btn, "#FFA000")
                // 네이티브 동기화가 위젯을 이미 갱신하므로 앱으로 refreshData 재푸시는 하지 않는다.
                // (앱이 현재 월을 다시 써서 위젯이 깜빡이던 문제 방지 — updateCalendar 중복 기록 제거)
                CalendarSyncJobService.executeSync(context, y, m) {
                    partiallySetBtnColor(context, R.id.cal_refresh_btn, "#4CAF50")
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        partiallySetBtnColor(context, R.id.cal_refresh_btn, "#FFFFFF")
                    }, 1500)
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
                        val activityIntent = Intent(context, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            putExtra("tab", 0)
                        }
                        val pendingIntent = PendingIntent.getActivity(
                            context, 451, activityIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        try {
                            pendingIntent.send()
                        } catch (e: Exception) {
                            context.startActivity(activityIntent)
                        }
                    }
                }
            }
        }
    }

    companion object {
        private const val PREFS = "HomeWidgetPreferences"

        private fun getContrastColor(color: Int): Int {
            val red = Color.red(color)
            val green = Color.green(color)
            val blue = Color.blue(color)
            val lum = 0.299 * red + 0.587 * green + 0.114 * blue
            return if (lum > 180) Color.BLACK else Color.WHITE
        }

        private class DisplayItem(val title: String, val isTask: Boolean, val color: Int)

        private fun getLocalDateKey(dueStr: String): String {
            if (dueStr.length < 10) return ""
            return try {
                if (dueStr.contains("T")) {
                    val instant = java.time.Instant.parse(dueStr)
                    val local = instant.atZone(java.time.ZoneId.systemDefault())
                    val formatter = java.time.format.DateTimeFormatter.ofPattern("yyyyMMdd")
                    local.format(formatter)
                } else {
                    dueStr.substring(0, 10).replace("-", "")
                }
            } catch (e: Exception) {
                dueStr.substring(0, 10).replace("-", "")
            }
        }

        private fun bindEventOrTask(views: RemoteViews, viewId: Int, item: DisplayItem, textDp: Float, isDark: Boolean) {
            views.setTextViewTextSize(viewId, android.util.TypedValue.COMPLEX_UNIT_DIP, textDp)
            if (item.isTask) {
                views.setInt(viewId, "setBackgroundColor", Color.TRANSPARENT)
                
                val ssb = SpannableStringBuilder("● ${item.title}")
                ssb.setSpan(ForegroundColorSpan(Color.parseColor("#4285F4")), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                val textColor = if (isDark) Color.WHITE else Color.parseColor("#1F2937")
                ssb.setSpan(ForegroundColorSpan(textColor), 2, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                ssb.setSpan(android.text.style.TypefaceSpan("sans-serif"), 0, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                
                views.setTextViewText(viewId, ssb)
                views.setTextColor(viewId, textColor)
            } else {
                views.setInt(viewId, "setBackgroundResource", R.drawable.event_chip_bg)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    views.setColorStateList(viewId, "setBackgroundTintList", android.content.res.ColorStateList.valueOf(item.color))
                } else {
                    views.setInt(viewId, "setBackgroundColor", item.color)
                }
                
                val ssb = SpannableStringBuilder(item.title)
                ssb.setSpan(android.text.style.TypefaceSpan("sans-serif"), 0, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                
                views.setTextViewText(viewId, ssb)
                views.setTextColor(viewId, getContrastColor(item.color))
            }
        }

        const val ACTION_COMPLETE_TASK   = "com.dhwjdgh.prv_dashboard.COMPLETE_TASK"
        const val ACTION_DELETE_TASK     = "com.dhwjdgh.prv_dashboard.DELETE_TASK"
        const val ACTION_TASK_ITEM       = "com.dhwjdgh.prv_dashboard.TASK_ITEM"
        const val ACTION_SWITCH_TAB      = "com.dhwjdgh.prv_dashboard.SWITCH_WIDGET_TAB"
        const val ACTION_CAL_PREV_MONTH  = "com.dhwjdgh.prv_dashboard.CAL_PREV_MONTH"
        const val ACTION_CAL_NEXT_MONTH  = "com.dhwjdgh.prv_dashboard.CAL_NEXT_MONTH"
        const val ACTION_CAL_SELECT_DATE = "com.dhwjdgh.prv_dashboard.CAL_SELECT_DATE"
        const val ACTION_CAL_BACK        = "com.dhwjdgh.prv_dashboard.CAL_BACK"
        const val ACTION_REFRESH_TASKS   = "com.dhwjdgh.prv_dashboard.REFRESH_TASKS"
        const val ACTION_TOGGLE_DONE_TASKS = "com.dhwjdgh.prv_dashboard.TOGGLE_DONE_TASKS"
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
            WidgetStrings.updateLocale(context)
            val prefs     = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

            val opts = manager.getAppWidgetOptions(widgetId)
            val widgetWidth  = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,  300)
            val widgetHeight = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 300)
            val isCover = resolveIsCover(context, prefs, widgetId, widgetWidth)
            val isTablet = resolveIsTablet(prefs, widgetId, context)
            val isDark = resolveIsDark(prefs, widgetId, context)
            
            val layoutId = when {
                isTablet -> R.layout.tablet_widget_layout
                isCover  -> R.layout.cover_widget_layout
                else     -> R.layout.home_widget_layout
            }
            val views     = RemoteViews(context.packageName, layoutId)

            // 최외각 배경 이미지 설정 및 투명도 반영
            views.setInt(R.id.widget_container, "setBackgroundResource", 0)
            val bgRes = if (isDark) R.drawable.widget_background_dark else R.drawable.widget_background_light
            views.setImageViewResource(R.id.widget_background_view, bgRes)

            val opacity = prefs.getFloat("widget_opacity_$widgetId", 1.0f)
            val alpha = (opacity * 255).toInt().coerceIn(0, 255)
            views.setInt(R.id.widget_background_view, "setImageAlpha", alpha)

            // 설정 톱니바퀴 아이콘 틴트 컬러 오버라이드
            val cogColor = if (isDark) Color.parseColor("#A0A0B0") else Color.parseColor("#707080")
            views.setInt(R.id.widget_settings_btn, "setColorFilter", cogColor)

            if (isTablet) {
                bindTasks(context, views, prefs, widgetWidth, widgetHeight, isCover = false, isTablet = true, isDark = isDark, widgetId = widgetId)
                bindCalendar(context, views, prefs, widgetWidth, widgetHeight, isCover = false, isTablet = true, isDark = isDark)
            } else {
                val activeTab = prefs.getInt("active_widget_tab", 0).coerceIn(0, 1)

                views.setViewVisibility(R.id.section_tasks,    if (activeTab == 0) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.section_calendar, if (activeTab == 1) View.VISIBLE else View.GONE)

                val activeColor = if (isDark) Color.WHITE else Color.parseColor("#1F2937")
                val inactiveColor = if (isDark) Color.parseColor("#A0A0B0") else Color.parseColor("#8C8275")

                views.setTextColor(R.id.tab_tasks,    if (activeTab == 0) activeColor else inactiveColor)
                views.setTextColor(R.id.tab_calendar, if (activeTab == 1) activeColor else inactiveColor)

                if (activeTab == 0) {
                    views.setInt(R.id.tab_tasks, "setBackgroundResource", R.drawable.tab_active_bg)
                } else {
                    views.setInt(R.id.tab_tasks, "setBackgroundResource", R.drawable.tab_inactive_bg)
                }
                if (activeTab == 1) {
                    views.setInt(R.id.tab_calendar, "setBackgroundResource", R.drawable.tab_active_bg)
                } else {
                    views.setInt(R.id.tab_calendar, "setBackgroundResource", R.drawable.tab_inactive_bg)
                }

                views.setOnClickPendingIntent(R.id.tab_tasks,    switchTabIntent(context, 0))
                views.setOnClickPendingIntent(R.id.tab_calendar, switchTabIntent(context, 1))

                // 탭 텍스트 크기 동적 조정
                val tabSp = if (isCover) 16f
                            else         scaledSp(widgetWidth, widgetHeight, 14f, 16f)
                views.setTextViewTextSize(R.id.tab_tasks,    android.util.TypedValue.COMPLEX_UNIT_SP, tabSp)
                views.setTextViewTextSize(R.id.tab_calendar, android.util.TypedValue.COMPLEX_UNIT_SP, tabSp)

                when (activeTab) {
                    0 -> bindTasks(context, views, prefs, widgetWidth, widgetHeight, isCover, isTablet = false, isDark = isDark, widgetId = widgetId)
                    1 -> bindCalendar(context, views, prefs, widgetWidth, widgetHeight, isCover, isTablet = false, isDark = isDark)
                }
            }

            val manual = prefs.getString("widget_cover_manual_$widgetId", "auto")
            Log.d("HomeWidget", "updateWidget id=$widgetId w=$widgetWidth h=$widgetHeight manual=$manual isCover=$isCover isTablet=$isTablet isDark=$isDark")

            // ⚙ 버튼 → WidgetConfigureActivity 직접 실행 (런처 무관)
            val configIntent = Intent(context, WidgetConfigureActivity::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val configPi = PendingIntent.getActivity(context, widgetId + 700, configIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_settings_btn, configPi)

            // Gmail 앱 바로가기 — 외부 앱 실행만 하므로 OAuth 스코프가 전혀 필요 없음.
            // Gmail 앱이 설치돼 있을 때만 버튼을 노출한다.
            views.setInt(R.id.widget_gmail_btn, "setColorFilter", cogColor)
            val gmailLaunch = context.packageManager.getLaunchIntentForPackage("com.google.android.gm")
            if (gmailLaunch != null) {
                gmailLaunch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                views.setViewVisibility(R.id.widget_gmail_btn, View.VISIBLE)
                views.setOnClickPendingIntent(R.id.widget_gmail_btn, PendingIntent.getActivity(
                    context, 999, gmailLaunch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                ))
            } else {
                views.setViewVisibility(R.id.widget_gmail_btn, View.GONE)
            }

            if (isTablet) {
                manager.notifyAppWidgetViewDataChanged(widgetId, R.id.task_list_view)
            } else {
                val activeTab = prefs.getInt("active_widget_tab", 0)
                if (activeTab == 0) manager.notifyAppWidgetViewDataChanged(widgetId, R.id.task_list_view)
            }

            manager.updateAppWidget(widgetId, views)
        }

        // ─────────────────────────────────────────────────────────────────
        //  태스크 섹션
        // ─────────────────────────────────────────────────────────────────
        private fun bindTasks(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false, isTablet: Boolean = false, isDark: Boolean = true, widgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID) {
            val count = prefs.getString("task_count", "0")?.toIntOrNull() ?: 0
            val hasAny = (0 until count).any { i -> (prefs.getString("task_$i", "") ?: "").isNotEmpty() }

            val primaryColor = if (isDark) Color.WHITE else Color.parseColor("#1C1C1E")
            val secondaryColor = if (isDark) Color.parseColor("#A0A0B0") else Color.parseColor("#707080")
            views.setTextColor(R.id.task_header_title, primaryColor)
            views.setTextColor(R.id.task_empty, secondaryColor)
            views.setInt(R.id.task_launch_btn, "setColorFilter", secondaryColor)
            views.setInt(R.id.task_refresh_btn, "setColorFilter", secondaryColor)

            if (hasAny) {
                views.setViewVisibility(R.id.task_list_view, View.VISIBLE)
                views.setViewVisibility(R.id.task_empty, View.GONE)
                val svcClass = if (isCover) TaskWidgetServiceCover::class.java else TaskWidgetService::class.java
                
                val adapterIntent = Intent(context, svcClass).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = android.net.Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.task_list_view, adapterIntent)
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

            val headerSp = if (isCover) 20f
                           else if (isTablet) 12f
                           else         scaledSp(widgetWidth, widgetHeight, 12f, 15f)
            views.setTextViewTextSize(R.id.task_header_title, android.util.TypedValue.COMPLEX_UNIT_SP, headerSp)
            val addSp = if (isCover) 18f
                        else if (isTablet) 11f
                        else scaledSp(widgetWidth, widgetHeight, 12f, 14f)
            views.setTextViewTextSize(R.id.task_add_btn, android.util.TypedValue.COMPLEX_UNIT_SP, addSp)
            views.setOnClickPendingIntent(R.id.task_add_btn, quickAddTaskIntent(context))

            views.setOnClickPendingIntent(R.id.task_launch_btn, openAppIntent(context, 0))
            views.setOnClickPendingIntent(R.id.task_refresh_btn, PendingIntent.getBroadcast(
                context, 150,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_REFRESH_TASKS },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))

            // 완료 할 일 표시 토글 버튼: 켜져 있으면 강조색, 꺼져 있으면 보조색
            val showCompleted = prefs.getBoolean("widget_show_completed", false)
            views.setInt(R.id.task_toggle_done_btn, "setColorFilter",
                if (showCompleted) Color.parseColor("#4285F4") else secondaryColor)
            views.setOnClickPendingIntent(R.id.task_toggle_done_btn, PendingIntent.getBroadcast(
                context, 151,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_TOGGLE_DONE_TASKS },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))
        }

        // ─────────────────────────────────────────────────────────────────
        //  캘린더 섹션
        // ─────────────────────────────────────────────────────────────────
        private fun bindCalendar(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false, isTablet: Boolean = false, isDark: Boolean = true) {
            val showDayPanel = prefs.getBoolean("cal_show_day_panel", false)

            views.setViewVisibility(R.id.cal_grid_panel, if (!showDayPanel) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.cal_day_panel,  if (showDayPanel)  View.VISIBLE else View.GONE)

            if (showDayPanel) {
                bindCalendarDayPanel(context, views, prefs, widgetWidth, widgetHeight, isCover, isTablet, isDark)
            } else {
                bindCalendarGrid(context, views, prefs, widgetWidth, widgetHeight, isCover, isTablet, isDark)
            }
        }

        private fun bindCalendarGrid(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false, isTablet: Boolean = false, isDark: Boolean = true) {
            val allPrefs    = prefs.all
            val actual      = now()
            val actualYear  = actual.get(java.util.Calendar.YEAR)
            val actualMonth = actual.get(java.util.Calendar.MONTH) + 1
            val actualToday = actual.get(java.util.Calendar.DAY_OF_MONTH)
            val dispYear    = when (val y = allPrefs["cal_display_year"]) {
                is Int -> y
                is String -> y.toIntOrNull() ?: actualYear
                else -> actualYear
            }
            val dispMonth   = when (val m = allPrefs["cal_display_month"]) {
                is Int -> m
                is String -> m.toIntOrNull() ?: actualMonth
                else -> actualMonth
            }

            val tasksByDate = mutableMapOf<String, MutableList<String>>()
            val taskCount = when (val tc = allPrefs["task_count"]) {
                is Int -> tc
                is String -> tc.toIntOrNull() ?: 0
                else -> 0
            }
            for (i in 0 until taskCount) {
                val title = when (val t = allPrefs["task_$i"]) {
                    is String -> t
                    else -> ""
                }
                val done = when (val d = allPrefs["task_${i}_done"]) {
                    is Boolean -> d.toString()
                    is String -> d
                    else -> "false"
                }
                val due = when (val d = allPrefs["task_${i}_due"]) {
                    is String -> d
                    else -> ""
                }
                if (title.isNotEmpty() && done != "true" && due.length >= 10) {
                    val dateKey = getLocalDateKey(due)
                    if (dateKey.isNotEmpty()) {
                        tasksByDate.getOrPut(dateKey) { mutableListOf() }.add(title)
                    }
                }
            }

            val locale = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                context.resources.configuration.locales[0]
            } else {
                @Suppress("DEPRECATION")
                context.resources.configuration.locale
            }
            val cal2 = java.util.Calendar.getInstance().apply { set(dispYear, dispMonth - 1, 1) }
            val monthLabel = if (locale.language == "ko") {
                "${dispYear}년 ${dispMonth}월"
            } else {
                java.text.SimpleDateFormat("MMMM yyyy", locale).format(cal2.time)
            }
            views.setTextViewText(R.id.cal_month_label, monthLabel)
            val monthLabelSp = if (isCover) 20f
                               else if (isTablet) 12f
                               else         scaledSp(widgetWidth, widgetHeight, 12f, 15f)
            views.setTextViewTextSize(R.id.cal_month_label, android.util.TypedValue.COMPLEX_UNIT_SP, monthLabelSp)

            val primaryColor = if (isDark) Color.WHITE else Color.parseColor("#1C1C1E")
            val secondaryColor = if (isDark) Color.parseColor("#A0A0B0") else Color.parseColor("#707080")
            views.setTextColor(R.id.cal_month_label, primaryColor)
            
            views.setInt(R.id.cal_prev, "setColorFilter", secondaryColor)
            views.setInt(R.id.cal_next, "setColorFilter", secondaryColor)
            views.setInt(R.id.cal_launch_btn, "setColorFilter", secondaryColor)
            views.setInt(R.id.cal_refresh_btn, "setColorFilter", secondaryColor)
            views.setInt(R.id.cal_add_btn, "setColorFilter", Color.parseColor("#60D8A0"))

            val dowColor = if (isDark) Color.parseColor("#9090A0") else Color.parseColor("#707080")
            listOf(R.id.cal_dow_mon, R.id.cal_dow_tue, R.id.cal_dow_wed,
                   R.id.cal_dow_thu, R.id.cal_dow_fri).forEach {
                views.setTextColor(it, dowColor)
            }

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
            if (isCover) {
                val dowSp = 16f
                listOf(R.id.cal_dow_sun, R.id.cal_dow_mon, R.id.cal_dow_tue, R.id.cal_dow_wed,
                       R.id.cal_dow_thu, R.id.cal_dow_fri, R.id.cal_dow_sat).forEach {
                    views.setTextViewTextSize(it, android.util.TypedValue.COMPLEX_UNIT_SP, dowSp)
                }
            }
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
            // 행 수와 위젯 높이에 따라 반응형으로 글씨 크기 및 표시 개수 조절
            val safeWidgetHeight = maxOf(widgetHeight, 100)
            val gridHeightDp = safeWidgetHeight - if (isCover) 88 else 100
            val rowHeightDp = (gridHeightDp.toFloat() / neededRows.toFloat()).toInt()

            // 태블릿: 행 높이에서 날짜(~12dp) 빼고 이벤트 칩 높이(~11dp)로 나누어 슬롯 수 동적 계산
            val tabletMaxSlots = if (isTablet) {
                val availableForEvents = rowHeightDp - 14
                val slotHeight = 11
                maxOf(2, minOf(6, availableForEvents / slotHeight))
            } else 2

            // Calculate font sizes dynamically
            val scaleFactor = if (isTablet) {
                (tabletMaxSlots.toFloat() + 1.2f)
            } else if (isCover) 3.1f else 3.45f
            val overhead = if (isCover) 2.5f else 3.15f
            val rawEventDp = (rowHeightDp.toFloat() - overhead) / scaleFactor
            
            var eventDp = rawEventDp
            var dateDp = eventDp + 1.0f
            
            // Apply maximum constraints depending on device type
            val maxDate = if (isTablet) 11.0f else if (isCover) 19.0f else 13.0f
            val maxEvent = if (isTablet) 10.0f else if (isCover) 16.5f else 11.0f
            
            dateDp = dateDp.coerceAtMost(maxDate)
            eventDp = eventDp.coerceAtMost(maxEvent)
            
            // Apply minimum constraints (hard floor)
            dateDp = dateDp.coerceAtLeast(7.0f)
            eventDp = eventDp.coerceAtLeast(5.5f)

            for (row in 0..5) {
                for (col in 0..6) {
                    val idx    = row * 7 + col
                    val day    = idx - firstDow + 1
                    val cellId = CELL_IDS[row][col]
                    val resName = context.resources.getResourceEntryName(cellId)
                    
                    val ev1Id = context.resources.getIdentifier("${resName}_ev1", "id", context.packageName)
                    val ev2Id = context.resources.getIdentifier("${resName}_ev2", "id", context.packageName)
                    val parentId = context.resources.getIdentifier("cell_${resName.substring(1)}", "id", context.packageName)

                    if (day < 1 || day > daysInMonth) {
                        views.setTextViewText(cellId, "")
                        if (ev1Id != 0) views.setViewVisibility(ev1Id, View.GONE)
                        if (ev2Id != 0) views.setViewVisibility(ev2Id, View.GONE)
                        if (parentId != 0) {
                            views.setInt(parentId, "setBackgroundColor", Color.TRANSPARENT)
                            views.setOnClickPendingIntent(parentId, null)
                        }
                    } else {
                        val isToday  = dispYear == actualYear && dispMonth == actualMonth && day == actualToday

                        val dateKey = "%04d-%02d-%02d".format(dispYear, dispMonth, day)
                        val compactKey = "%04d%02d%02d".format(dispYear, dispMonth, day)

                        val titlesRaw = (allPrefs["cal_day_${compactKey}_titles"] as? String) ?: ""
                        val colorsRaw = (allPrefs["cal_day_${compactKey}_colors"] as? String) ?: ""
                        val timesRaw = (allPrefs["cal_day_${compactKey}_times"] as? String) ?: ""

                        val titles = if (titlesRaw.isEmpty()) emptyList() else titlesRaw.split("|")
                        val colors = if (colorsRaw.isEmpty()) emptyList() else colorsRaw.split("|")
                        val times = if (timesRaw.isEmpty()) emptyList() else timesRaw.split("|")

                        // 1. 날짜 설정
                        views.setTextViewText(cellId, day.toString())
                        val dayColor = when {
                            isToday  -> Color.parseColor("#4285F4")
                            col == 0 -> Color.parseColor("#FF8A80")
                            col == 6 -> Color.parseColor("#82B1FF")
                            else     -> if (isDark) Color.parseColor("#D0D0E0") else Color.parseColor("#1C1C1E")
                        }
                        views.setTextColor(cellId, dayColor)
                        views.setTextViewTextSize(cellId, android.util.TypedValue.COMPLEX_UNIT_DIP, dateDp)

                        views.setInt(cellId, "setBackgroundColor", Color.TRANSPARENT)
                        if (parentId != 0) {
                            if (isToday) {
                                views.setInt(parentId, "setBackgroundResource", R.drawable.today_cell_ripple)
                            } else {
                                views.setInt(parentId, "setBackgroundResource", R.drawable.widget_cell_ripple)
                            }
                        }

                        // 2. 일정 및 태스크 결합 바인딩 (태블릿: 높이 따라 최대 4개, 그 외: 최대 2개)
                        val dayTasks = tasksByDate[compactKey] ?: emptyList<String>()
                        val displayItems = mutableListOf<DisplayItem>()
                        
                        for (i in titles.indices) {
                            val t = titles[i]
                            val cStr = colors.getOrNull(i)
                            val c = try {
                                if (!cStr.isNullOrEmpty()) Color.parseColor(cStr) else Color.parseColor("#ff4285f4")
                            } catch (e: Exception) {
                                Color.parseColor("#ff4285f4")
                            }
                            displayItems.add(DisplayItem(t, false, c))
                        }
                        for (t in dayTasks) {
                            displayItems.add(DisplayItem(t, true, Color.parseColor("#4285F4")))
                        }

                        // 태블릿: 행 높이에 따라 표시 가능한 슬롯 수를 동적 결정 (최대 6, XML 한계)
                        val maxSlots = if (isTablet) tabletMaxSlots else 2

                        // ev1~ev6 ID 조회 (태블릿만 ev3~ev6 사용)
                        val ev3Id = if (isTablet) context.resources.getIdentifier("${resName}_ev3", "id", context.packageName) else 0
                        val ev4Id = if (isTablet) context.resources.getIdentifier("${resName}_ev4", "id", context.packageName) else 0
                        val ev5Id = if (isTablet) context.resources.getIdentifier("${resName}_ev5", "id", context.packageName) else 0
                        val ev6Id = if (isTablet) context.resources.getIdentifier("${resName}_ev6", "id", context.packageName) else 0

                        val slotIds = listOf(ev1Id, ev2Id, ev3Id, ev4Id, ev5Id, ev6Id)
                        val totalItems = displayItems.size
                        val hasOverflow = totalItems > maxSlots

                        for (s in 0 until 6) {
                            val slotId = slotIds[s]
                            if (slotId == 0) continue

                            if (s >= maxSlots) {
                                // 슬롯 한계 초과 → 숨기기
                                views.setViewVisibility(slotId, View.GONE)
                            } else if (hasOverflow && s == maxSlots - 1) {
                                // 마지막 가시 슬롯 → "+N" 오버플로 표시
                                val remaining = totalItems - (maxSlots - 1)
                                views.setViewVisibility(slotId, View.VISIBLE)
                                views.setTextViewText(slotId, "+$remaining")
                                views.setTextViewTextSize(slotId, android.util.TypedValue.COMPLEX_UNIT_DIP, eventDp)
                                views.setTextColor(slotId, if (isDark) Color.parseColor("#9E9EBF") else Color.parseColor("#757575"))
                                views.setInt(slotId, "setBackgroundResource", R.drawable.overflow_chip_bg)
                            } else {
                                val item = displayItems.getOrNull(s)
                                if (item != null) {
                                    views.setViewVisibility(slotId, View.VISIBLE)
                                    bindEventOrTask(views, slotId, item, eventDp, isDark)
                                } else {
                                    views.setViewVisibility(slotId, View.GONE)
                                }
                            }
                        }

                        // 날짜 탭 → 위젯 내 일정 패널로 전환 (앱 열지 않음)
                        if (parentId != 0) {
                            views.setOnClickPendingIntent(parentId, PendingIntent.getBroadcast(
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
        }

        private fun bindCalendarDayPanel(context: Context, views: RemoteViews, prefs: android.content.SharedPreferences, widgetWidth: Int = 300, widgetHeight: Int = 300, isCover: Boolean = false, isTablet: Boolean = false, isDark: Boolean = true) {
            val dateKey = prefs.getString("cal_selected_date", "") ?: ""

            // 날짜 레이블 (MM/DD 요일 형식)
            val label = if (dateKey.length >= 10) {
                val m = dateKey.substring(5, 7).trimStart('0')
                val d = dateKey.substring(8, 10).trimStart('0')
                val locale = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    context.resources.configuration.locales[0]
                } else {
                    @Suppress("DEPRECATION")
                    context.resources.configuration.locale
                }
                val dName = try {
                    val cal = java.util.Calendar.getInstance()
                    cal.set(dateKey.substring(0, 4).toInt(), dateKey.substring(5, 7).toInt() - 1, d.toInt())
                    java.text.DateFormatSymbols(locale).shortWeekdays[cal.get(java.util.Calendar.DAY_OF_WEEK)]
                } catch (_: Exception) { "" }
                if (locale.language == "ko") "${m}월 ${d}일 ($dName)" else "$m/$d ($dName)"
            } else ""
            views.setTextViewText(R.id.cal_day_label, label)
            val dayLabelSp = if (isCover) 16f
                             else if (isTablet) 11f
                             else         scaledSp(widgetWidth, widgetHeight, 11f, 14f)
            views.setTextViewTextSize(R.id.cal_day_label, android.util.TypedValue.COMPLEX_UNIT_SP, dayLabelSp)

            val primaryColor = if (isDark) Color.WHITE else Color.parseColor("#1C1C1E")
            val secondaryColor = if (isDark) Color.parseColor("#A0A0B0") else Color.parseColor("#707080")
            views.setTextColor(R.id.cal_day_label, primaryColor)
            views.setTextColor(R.id.cal_day_empty, secondaryColor)
            
            views.setInt(R.id.cal_back_btn, "setColorFilter", secondaryColor)
            views.setInt(R.id.cal_day_add_btn, "setColorFilter", Color.parseColor("#60D8A0"))

            // 뒤로 버튼

            views.setOnClickPendingIntent(R.id.cal_back_btn, PendingIntent.getBroadcast(
                context, 702,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_CAL_BACK },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))

            // 일정 추가 → 앱 열기
            views.setOnClickPendingIntent(R.id.cal_day_add_btn,
                openCreateEventForDateIntent(context, dateKey))

            // 저장된 일정 데이터 로드 (compact key: cal_day_YYYYMMDD)
            val compactKey = dateKey.replace("-", "")
            val titlesRaw = prefs.getString("cal_day_${compactKey}_titles", "") ?: ""
            val timesRaw  = prefs.getString("cal_day_${compactKey}_times",  "") ?: ""
            val idsRaw    = prefs.getString("cal_day_${compactKey}_ids",    "") ?: ""
            val colorsRaw = prefs.getString("cal_day_${compactKey}_colors", "") ?: ""

            val allPrefs = prefs.all
            val tasksByDate = mutableMapOf<String, MutableList<String>>()
            val taskCount = when (val tc = allPrefs["task_count"]) {
                is Int -> tc
                is String -> tc.toIntOrNull() ?: 0
                else -> 0
            }
            for (i in 0 until taskCount) {
                val title = when (val t = allPrefs["task_$i"]) {
                    is String -> t
                    else -> ""
                }
                val done = when (val d = allPrefs["task_${i}_done"]) {
                    is Boolean -> d.toString()
                    is String -> d
                    else -> "false"
                }
                val due = when (val d = allPrefs["task_${i}_due"]) {
                    is String -> d
                    else -> ""
                }
                if (title.isNotEmpty() && done != "true" && due.length >= 10) {
                    val dk = getLocalDateKey(due)
                    if (dk.isNotEmpty()) {
                        tasksByDate.getOrPut(dk) { mutableListOf() }.add(title)
                    }
                }
            }
            val dayTasks = tasksByDate[compactKey] ?: emptyList<String>()

            class DayDisplayItem(val title: String, val time: String, val id: String, val color: Int, val isTask: Boolean)
            val displayItems = mutableListOf<DayDisplayItem>()

            val eventTitles = if (titlesRaw.isEmpty()) emptyList() else titlesRaw.split("|")
            val eventTimes  = if (timesRaw.isEmpty())  emptyList() else timesRaw.split("|")
            val eventIds    = if (idsRaw.isEmpty())     emptyList() else idsRaw.split("|")
            val eventColors = if (colorsRaw.isEmpty()) emptyList() else colorsRaw.split("|")

            for (i in eventTitles.indices) {
                val t = eventTitles[i]
                val timeStr = eventTimes.getOrElse(i) { "" }
                val evId = eventIds.getOrElse(i) { "" }
                val colorStr = eventColors.getOrNull(i)
                val eventColor = try {
                    if (!colorStr.isNullOrEmpty()) Color.parseColor(colorStr) else Color.parseColor("#ff4285f4")
                } catch (e: Exception) {
                    Color.parseColor("#ff4285f4")
                }
                displayItems.add(DayDisplayItem(t, timeStr, evId, eventColor, isTask = false))
            }
            for (t in dayTasks) {
                displayItems.add(DayDisplayItem(t, context.getString(R.string.widget_task_label), "", Color.parseColor("#4285F4"), isTask = true))
            }

            data class DayRow(val row: Int, val time: Int, val title: Int, val colorBar: Int)
            val maxRowsCount = if (isTablet) 12 else 8
            val dayRows = mutableListOf<DayRow>()
            for (i in 0 until maxRowsCount) {
                val rowId = context.resources.getIdentifier("cal_day_row_$i", "id", context.packageName)
                val timeId = context.resources.getIdentifier("cal_day_time_$i", "id", context.packageName)
                val titleId = context.resources.getIdentifier("cal_day_title_$i", "id", context.packageName)
                val colorId = context.resources.getIdentifier("cal_day_color_$i", "id", context.packageName)
                if (rowId != 0 && timeId != 0 && titleId != 0 && colorId != 0) {
                    dayRows.add(DayRow(rowId, timeId, titleId, colorId))
                }
            }
            var visible = 0
            for ((i, r) in dayRows.withIndex()) {
                val item = displayItems.getOrNull(i)
                if (item != null && item.title.isNotEmpty()) {
                    views.setViewVisibility(r.row, View.VISIBLE)
                    views.setTextColor(r.time, secondaryColor)
                    
                    if (item.isTask) {
                        views.setTextViewText(r.time, context.getString(R.string.widget_task_label))
                        val ssb = SpannableStringBuilder("● ${item.title}")
                        ssb.setSpan(ForegroundColorSpan(Color.parseColor("#4285F4")), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        ssb.setSpan(android.text.style.TypefaceSpan("sans-serif"), 0, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        views.setTextViewText(r.title, ssb)
                        views.setTextColor(r.title, primaryColor)
                        views.setInt(r.colorBar, "setBackgroundColor", Color.TRANSPARENT)
                        
                        views.setOnClickPendingIntent(r.row, openAppIntent(context, 0))
                    } else {
                        views.setTextViewText(r.time, item.time)
                        val ssb = SpannableStringBuilder(item.title)
                        ssb.setSpan(android.text.style.TypefaceSpan("sans-serif"), 0, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        views.setTextViewText(r.title, ssb)
                        views.setTextColor(r.title, primaryColor)
                        views.setInt(r.colorBar, "setBackgroundColor", item.color)
                        
                        views.setOnClickPendingIntent(r.row,
                            if (item.id.isNotEmpty()) openEventDetailIntent(context, item.id, dateKey, i)
                            else openCalendarDateAppIntent(context, dateKey)
                        )
                    }
                    visible++
                } else {
                    views.setViewVisibility(r.row, View.GONE)
                }
            }
            views.setViewVisibility(R.id.cal_day_empty, if (visible == 0) View.VISIBLE else View.GONE)
            dayRows.forEach { r ->
                val titleSp = if (isCover) 18f else if (isTablet) 12f else scaledSp(widgetWidth, widgetHeight, 12f, 15f)
                val timeSp = if (isCover) 15f else if (isTablet) 10f else scaledSp(widgetWidth, widgetHeight, 10f, 12f)
                views.setTextViewTextSize(r.title, android.util.TypedValue.COMPLEX_UNIT_SP, titleSp)
                views.setTextViewTextSize(r.time,  android.util.TypedValue.COMPLEX_UNIT_SP, timeSp)
            }

            val backIntent = PendingIntent.getBroadcast(
                context, 703,
                Intent(context, HomeWidgetProvider::class.java).apply { action = ACTION_CAL_BACK },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.cal_day_swipe_back, backIntent)
            views.setOnClickPendingIntent(R.id.cal_day_empty, backIntent)
        }

        // 가로(클수록 큰 글씨) × 세로(짧을수록 작은 글씨) 두 제약 중 작은 쪽을 따름
        // DisplayManager로 폴더블 기기 여부 확인
        // 폴더블이면 커버/홈 구분 로직 활성화, 단일 디스플레이 기기는 항상 false
        fun isFoldableDevice(context: Context): Boolean {
            val dm = context.getSystemService(Context.DISPLAY_SERVICE)
                as android.hardware.display.DisplayManager
            return dm.displays.size >= 2
        }

        fun isTablet(context: Context): Boolean {
            return context.resources.configuration.smallestScreenWidthDp >= 600
        }

        fun resolveIsTablet(prefs: android.content.SharedPreferences, widgetId: Int, context: Context): Boolean {
            val manual = prefs.getString("widget_cover_manual_$widgetId", "auto")
            return when (manual) {
                "tablet" -> true
                "cover"  -> false
                "home"   -> false
                else     -> isTablet(context)
            }
        }

        fun resolveIsDark(prefs: android.content.SharedPreferences, widgetId: Int, context: Context): Boolean {
            val theme = prefs.getString("widget_theme_$widgetId", "system") ?: "system"
            return when (theme) {
                "dark"  -> true
                "light" -> false
                else    -> {
                    val nightModeFlags = context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
                    nightModeFlags == android.content.res.Configuration.UI_MODE_NIGHT_YES
                }
            }
        }

        // isCover 판정 우선순위:
        // 1순위: 사용자 수동 설정 ("cover" / "home" / "tablet") via WidgetConfigureActivity
        // 2순위: 폴더블 기기에서 위젯 치수 휴리스틱 (ww in 415..455)
        // 비폴더블 기기는 항상 false
        fun resolveIsCover(context: Context, prefs: android.content.SharedPreferences, widgetId: Int, widgetWidth: Int): Boolean {
            val manual = prefs.getString("widget_cover_manual_$widgetId", "auto")
            return when (manual) {
                "cover"  -> true
                "home"   -> false
                "tablet" -> false
                else     -> isFoldableDevice(context) && widgetWidth in 415..455
            }
        }

        private fun scaledSp(widgetWidth: Int, widgetHeight: Int, spAtMin: Float, spAtMax: Float): Float {
            val tW = ((widgetWidth  - 250).toFloat() / 300f).coerceIn(0f, 1f)
            val tH = ((widgetHeight - 180).toFloat() / 220f).coerceIn(0f, 1f)
            return spAtMin + minOf(tW, tH) * (spAtMax - spAtMin)
        }

        private fun partiallySetBtnColor(context: Context, viewId: Int, colorHex: String) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
            val color = android.graphics.Color.parseColor(colorHex)
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            for (id in ids) {
                val isTablet = resolveIsTablet(prefs, id, context)
                val widgetOpts = mgr.getAppWidgetOptions(id)
                val isCover = resolveIsCover(context, prefs, id, widgetOpts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 300))
                val layoutId = when {
                    isTablet -> R.layout.tablet_widget_layout
                    isCover  -> R.layout.cover_widget_layout
                    else     -> R.layout.home_widget_layout
                }
                val v = RemoteViews(context.packageName, layoutId)
                v.setInt(viewId, "setColorFilter", color)
                mgr.partiallyUpdateAppWidget(id, v)
            }
        }

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

        private fun openAppWithActionIntent(context: Context, action: String): PendingIntent =
            PendingIntent.getActivity(
                context, when (action) { "create_task" -> 500; "create_event" -> 501; else -> 502 },
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

        private fun openCreateEventForDateIntent(context: Context, dateKey: String): PendingIntent =
            PendingIntent.getActivity(
                context, 505,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("action", "create_event")
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
    }
}
