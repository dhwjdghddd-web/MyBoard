package com.dhwjdgh.prv_dashboard

import android.app.Application
import android.util.Log
import androidx.work.Configuration
import androidx.work.WorkManager

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        initWorkManagerSafely()
    }

    private fun initWorkManagerSafely() {
        try {
            WorkManager.initialize(applicationContext, Configuration.Builder().build())
        } catch (e: IllegalStateException) {
            // already initialized — fine
        } catch (e: Exception) {
            Log.w("App", "WorkManager init failed (DB corrupt?), resetting: $e")
            arrayOf("androidx.work.workdb", "androidx.work.workdb-wal", "androidx.work.workdb-shm")
                .forEach { runCatching { deleteDatabase(it) } }
            runCatching {
                WorkManager.initialize(applicationContext, Configuration.Builder().build())
            }.onFailure { e2 -> Log.e("App", "WorkManager init failed after reset: $e2") }
        }
    }
}
