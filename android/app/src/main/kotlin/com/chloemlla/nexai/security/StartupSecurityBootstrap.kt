package com.chloemlla.nexai.security

import android.content.Context
import com.chloemlla.lumen.crash.LumenCrash
import java.util.concurrent.atomic.AtomicReference

/**
 * Non-fatal startup security snapshot for early host diagnostics.
 * Never throws into Application attach/onCreate paths.
 */
object StartupSecurityBootstrap {
    private val snapshotRef = AtomicReference<Map<String, Any?>?>(null)

    fun snapshotOrNull(): Map<String, Any?>? = snapshotRef.get()

    fun ensureInitialized(context: Context): Map<String, Any?> {
        snapshotRef.get()?.let { return it }

        val app = context.applicationContext
        val signals = SecuritySignals(app)
        val security = runCatching { signals.getSecuritySnapshot() }
            .getOrElse { error ->
                mapOf(
                    "source" to "android_kotlin_native",
                    "errors" to mapOf("securitySnapshot" to (error.javaClass.simpleName)),
                )
            }
        val passkey = runCatching {
            PasskeyProviderDiagnostics.diagnose(app, googleOnlyPreferred = true)
        }.getOrElse { error ->
            mapOf(
                "source" to "android_kotlin_native",
                "errors" to mapOf("passkeyDiagnostics" to (error.javaClass.simpleName)),
            )
        }

        val snapshot = mapOf(
            "checkedAt" to System.currentTimeMillis(),
            "security" to security,
            "passkeyProviders" to passkey,
            "source" to "android_kotlin_native",
        )
        snapshotRef.compareAndSet(null, snapshot)

        runCatching {
            val rooted = security["rooted"] == true
            val debugger = security["debuggerAttached"] == true
            val frida = security["fridaDetected"] == true
            val xposed = security["xposedDetected"] == true
            val risk = passkey["risk"]?.toString() ?: "unknown"
            LumenCrash.recordBreadcrumb(
                "startup-security rooted=$rooted debugger=$debugger frida=$frida xposed=$xposed passkeyRisk=$risk",
            )
        }

        return snapshotRef.get() ?: snapshot
    }
}