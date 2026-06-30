package com.chloemlla.nexai.channels

import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import com.chloemlla.nexai.MainActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ShareChannel(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "shareText" -> shareText(call, result)
            "shareFile" -> shareFile(call, result)
            "shareFiles" -> shareFiles(call, result)
            else -> result.notImplemented()
        }
    }

    private fun shareText(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")
            ?: return result.success(NativeResult.invalidArgument("text is required"))
        val subject = call.argument<String>("subject")
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (!subject.isNullOrBlank()) putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        startChooser(intent, call.argument<String>("title") ?: subject ?: "Share", result)
    }

    private fun shareFile(call: MethodCall, result: MethodChannel.Result) {
        val rawUri = call.argument<String>("uri")
            ?: return result.success(NativeResult.invalidArgument("uri is required"))
        val uri = shareableUri(rawUri)
        val mimeType = call.argument<String>("mimeType") ?: inferMimeType(uri)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startChooser(intent, call.argument<String>("title") ?: "Share file", result)
    }

    private fun shareFiles(call: MethodCall, result: MethodChannel.Result) {
        val rawUris = call.argument<List<String>>("uris")
            ?: return result.success(NativeResult.invalidArgument("uris is required"))
        if (rawUris.isEmpty()) {
            return result.success(NativeResult.invalidArgument("uris cannot be empty"))
        }
        val uris = ArrayList(rawUris.map(::shareableUri))
        val mimeType = call.argument<String>("mimeType") ?: "*/*"
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = mimeType
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startChooser(intent, call.argument<String>("title") ?: "Share files", result)
    }

    private fun startChooser(intent: Intent, title: String, result: MethodChannel.Result) {
        val chooser = Intent.createChooser(intent, title)
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        result.success(
            runCatching {
                activity.startActivity(chooser)
                NativeResult.ok(mapOf("started" to true))
            }.getOrElse {
                NativeResult.nativeFailure("No activity can handle this share request")
            },
        )
    }

    private fun shareableUri(raw: String): Uri {
        val parsed = Uri.parse(raw)
        if (parsed.scheme == "content") return parsed
        val file = if (parsed.scheme == "file") File(parsed.path ?: raw) else File(raw)
        return FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.fileprovider",
            file,
        )
    }

    private fun inferMimeType(uri: Uri): String {
        activity.contentResolver.getType(uri)?.let { return it }
        val extension = MimeTypeMap.getFileExtensionFromUrl(uri.toString())
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase())
            ?: "application/octet-stream"
    }
}
