package com.chloemlla.nexai.channels

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.chloemlla.nexai.MainActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PermissionChannel(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    private var pendingActivityResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    companion object {
        private const val REQ_PICK_IMAGE = 4101
        private const val REQ_PICK_VIDEO = 4102
        private const val REQ_OPEN_DOCUMENT = 4103
        private const val REQ_CREATE_DOCUMENT = 4104
        private const val REQ_NOTIFICATION_PERMISSION = 4201
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickImage" -> pickMedia(result, REQ_PICK_IMAGE, "image/*")
            "pickVideo" -> pickMedia(result, REQ_PICK_VIDEO, "video/*")
            "openDocument" -> openDocument(call, result)
            "createDocument" -> createDocument(call, result)
            "ensureNotificationPermission" -> ensureNotificationPermission(result)
            "getNotificationPermissionStatus" -> result.success(NativeResult.ok(notificationStatus()))
            "takePersistableUriPermission" -> takePersistableUriPermission(call, result)
            "openAppSettings" -> {
                openAppSettings()
                result.success(NativeResult.ok(mapOf("opened" to true)))
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode !in setOf(REQ_PICK_IMAGE, REQ_PICK_VIDEO, REQ_OPEN_DOCUMENT, REQ_CREATE_DOCUMENT)) {
            return false
        }
        val result = pendingActivityResult ?: return true
        pendingActivityResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(NativeResult.error("user_cancelled", "User cancelled picker"))
            return true
        }

        val uri = data.data
        if (uri == null) {
            result.success(NativeResult.error("user_cancelled", "No document selected"))
            return true
        }

        if (requestCode == REQ_OPEN_DOCUMENT || requestCode == REQ_CREATE_DOCUMENT) {
            val flags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            if (flags != 0) {
                runCatching { activity.contentResolver.takePersistableUriPermission(uri, flags) }
            }
        }

        result.success(NativeResult.ok(uriPayload(uri)))
        return true
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQ_NOTIFICATION_PERMISSION) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        result.success(
            if (granted) {
                NativeResult.ok(notificationStatus())
            } else {
                NativeResult.error(permissionDeniedCode(permissions.firstOrNull()), "Notification permission denied")
            },
        )
        return true
    }

    private fun pickMedia(result: MethodChannel.Result, requestCode: Int, mimeType: String) {
        if (pendingActivityResult != null) {
            result.success(NativeResult.error("native_failure", "Another picker is already active"))
            return
        }
        pendingActivityResult = result
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                type = mimeType
            }
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
        }
        startForResult(intent, requestCode, result)
    }

    private fun openDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingActivityResult != null) {
            result.success(NativeResult.error("native_failure", "Another picker is already active"))
            return
        }
        pendingActivityResult = result
        val mimeType = call.argument<String>("mimeType") ?: "*/*"
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startForResult(intent, REQ_OPEN_DOCUMENT, result)
    }

    private fun createDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingActivityResult != null) {
            result.success(NativeResult.error("native_failure", "Another picker is already active"))
            return
        }
        val fileName = call.argument<String>("fileName")
            ?: return result.success(NativeResult.invalidArgument("fileName is required"))
        pendingActivityResult = result
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startForResult(intent, REQ_CREATE_DOCUMENT, result)
    }

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(NativeResult.ok(notificationStatus()))
            return
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(NativeResult.ok(notificationStatus()))
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATION_PERMISSION)
    }

    private fun takePersistableUriPermission(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.let(Uri::parse)
            ?: return result.success(NativeResult.invalidArgument("uri is required"))
        val read = call.argument<Boolean>("read") ?: true
        val write = call.argument<Boolean>("write") ?: false
        var flags = 0
        if (read) flags = flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
        if (write) flags = flags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        result.success(
            runCatching {
                activity.contentResolver.takePersistableUriPermission(uri, flags)
                NativeResult.ok(mapOf("uri" to uri.toString(), "persisted" to true))
            }.getOrElse {
                NativeResult.nativeFailure("Failed to persist URI permission")
            },
        )
    }

    private fun notificationStatus(): Map<String, Any?> {
        val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        return mapOf(
            "granted" to granted,
            "required" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU),
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun permissionDeniedCode(permission: String?): String {
        if (permission == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return "permission_denied"
        }
        return if (activity.shouldShowRequestPermissionRationale(permission)) {
            "permission_denied"
        } else {
            "permission_permanently_denied"
        }
    }

    private fun uriPayload(uri: Uri): Map<String, Any?> = mapOf(
        "uri" to uri.toString(),
        "mimeType" to activity.contentResolver.getType(uri),
        "displayName" to displayName(uri),
    )

    private fun displayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = activity.contentResolver.query(uri, null, null, null, null)
            val nameIndex = cursor?.getColumnIndex(OpenableColumns.DISPLAY_NAME) ?: -1
            if (cursor?.moveToFirst() == true && nameIndex >= 0) cursor.getString(nameIndex) else null
        } catch (_: Exception) {
            null
        } finally {
            cursor?.close()
        }
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", activity.packageName, null)
        }
        activity.startActivity(intent)
    }

    private fun startForResult(
        intent: Intent,
        requestCode: Int,
        result: MethodChannel.Result,
    ) {
        runCatching {
            activity.startActivityForResult(intent, requestCode)
        }.onFailure {
            pendingActivityResult = null
            result.success(NativeResult.nativeFailure("No activity can handle this request"))
        }
    }
}
