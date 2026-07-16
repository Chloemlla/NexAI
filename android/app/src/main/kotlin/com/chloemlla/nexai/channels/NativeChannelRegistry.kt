package com.chloemlla.nexai.channels

import android.content.Intent
import com.chloemlla.nexai.DeviceFingerprint
import com.chloemlla.nexai.MainActivity
import com.chloemlla.nexai.background.NativeTaskStore
import com.chloemlla.nexai.security.SecuritySignals
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class NativeChannelRegistry(
    private val activity: MainActivity,
    private val flutterEngine: FlutterEngine,
) {
    private lateinit var permissionChannel: PermissionChannel

    fun register() {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val securitySignals = SecuritySignals(activity)
        val deviceFingerprint = DeviceFingerprint(activity)
        val taskStore = NativeTaskStore(activity)
        val taskEvents = NativeTaskEvents()

        MethodChannel(messenger, "com.chloemlla.nexai/security").setMethodCallHandler(
            SecurityChannel(activity, securitySignals, deviceFingerprint),
        )
        MethodChannel(messenger, "com.chloemlla.nexai/fingerprint").setMethodCallHandler(
            DeviceFingerprintChannel(deviceFingerprint),
        )
        MethodChannel(messenger, "com.chloemlla.nexai/media").setMethodCallHandler(
            MediaChannel(activity, taskStore, taskEvents),
        )
        permissionChannel = PermissionChannel(activity)
        MethodChannel(messenger, "com.chloemlla.nexai/permissions").setMethodCallHandler(permissionChannel)
        MethodChannel(messenger, "com.chloemlla.nexai/background").setMethodCallHandler(
            BackgroundTaskChannel(taskStore, taskEvents),
        )
        MethodChannel(messenger, "com.chloemlla.nexai/share").setMethodCallHandler(ShareChannel(activity))
        MethodChannel(messenger, "com.chloemlla.nexai/notifications").setMethodCallHandler(
            NotificationChannelHandler(activity).also { it.initializeChannels() },
        )
        MethodChannel(messenger, "com.chloemlla.nexai/update").setMethodCallHandler(
            UpdateChannel(activity, securitySignals),
        )
        MethodChannel(messenger, "com.chloemlla.nexai/passkeys").setMethodCallHandler(
            PasskeyChannel(activity),
        )
        MethodChannel(messenger, "com.chloemlla.nexai/crash").setMethodCallHandler(
            CrashChannel(),
        )
        EventChannel(messenger, "com.chloemlla.nexai/native_task_events").setStreamHandler(taskEvents)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean =
        if (::permissionChannel.isInitialized) {
            permissionChannel.onActivityResult(requestCode, resultCode, data)
        } else {
            false
        }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean = if (::permissionChannel.isInitialized) {
        permissionChannel.onRequestPermissionsResult(requestCode, permissions, grantResults)
    } else {
        false
    }
}
