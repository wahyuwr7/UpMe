package app.upme.upme.capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import app.upme.upme.R
import org.json.JSONObject
import java.util.UUID

/**
 * Listens to every notification the user receives (after they grant
 * "Notification access"), keeps the ones that look like transactions and
 * either pops the confirmation dialog over the current app or posts a quiet
 * "tap to log" notification.
 */
class TransactionNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            handle(sbn ?: return)
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to process notification", t)
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return

        val store = CaptureStore(this)
        if (!store.enabled) return

        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.joinToString("\n") { it.toString() }
        val body = listOfNotNull(bigText ?: text, lines).filter { it.isNotBlank() }.joinToString("\n")
        val full = "$title\n$body".trim()
        if (full.isEmpty() || !CaptureFilter.looksLikeTransaction(full)) return

        val label = appLabel(sbn)
        store.recordSeen(sbn.packageName, label)
        if (sbn.packageName in store.mutedPackages) return
        if (store.isDuplicate("${sbn.packageName}|$full".hashCode().toString())) return

        val id = UUID.randomUUID().toString()
        store.addPending(
            JSONObject()
                .put("id", id)
                .put("package", sbn.packageName)
                .put("appName", label)
                .put("title", title)
                .put("text", body)
                .put("postedAt", sbn.postTime)
        )

        if (store.popupEnabled && Settings.canDrawOverlays(this)) {
            // SYSTEM_ALERT_WINDOW exempts us from background-activity-start limits.
            startActivity(CaptureActivity.intent(this))
        } else {
            postReviewNotification(label, title, body)
        }
    }

    private fun appLabel(sbn: StatusBarNotification): String {
        return try {
            @Suppress("DEPRECATION")
            val info = sbn.notification.extras.getParcelable<ApplicationInfo>("android.appInfo")
                ?: packageManager.getApplicationInfo(sbn.packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Throwable) {
            sbn.packageName
        }
    }

    private fun postReviewNotification(appLabel: String, title: String, body: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Detected transactions", NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { description = "Tap to confirm a transaction UpMe detected" }
            )
        }
        val pi = PendingIntent.getActivity(
            this, 0, CaptureActivity.intent(this),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Log this? · $appLabel")
            .setContentText(if (body.isNotBlank()) body else title)
            .setStyle(Notification.BigTextStyle().bigText("$title\n$body".trim()))
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(REVIEW_NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted: it still waits in the in-app inbox.
        }
    }

    companion object {
        private const val TAG = "UpMeListener"
        private const val CHANNEL_ID = "detected_transactions"
        private const val REVIEW_NOTIFICATION_ID = 4201
    }
}
