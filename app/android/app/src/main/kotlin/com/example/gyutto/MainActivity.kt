package com.example.gyutto

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private var notifications: MethodChannel? = null
    private val channelId = "family_chat"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Direct reference: fail compilation if plugin generation was skipped.
        // This activity creates its own engine; register once, without super's
        // reflective registration path.
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                channelId, "家族チャット", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "家族から届いた新しいメッセージ"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
        }
        notifications = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gyutto/chat_notifications")
        notifications!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialMessage" -> {
                    result.success(localMessage(intent))
                    intent.removeExtra("gyutto_local_chat")
                }
                "clear" -> { manager.cancelAll(); result.success(null) }
                "settings" -> {
                    val settings = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                    else Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        android.net.Uri.parse("package:$packageName"))
                    startActivity(settings)
                    result.success(null)
                }
                "show" -> {
                    val data = call.arguments as? Map<*, *>
                    if (data == null) { result.error("invalid", "Missing notification", null) }
                    else {
                        val tag = "${data["familyId"]}:${data["messageId"]}"
                        val open = Intent(this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            putExtra("gyutto_local_chat", true)
                            for (key in listOf("type", "familyId", "messageId", "recipientUid")) {
                                putExtra(key, data[key]?.toString())
                            }
                        }
                        val pending = PendingIntent.getActivity(this, tag.hashCode(), open,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            Notification.Builder(this, channelId) else Notification.Builder(this)
                        val icon = resources.getIdentifier("ic_chat_notification", "drawable", packageName)
                        try {
                            manager.notify(tag, 0, builder.setSmallIcon(icon)
                                .setContentTitle(data["title"]?.toString())
                                .setContentText(data["body"]?.toString())
                                .setContentIntent(pending).setAutoCancel(true)
                                .setVisibility(Notification.VISIBILITY_PRIVATE)
                                .setPriority(Notification.PRIORITY_HIGH)
                                .setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
                                .build())
                            result.success(null)
                        } catch (error: SecurityException) {
                            result.error("permission", "Notifications are disabled", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun localMessage(source: Intent?): Map<String, String?>? {
        if (source?.getBooleanExtra("gyutto_local_chat", false) != true) return null
        return listOf("type", "familyId", "messageId", "recipientUid")
            .associateWith { source.getStringExtra(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        localMessage(intent)?.let {
            notifications?.invokeMethod("openChat", it)
            intent.removeExtra("gyutto_local_chat")
        }
    }
}
