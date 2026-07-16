package com.chloemlla.nexai.channels

import android.content.Intent
import android.content.pm.PackageInfo
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
import java.io.FileInputStream
import java.io.InputStream
import java.security.MessageDigest
import java.util.zip.
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
            "verifyApkPackage" -> verifyApkPackage(call, result)
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
                val verification = verifyPackageIdentity(
                    uriOrPath = uriOrPath,
                    expectedSha256 = expectedSha256,
                    requireHashMatch = expectedSha256 != null,
                    requirePackageMatch = false,
                    requireSignatureMatch = false,
                )
                when (verification) {
                    is VerificationOutcome.Ok -> NativeResult.ok(verification.payload)
                    is VerificationOutcome.Error -> verification.result
                }
            }.getOrElse {
                NativeResult.nativeFailure("Failed to verify APK hash")
            },
        )
    }

    private fun verifyApkPackage(call: MethodCall, result: MethodChannel.Result) {
        val uriOrPath = call.argument<String>("uri")
            ?: call.argument<String>("path")
            ?: return result.success(NativeResult.invalidArgument("uri or path is required"))
        val expectedSha256 = call.argument<String>("expectedSha256")
        result.success(
            runCatching {
                val verification = verifyPackageIdentity(
                    uriOrPath = uriOrPath,
                    expectedSha256 = expectedSha256,
                    requireHashMatch = expectedSha256 != null,
                    requirePackageMatch = true,
                    requireSignatureMatch = true,
                )
                when (verification) {
                    is VerificationOutcome.Ok -> NativeResult.ok(verification.payload)
                    is VerificationOutcome.Error -> verification.result
                }
            }.getOrElse {
                NativeResult.nativeFailure("Failed to verify APK package identity")
            },
        )
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        if (!canRequestPackageInstalls()) {
            return result.success(
                NativeResult.error(
                    "permission_denied",
                    "Installing unknown apps is not allowed for this source",
                    recoverable = true,
                ),
            )
        }
        val uriOrPath = call.argument<String>("uri")
            ?: call.argument<String>("path")
            ?: return result.success(NativeResult.invalidArgument("uri or path is required"))
        val expectedSha256 = call.argument<String>("expectedSha256")

        val verification = runCatching {
            verifyPackageIdentity(
                uriOrPath = uriOrPath,
                expectedSha256 = expectedSha256,
                requireHashMatch = expectedSha256 != null,
                requirePackageMatch = true,
                requireSignatureMatch = true,
            )
        }.getOrElse {
            return result.success(NativeResult.nativeFailure("Failed to verify APK before install"))
        }
        if (verification is VerificationOutcome.Error) {
            return result.success(verification.result)
        }

        val uri = shareableApkUri(uriOrPath)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        result.success(
            runCatching {
                activity.startActivity(intent)
                NativeResult.ok(
                    mapOf(
                        "started" to true,
                        "verification" to (verification as VerificationOutcome.Ok).payload,
                    ),
                )
            }.getOrElse {
                NativeResult.nativeFailure("Failed to open system package installer")
            },
        )
    }

    private fun verifyPackageIdentity(
        uriOrPath: String,
        expectedSha256: String?,
        requireHashMatch: Boolean,
        requirePackageMatch: Boolean,
        requireSignatureMatch: Boolean,
    ): VerificationOutcome {
        val readable = ensureReadable(uriOrPath)
            ?: return VerificationOutcome.Error(
                NativeResult.error(
                    "invalid_argument",
                    "APK path/uri is not readable",
                    recoverable = false,
                    details = mapOf("uri" to uriOrPath),
                ),
            )

        val actualSha256 = sha256(uriOrPath)
        val hashMatches = expectedSha256?.equals(actualSha256, ignoreCase = true) ?: true
        if (requireHashMatch && !hashMatches) {
            return VerificationOutcome.Error(
                NativeResult.error(
                    "hash_mismatch",
                    "APK SHA256 does not match expected value",
                    recoverable = false,
                    details = mapOf(
                        "sha256" to actualSha256,
                        "expectedSha256" to expectedSha256,
                        "matches" to false,
                    ),
                ),
            )
        }

        val packageInfo = readPackageInfo(uriOrPath)
        val packageName = packageInfo?.packageName
        val versionName = packageInfo?.versionName
        val versionCode = packageInfo?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) it.longVersionCode else it.versionCode.toLong()
        }
        val packageMatches = packageName == null || packageName == activity.packageName
        if (requirePackageMatch && packageName != null && !packageMatches) {
            return VerificationOutcome.Error(
                NativeResult.error(
                    "package_mismatch",
                    "APK package name does not match installed app",
                    recoverable = false,
                    details = mapOf(
                        "packageName" to packageName,
                        "expectedPackageName" to activity.packageName,
                    ),
                ),
            )
        }

        val apkSignatureSha256 = packageInfo?.let { signatureSha256(it) }
        val installedSignature = securitySignals.getApkSignatureSha256()
        val signatureMatchesInstalled = when {
            apkSignatureSha256 == null || installedSignature == null -> null
            else -> apkSignatureSha256.equals(installedSignature, ignoreCase = true)
        }
        if (requireSignatureMatch && signatureMatchesInstalled == false) {
            return VerificationOutcome.Error(
                NativeResult.error(
                    "signature_mismatch",
                    "APK signing certificate does not match the installed app",
                    recoverable = false,
                    details = mapOf(
                        "signatureSha256" to apkSignatureSha256,
                        "installedSignatureSha256" to installedSignature,
                        "signatureMatchesInstalled" to false,
                    ),
                ),
            )
        }

        return VerificationOutcome.Ok(
            mapOf(
                "sha256" to actualSha256,
                "matches" to hashMatches,
                "readable" to readable,
                "packageName" to packageName,
                "expectedPackageName" to activity.packageName,
                "packageMatches" to packageMatches,
                "versionName" to versionName,
                "versionCode" to versionCode,
                "signatureSha256" to apkSignatureSha256,
                "installedSignatureSha256" to installedSignature,
                "signatureMatchesInstalled" to signatureMatchesInstalled,
                "source" to "android_kotlin_native",
            ),
        )
    }

    private fun ensureReadable(uriOrPath: String): Boolean? = runCatching {
        if (uriOrPath.startsWith("content://")) {
            activity.contentResolver.openInputStream(Uri.parse(uriOrPath)).use { input ->
                input != null
            }
        } else {
            val file = File(uriOrPath.removePrefix("file://"))
            file.exists() && file.canRead() && file.length() > 0L
        }
    }.getOrNull()

    private fun readPackageInfo(uriOrPath: String): PackageInfo? {
        val pm = activity.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }

        if (!uriOrPath.startsWith("content://")) {
            val path = uriOrPath.removePrefix("file://")
            @Suppress("DEPRECATION")
            return pm.getPackageArchiveInfo(path, flags)?.also { info ->
                info.applicationInfo?.sourceDir = path
                info.applicationInfo?.publicSourceDir = path
            }
        }

        // Copy content URI to cache so PackageManager can archive-parse it.
        val temp = File(activity.cacheDir, "update-verify-${System.currentTimeMillis()}.apk")
        return try {
            activity.contentResolver.openInputStream(Uri.parse(uriOrPath)).use { input ->
                requireNotNull(input) { "Unable to open URI" }
                temp.outputStream().use { output -> input.copyTo(output) }
            }
            @Suppress("DEPRECATION")
            pm.getPackageArchiveInfo(temp.absolutePath, flags)?.also { info ->
                info.applicationInfo?.sourceDir = temp.absolutePath
                info.applicationInfo?.publicSourceDir = temp.absolutePath
            }
        } finally {
            runCatching { temp.delete() }
        }
    }

    private fun signatureSha256(info: PackageInfo): String? = runCatching {
        val cert = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners?.firstOrNull()
                ?: info.signingInfo?.signingCertificateHistory?.firstOrNull()
        } else {
            @Suppress("DEPRECATION")
            info.signatures?.firstOrNull()
        } ?: return null
        MessageDigest.getInstance("SHA-256")
            .digest(cert.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }.getOrNull()

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
        openApkStream(uriOrPath).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read == -1) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun openApkStream(uriOrPath: String): InputStream {
        if (uriOrPath.startsWith("content://")) {
            return requireNotNull(activity.contentResolver.openInputStream(Uri.parse(uriOrPath))) {
                "Unable to open URI"
            }
        }
        return FileInputStream(File(uriOrPath.removePrefix("file://")))
    }

    private sealed class VerificationOutcome {
        data class Ok(val payload: Map<String, Any?>) : VerificationOutcome()
        data class Error(val result: Map<String, Any?>) : VerificationOutcome()
    }
}
