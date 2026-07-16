package com.chloemlla.nexai.channels

import android.Manifest
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.chloemlla.nexai.MainActivity
import com.chloemlla.nexai.R
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationChannelHandler(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    companion object {
        const val MEDIA_TASKS = "nexai_media_tasks"
        const val UPDATES = "nexai_updates"
        const val SYNC = "nexai_sync"
        const val SECURITY = "nexai_security"
    }

    @Volatile
    private var channelsInitialized = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeChannels" -> {
                initializeChannels()
                result.success(
                    NativeResult.ok(
                        mapOf(
                            "initialized" to true,
                            "channelsInitialized" to channelsInitialized,
                        ),
                    ),
                )
            }
            "showProgressNotification" -> showProgress(call, result)
            "showNotification" -> showNotification(call, result)
            "cancelNotification" -> {
                val id = call.argument<Int>("id")
                    ?: return result.success(NativeResult.invalidArgument("id is required"))
                NotificationManagerCompat.from(activity).cancel(id)
                result.success(NativeResult.ok(mapOf("id" to id, "cancelled" to true)))
            }
            "areNotificationsEnabled" -> result.success(NativeResult.ok(notificationState()))
            else -> result.notImplemented()
        }
    }

    fun initializeChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            channelsInitialized = true
            return
        }
        val manager = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channels = listOf(
            android.app.NotificationChannel(MEDIA_TASKS, "Media tasks", NotificationManager.IMPORTANCE_LOW),
            android.app.NotificationChannel(UPDATES, "Updates", NotificationManager.IMPORTANCE_DEFAULT),
            android.app.NotificationChannel(SYNC, "Sync", NotificationManager.IMPORTANCE_DEFAULT),
            android.app.NotificationChannel(SECURITY, "Security", NotificationManager.IMPORTANCE_HIGH),
        )
        manager.createNotificationChannels(channels)
        channelsInitialized = true
    }

    private fun showProgress(call: MethodCall, result: MethodChannel.Result) {
        if (!hasNotificationPermission()) {
            return result.success(
                NativeResult.error(
                    "permission_denied",
                    "Notification permission denied",
                    recoverable = true,
                    details = notificationState(),
                ),
            )
        }
        initializeChannels()
        val id = call.argument<Int>("id")
            ?: call.argument<String>("taskId")?.hashCode()
            ?: return result.success(NativeResult.invalidArgument("id or taskId is required"))
        val taskId = call.argument<String>("taskId") ?: id.toString()
        val title = call.argument<String>("title") ?: "NexAI task"
        val message = call.argument<String>("message") ?: ""
        val progress = ((call.argument<Double>("progress") ?: 0.0) * 100).toInt().coerceIn(0, 100)

        val notification = NotificationCompat.Builder(activity, MEDIA_TASKS)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setOnlyAlertOnce(true)
            .setOngoing(progress < 100)
            .setProgress(100, progress, false)
            .setContentIntent(mainPendingIntent("media", taskId))
            .build()

        NotificationManagerCompat.from(activity).notify(id, notification)
        result.success(
            NativeResult.ok(
                mapOf(
                    "id" to id,
                    "shown" to true,
                    "taskId" to taskId,
                    "channelsInitialized" to channelsInitialized,
                ),
            ),
        )
    }

    private fun showNotification(call: MethodCall, result: MethodChannel.Result) {
        if (!hasNotificationPermission()) {
            return result.success(
                NativeResult.error(
                    "permission_denied",
                    "Notification permission denied",
                    recoverable = true,
                    details = notificationState(),
                ),
            )
        }
        initializeChannels()
        val id = call.argument<Int>("id")
            ?: return result.success(NativeResult.invalidArgument("id is required"))
        val channelId = call.argument<String>("channelId") ?: UPDATES
        val title = call.argument<String>("title") ?: "NexAI"
        val message = call.argument<String>("message") ?: ""
        val route = call.argument<String>("route") ?: "home"
        val taskId = call.argument<String>("taskId")

        val notification = NotificationCompat.Builder(activity, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(mainPendingIntent(route, taskId))
            .build()

        NotificationManagerCompat.from(activity).notify(id, notification)
        result.success(
            NativeResult.ok(
                mapOf(
                    "id" to id,
                    "shown" to true,
                    "taskId" to taskId,
                    "channelsInitialized" to channelsInitialized,
                ),
            ),
        )
    }

    private fun mainPendingIntent(route: String, taskId: String?): PendingIntent {
        val intent = Intent(activity, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("nexai_route", route)
            if (taskId != null) putExtra("nexai_task_id", taskId)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(activity, route.hashCode() xor (taskId?.hashCode() ?: 0), intent, flags)
    }

    private fun notificationState(): Map<String, Any?> = mapOf(
        "enabled" to NotificationManagerCompat.from(activity).areNotificationsEnabled(),
        "runtimePermissionGranted" to hasNotificationPermission(),
        "channelsInitialized" to channelsInitialized,
        "sdkInt" to Build.VERSION.SDK_INT,
    )

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
}
