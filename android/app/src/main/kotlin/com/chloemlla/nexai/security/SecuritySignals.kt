package com.chloemlla.nexai.security

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Debug
import android.provider.Settings
import java.io.File
import java.security.MessageDigest

class SecuritySignals(private val context: Context) {
    fun getApkSignatureSha256(): String? = runCatching {
        val cert = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            info.signingInfo?.apkContentsSigners?.firstOrNull() ?: return null
        } else {
            @Suppress("DEPRECATION")
            val info = context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNATURES,
            )
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull() ?: return null
        }
        sha256(cert.toByteArray())
    }.getOrNull()

    fun getApkFileSha256(): String? = runCatching {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val apkPath = info.applicationInfo?.sourceDir ?: return null
        sha256(File(apkPath))
    }.getOrNull()

    fun getDexFileHash(): String? = getApkFileSha256()

    fun isRooted(): Boolean =
        checkSuBinaries() || checkDangerousProps() || checkRootApps() || checkTestKeys()

    fun isDebuggerAttached(): Boolean = Debug.isDebuggerConnected() || Debug.waitingForDebugger()

    fun isEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.startsWith("unknown") ||
            Build.MODEL.contains("google_sdk", ignoreCase = true) ||
            Build.MODEL.contains("Emulator", ignoreCase = true) ||
            Build.MODEL.contains("Android SDK built for x86", ignoreCase = true) ||
            Build.MANUFACTURER.contains("Genymotion", ignoreCase = true) ||
            (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
            Build.PRODUCT == "google_sdk" ||
            Build.HARDWARE.contains("goldfish", ignoreCase = true) ||
            Build.HARDWARE.contains("ranchu", ignoreCase = true)

    fun isVpnActive(): Boolean =
        checkVpnTransport() || checkVpnInterface() || checkVpnRoutes() || checkVpnApps()

    fun isFridaDetected(): Boolean = checkFridaPorts() || checkFridaMaps()

    fun isXposedDetected(): Boolean = checkXposedStack() || checkXposedApps()

    fun isAdbEnabled(): Boolean = runCatching {
        Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
    }.getOrDefault(false)

    fun isDevelopmentSettingsEnabled(): Boolean = runCatching {
        Settings.Global.getInt(
            context.contentResolver,
            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
            0,
        ) == 1
    }.getOrDefault(false)

    fun isDebugBuild(): Boolean = runCatching {
        (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }.getOrDefault(false)

    fun getTracerPid(): Int = runCatching {
        val status = File("/proc/self/status")
        if (!status.exists()) return@runCatching 0
        status.useLines { lines ->
            lines.firstOrNull { it.startsWith("TracerPid:") }
                ?.substringAfter(":")
                ?.trim()
                ?.toIntOrNull()
                ?: 0
        }
    }.getOrDefault(0)

    fun getOverlayRisk(): Map<String, Any?> {
        val canDrawOverlays = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            false
        }
        return mapOf(
            "overlayPermissionGranted" to canDrawOverlays,
            "risk" to canDrawOverlays,
            "source" to "settings_can_draw_overlays",
            "confidence" to if (canDrawOverlays) 0.35 else 0.85,
            "checkedAt" to System.currentTimeMillis(),
        )
    }

    fun getSecuritySnapshot(): Map<String, Any?> {
        val checkedAt = System.currentTimeMillis()
        val errors = mutableMapOf<String, String>()

        fun <T> checked(key: String, fallback: T, block: () -> T): T =
            runCatching(block).getOrElse {
                errors[key] = "native_failure"
                fallback
            }

        val rooted = checked("rooted", false) { isRooted() }
        val debuggerAttached = checked("debuggerAttached", false) { isDebuggerAttached() }
        val emulator = checked("emulator", false) { isEmulator() }
        val vpnActive = checked("vpnActive", false) { isVpnActive() }
        val fridaDetected = checked("fridaDetected", false) { isFridaDetected() }
        val xposedDetected = checked("xposedDetected", false) { isXposedDetected() }
        val adbEnabled = checked("adbEnabled", false) { isAdbEnabled() }
        val developmentSettingsEnabled = checked("developmentSettingsEnabled", false) {
            isDevelopmentSettingsEnabled()
        }
        val debugBuild = checked("debugBuild", false) { isDebugBuild() }
        val tracerPid = checked("tracerPid", 0) { getTracerPid() }
        val tracerAttached = tracerPid > 0

        val antiDebugScore = listOf(
            debuggerAttached to 0.35,
            tracerAttached to 0.25,
            adbEnabled to 0.10,
            developmentSettingsEnabled to 0.08,
            debugBuild to 0.12,
            fridaDetected to 0.35,
            xposedDetected to 0.30,
            rooted to 0.20,
            emulator to 0.15,
        ).sumOf { (flag, weight) -> if (flag) weight else 0.0 }.coerceIn(0.0, 1.0)

        return mapOf(
            "rooted" to (rooted || fridaDetected || xposedDetected),
            "rootSignalDetected" to rooted,
            "debuggerAttached" to debuggerAttached,
            "emulator" to emulator,
            "vpnActive" to vpnActive,
            "fridaDetected" to fridaDetected,
            "xposedDetected" to xposedDetected,
            "adbEnabled" to adbEnabled,
            "developmentSettingsEnabled" to developmentSettingsEnabled,
            "debugBuild" to debugBuild,
            "tracerPid" to tracerPid,
            "tracerAttached" to tracerAttached,
            "antiDebugScore" to antiDebugScore,
            "overlayRisk" to checked("overlayRisk", emptyMap<String, Any?>()) { getOverlayRisk() },
            "signatureSha256" to checked("signatureSha256", null) { getApkSignatureSha256() },
            "apkSha256" to checked("apkSha256", null) { getApkFileSha256() },
            "dexSha256" to checked("dexSha256", null) { getDexFileHash() },
            "checkedAt" to checkedAt,
            "source" to "android_kotlin_native",
            "confidence" to 0.85,
            "errors" to errors,
        )
    }

    private fun checkSuBinaries(): Boolean {
        val paths = arrayOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/data/local/su",
            "/data/local/xbin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/adb/magisk",
            "/sbin/.magisk",
        )
        return paths.any { File(it).exists() }
    }

    private fun checkDangerousProps(): Boolean = runCatching {
        Runtime.getRuntime().exec("getprop ro.debuggable")
            .inputStream
            .bufferedReader()
            .use { it.readText().trim() == "1" }
    }.getOrDefault(false)

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
        return rootApps.any(::isPackageInstalled)
    }

    private fun checkTestKeys(): Boolean = Build.TAGS?.contains("test-keys") == true

    private fun checkFridaPorts(): Boolean = runCatching {
        Runtime.getRuntime().exec("netstat -an")
            .inputStream
            .bufferedReader()
            .use { reader ->
                val output = reader.readText()
                output.contains(":27042") || output.contains(":27043")
            }
    }.getOrDefault(false)

    private fun checkFridaMaps(): Boolean = runCatching {
        val mapsFile = File("/proc/self/maps")
        if (mapsFile.exists()) {
            val maps = mapsFile.readText()
            listOf("frida-agent", "frida-gadget", "frida-server", "re.frida.server")
                .any { maps.contains(it, ignoreCase = true) }
        } else {
            false
        }
    }.getOrDefault(false)

    private fun checkXposedStack(): Boolean = runCatching {
        try {
            throw IllegalStateException("xposed-stack-probe")
        } catch (e: IllegalStateException) {
            e.stackTrace.any {
                it.className.contains("de.robv.android.xposed.XposedBridge") ||
                    it.className.contains("de.robv.android.xposed.XposedHelpers")
            }
        }
    }.getOrDefault(false)

    private fun checkXposedApps(): Boolean {
        val xposedApps = arrayOf(
            "de.robv.android.xposed.installer",
            "org.meowcat.edxposed.manager",
            "com.solohsu.android.edxp.manager",
            "io.github.lsposed.manager",
        )
        return xposedApps.any(::isPackageInstalled)
    }

    private fun checkVpnTransport(): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork
            val capabilities = if (network != null) cm.getNetworkCapabilities(network) else null
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        } else {
            false
        }
    }.getOrDefault(false)

    private fun checkVpnInterface(): Boolean = runCatching {
        val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
        var detected = false
        while (interfaces.hasMoreElements()) {
            val name = interfaces.nextElement().name.lowercase()
            if (name.startsWith("tun") ||
                name.startsWith("ppp") ||
                name.startsWith("pptp") ||
                name.startsWith("l2tp") ||
                name.startsWith("ipsec") ||
                name.startsWith("wg")
            ) {
                detected = true
                break
            }
        }
        detected
    }.getOrDefault(false)

    private fun checkVpnRoutes(): Boolean = runCatching {
        Runtime.getRuntime().exec("ip route")
            .inputStream
            .bufferedReader()
            .use { reader ->
                val output = reader.readText()
                output.contains("tun", ignoreCase = true) ||
                    output.contains("ppp", ignoreCase = true) ||
                    output.contains("wg", ignoreCase = true)
            }
    }.getOrDefault(false)

    private fun checkVpnApps(): Boolean {
        val vpnApps = arrayOf(
            "com.nordvpn.android",
            "net.openvpn.openvpn",
            "com.expressvpn.vpn",
            "com.privateinternetaccess.android",
            "com.surfshark.vpnclient.android",
            "com.protonvpn.android",
            "com.cloudflare.onedotonedotone",
            "com.wireguard.android",
            "de.blinkt.openvpn",
            "com.github.shadowsocks",
            "com.v2ray.ang",
            "io.nekohasekai.sagernet",
            "com.v2ray.actinium",
            "com.github.kr328.clash",
            "com.github.kr328.clash.premium",
        )
        return vpnApps.any(::isPackageInstalled)
    }

    private fun isPackageInstalled(packageName: String): Boolean = try {
        context.packageManager.getPackageInfo(packageName, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun sha256(file: File): String? {
        if (!file.exists()) return null
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read == -1) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { "%02x".format(it) }
}
