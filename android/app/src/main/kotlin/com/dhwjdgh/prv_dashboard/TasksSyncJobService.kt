package com.dhwjdgh.prv_dashboard

import android.app.job.JobParameters
import android.app.job.JobService
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.ProtocolException

class TasksSyncJobService : JobService() {
    private var jobThread: Thread? = null

    override fun onStartJob(params: JobParameters?): Boolean {
        val action = params?.extras?.getString("action", "sync") ?: "sync"
        val taskId = params?.extras?.getString("task_id", "") ?: ""
        val listId = params?.extras?.getString("list_id", "") ?: ""
        val isCompleted = params?.extras?.getBoolean("is_completed", true) ?: true
        val ctx = applicationContext

        jobThread = Thread {
            try {
                when (action) {
                    "complete" -> {
                        if (taskId.isNotEmpty()) executeCompleteInternal(ctx, taskId, isCompleted, listId)
                    }
                    "delete" -> {
                        if (taskId.isNotEmpty()) executeDeleteInternal(ctx, taskId, listId)
                    }
                    else -> {
                        executeSyncInternal(ctx)
                    }
                }
                // 위젯 갱신
                val mgr = AppWidgetManager.getInstance(ctx)
                val ids = mgr.getAppWidgetIds(ComponentName(ctx, HomeWidgetProvider::class.java))
                for (id in ids) HomeWidgetProvider.updateWidget(ctx, mgr, id)
            } finally {
                jobFinished(params, false)
            }
        }.apply { start() }
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        jobThread?.interrupt()
        return true
    }

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

        fun executeComplete(context: Context, taskId: String, isCompleted: Boolean, listId: String? = null, onDone: () -> Unit = {}) {
            Thread {
                executeCompleteInternal(context, taskId, isCompleted, listId)
                onDone()
            }.start()
        }

        fun executeDelete(context: Context, taskId: String, listId: String? = null, onDone: () -> Unit = {}) {
            Thread {
                executeDeleteInternal(context, taskId, listId)
                onDone()
            }.start()
        }

        private fun executeSyncInternal(context: Context) {
            Log.d(TAG, "executeSyncInternal: start")
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (!token.isNullOrEmpty()) {
                runCatching { syncTasks(context, token!!) }
                    .onSuccess { Log.d(TAG, "syncTasks success") }
                    .onFailure { e ->
                        Log.e(TAG, "syncTasks failed: $e — retrying with fresh token")
                        freshToken(context)?.let { t ->
                            runCatching { syncTasks(context, t) }
                                .onSuccess { Log.d(TAG, "syncTasks retry success") }
                                .onFailure { e2 -> Log.e(TAG, "syncTasks retry failed: $e2") }
                        }
                    }
            } else {
                Log.e(TAG, "No token available — sync skipped")
            }
        }

        // 모든 태스크 목록을 조회해 ID 집합을 반환한다. 실패 시 기본 목록만.
        private fun fetchListIds(token: String): List<String> {
            return try {
                val body = doGet(token, URL("https://tasks.googleapis.com/tasks/v1/users/@me/lists"))
                    ?: return listOf("@default")
                val items = JSONObject(body).optJSONArray("items") ?: return listOf("@default")
                val ids = mutableListOf<String>()
                for (i in 0 until items.length()) {
                    val id = items.getJSONObject(i).optString("id", "")
                    if (id.isNotEmpty()) ids.add(id)
                }
                if (ids.isEmpty()) listOf("@default") else ids
            } catch (e: Exception) {
                Log.e(TAG, "fetchListIds failed: $e")
                listOf("@default")
            }
        }

        private fun executeCompleteInternal(context: Context, taskId: String, isCompleted: Boolean, listId: String?) {
            val targetList = listId?.takeIf { it.isNotEmpty() } ?: readListId(context) ?: "@default"
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (!token.isNullOrEmpty()) {
                runCatching { completeTask(token!!, targetList, taskId, isCompleted) }.onFailure {
                    freshToken(context)?.let { t -> runCatching { completeTask(t, targetList, taskId, isCompleted) } }
                }
            }
        }

        private fun executeDeleteInternal(context: Context, taskId: String, listId: String?) {
            val targetList = listId?.takeIf { it.isNotEmpty() } ?: readListId(context) ?: "@default"
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (!token.isNullOrEmpty()) {
                runCatching { deleteTask(token!!, targetList, taskId) }.onFailure {
                    freshToken(context)?.let { t -> runCatching { deleteTask(t, targetList, taskId) } }
                }
            }
        }

        private fun syncTasks(context: Context, token: String) {
            val listIds = fetchListIds(token)

            val activeTasks = mutableListOf<TaskItem>()
            val completedTasks = mutableListOf<TaskItem>()

            for (listId in listIds) {
                val urlStr = "https://tasks.googleapis.com/tasks/v1/lists/$listId/tasks?showCompleted=true&maxResults=100"
                val body = doGet(token, URL(urlStr)) ?: continue
                val items = JSONObject(body).optJSONArray("items") ?: continue
                for (i in 0 until items.length()) {
                    val item = items.getJSONObject(i)
                    val id = item.optString("id", "")
                    val title = item.optString("title", "")
                    val status = item.optString("status", "needsAction")
                    val due = if (item.has("due")) item.optString("due", null) else null
                    if (id.isEmpty()) continue

                    val task = TaskItem(id, listId, title, status == "completed", due)
                    if (task.isCompleted) completedTasks.add(task) else activeTasks.add(task)
                }
            }

            // 미완료 먼저, 완료 나중 (앱/위젯 표시 순서와 동일)
            val sorted = activeTasks + completedTasks

            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val edit = prefs.edit()

            edit.putString("task_count", sorted.size.toString())

            for (i in sorted.indices) {
                val task = sorted[i]
                edit.putString("task_$i", task.title)
                edit.putString("task_${i}_id", task.id)
                edit.putString("task_${i}_list", task.listId)
                edit.putString("task_${i}_done", if (task.isCompleted) "true" else "false")
                edit.putString("task_${i}_due", task.due ?: "")
            }
            // 이전 동기화에서 남은 슬롯 제거
            for (i in sorted.size until sorted.size + 30) {
                if ((prefs.getString("task_$i", "") ?: "").isEmpty()) break
                edit.putString("task_$i", "")
                edit.putString("task_${i}_id", "")
                edit.putString("task_${i}_list", "")
                edit.putString("task_${i}_done", "false")
                edit.putString("task_${i}_due", "")
            }
            edit.commit()
            Log.d(TAG, "syncTasks written ${activeTasks.size} active / ${completedTasks.size} done from ${listIds.size} lists")
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
            var conn: HttpURLConnection? = null
            return try {
                conn = url.openConnection() as HttpURLConnection
                
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
                if (code in 200..299) {
                    conn.inputStream.bufferedReader().use { it.readText() }
                } else {
                    if (code == 401) throw Exception("HTTP 401")
                    null
                }
            } finally {
                conn?.disconnect()
            }
        }

        private fun readListId(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return prefs.getString("task_list_id", null)
        }

        private fun readToken(context: Context): String? = TokenManager.readCachedToken(context)

        private fun freshToken(context: Context): String? =
            TokenManager.fetchFreshToken(context, "oauth2:https://www.googleapis.com/auth/tasks")
    }

    private data class TaskItem(val id: String, val listId: String, val title: String, val isCompleted: Boolean, val due: String?)
}

