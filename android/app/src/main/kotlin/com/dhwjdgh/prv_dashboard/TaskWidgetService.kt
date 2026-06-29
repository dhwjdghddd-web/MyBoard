package com.dhwjdgh.prv_dashboard

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TaskWidgetFactory(applicationContext, isCover = false, intent = intent)
}

class TaskWidgetServiceCover : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TaskWidgetFactory(applicationContext, isCover = true, intent = intent)
}

class TaskWidgetFactory(private val context: Context, private val isCover: Boolean = false, private val intent: Intent) : RemoteViewsService.RemoteViewsFactory {

    private val PREFS = "HomeWidgetPreferences"
    private var tasksList = mutableListOf<TaskItem>()

    data class TaskItem(val title: String, val id: String, val listId: String, val done: Boolean, val prefsIndex: Int)

    override fun onCreate() { loadData() }
    override fun onDataSetChanged() { loadData() }
    override fun onDestroy() { tasksList.clear() }
    override fun getCount(): Int = tasksList.size
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false

    private val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

    private fun resolveIsDark(): Boolean {
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            val nightModeFlags = context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
            return nightModeFlags == android.content.res.Configuration.UI_MODE_NIGHT_YES
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
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

    override fun getViewAt(position: Int): RemoteViews {
        val layoutId = if (isCover) R.layout.cover_task_item_layout else R.layout.task_item_layout
        val views = RemoteViews(context.packageName, layoutId)
        if (position >= tasksList.size) return views

        val item = tasksList[position]
        views.setTextViewText(R.id.task_item_title, item.title)
        views.setTextViewText(R.id.task_item_check, if (item.done) "☑" else "☐")

        val isDark = resolveIsDark()
        val activeTextColor = if (isDark) Color.WHITE else Color.parseColor("#1F2937")
        val doneTextColor = if (isDark) Color.parseColor("#606070") else Color.parseColor("#9CA3AF")
        val checkColor = if (isDark) Color.parseColor("#4285F4") else Color.parseColor("#1A73E8")

        views.setTextColor(R.id.task_item_title, if (item.done) doneTextColor else activeTextColor)
        views.setTextColor(R.id.task_item_check, if (item.done) doneTextColor else checkColor)
        views.setInt(R.id.task_item_delete, "setColorFilter", doneTextColor)

        val completeIntent = Intent().apply {
            putExtra("task_item_action", "complete")
            putExtra("task_id", item.id)
            putExtra("task_list", item.listId)
            putExtra("task_index", item.prefsIndex)
        }
        views.setOnClickFillInIntent(R.id.task_item_check, completeIntent)

        val deleteIntent = Intent().apply {
            putExtra("task_item_action", "delete")
            putExtra("task_id", item.id)
            putExtra("task_list", item.listId)
            putExtra("task_index", item.prefsIndex)
        }
        views.setOnClickFillInIntent(R.id.task_item_delete, deleteIntent)

        val openIntent = Intent().apply {
            putExtra("task_item_action", "open")
        }
        views.setOnClickFillInIntent(R.id.task_item_root, openIntent)

        return views
    }

    private fun loadData() {
        tasksList.clear()
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val count = prefs.getString("task_count", "0")?.toIntOrNull() ?: 0
        // widget_show_completed 가 켜져 있으면 완료된 할 일도 함께 표시한다.
        val showCompleted = prefs.getBoolean("widget_show_completed", false)
        for (i in 0 until count) {
            val title = prefs.getString("task_$i", "") ?: ""
            val id = prefs.getString("task_${i}_id", "") ?: ""
            val listId = prefs.getString("task_${i}_list", "") ?: ""
            val done = prefs.getString("task_${i}_done", "false") == "true"
            if (title.isNotEmpty() && (showCompleted || !done)) {
                tasksList.add(TaskItem(title, id, listId, done, i))
            }
        }
    }
}
