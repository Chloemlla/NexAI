package com.chloemlla.nexai.channels

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.chloemlla.nexai.MainActivity
import com.chloemlla.nexai.security.SecuritySignals
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class UpdateChannel(
    private val activity: MainActivity,
    private val securitySignals: SecuritySignals,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstallEnvironment" -> result.success(NativeResult.ok(installEnvironment()))
            "openUrl" -> openUrl(call, result)
            "openUnknownSourcesSettings" -> {
                openUnknownSourcesSettings()
                result.success(NativeResult.ok(mapOf("opened" to true)))
            }
            "verifyApkSha256" -> verifyApkSha256(call, result)
            "installApk" -> installApk(call, result)
            else -> result.notImplemented()
        }
    }

    private fun installEnvironment(): Map<String, Any?> {
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            runCatching {
                activity.packageManager.getInstallSourceInfo(activity.packageName).installingPackageName
            }.getOrNull()
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getInstallerPackageName(activity.packageName)
        }
        return mapOf(
            "packageName" to activity.packageName,
            "versionName" to info.versionName,
            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong(),
            "signatureSha256" to securitySignals.getApkSignatureSha256(),
            "canRequestPackageInstalls" to canRequestPackageInstalls(),
            "installerPackageName" to installer,
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun openUrl(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
            ?: return result.success(NativeResult.invalidArgument("url is required"))
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
        }
        result.success(
            runCatching {
                activity.startActivity(intent)
                NativeResult.ok(mapOf("opened" to true))
            }.getOrElse {
                NativeResult.nativeFailure("Failed to open URL")
            },
        )
    }

    private fun verifyApkSha256(call: MethodCall, result: MethodChannel.Result) {
        val uriOrPath = call.argument<String>("uri")
            ?: call.argument<String>("path")
            ?: return result.success(NativeResult.invalidArgument("uri or path is required"))
        val expectedSha256 = call.argument<String>("expectedSha256")
        result.success(
            runCatching {
                val actual = sha256(uriOrPath)
                NativeResult.ok(
                    mapOf(
                        "sha256" to actual,
                        "matches" to (expectedSha256?.equals(actual, ignoreCase = true) ?: true),
                    ),
                )
            }.getOrElse {
                NativeResult.nativeFailure("Failed to verify APK hash")
            },
        )
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        if (!canRequestPackageInstalls()) {
            return result.success(
                NativeResult.error(
                    "permission_denied",
                    "Installing unknown apps is not allowed for this source",
                ),
            )
        }
        val uriOrPath = call.argument<String>("uri")
            ?: call.argument<String>("path")
            ?: return result.success(NativeResult.invalidArgument("uri or path is required"))
        val uri = shareableApkUri(uriOrPath)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        result.success(
            runCatching {
                activity.startActivity(intent)
                NativeResult.ok(mapOf("started" to true))
            }.getOrElse {
                NativeResult.nativeFailure("Failed to open system package installer")
            },
        )
    }

    private fun openUnknownSourcesSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val uri = Uri.parse("package:${activity.packageName}")
            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, uri))
        } else {
            @Suppress("DEPRECATION")
            activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
        }
    }

    private fun canRequestPackageInstalls(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.packageManager.canRequestPackageInstalls()

    private fun shareableApkUri(raw: String): Uri {
        val parsed = Uri.parse(raw)
        if (parsed.scheme == "content") return parsed
        val file = if (parsed.scheme == "file") File(parsed.path ?: raw) else File(raw)
        return FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", file)
    }

    private fun sha256(uriOrPath: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        if (uriOrPath.startsWith("content://")) {
            activity.contentResolver.openInputStream(Uri.parse(uriOrPath)).use { input ->
                requireNotNull(input) { "Unable to open URI" }
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = input.read(buffer)
                    if (read == -1) break
                    digest.update(buffer, 0, read)
                }
            }
        } else {
            File(uriOrPath.removePrefix("file://")).inputStream().use { input ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = input.read(buffer)
                    if (read == -1) break
                    digest.update(buffer, 0, read)
                }
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
