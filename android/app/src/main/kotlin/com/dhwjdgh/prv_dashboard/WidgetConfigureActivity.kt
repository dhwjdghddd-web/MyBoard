package com.dhwjdgh.prv_dashboard

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class WidgetConfigureActivity : AppCompatActivity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        widgetId = intent.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            setResult(RESULT_CANCELED)
            finish()
            return
        }

        // 유저가 뒤로가면 위젯 추가 취소
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        setContentView(R.layout.widget_configure_layout)

        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val existing = prefs.getString("widget_cover_manual_$widgetId", null)

        val hint = findViewById<TextView>(R.id.configure_hint)
        hint.text = when {
            existing == "cover" -> "현재 설정: 커버화면"
            existing == "home"  -> "현재 설정: 홈화면"
            HomeWidgetProvider.isFoldableDevice(this) -> "폴더블 기기 감지됨 — 화면을 선택하거나 자동 감지를 사용하세요"
            else -> "화면을 선택하거나 자동 감지를 사용하세요"
        }

        findViewById<Button>(R.id.btn_cover).setOnClickListener { saveAndFinish("cover") }
        findViewById<Button>(R.id.btn_home).setOnClickListener  { saveAndFinish("home")  }
        findViewById<Button>(R.id.btn_auto).setOnClickListener  { saveAndFinish("auto")  }
    }

    private fun saveAndFinish(choice: String) {
        getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE).edit()
            .putString("widget_cover_manual_$widgetId", choice).apply()

        val manager = AppWidgetManager.getInstance(this)
        HomeWidgetProvider.updateWidget(this, manager, widgetId)

        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }
}
