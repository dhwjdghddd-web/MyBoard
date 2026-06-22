package com.dhwjdgh.prv_dashboard

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import java.util.Calendar

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val now = Calendar.getInstance()
        val year = now.get(Calendar.YEAR)
        val month = now.get(Calendar.MONTH) + 1

        TasksSyncJobService.executeSync(context)
        CalendarSyncJobService.executeSync(context, year, month)

        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, HomeWidgetProvider::class.java))
        for (id in ids) {
            HomeWidgetProvider.updateWidget(context, mgr, id)
        }
    }
}
