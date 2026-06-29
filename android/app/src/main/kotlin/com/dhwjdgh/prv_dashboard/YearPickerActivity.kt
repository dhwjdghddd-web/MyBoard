package com.dhwjdgh.prv_dashboard

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class YearPickerActivity : AppCompatActivity() {

    private lateinit var yearLabel: TextView
    private lateinit var btnApply: Button
    private var year: Int = 0
    private var month: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WidgetStrings.updateLocale(this)
        setContentView(R.layout.year_picker_layout)
        window.setBackgroundDrawableResource(android.R.color.transparent)

        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = java.util.Calendar.getInstance()
        year = prefs.getInt("cal_display_year", now.get(java.util.Calendar.YEAR))
        month = prefs.getInt("cal_display_month", now.get(java.util.Calendar.MONTH) + 1)

        yearLabel = findViewById(R.id.year_picker_label)
        btnApply = findViewById(R.id.year_picker_apply)
        updateLabel()

        findViewById<android.view.View>(R.id.year_picker_prev).setOnClickListener {
            year--; updateLabel()
        }
        findViewById<android.view.View>(R.id.year_picker_next).setOnClickListener {
            year++; updateLabel()
        }
        findViewById<Button>(R.id.year_picker_cancel).setOnClickListener { finish() }
        btnApply.setOnClickListener { applyYear() }
    }

    private fun updateLabel() {
        yearLabel.text = year.toString()
    }

    private fun applyYear() {
        btnApply.isEnabled = false
        btnApply.text = WidgetStrings.yearPickerMoving

        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt("cal_display_year", year)
            .putBoolean("cal_show_day_panel", false)
            .apply()

        redrawWidgets()

        val lastSync = prefs.getLong("cal_synced_${year}_${month}", 0L)
        val isCached = System.currentTimeMillis() - lastSync < 30 * 60 * 1000L
        if (isCached) {
            finish()
        } else {
            CalendarSyncJobService.executeSync(applicationContext, year, month) {
                runOnUiThread { finish() }
            }
        }
    }

    private fun redrawWidgets() {
        val manager = AppWidgetManager.getInstance(applicationContext)
        val ids = manager.getAppWidgetIds(ComponentName(applicationContext, HomeWidgetProvider::class.java))
        ids.forEach { id -> HomeWidgetProvider.updateWidget(applicationContext, manager, id) }
    }

    companion object {
        private const val PREFS = "HomeWidgetPreferences"
    }
}
