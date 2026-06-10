package com.dhwjdgh.prv_dashboard

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TaskWidgetFactory(applicationContext)
    }
}

class TaskWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private val PREFS = "HomeWidgetPreferences"
    private var tasksList = mutableListOf<TaskItem>()

    data class TaskItem(val title: String, val id: String, val done: Boolean, val prefsIndex: Int)

    override fun onCreate() { loadData() }
    override fun onDataSetChanged() { loadData() }
    override fun onDestroy() { tasksList.clear() }
    override fun getCount(): Int = tasksList.size
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.task_item_layout)
        if (position >= tasksList.size) return views

        val item = tasksList[position]
        views.setTextViewText(R.id.task_item_title, item.title)
        views.setTextViewText(R.id.task_item_check, if (item.done) "☑" else "☐")
        views.setTextColor(R.id.task_item_title, if (item.done) Color.parseColor("#606070") else Color.WHITE)
        views.setTextColor(R.id.task_item_check, if (item.done) Color.parseColor("#606070") else Color.parseColor("#4285F4"))

        val completeIntent = Intent().apply {
            putExtra("task_item_action", "complete")
            putExtra("task_id", item.id)
            putExtra("task_index", item.prefsIndex)
        }
        views.setOnClickFillInIntent(R.id.task_item_check, completeIntent)

        val deleteIntent = Intent().apply {
            putExtra("task_item_action", "delete")
            putExtra("task_id", item.id)
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
        for (i in 0 until count) {
            val title = prefs.getString("task_$i", "") ?: ""
            val id = prefs.getString("task_${i}_id", "") ?: ""
            val done = prefs.getString("task_${i}_done", "false") == "true"
            if (title.isNotEmpty()) {
                tasksList.add(TaskItem(title, id, done, i))
            }
        }
    }
}
