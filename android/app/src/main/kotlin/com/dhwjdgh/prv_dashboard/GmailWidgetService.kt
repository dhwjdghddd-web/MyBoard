package com.dhwjdgh.prv_dashboard

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class GmailWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        GmailWidgetFactory(applicationContext, isCover = false, intent = intent)
}

class GmailWidgetServiceCover : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        GmailWidgetFactory(applicationContext, isCover = true, intent = intent)
}

class GmailWidgetFactory(private val context: Context, private val isCover: Boolean = false, private val intent: Intent) : RemoteViewsService.RemoteViewsFactory {

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
        val layoutId = if (isCover) R.layout.cover_gmail_item_layout else R.layout.gmail_item_layout
        val views = RemoteViews(context.packageName, layoutId)
        if (position >= emailsList.size) return views

        val item = emailsList[position]
        
        val sender = item.sender.ifEmpty { "(이름 없음)" }
        views.setTextViewText(R.id.gmail_item_sender, sender)
        views.setTextViewText(R.id.gmail_item_subject, item.subject.ifEmpty { "(제목 없음)" })
        views.setTextViewText(R.id.gmail_item_time, item.time)

        val isDark = resolveIsDark()
        val unreadSender = if (isDark) Color.WHITE else Color.parseColor("#1F2937")
        val unreadSubject = if (isDark) Color.parseColor("#E0E0FF") else Color.parseColor("#1A73E8")
        val readSender = if (isDark) Color.parseColor("#A0A0B0") else Color.parseColor("#6B7280")
        val readSubject = if (isDark) Color.parseColor("#707080") else Color.parseColor("#9CA3AF")
        val timeColor = if (isDark) Color.parseColor("#707080") else Color.parseColor("#9CA3AF")

        views.setTextColor(R.id.gmail_item_sender, if (item.isUnread) unreadSender else readSender)
        views.setTextColor(R.id.gmail_item_subject, if (item.isUnread) unreadSubject else readSubject)
        views.setTextColor(R.id.gmail_item_time, timeColor)

        val openIntent = Intent().apply {
            putExtra("gmail_item_action", "open")
            putExtra("tab", 2)
            if (item.emailId.isNotEmpty()) putExtra("email_id", item.emailId)
        }
        views.setOnClickFillInIntent(R.id.gmail_item_root, openIntent)
        
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
        return false
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
