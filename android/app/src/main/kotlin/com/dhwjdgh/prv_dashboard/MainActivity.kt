package com.dhwjdgh.prv_dashboard

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "widget_channel"
    private var methodChannel: MethodChannel? = null

    companion object {
        var activeChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        activeChannel = methodChannel
        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialTab"     -> result.success(intent?.getIntExtra("tab", -1) ?: -1)
                "getInitialEmailId" -> result.success(intent?.getStringExtra("email_id") ?: "")
                "getInitialAction"  -> result.success(intent?.getStringExtra("action") ?: "")
                "getInitialEventId" -> result.success(intent?.getStringExtra("event_id") ?: "")
                "getInitialDateKey" -> result.success(intent?.getStringExtra("date_key") ?: "")
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (activeChannel == methodChannel) {
            activeChannel = null
        }
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val emailId = intent.getStringExtra("email_id") ?: ""
        val eventId = intent.getStringExtra("event_id") ?: ""
        val dateKey = intent.getStringExtra("date_key") ?: ""
        val action  = intent.getStringExtra("action") ?: ""
        val tab     = intent.getIntExtra("tab", -1)

        when {
            emailId.isNotEmpty() ->
                methodChannel?.invokeMethod("openEmail", emailId)
            dateKey.isNotEmpty() ->
                methodChannel?.invokeMethod("openCalendarDate", mapOf("eventId" to eventId, "dateKey" to dateKey))
            action == "create_task" ->
                methodChannel?.invokeMethod("openCreateTask", null)
            action == "create_event" ->
                methodChannel?.invokeMethod("openCreateEvent", null)
            action == "compose_email" ->
                methodChannel?.invokeMethod("openComposeEmail", null)
            tab >= 0 ->
                methodChannel?.invokeMethod("switchTab", tab)
        }
    }
}
