package app.upme.upme.capture

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Method channel `upme/capture` shared by MainActivity and CaptureActivity. */
object CaptureChannel {
    private const val NAME = "upme/capture"

    fun register(activity: Activity, engine: FlutterEngine): MethodChannel {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, NAME)
        val store = CaptureStore(activity)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "notificationAccess" to hasNotificationAccess(activity),
                        "overlay" to Settings.canDrawOverlays(activity),
                        "postNotifications" to canPostNotifications(activity),
                        "enabled" to store.enabled,
                        "popup" to store.popupEnabled,
                        "muted" to store.mutedPackages.toList(),
                    )
                )
                "openNotificationAccess" -> {
                    activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    activity.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${activity.packageName}")
                        )
                    )
                    result.success(null)
                }
                "requestPostNotifications" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
                    }
                    result.success(null)
                }
                "setEnabled" -> { store.enabled = call.arguments as Boolean; result.success(null) }
                "setPopup" -> { store.popupEnabled = call.arguments as Boolean; result.success(null) }
                "setMuted" -> {
                    @Suppress("UNCHECKED_CAST")
                    store.mutedPackages = (call.arguments as List<String>).toSet()
                    result.success(null)
                }
                "getPending" -> result.success(store.pending().toString())
                "removePending" -> {
                    @Suppress("UNCHECKED_CAST")
                    store.removePending(call.arguments as List<String>)
                    result.success(null)
                }
                "seenApps" -> result.success(store.seenApps().toString())
                "close" -> {
                    result.success(null)
                    activity.finish()
                    activity.overridePendingTransition(0, 0)
                }
                else -> result.notImplemented()
            }
        }
        return channel
    }

    private fun hasNotificationAccess(activity: Activity): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(activity).contains(activity.packageName) ||
            Settings.Secure.getString(activity.contentResolver, "enabled_notification_listeners")
                ?.contains(ComponentName(activity, TransactionNotificationListener::class.java).flattenToString()) == true

    private fun canPostNotifications(activity: Activity): Boolean =
        if (Build.VERSION.SDK_INT >= 33) {
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            NotificationManagerCompat.from(activity).areNotificationsEnabled()
        }
}
