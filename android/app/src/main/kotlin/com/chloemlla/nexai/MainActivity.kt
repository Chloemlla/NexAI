package com.chloemlla.nexai

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.os.Debug
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
                    "getApkFileSha256"          -> result.success(getApkFileSha256())
                    "isRooted"                  -> result.success(detectRoot())
                    "isDebuggerAttached"        -> result.success(isDebuggerConnected())
                    "isEmulator"                -> result.success(isRunningOnEmulator())
                    "isVpnActive"               -> result.success(isVpnConnected())
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

    private fun getApkFileSha256(): String? {
        return try {
            val info = packageManager.getPackageInfo(packageName, 0)
            val apkPath = info.applicationInfo.sourceDir
            val apkFile = File(apkPath)

            if (!apkFile.exists()) return null

            val digest = MessageDigest.getInstance("SHA-256")
            apkFile.inputStream().use { input ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    digest.update(buffer, 0, bytesRead)
                }
            }

            digest.digest().joinToString("") { "%02x".format(it) }
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
            || checkFrida()
            || checkXposed()
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

    // ── Frida Detection ───────────────────────────────────────────────────────

    private fun checkFrida(): Boolean {
        // Check for Frida server process
        val fridaPorts = arrayOf(27042, 27043) // Default Frida ports
        for (port in fridaPorts) {
            try {
                val process = Runtime.getRuntime().exec("netstat -an")
                val result = process.inputStream.bufferedReader().readText()
                if (result.contains(":$port")) {
                    return true
                }
            } catch (e: Exception) {
                // Ignore
            }
        }

        // Check for Frida libraries
        val fridaLibs = arrayOf(
            "frida-agent",
            "frida-gadget",
            "frida-server",
            "re.frida.server"
        )

        try {
            val mapsFile = File("/proc/self/maps")
            if (mapsFile.exists()) {
                val maps = mapsFile.readText()
                for (lib in fridaLibs) {
                    if (maps.contains(lib, ignoreCase = true)) {
                        return true
                    }
                }
            }
        } catch (e: Exception) {
            // Ignore
        }

        return false
    }

    // ── Xposed Detection ──────────────────────────────────────────────────────

    private fun checkXposed(): Boolean {
        // Check for Xposed framework
        try {
            throw Exception("Xposed check")
        } catch (e: Exception) {
            val stackTrace = e.stackTrace
            for (element in stackTrace) {
                if (element.className.contains("de.robv.android.xposed.XposedBridge") ||
                    element.className.contains("de.robv.android.xposed.XposedHelpers")) {
                    return true
                }
            }
        }

        // Check for Xposed installer
        val xposedApps = arrayOf(
            "de.robv.android.xposed.installer",
            "org.meowcat.edxposed.manager",
            "com.solohsu.android.edxp.manager",
            "io.github.lsposed.manager"
        )

        return xposedApps.any {
            try {
                packageManager.getPackageInfo(it, 0)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
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

    // ── Anti-Debug ────────────────────────────────────────────────────────────

    private fun isDebuggerConnected(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }

    // ── Emulator Detection ────────────────────────────────────────────────────

    private fun isRunningOnEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
            || Build.FINGERPRINT.startsWith("unknown")
            || Build.MODEL.contains("google_sdk")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("Android SDK built for x86")
            || Build.MANUFACTURER.contains("Genymotion")
            || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
            || "google_sdk" == Build.PRODUCT
            || Build.HARDWARE.contains("goldfish")
            || Build.HARDWARE.contains("ranchu"))
    }

    // ── VPN Detection ─────────────────────────────────────────────────────────

    private fun isVpnConnected(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val network = cm.activeNetwork ?: return false
                val capabilities = cm.getNetworkCapabilities(network) ?: return false
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
