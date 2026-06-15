package com.dhwjdgh.prv_dashboard

import android.app.Application
import android.util.Log
import androidx.work.Configuration

class App : Application(), Configuration.Provider {

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().build()

    override fun onCreate() {
        super.onCreate()
        try {
            MailNotificationWorker.schedule(applicationContext)
        } catch (e: Exception) {
            Log.e("App", "MailNotificationWorker.schedule failed: $e")
        }
    }
}
