package com.chloemlla.nexai

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    private val SECURITY_CHANNEL = "com.chloemlla.nexai/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Edge-to-edge
        if (Build.VERSION.SDK_INT in Build.VERSION_CODES.R until 36) {
            @Suppress("DEPRECATION")
            window.setDecorFitsSystemWindows(false)
        }
        if (Build.VERSION.SDK_INT in Build.VERSION_CODES.LOLLIPOP until 36) {
            @Suppress("DEPRECATION")
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            @Suppress("DEPRECATION")
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getApkSignatureFingerprint" -> result.success(getApkSignatureSha256())
                    "isRooted"                  -> result.success(detectRoot())
                    "setSecureScreen"           -> {
                        val enable = call.argument<Boolean>("enable") ?: true
                        setSecureWindow(enable)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── APK Signature ─────────────────────────────────────────────────────────

    private fun getApkSignatureSha256(): String? {
        return try {
            val cert = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                info.signingInfo.apkContentsSigners[0]
            } else {
                @Suppress("DEPRECATION")
                val info = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
                @Suppress("DEPRECATION")
                info.signatures[0]
            }
            val digest = MessageDigest.getInstance("SHA-256").digest(cert.toByteArray())
            digest.joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            null
        }
    }

    // ── Root Detection ────────────────────────────────────────────────────────

    private fun detectRoot(): Boolean {
        return checkSuBinaries()
            || checkDangerousProps()
            || checkRootApps()
            || checkTestKeys()
    }

    private fun checkSuBinaries(): Boolean {
        val paths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su",
            "/data/local/su", "/data/local/xbin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su",
            // Magisk
            "/data/adb/magisk", "/sbin/.magisk",
        )
        return paths.any { File(it).exists() }
    }

    private fun checkDangerousProps(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("getprop ro.debuggable")
            val result = process.inputStream.bufferedReader().readText().trim()
            result == "1"
        } catch (e: Exception) { false }
    }

    private fun checkRootApps(): Boolean {
        val rootApps = arrayOf(
            "com.noshufou.android.su",
            "com.thirdparty.superuser",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "com.zachspong.temprootremovejb",
            "com.ramdroid.appquarantine",
            "com.topjohnwu.magisk",
        )
        return rootApps.any {
            try {
                packageManager.getPackageInfo(it, 0)
                true
            } catch (e: PackageManager.NameNotFoundException) { false }
        }
    }

    private fun checkTestKeys(): Boolean {
        val tags = Build.TAGS ?: return false
        return tags.contains("test-keys")
    }

    // ── Secure Screen ─────────────────────────────────────────────────────────

    private fun setSecureWindow(enable: Boolean) {
        runOnUiThread {
            if (enable) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }
}
