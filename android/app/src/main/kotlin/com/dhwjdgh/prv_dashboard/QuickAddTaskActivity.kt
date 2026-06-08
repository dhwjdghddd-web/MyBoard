package com.dhwjdgh.prv_dashboard

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class QuickAddTaskActivity : AppCompatActivity() {

    private lateinit var taskInput: EditText
    private lateinit var btnAdd: Button
    private lateinit var btnCancel: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.quick_add_task_layout)

        taskInput  = findViewById(R.id.task_input)
        btnAdd     = findViewById(R.id.btn_add)
        btnCancel  = findViewById(R.id.btn_cancel)

        taskInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) { addTask(); true } else false
        }
        btnAdd.setOnClickListener { addTask() }
        btnCancel.setOnClickListener { finish() }

        // 키보드 자동 열기
        taskInput.requestFocus()
        taskInput.postDelayed({
            (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
                .showSoftInput(taskInput, InputMethodManager.SHOW_IMPLICIT)
        }, 150)
    }

    private fun addTask() {
        val title = taskInput.text.toString().trim()
        if (title.isEmpty()) { taskInput.error = "이름을 입력해주세요"; return }

        btnAdd.isEnabled    = false
        btnCancel.isEnabled = false
        btnAdd.text         = "추가 중…"

        Thread {
            val success = tryApiCall(title)
            if (!success) storePending(title)

            runOnUiThread {
                if (success) Toast.makeText(this, "태스크가 추가됐어요 ✓", Toast.LENGTH_SHORT).show()
                finish()
            }
        }.start()
    }

    private fun tryApiCall(title: String): Boolean {
        return try {
            val token = readToken() ?: return false

            val url  = URL("https://tasks.googleapis.com/tasks/v1/lists/%40default/tasks")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                doOutput       = true
                connectTimeout = 10_000
                readTimeout    = 10_000
            }

            val body = JSONObject().apply { put("title", title) }.toString()
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }

            val code     = conn.responseCode
            val response = if (code in 200..299) conn.inputStream.bufferedReader().readText() else ""
            conn.disconnect()

            if (code in 200..299) {
                val newId = try { JSONObject(response).getString("id") } catch (_: Exception) { "" }
                pushToWidget(title, newId)
                true
            } else false

        } catch (_: Exception) { false }
    }

    private fun readToken(): String? {
        return try {
            val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
            EncryptedSharedPreferences.create(
                "FlutterSecureStorage",
                masterKeyAlias,
                this,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            ).getString("access_token", null)
        } catch (_: Exception) { null }
    }

    private fun pushToWidget(title: String, newId: String) {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val edit  = prefs.edit()
        // 기존 항목 한 칸씩 뒤로
        for (i in 2 downTo 1) {
            edit.putString("task_$i",       prefs.getString("task_${i-1}", "")       ?: "")
            edit.putString("task_${i}_id",  prefs.getString("task_${i-1}_id", "")    ?: "")
            edit.putString("task_${i}_done",prefs.getString("task_${i-1}_done","false") ?: "false")
        }
        edit.putString("task_0",       title)
        edit.putString("task_0_id",    newId)
        edit.putString("task_0_done",  "false")
        edit.apply()

        val manager = AppWidgetManager.getInstance(applicationContext)
        manager.getAppWidgetIds(
            ComponentName(applicationContext, HomeWidgetProvider::class.java)
        ).forEach { id -> HomeWidgetProvider.updateWidget(applicationContext, manager, id) }
    }

    private fun storePending(title: String) {
        val prefs   = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val current = prefs.getString("pending_new_tasks", "") ?: ""
        val updated = if (current.isEmpty()) title else "$current\n$title"
        prefs.edit().putString("pending_new_tasks", updated).apply()
    }
}
