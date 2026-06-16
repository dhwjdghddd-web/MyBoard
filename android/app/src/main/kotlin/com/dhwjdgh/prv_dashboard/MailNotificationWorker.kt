package com.dhwjdgh.prv_dashboard

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class MailNotificationWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {

    companion object {
        private const val TAG = "MailNotifWorker"
        private const val CHANNEL_ID = "mail_channel"
        private const val PREFS_KEY = "mail_last_unread"
        private const val WORK_NAME = "mail_notification_periodic"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<MailNotificationWorker>(15, TimeUnit.MINUTES)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setBackoffCriteria(BackoffPolicy.LINEAR, 5, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }
    }

    override fun doWork(): Result {
        WidgetStrings.updateLocale(applicationContext)
        // 앱이 포그라운드면 MailPoller가 담당 — 중복 알림 방지
        if (MainActivity.activeChannel != null) {
            Log.d(TAG, "app in foreground — skipping (MailPoller active)")
            return Result.success()
        }

        val ctx = applicationContext
        var token = TokenManager.readCachedToken(ctx)
        if (token.isNullOrEmpty()) {
            token = TokenManager.fetchFreshToken(ctx,
                "oauth2:https://www.googleapis.com/auth/gmail.readonly")
        }
        if (token.isNullOrEmpty()) {
            Log.d(TAG, "no token — skip")
            return Result.success()
        }

        return try {
            val body = doGet(token, URL("https://gmail.googleapis.com/gmail/v1/users/me/labels/INBOX"))
                ?: return Result.success()
            val unread = JSONObject(body).optInt("messagesUnread", -1)
            if (unread < 0) return Result.success()

            val prefs = ctx.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val lastUnread = prefs.getInt(PREFS_KEY, -1)

            if (lastUnread == -1) {
                // 첫 실행 — 기준선만 기록, 알림 없음
                prefs.edit().putInt(PREFS_KEY, unread).apply()
                return Result.success()
            }

            if (unread > lastUnread) {
                val newCount = unread - lastUnread
                val from = fetchLatestSender(token) ?: WidgetStrings.mailNotificationDefaultSender
                sendNotification(ctx, newCount, from)
            }
            prefs.edit().putInt(PREFS_KEY, unread).apply()
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "doWork failed: $e")
            Result.retry()
        }
    }

    private fun fetchLatestSender(token: String): String? = runCatching {
        val listBody = doGet(token, URL(
            "https://gmail.googleapis.com/gmail/v1/users/me/messages?labelIds=INBOX&maxResults=1&q=is:unread"
        )) ?: return null
        val msgs = JSONObject(listBody).optJSONArray("messages") ?: return null
        if (msgs.length() == 0) return null
        val msgId = msgs.getJSONObject(0).optString("id").ifEmpty { return null }
        val msgBody = doGet(token, URL(
            "https://gmail.googleapis.com/gmail/v1/users/me/messages/$msgId?format=metadata&metadataHeaders=From"
        )) ?: return null
        val headers = JSONObject(msgBody).optJSONObject("payload")?.optJSONArray("headers") ?: return null
        for (i in 0 until headers.length()) {
            val h = headers.getJSONObject(i)
            if (h.optString("name", "").lowercase() == "from") {
                val raw = h.optString("value", "")
                val match = Regex("""^"?([^"<]+)"?\s*<""").find(raw)
                return match?.groupValues?.get(1)?.trim()?.ifEmpty { null } ?: raw.ifEmpty { null }
            }
        }
        null
    }.onFailure { Log.w(TAG, "fetchLatestSender failed: $it") }.getOrNull()

    private fun sendNotification(ctx: Context, newCount: Int, from: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Flutter NotificationService가 채널을 만들기 전에 워커가 먼저 실행될 수 있으므로 여기서도 생성
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, WidgetStrings.mailChannelName, NotificationManager.IMPORTANCE_HIGH).apply {
                    description = WidgetStrings.mailChannelDesc
                }
            )
        }

        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("tab", 2)
        }
        val pi = PendingIntent.getActivity(
            ctx, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(WidgetStrings.mailNotificationTitle(newCount))
            .setContentText(from)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()

        val id = (System.currentTimeMillis() and 0x7FFFFFFF).toInt()
        nm.notify(id, notification)
        Log.d(TAG, "알림 발송: 새 메일 ${newCount}통 from $from")
    }

    private fun doGet(token: String, url: URL): String? {
        var conn: HttpURLConnection? = null
        return try {
            conn = url.openConnection() as HttpURLConnection
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000
            if (conn.responseCode in 200..299) {
                conn.inputStream.bufferedReader().use { it.readText() }
            } else {
                Log.e(TAG, "doGet HTTP ${conn.responseCode}: $url")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "doGet exception: $e")
            null
        } finally {
            conn?.disconnect()
        }
    }
}
