package com.chloemlla.nexai

import android.content.Context
import android.content.pm.ApplicationInfo
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import java.io.File
import java.security.MessageDigest

/**
 * Aggressive device fingerprinting using multi-dimensional characteristics.
 * Prioritizes uniqueness over performance.
 */
class DeviceFingerprint(private val context: Context) {

    // ── Hardware Information ──────────────────────────────────────────────────

    fun getHardwareInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()

        // CPU information
        info["cpuAbi"] = Build.SUPPORTED_ABIS.joinToString(",")
        info["cpuAbi32"] = Build.SUPPORTED_32_BIT_ABIS.joinToString(",")
        info["cpuAbi64"] = Build.SUPPORTED_64_BIT_ABIS.joinToString(",")

        // Screen information
        val displayMetrics = context.resources.displayMetrics
        info["screenDensity"] = displayMetrics.density
        info["screenDensityDpi"] = displayMetrics.densityDpi
        info["screenWidth"] = displayMetrics.widthPixels
        info["screenHeight"] = displayMetrics.heightPixels
        info["screenXdpi"] = displayMetrics.xdpi
        info["screenYdpi"] = displayMetrics.ydpi

        // Sensor list (unique to device model)
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensors = sensorManager.getSensorList(Sensor.TYPE_ALL)
        info["sensorCount"] = sensors.size
        info["sensorList"] = sensors.map { "${it.name}:${it.vendor}:${it.version}" }
            .sorted()
            .joinToString("|")

        // Camera information
        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
            val cameraIds = cameraManager.cameraIdList
            info["cameraCount"] = cameraIds.size
            info["cameraIds"] = cameraIds.joinToString(",")
        } catch (e: Exception) {
            info["cameraCount"] = 0
        }

        // Battery capacity (requires permission, may fail)
        try {
            val powerProfile = Class.forName("com.android.internal.os.PowerProfile")
                .getConstructor(Context::class.java)
                .newInstance(context)
            val batteryCapacity = powerProfile.javaClass
                .getMethod("getBatteryCapacity")
                .invoke(powerProfile) as Double
            info["batteryCapacity"] = batteryCapacity
        } catch (e: Exception) {
            // Ignore
        }

        return info
    }

    // ── Software Information ──────────────────────────────────────────────────

    fun getSoftwareInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()

        // Installed apps hash (privacy-preserving)
        val installedApps = context.packageManager.getInstalledApplications(0)
        val appPackages = installedApps
            .filter { it.flags and ApplicationInfo.FLAG_SYSTEM == 0 } // User apps only
            .map { it.packageName }
            .sorted()
        info["installedAppCount"] = appPackages.size
        info["installedAppsHash"] = hashString(appPackages.joinToString("|"))

        // System apps hash
        val systemApps = installedApps
            .filter { it.flags and ApplicationInfo.FLAG_SYSTEM != 0 }
            .map { it.packageName }
            .sorted()
        info["systemAppCount"] = systemApps.size
        info["systemAppsHash"] = hashString(systemApps.joinToString("|"))

        // Font list (unique to ROM)
        val fontFiles = File("/system/fonts").listFiles()
        if (fontFiles != null) {
            info["fontCount"] = fontFiles.size
            info["fontListHash"] = hashString(fontFiles.map { it.name }.sorted().joinToString("|"))
        }

        // Timezone
        info["timezone"] = java.util.TimeZone.getDefault().id

        // Locale
        info["locale"] = java.util.Locale.getDefault().toString()

        return info
    }

    // ── Storage Information ───────────────────────────────────────────────────

    fun getStorageInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()

        // Internal storage
        val internalPath = Environment.getDataDirectory()
        val internalStat = StatFs(internalPath.path)
        info["internalTotalBytes"] = internalStat.totalBytes
        info["internalBlockSize"] = internalStat.blockSizeLong

        // External storage
        if (Environment.getExternalStorageState() == Environment.MEDIA_MOUNTED) {
            val externalPath = Environment.getExternalStorageDirectory()
            val externalStat = StatFs(externalPath.path)
            info["externalTotalBytes"] = externalStat.totalBytes
            info["externalBlockSize"] = externalStat.blockSizeLong
        }

        // Partition information
        try {
            val mountsFile = File("/proc/mounts")
            if (mountsFile.exists()) {
                val mounts = mountsFile.readText()
                info["mountsHash"] = hashString(mounts)
            }
        } catch (e: Exception) {
            // Ignore
        }

        return info
    }

    // ── Sensor Fingerprinting ─────────────────────────────────────────────────

    fun getSensorFingerprint(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()

        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

        // Accelerometer characteristics
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer != null) {
            info["accel_vendor"] = accelerometer.vendor
            info["accel_version"] = accelerometer.version
            info["accel_power"] = accelerometer.power
            info["accel_resolution"] = accelerometer.resolution
            info["accel_maxRange"] = accelerometer.maximumRange
        }

        // Gyroscope characteristics
        val gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        if (gyroscope != null) {
            info["gyro_vendor"] = gyroscope.vendor
            info["gyro_version"] = gyroscope.version
            info["gyro_power"] = gyroscope.power
            info["gyro_resolution"] = gyroscope.resolution
        }

        // Magnetometer characteristics
        val magnetometer = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (magnetometer != null) {
            info["mag_vendor"] = magnetometer.vendor
            info["mag_version"] = magnetometer.version
        }

        return info
    }

    // ── Network Information ───────────────────────────────────────────────────

    fun getNetworkInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()

        // Android ID (unique per device + user + app signing key)
        val androidId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID
        )
        info["androidId"] = androidId ?: "unknown"

        // Network interfaces
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            val interfaceNames = mutableListOf<String>()
            while (interfaces.hasMoreElements()) {
                val intf = interfaces.nextElement()
                interfaceNames.add("${intf.name}:${intf.mtu}")
            }
            info["networkInterfaces"] = interfaceNames.sorted().joinToString("|")
        } catch (e: Exception) {
            // Ignore
        }

        return info
    }

    // ── System Properties ─────────────────────────────────────────────────────

    fun getSystemProperties(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()

        // Build properties
        info["build_id"] = Build.ID
        info["build_display"] = Build.DISPLAY
        info["build_product"] = Build.PRODUCT
        info["build_device"] = Build.DEVICE
        info["build_board"] = Build.BOARD
        info["build_manufacturer"] = Build.MANUFACTURER
        info["build_brand"] = Build.BRAND
        info["build_model"] = Build.MODEL
        info["build_bootloader"] = Build.BOOTLOADER
        info["build_hardware"] = Build.HARDWARE
        info["build_serial"] = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Build.getSerial()
            } else {
                @Suppress("DEPRECATION")
                Build.SERIAL
            }
        } catch (e: Exception) {
            "unknown"
        }
        info["build_fingerprint"] = Build.FINGERPRINT
        info["build_time"] = Build.TIME
        info["build_type"] = Build.TYPE
        info["build_tags"] = Build.TAGS
        info["build_user"] = Build.USER
        info["build_host"] = Build.HOST

        // Radio version
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.ICE_CREAM_SANDWICH) {
            info["radio_version"] = Build.getRadioVersion() ?: "unknown"
        }

        return info
    }

    // ── DEX File Hash ─────────────────────────────────────────────────────────

    fun getDexFileHash(): String? {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            val apkPath = packageInfo.applicationInfo?.sourceDir ?: return null
            val apkFile = File(apkPath)

            if (!apkFile.exists()) return null

            // Calculate SHA256 of APK (contains DEX)
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

    // ── Utilities ─────────────────────────────────────────────────────────────

    private fun hashString(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(input.toByteArray())
        return hash.joinToString("") { "%02x".format(it) }
    }
}
