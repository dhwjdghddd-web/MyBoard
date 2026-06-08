package com.dhwjdgh.prv_dashboard

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews

class HomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        private const val PREFS = "HomeWidgetPlugin"

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val count = prefs.getString("task_count", "0")?.toIntOrNull() ?: 0

            val views = RemoteViews(context.packageName, R.layout.home_widget_layout)

            // 카운트 표시
            views.setTextViewText(R.id.widget_count, "${count}개")

            // 태스크 행 ID 목록 (rowId to titleId)
            val rows = listOf(
                Pair(R.id.task_row_0, R.id.task_title_0),
                Pair(R.id.task_row_1, R.id.task_title_1),
                Pair(R.id.task_row_2, R.id.task_title_2),
                Pair(R.id.task_row_3, R.id.task_title_3),
            )

            var visible = 0
            for ((i, pair) in rows.withIndex()) {
                val (rowId, titleId) = pair
                val title = prefs.getString("task_$i", "") ?: ""
                val done = prefs.getString("task_${i}_done", "false") == "true"

                if (title.isEmpty()) {
                    views.setViewVisibility(rowId, View.GONE)
                } else {
                    views.setViewVisibility(rowId, View.VISIBLE)
                    val prefix = if (done) "✓  " else "•  "
                    views.setTextViewText(titleId, "$prefix$title")
                    views.setTextColor(
                        titleId,
                        if (done) Color.parseColor("#9E9E9E") else Color.parseColor("#202124")
                    )
                    visible++
                }
            }

            // 빈 상태
            views.setViewVisibility(
                R.id.widget_empty,
                if (visible == 0) View.VISIBLE else View.GONE
            )

            // 클릭 → 앱 열기 (태스크 탭)
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("tab", 0)
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            manager.updateAppWidget(widgetId, views)
        }
    }
}
