package com.chloemlla.nexai.channels

import com.chloemlla.lumen.crash.AuthorIntegrity
import com.chloemlla.lumen.crash.CrashReport
import com.chloemlla.lumen.crash.LumenCrash
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter/Dart crash reports into the lumen-crash store so the next cold
 * start can show [com.chloemlla.lumen.crash.ui.LumenCrashReportScreen] via CrashGate.
 */
class CrashChannel : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "recordReport" -> result.success(recordReport(call.arguments))
            "recordBreadcrumb" -> {
                val event = call.argument<String>("event")
                    ?: (call.arguments as? String)
                    ?: ""
                result.success(recordBreadcrumb(event))
            }
            "clearPendingReport" -> result.success(clearPendingReport())
            "isInstalled" -> result.success(LumenCrash.isInstalled())
            else -> result.notImplemented()
        }
    }

    private fun recordBreadcrumb(event: String): Boolean {
        if (event.isBlank()) return false
        return runCatching {
            LumenCrash.recordBreadcrumb(event)
            true
        }.getOrDefault(false)
    }

    private fun clearPendingReport(): Boolean {
        return runCatching {
            LumenCrash.clearPendingReport()
            true
        }.getOrDefault(false)
    }

    private fun recordReport(arguments: Any?): Boolean {
        val map = arguments as? Map<*, *> ?: return false
        if (!LumenCrash.isInstalled()) return false

        return runCatching {
            AuthorIntegrity.verifyOrThrow("flutter-record")
            val author = AuthorIntegrity.verifiedAuthorBlock()

            val exceptionTypeRaw = stringOf(map["exceptionType"]).ifBlank { "Unknown" }
            val exceptionType = if (exceptionTypeRaw.startsWith("flutter.")) {
                exceptionTypeRaw
            } else {
                "flutter.$exceptionTypeRaw"
            }
            val rootCause = stringOf(map["rootCause"]).ifBlank { exceptionType }
            val stackTrace = stringOf(map["stackTrace"]).ifBlank { "<missing dart stack>" }
            val crashedAtMillis = numberOf(map["crashedAtMillis"]) ?: System.currentTimeMillis()
            val crashedAtText = stringOf(map["crashedAtText"]).ifBlank { crashedAtMillis.toString() }
            val reportId = stringOf(map["reportId"]).ifBlank {
                crashedAtMillis.toString().takeLast(12)
            }
            val threadName = stringOf(map["threadName"]).ifBlank { "flutter-main-isolate" }
            val processName = stringOf(map["processName"]).ifBlank { "NexAI" }
            val systemInfo = buildString {
                appendLine("Source: Flutter/Dart")
                val hostInfo = stringOf(map["systemInfo"])
                if (hostInfo.isNotBlank()) {
                    append(hostInfo)
                }
            }.trim()
            val recentEvents = listOfString(map["recentEvents"])

            val report = CrashReport(
                reportId = reportId,
                crashedAtMillis = crashedAtMillis,
                crashedAtText = crashedAtText,
                exceptionType = exceptionType,
                rootCause = rootCause,
                threadName = threadName,
                processName = processName,
                systemInfo = systemInfo,
                stackTrace = stackTrace,
                recentEvents = recentEvents,
                authorName = author.authorName,
                authorUrl = author.authorUrl,
                authorFingerprint = author.authorFingerprint,
            )

            LumenCrash.store().save(report)
            LumenCrash.recordBreadcrumb("Flutter crash bridged: $exceptionType")
            true
        }.getOrDefault(false)
    }

    private fun stringOf(value: Any?): String = value?.toString()?.trim().orEmpty()

    private fun numberOf(value: Any?): Long? = when (value) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull()
        else -> null
    }

    private fun listOfString(value: Any?): List<String> {
        val list = value as? List<*> ?: return emptyList()
        return list.mapNotNull { item ->
            item?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        }
    }
}
