package com.chloemlla.nexai.channels

import com.chloemlla.nexai.DeviceFingerprint
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DeviceFingerprintChannel(
    private val deviceFingerprint: DeviceFingerprint,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val response = when (call.method) {
            "getHardwareInfo" -> NativeResult.ok(deviceFingerprint.getHardwareInfo())
            "getSoftwareInfo" -> NativeResult.ok(deviceFingerprint.getSoftwareInfo())
            "getStorageInfo" -> NativeResult.ok(deviceFingerprint.getStorageInfo())
            "getSensorFingerprint" -> NativeResult.ok(deviceFingerprint.getSensorFingerprint())
            "getNetworkInfo" -> NativeResult.ok(deviceFingerprint.getNetworkInfo())
            "getSystemProperties" -> NativeResult.ok(deviceFingerprint.getSystemProperties())
            "getDexHash" -> NativeResult.ok(mapOf("dexSha256" to deviceFingerprint.getDexFileHash()))
            "getFingerprintSnapshot" -> NativeResult.ok(deviceFingerprint.getFingerprintSnapshot())
            else -> {
                result.notImplemented()
                return
            }
        }
        result.success(response)
    }
}
