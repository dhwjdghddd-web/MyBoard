package com.dhwjdgh.prv_dashboard

import android.app.job.JobParameters
import android.app.job.JobService
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import com.google.android.gms.auth.api.signin.GoogleSignIn
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.ProtocolException

class TasksSyncJobService : JobService() {

    override fun onStartJob(params: JobParameters?): Boolean {
        val action = params?.extras?.getString("action", "sync") ?: "sync"
        val taskId = params?.extras?.getString("task_id", "") ?: ""
        val isCompleted = params?.extras?.getBoolean("is_completed", true) ?: true
        val ctx = applicationContext

        Thread {
            when (action) {
                "complete" -> {
                    if (taskId.isNotEmpty()) executeCompleteInternal(ctx, taskId, isCompleted)
                }
                "delete" -> {
                    if (taskId.isNotEmpty()) executeDeleteInternal(ctx, taskId)
                }
                else -> {
                    executeSyncInternal(ctx)
                }
            }
            // 위젯 갱신
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, HomeWidgetProvider::class.java))
            for (id in ids) HomeWidgetProvider.updateWidget(ctx, mgr, id)
            
            jobFinished(params, false)
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean = true

    companion object {
        const val PREFS = "HomeWidgetPreferences"
        private const val TAG = "TasksSync"
        private val isSyncing = java.util.concurrent.atomic.AtomicBoolean(false)

        fun executeSync(context: Context, onDone: () -> Unit = {}) {
            if (!isSyncing.compareAndSet(false, true)) {
                Log.d(TAG, "sync already in progress — skipping duplicate request")
                onDone()
                return
            }
            Thread {
                try {
                    executeSyncInternal(context)
                } finally {
                    isSyncing.set(false)
                }
                onDone()
            }.start()
        }

        fun executeComplete(context: Context, taskId: String, isCompleted: Boolean, onDone: () -> Unit = {}) {
            Thread {
                executeCompleteInternal(context, taskId, isCompleted)
                onDone()
            }.start()
        }

        fun executeDelete(context: Context, taskId: String, onDone: () -> Unit = {}) {
            Thread {
                executeDeleteInternal(context, taskId)
                onDone()
            }.start()
        }

        private fun executeSyncInternal(context: Context) {
            Log.d(TAG, "executeSyncInternal: start")
            val listId = readListId(context) ?: "@default"
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (!token.isNullOrEmpty()) {
                runCatching { syncTasks(context, token!!, listId) }
                    .onSuccess { Log.d(TAG, "syncTasks success") }
                    .onFailure { e ->
                        Log.e(TAG, "syncTasks failed: $e — retrying with fresh token")
                        freshToken(context)?.let { t ->
                            runCatching { syncTasks(context, t, listId) }
                                .onSuccess { Log.d(TAG, "syncTasks retry success") }
                                .onFailure { e2 -> Log.e(TAG, "syncTasks retry failed: $e2") }
                        }
                    }
            } else {
                Log.e(TAG, "No token available — sync skipped")
            }
        }

        private fun executeCompleteInternal(context: Context, taskId: String, isCompleted: Boolean) {
            val listId = readListId(context) ?: "@default"
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (!token.isNullOrEmpty()) {
                runCatching { completeTask(token!!, listId, taskId, isCompleted) }.onFailure {
                    freshToken(context)?.let { t -> runCatching { completeTask(t, listId, taskId, isCompleted) } }
                }
            }
        }

        private fun executeDeleteInternal(context: Context, taskId: String) {
            val listId = readListId(context) ?: "@default"
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (!token.isNullOrEmpty()) {
                runCatching { deleteTask(token!!, listId, taskId) }.onFailure {
                    freshToken(context)?.let { t -> runCatching { deleteTask(t, listId, taskId) } }
                }
            }
        }

        private fun syncTasks(context: Context, token: String, listId: String) {
            val urlStr = "https://tasks.googleapis.com/tasks/v1/lists/$listId/tasks?showCompleted=true&maxResults=100"
            val body = doGet(token, URL(urlStr)) ?: return
            
            val items = JSONObject(body).optJSONArray("items") ?: org.json.JSONArray()
            
            val activeTasks = mutableListOf<TaskItem>()
            val completedTasks = mutableListOf<TaskItem>()
            
            for (i in 0 until items.length()) {
                val item = items.getJSONObject(i)
                val id = item.optString("id", "")
                val title = item.optString("title", "")
                val status = item.optString("status", "needsAction")
                if (id.isEmpty()) continue
                
                val task = TaskItem(id, title, status == "completed")
                if (task.isCompleted) {
                    completedTasks.add(task)
                } else {
                    activeTasks.add(task)
                }
            }
            
            val sorted = activeTasks + completedTasks
            
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val edit = prefs.edit()
            
            edit.putString("task_count", sorted.size.toString())

            for (i in sorted.indices) {
                val task = sorted[i]
                edit.putString("task_$i", task.title)
                edit.putString("task_${i}_id", task.id)
                edit.putString("task_${i}_done", if (task.isCompleted) "true" else "false")
            }
            // 이전 동기화에서 남은 슬롯 제거
            for (i in sorted.size until sorted.size + 30) {
                if ((prefs.getString("task_$i", "") ?: "").isEmpty()) break
                edit.putString("task_$i", "")
                edit.putString("task_${i}_id", "")
                edit.putString("task_${i}_done", "false")
            }
            edit.commit()
            Log.d(TAG, "syncTasks written ${activeTasks.size} active tasks to prefs")
        }

        private fun completeTask(token: String, listId: String, taskId: String, isCompleted: Boolean) {
            val url = URL("https://tasks.googleapis.com/tasks/v1/lists/$listId/tasks/$taskId")
            val status = if (isCompleted) "completed" else "needsAction"
            val body = JSONObject().apply {
                put("id", taskId)
                put("status", status)
            }.toString()
            
            doRequest(token, url, "PATCH", body)
        }

        private fun deleteTask(token: String, listId: String, taskId: String) {
            val url = URL("https://tasks.googleapis.com/tasks/v1/lists/$listId/tasks/$taskId")
            doRequest(token, url, "DELETE")
        }

        private fun doGet(token: String, url: URL): String? {
            return doRequest(token, url, "GET")
        }

        private fun doRequest(token: String, url: URL, method: String, body: String? = null): String? {
            val conn = url.openConnection() as HttpURLConnection
            
            if (method == "PATCH") {
                try {
                    conn.requestMethod = "PATCH"
                } catch (e: ProtocolException) {
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                }
            } else {
                conn.requestMethod = method
            }

            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.connectTimeout = 15_000
            conn.readTimeout    = 15_000

            if (body != null) {
                conn.setRequestProperty("Content-Type", "application/json; utf-8")
                conn.doOutput = true
                conn.outputStream.use { os ->
                    val input = body.toByteArray(charset("utf-8"))
                    os.write(input, 0, input.size)
                }
            } else if (method == "PATCH" || method == "POST") {
                conn.setRequestProperty("Content-Length", "0")
            }

            val code = conn.responseCode
            return if (code in 200..299) {
                val res = conn.inputStream.bufferedReader().use { it.readText() }
                conn.disconnect()
                res
            } else {
                conn.disconnect()
                if (code == 401) throw Exception("HTTP 401")
                null
            }
        }

        private fun readListId(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return prefs.getString("task_list_id", null)
        }

        private fun readToken(context: Context): String? = runCatching {
            val alias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
            EncryptedSharedPreferences.create(
                "FlutterSecureStorage", alias, context,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            ).getString("VGtWcmJHbHVaMjl1_access_token", null)
        }.getOrNull()

        private fun freshToken(context: Context): String? = runCatching {
            val acct = GoogleSignIn.getLastSignedInAccount(context) ?: return null
            val scope = "oauth2:https://www.googleapis.com/auth/calendar.readonly " +
                        "https://www.googleapis.com/auth/tasks " +
                        "https://www.googleapis.com/auth/gmail.modify"
            com.google.android.gms.auth.GoogleAuthUtil.getToken(context, acct.account!!, scope)
        }.getOrNull()
    }

    private data class TaskItem(val id: String, val title: String, val isCompleted: Boolean)
}
