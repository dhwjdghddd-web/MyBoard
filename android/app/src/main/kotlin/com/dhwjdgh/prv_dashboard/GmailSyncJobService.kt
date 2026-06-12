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
import java.text.SimpleDateFormat
import java.util.Locale

class GmailSyncJobService : JobService() {
    private var jobThread: Thread? = null

    override fun onStartJob(params: JobParameters?): Boolean {
        val action  = params?.extras?.getString("action", "sync") ?: "sync"
        val emailId = params?.extras?.getString("email_id", "") ?: ""
        val ctx = applicationContext

        jobThread = Thread {
            try {
                if (action == "trash" && emailId.isNotEmpty()) {
                    executeTrashInternal(ctx, emailId)
                } else {
                    executeSyncInternal(ctx)
                    val mgr = AppWidgetManager.getInstance(ctx)
                    val ids = mgr.getAppWidgetIds(ComponentName(ctx, HomeWidgetProvider::class.java))
                    for (id in ids) HomeWidgetProvider.updateWidget(ctx, mgr, id)
                }
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
        private const val MAX_EMAILS = 10
        private const val TAG = "GmailSync"
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

        fun executeTrash(context: Context, emailId: String, onDone: () -> Unit = {}) {
            Thread {
                executeTrashInternal(context, emailId)
                onDone()
            }.start()
        }

        fun executeSyncInternal(context: Context) {
            Log.d(TAG, "executeSyncInternal: start")
            var token = readToken(context)
            Log.d(TAG, "token from prefs: ${if (token.isNullOrEmpty()) "NULL/EMPTY" else "OK (len=${token!!.length})"}")
            if (token.isNullOrEmpty()) {
                Log.d(TAG, "fetching fresh token via GoogleAuthUtil...")
                token = freshToken(context)
                Log.d(TAG, "freshToken result: ${if (token.isNullOrEmpty()) "NULL (failed)" else "OK"}")
            }
            if (!token.isNullOrEmpty()) {
                runCatching { syncGmail(context, token!!) }
                    .onSuccess { Log.d(TAG, "syncGmail success") }
                    .onFailure { e ->
                        Log.e(TAG, "syncGmail failed: $e — retrying with fresh token")
                        val t2 = freshToken(context)
                        if (t2 != null) {
                            runCatching { syncGmail(context, t2) }
                                .onSuccess { Log.d(TAG, "syncGmail retry success") }
                                .onFailure { e2 -> Log.e(TAG, "syncGmail retry failed: $e2") }
                        } else {
                            Log.e(TAG, "freshToken returned null on retry — sync aborted")
                        }
                    }
            } else {
                Log.e(TAG, "No token available — sync skipped")
            }
        }

        fun executeTrashInternal(context: Context, emailId: String) {
            Log.d(TAG, "executeTrashInternal: emailId=$emailId")
            var token = readToken(context)
            if (token.isNullOrEmpty()) token = freshToken(context)
            if (!token.isNullOrEmpty()) {
                runCatching { trashEmail(token!!, emailId) }
                    .onSuccess { Log.d(TAG, "trashEmail success: $emailId") }
                    .onFailure { e ->
                        Log.e(TAG, "trashEmail failed: $e — retrying")
                        freshToken(context)?.let { t ->
                            runCatching { trashEmail(t, emailId) }
                                .onSuccess { Log.d(TAG, "trashEmail retry success") }
                                .onFailure { e2 -> Log.e(TAG, "trashEmail retry failed: $e2") }
                        }
                    }
            } else {
                Log.e(TAG, "No token for trash — skipped")
            }
        }

        private fun trashEmail(token: String, emailId: String) {
            val url = URL("https://gmail.googleapis.com/gmail/v1/users/me/messages/$emailId/trash")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Content-Length", "0")
            conn.connectTimeout = 15_000
            conn.readTimeout    = 15_000
            val code = conn.responseCode
            conn.disconnect()
            if (code == 401) throw Exception("HTTP 401")
        }

        private fun syncGmail(context: Context, token: String) {
            val listUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages" +
                "?labelIds=INBOX&maxResults=$MAX_EMAILS"
            val listBody = doGet(token, URL(listUrl)) ?: return
            val messages = JSONObject(listBody).optJSONArray("messages") ?: return

            Log.d(TAG, "syncGmail: list returned ${messages.length()} messages")
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val edit = prefs.edit()

            var count = 0
            for (i in 0 until messages.length()) {
                val msgId = messages.getJSONObject(i).optString("id", "")
                if (msgId.isEmpty()) continue

                val msgUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/$msgId" +
                    "?format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date"
                val msgBody = runCatching { doGet(token, URL(msgUrl)) }.getOrNull() ?: continue
                val msg = JSONObject(msgBody)

                val labelIds = msg.optJSONArray("labelIds")
                val isUnread = (0 until (labelIds?.length() ?: 0)).any { labelIds!!.getString(it) == "UNREAD" }
                val isTrash  = (0 until (labelIds?.length() ?: 0)).any { labelIds!!.getString(it) == "TRASH" }
                if (isTrash) { Log.d(TAG, "skipping TRASH msg $msgId"); continue }

                val headers = msg.optJSONObject("payload")?.optJSONArray("headers") ?: continue
                var from = ""; var subject = ""; var date = ""
                for (j in 0 until headers.length()) {
                    val h = headers.getJSONObject(j)
                    when (h.optString("name", "").lowercase()) {
                        "from"    -> from    = h.optString("value", "")
                        "subject" -> subject = h.optString("value", "")
                        "date"    -> date    = h.optString("value", "")
                    }
                }

                val senderMatch = Regex("""^"?([^"<]+)"?\s*<""").find(from)
                val sender = senderMatch?.groupValues?.get(1)?.trim()?.ifEmpty { null } ?: from

                edit.putString("gmail_${count}_sender",  sender)
                edit.putString("gmail_${count}_time",    parseEmailDate(date))
                edit.putString("gmail_${count}_subject", subject)
                edit.putString("gmail_${count}_unread",  if (isUnread) "true" else "false")
                edit.putString("gmail_${count}_id",      msgId)
                count++
            }
            edit.putInt("gmail_count", count)
            edit.commit()  // commit() not apply() — ensures write is complete before notifyAppWidgetViewDataChanged
            Log.d(TAG, "syncGmail written $count emails to prefs")
        }

        private fun parseEmailDate(dateStr: String): String {
            if (dateStr.isEmpty()) return ""
            val formats = arrayOf(
                "EEE, dd MMM yyyy HH:mm:ss Z",
                "dd MMM yyyy HH:mm:ss Z",
                "EEE, d MMM yyyy HH:mm:ss Z"
            )
            for (fmt in formats) {
                runCatching {
                    val date = SimpleDateFormat(fmt, Locale.ENGLISH).parse(dateStr) ?: return@runCatching
                    val now = java.util.Calendar.getInstance()
                    val msgCal = java.util.Calendar.getInstance().apply { time = date }
                    return if (now.get(java.util.Calendar.YEAR) == msgCal.get(java.util.Calendar.YEAR) &&
                               now.get(java.util.Calendar.DAY_OF_YEAR) == msgCal.get(java.util.Calendar.DAY_OF_YEAR)) {
                        SimpleDateFormat("HH:mm", Locale.getDefault()).format(date)
                    } else {
                        SimpleDateFormat("M/d", Locale.getDefault()).format(date)
                    }
                }
            }
            return ""
        }

        fun doGet(token: String, url: URL): String? {
            var conn: HttpURLConnection? = null
            return try {
                conn = url.openConnection() as HttpURLConnection
                conn.setRequestProperty("Authorization", "Bearer $token")
                conn.connectTimeout = 15_000
                conn.readTimeout    = 15_000
                val code = conn.responseCode
                if (code in 200..299) {
                    conn.inputStream.bufferedReader().use { it.readText() }
                } else {
                    Log.e(TAG, "doGet HTTP $code: $url")
                    if (code == 401) throw Exception("HTTP 401")
                    null
                }
            } catch (e: Exception) {
                if (e.message == "HTTP 401") throw e
                Log.e(TAG, "doGet exception: $e for $url")
                null
            } finally {
                conn?.disconnect()
            }
        }

        fun readToken(context: Context): String? = TokenManager.readCachedToken(context)

        fun freshToken(context: Context): String? =
            TokenManager.fetchFreshToken(context, "oauth2:https://www.googleapis.com/auth/gmail.modify")
    }
}

