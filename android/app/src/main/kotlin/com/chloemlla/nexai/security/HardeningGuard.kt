package com.chloemlla.nexai.security

import android.content.Context

class HardeningGuard(private val context: Context) {
    private external fun nativeAntiDebugDetected(): Boolean
    private external fun nativeTracerPid(): Int
    private external fun nativeEmulatorDetected(): Boolean
    private external fun nativeStartWatchdog()
    private external fun nativeStopWatchdog()

    fun start() = runCatching { nativeStartWatchdog() }

    fun stop() = runCatching { nativeStopWatchdog() }

    fun snapshot(): Map<String, Any?> = mapOf(
        "nativeAntiDebug" to runCatching { nativeAntiDebugDetected() }.getOrDefault(false),
        "nativeTracerPid" to runCatching { nativeTracerPid() }.getOrDefault(0),
        "nativeEmulator" to runCatching { nativeEmulatorDetected() }.getOrDefault(false),
        "nativeAvailable" to isNativeAvailable,
        "checkedAt" to System.currentTimeMillis(),
    )

    companion object {
        val isNativeAvailable: Boolean = runCatching {
            System.loadLibrary("nexai_hardening")
            true
        }.getOrDefault(false)
    }
}