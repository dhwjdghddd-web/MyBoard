package com.dhwjdgh.prv_dashboard

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "widget_channel"
    private var methodChannel: MethodChannel? = null
    private var isActivityResumed = false
    private var pendingIntentAction: Intent? = null

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
                "getInitialAction"  -> result.success(intent?.getStringExtra("action") ?: "")
                "getInitialEventId" -> result.success(intent?.getStringExtra("event_id") ?: "")
                "getInitialDateKey" -> result.success(intent?.getStringExtra("date_key") ?: "")
                "getWidgetConfigs"  -> result.success(getWidgetConfigs())
                "setWidgetConfig"   -> {
                    val args = call.arguments as Map<*, *>
                    val id      = (args["id"] as Int)
                    val setting = args["setting"] as String
                    setWidgetConfig(id, setting)
                    result.success(null)
                }
                "setWidgetTheme"    -> {
                    val args = call.arguments as Map<*, *>
                    val id    = (args["id"] as Int)
                    val theme = args["theme"] as String
                    setWidgetTheme(id, theme)
                    result.success(null)
                }
                "setWidgetOpacity"  -> {
                    val args = call.arguments as Map<*, *>
                    val id      = (args["id"] as Int)
                    val opacity = (args["opacity"] as Number).toFloat()
                    setWidgetOpacity(id, opacity)
                    result.success(null)
                }
                "saveAttachment" -> {
                    val args = call.arguments as Map<*, *>
                    val filename  = args["filename"] as String
                    val mimeType  = args["mimeType"] as String
                    val base64Data = args["data"] as String
                    saveAttachment(filename, mimeType, base64Data, result)
                }
                "openFile" -> {
                    val args     = call.arguments as Map<*, *>
                    val filePath = args["uri"] as String
                    val rawMime  = args["mimeType"] as String
                    try {
                        val file = java.io.File(filePath)
                        val uri  = androidx.core.content.FileProvider.getUriForFile(
                            this, "${packageName}.fileprovider", file
                        )
                        // 확장자로 MIME 타입 보정 (Gmail이 octet-stream 반환할 때 대비)
                        val ext = file.extension.lowercase()
                        val mimeType = if (rawMime == "application/octet-stream" || rawMime.isBlank()) {
                            android.webkit.MimeTypeMap.getSingleton()
                                .getMimeTypeFromExtension(ext) ?: rawMime
                        } else rawMime

                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, mimeType)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            clipData = android.content.ClipData.newRawUri("", uri)
                        }
                        WidgetStrings.updateLocale(this)
                        val chooser = android.content.Intent.createChooser(intent, WidgetStrings.fileChooserTitle).apply {
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(chooser)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.message, null)
                    }
                }
                "findExistingDownload" -> {
                    val filename = call.arguments as String
                    result.success(findExistingDownload(filename))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getWidgetConfigs(): List<Map<String, Any>> {
        val mgr   = AppWidgetManager.getInstance(this)
        val ids   = mgr.getAppWidgetIds(ComponentName(this, HomeWidgetProvider::class.java))
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        return ids.map { id ->
            val opts   = mgr.getAppWidgetOptions(id)
            val width  = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
            val height = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            val manual = prefs.getString("widget_cover_manual_$id", "auto") ?: "auto"
            val isCover = HomeWidgetProvider.resolveIsCover(this, prefs, id, width)
            val isTablet = HomeWidgetProvider.resolveIsTablet(prefs, id, this)
            val theme = prefs.getString("widget_theme_$id", "system") ?: "system"
            val opacity = prefs.getFloat("widget_opacity_$id", 1.0f).toDouble()
            mapOf("id" to id, "width" to width, "height" to height,
                  "manual" to manual, "isCover" to isCover, "isTablet" to isTablet, "theme" to theme,
                  "opacity" to opacity)
        }
    }

    private fun downloadsDir(): java.io.File {
        val dir = getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS)
            ?: java.io.File(cacheDir, "downloads")
        dir.mkdirs()
        return dir
    }

    private fun findExistingDownload(filename: String): String? {
        val file = java.io.File(downloadsDir(), filename)
        return if (file.exists()) file.absolutePath else null
    }

    private fun saveAttachment(filename: String, mimeType: String, base64Data: String, result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val safeFilename = filename.replace("/", "_").replace("\\", "_").replace("..", "_")
            val normalized = base64Data.replace("\n", "").replace(" ", "")
                .replace("-", "+").replace("_", "/")
            val bytes = android.util.Base64.decode(normalized, android.util.Base64.DEFAULT)
            val file  = java.io.File(downloadsDir(), safeFilename)
            file.writeBytes(bytes)
            result.success(file.absolutePath)
        } catch (e: Exception) {
            result.error("SAVE_ERROR", e.message, null)
        }
    }

    private fun setWidgetConfig(widgetId: Int, setting: String) {
        getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE).edit()
            .putString("widget_cover_manual_$widgetId", setting).apply()
        val mgr = AppWidgetManager.getInstance(this)
        HomeWidgetProvider.updateWidget(this, mgr, widgetId)
    }

    private fun setWidgetTheme(widgetId: Int, theme: String) {
        getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE).edit()
            .putString("widget_theme_$widgetId", theme).apply()
        val mgr = AppWidgetManager.getInstance(this)
        HomeWidgetProvider.updateWidget(this, mgr, widgetId)
    }

    private fun setWidgetOpacity(widgetId: Int, opacity: Float) {
        getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE).edit()
            .putFloat("widget_opacity_$widgetId", opacity).apply()
        val mgr = AppWidgetManager.getInstance(this)
        HomeWidgetProvider.updateWidget(this, mgr, widgetId)
    }

    override fun onResume() {
        super.onResume()
        isActivityResumed = true
        try {
            val mgr = AppWidgetManager.getInstance(this)
            val ids = mgr.getAppWidgetIds(ComponentName(this, HomeWidgetProvider::class.java))
            for (id in ids) {
                HomeWidgetProvider.updateWidget(this, mgr, id)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        pendingIntentAction?.let {
            processIntentAction(it)
            pendingIntentAction = null
        }
    }

    override fun onPause() {
        super.onPause()
        isActivityResumed = false
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
        if (isActivityResumed) {
            processIntentAction(intent)
        } else {
            pendingIntentAction = intent
        }
    }

    private fun processIntentAction(intent: Intent) {
        val eventId = intent.getStringExtra("event_id") ?: ""
        val dateKey = intent.getStringExtra("date_key") ?: ""
        val action  = intent.getStringExtra("action") ?: ""
        val tab     = intent.getIntExtra("tab", -1)

        when {
            action == "create_event" ->
                methodChannel?.invokeMethod("openCreateEvent", dateKey.ifEmpty { null })
            dateKey.isNotEmpty() ->
                methodChannel?.invokeMethod("openCalendarDate", mapOf("eventId" to eventId, "dateKey" to dateKey))
            action == "create_task" ->
                methodChannel?.invokeMethod("openCreateTask", null)
            tab >= 0 ->
                methodChannel?.invokeMethod("switchTab", tab)
        }
    }
}
