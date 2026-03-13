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
    private lateinit var deviceFingerprint: DeviceFingerprint

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

        deviceFingerprint = DeviceFingerprint(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getApkSignatureFingerprint" -> result.success(getApkSignatureSha256())
                    "getApkFileSha256"          -> result.success(getApkFileSha256())
                    "isRooted"                  -> result.success(detectRoot())
                    "isDebuggerAttached"        -> result.success(isDebuggerConnected())
                    "isEmulator"                -> result.success(isRunningOnEmulator())
                    "isVpnActive"               -> result.success(isVpnConnected())
                    "getHardwareInfo"           -> result.success(getHardwareInfo())
                    "getSoftwareInfo"           -> result.success(getSoftwareInfo())
                    "getStorageInfo"            -> result.success(getStorageInfo())
                    "getSensorFingerprint"      -> result.success(getSensorFingerprint())
                    "getNetworkInfo"            -> result.success(getNetworkInfo())
                    "getSystemProperties"       -> result.success(getSystemProperties())
                    "getDexHash"                -> result.success(getDexFileHash())
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
                info.signingInfo?.apkContentsSigners?.get(0) ?: return null
            } else {
                @Suppress("DEPRECATION")
                val info = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
                @Suppress("DEPRECATION")
                info.signatures?.get(0) ?: return null
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
            val apkPath = info.applicationInfo?.sourceDir ?: return null
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
        return checkVpnTransport() ||
               checkVpnInterface() ||
               checkVpnRoutes() ||
               checkVpnDns() ||
               checkVpnApps()
    }

    // Method 1: NetworkCapabilities API (Android M+)
    private fun checkVpnTransport(): Boolean {
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

    // Method 2: Check network interfaces for VPN (tun0, ppp0, etc.)
    private fun checkVpnInterface(): Boolean {
        return try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val intf = interfaces.nextElement()
                val name = intf.name.lowercase()

                // Common VPN interface names
                if (name.startsWith("tun") ||    // TUN interface (most VPNs)
                    name.startsWith("ppp") ||    // PPP interface (PPTP VPN)
                    name.startsWith("pptp") ||   // PPTP VPN
                    name.startsWith("l2tp") ||   // L2TP VPN
                    name.startsWith("ipsec") ||  // IPSec VPN
                    name.startsWith("wg")) {     // WireGuard VPN
                    return true
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    // Method 3: Check routing table for VPN routes
    private fun checkVpnRoutes(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("ip route")
            val result = process.inputStream.bufferedReader().readText()

            // VPN typically routes all traffic through tun/ppp interface
            result.contains("tun", ignoreCase = true) ||
            result.contains("ppp", ignoreCase = true) ||
            result.contains("wg", ignoreCase = true)
        } catch (e: Exception) {
            false
        }
    }

    // Method 4: Check DNS servers (VPN often uses custom DNS)
    private fun checkVpnDns(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val network = cm.activeNetwork ?: return false
                val linkProperties = cm.getLinkProperties(network) ?: return false
                val dnsServers = linkProperties.dnsServers

                // Check for common VPN DNS servers
                for (dns in dnsServers) {
                    val dnsStr = dns.hostAddress ?: continue

                    // Common VPN DNS patterns
                    if (dnsStr.startsWith("10.") ||      // Private network
                        dnsStr.startsWith("172.16.") ||  // Private network
                        dnsStr.startsWith("192.168.") || // Private network
                        dnsStr == "1.1.1.1" ||           // Cloudflare (common in VPNs)
                        dnsStr == "8.8.8.8" ||           // Google DNS (common in VPNs)
                        dnsStr == "9.9.9.9") {           // Quad9 (common in VPNs)
                        // Note: This is a weak indicator, many non-VPN networks use these
                        // Only flag if combined with other indicators
                    }
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    // Method 5: Check for VPN apps installed
    private fun checkVpnApps(): Boolean {
        val vpnApps = arrayOf(
            // Commercial VPNs
            "com.nordvpn.android",
            "net.openvpn.openvpn",
            "com.expressvpn.vpn",
            "com.privateinternetaccess.android",
            "com.surfshark.vpnclient.android",
            "com.protonvpn.android",
            "com.cloudflare.onedotonedotonedotone",
            "com.wireguard.android",
            "de.blinkt.openvpn",
            // Chinese VPNs
            "com.github.shadowsocks",
            "com.v2ray.ang",
            "io.nekohasekai.sagernet",
            "com.v2ray.actinium",
            "com.github.kr328.clash",
            "com.github.kr328.clash.premium",
        )

        return vpnApps.any {
            try {
                packageManager.getPackageInfo(it, 0)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    // ── Device Fingerprint Methods ────────────────────────────────────────────

    private fun getHardwareInfo(): Map<String, Any> = deviceFingerprint.getHardwareInfo()
    private fun getSoftwareInfo(): Map<String, Any> = deviceFingerprint.getSoftwareInfo()
    private fun getStorageInfo(): Map<String, Any> = deviceFingerprint.getStorageInfo()
    private fun getSensorFingerprint(): Map<String, Any> = deviceFingerprint.getSensorFingerprint()
    private fun getNetworkInfo(): Map<String, Any> = deviceFingerprint.getNetworkInfo()
    private fun getSystemProperties(): Map<String, Any> = deviceFingerprint.getSystemProperties()
    private fun getDexFileHash(): String? = deviceFingerprint.getDexFileHash()
}
