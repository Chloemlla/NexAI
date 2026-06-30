package com.chloemlla.nexai.channels

import android.view.WindowManager
import com.chloemlla.nexai.DeviceFingerprint
import com.chloemlla.nexai.MainActivity
import com.chloemlla.nexai.security.SecuritySignals
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SecurityChannel(
    private val activity: MainActivity,
    private val signals: SecuritySignals,
    private val deviceFingerprint: DeviceFingerprint,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getApkSignatureFingerprint" -> result.success(signals.getApkSignatureSha256())
            "getApkFileSha256" -> result.success(signals.getApkFileSha256())
            "isRooted" -> result.success(signals.isRooted() || signals.isFridaDetected() || signals.isXposedDetected())
            "isDebuggerAttached" -> result.success(signals.isDebuggerAttached())
            "isEmulator" -> result.success(signals.isEmulator())
            "isVpnActive" -> result.success(signals.isVpnActive())
            "getDexHash" -> result.success(signals.getDexFileHash())
            "setSecureScreen" -> {
                setSecureWindow(call.argument<Boolean>("enable") ?: true)
                result.success(null)
            }

            "isFridaDetected" -> result.success(NativeResult.ok(detection("fridaDetected") {
                signals.isFridaDetected()
            }))
            "isXposedDetected" -> result.success(NativeResult.ok(detection("xposedDetected") {
                signals.isXposedDetected()
            }))
            "getOverlayRisk" -> result.success(NativeResult.ok(signals.getOverlayRisk()))
            "getSecuritySnapshot" -> result.success(NativeResult.ok(signals.getSecuritySnapshot()))

            // Compatibility: old Dart device fingerprint helper used the security channel.
            "getHardwareInfo" -> result.success(deviceFingerprint.getHardwareInfo())
            "getSoftwareInfo" -> result.success(deviceFingerprint.getSoftwareInfo())
            "getStorageInfo" -> result.success(deviceFingerprint.getStorageInfo())
            "getSensorFingerprint" -> result.success(deviceFingerprint.getSensorFingerprint())
            "getNetworkInfo" -> result.success(deviceFingerprint.getNetworkInfo())
            "getSystemProperties" -> result.success(deviceFingerprint.getSystemProperties())

            else -> result.notImplemented()
        }
    }

    private fun setSecureWindow(enable: Boolean) {
        activity.runOnUiThread {
            if (enable) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    private fun detection(key: String, block: () -> Boolean): Map<String, Any?> {
        val detected = block()
        return mapOf(
            key to detected,
            "checkedAt" to System.currentTimeMillis(),
            "source" to "android_kotlin_native",
            "confidence" to if (detected) 0.75 else 0.85,
        )
    }
}
