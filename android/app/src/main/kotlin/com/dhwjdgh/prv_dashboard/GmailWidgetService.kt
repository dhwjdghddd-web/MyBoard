package com.dhwjdgh.prv_dashboard

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class GmailWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        GmailWidgetFactory(applicationContext, isCover = false)
}

class GmailWidgetServiceCover : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        GmailWidgetFactory(applicationContext, isCover = true)
}

class GmailWidgetFactory(private val context: Context, private val isCover: Boolean = false) : RemoteViewsService.RemoteViewsFactory {

    private val PREFS = "HomeWidgetPreferences"
    private var emailsList = mutableListOf<EmailItem>()

    data class EmailItem(
        val sender: String,
        val time: String,
        val subject: String,
        val isUnread: Boolean,
        val emailId: String
    )

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        emailsList.clear()
    }

    override fun getCount(): Int {
        return emailsList.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.gmail_item_layout)
        if (position >= emailsList.size) return views

        val item = emailsList[position]
        
        views.setTextViewText(R.id.gmail_item_sender, item.sender.ifEmpty { "(이름 없음)" })
        views.setTextViewText(R.id.gmail_item_time, item.time)
        views.setTextViewText(R.id.gmail_item_subject, item.subject)

        views.setTextColor(R.id.gmail_item_sender, if (item.isUnread) Color.WHITE else Color.parseColor("#B0B0C0"))
        if (isCover) {
            views.setTextViewTextSize(R.id.gmail_item_sender,  android.util.TypedValue.COMPLEX_UNIT_SP, 17f)
            views.setTextViewTextSize(R.id.gmail_item_time,    android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
            views.setTextViewTextSize(R.id.gmail_item_subject, android.util.TypedValue.COMPLEX_UNIT_SP, 15f)
        }
        
        val openIntent = Intent().apply {
            putExtra("gmail_item_action", "open")
            putExtra("tab", 2)
            if (item.emailId.isNotEmpty()) putExtra("email_id", item.emailId)
        }
        views.setOnClickFillInIntent(R.id.gmail_item_root, openIntent)

        val deleteIntent = Intent().apply {
            putExtra("gmail_item_action", "delete")
            putExtra("email_id", item.emailId)
            putExtra("email_idx", position)
        }
        views.setOnClickFillInIntent(R.id.gmail_item_delete, deleteIntent)
        
        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }

    private fun loadData() {
        emailsList.clear()
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val count = try {
            prefs.getInt("gmail_count", 0)
        } catch (e: ClassCastException) {
            prefs.getString("gmail_count", "0")?.toIntOrNull() ?: 0
        }

        for (i in 0 until count) {
            val sender = prefs.getString("gmail_${i}_sender", "") ?: ""
            val time = prefs.getString("gmail_${i}_time", "") ?: ""
            val subject = prefs.getString("gmail_${i}_subject", "") ?: ""
            val unread = prefs.getString("gmail_${i}_unread", "false") == "true"
            val emailId = prefs.getString("gmail_${i}_id", "") ?: ""

            if (sender.isNotEmpty() || subject.isNotEmpty()) {
                emailsList.add(EmailItem(sender, time, subject, unread, emailId))
            }
        }
    }
}
