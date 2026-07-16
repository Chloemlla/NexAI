package com.chloemlla.nexai.channels

import com.chloemlla.nexai.background.NativeTaskStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class BackgroundTaskChannel(
    private val taskStore: NativeTaskStore,
    private val events: NativeTaskEvents,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "enqueueTask" -> enqueueTask(call, result)
            "getTaskStatus" -> {
                val taskId = call.argument<String>("taskId")
                    ?: return result.success(NativeResult.invalidArgument("taskId is required"))
                val task = taskStore.get(taskId)?.let(::normalizeTask)
                result.success(
                    task?.let { NativeResult.ok(it) }
                        ?: NativeResult.error("task_not_found", "Task not found"),
                )
            }
            "listTasks" -> result.success(
                NativeResult.ok(taskStore.list().map(::normalizeTask)),
            )
            "cancelTask" -> cancelTask(call, result)
            else -> result.notImplemented()
        }
    }

    private fun enqueueTask(call: MethodCall, result: MethodChannel.Result) {
        val type = call.argument<String>("type")?.trim().orEmpty()
        if (type.isEmpty()) {
            return result.success(NativeResult.invalidArgument("type is required"))
        }
        if (type !in SUPPORTED_TYPES) {
            return result.success(
                NativeResult.error(
                    "invalid_argument",
                    "Unsupported task type: $type",
                    details = mapOf("supportedTypes" to SUPPORTED_TYPES.toList()),
                ),
            )
        }

        taskStore.pruneTerminalTasks()
        val taskId = call.argument<String>("taskId")?.takeIf { it.isNotBlank() }
            ?: "task-${UUID.randomUUID()}"
        val now = System.currentTimeMillis()
        val task = mapOf(
            "taskId" to taskId,
            "type" to type,
            "status" to "queued",
            "message" to "queued",
            "progress" to 0.0,
            "constraints" to (call.argument<Map<String, Any?>>("constraints") ?: emptyMap()),
            "payload" to (call.argument<Map<String, Any?>>("payload") ?: emptyMap()),
            "retryCount" to (call.argument<Int>("retryCount") ?: 0),
            "createdAt" to now,
            "updatedAt" to now,
        )
        taskStore.put(task)
        events.emit(
            mapOf(
                "taskId" to taskId,
                "type" to "started",
                "progress" to 0.0,
                "message" to "queued",
                "payload" to task,
            ),
        )
        result.success(NativeResult.ok(normalizeTask(task)))
    }

    private fun cancelTask(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId")
            ?: return result.success(NativeResult.invalidArgument("taskId is required"))
        val existing = taskStore.get(taskId)
            ?: return result.success(NativeResult.error("task_not_found", "Task not found"))

        val status = existing["status"]?.toString()
        if (status in TERMINAL_STATUSES) {
            // Cancel is idempotent for terminal tasks.
            return result.success(NativeResult.ok(normalizeTask(existing)))
        }

        taskStore.updateStatus(taskId, "cancelled", "cancelled by user")
        taskStore.cleanupOutput(existing["outputUri"] as? String)
        val cancelled = taskStore.get(taskId) ?: existing + mapOf(
            "status" to "cancelled",
            "message" to "cancelled by user",
            "updatedAt" to System.currentTimeMillis(),
        )
        events.emit(
            mapOf(
                "taskId" to taskId,
                "type" to "cancelled",
                "progress" to 0.0,
                "message" to "cancelled by user",
                "payload" to normalizeTask(cancelled),
            ),
        )
        result.success(NativeResult.ok(normalizeTask(cancelled)))
    }

    private fun normalizeTask(task: Map<String, Any?>): Map<String, Any?> {
        val status = task["status"]?.toString() ?: "queued"
        return mapOf(
            "taskId" to (task["taskId"] ?: ""),
            "type" to (task["type"] ?: "unknown"),
            "status" to status,
            "message" to (task["message"] ?: status),
            "progress" to ((task["progress"] as? Number)?.toDouble() ?: defaultProgress(status)),
            "constraints" to (task["constraints"] ?: emptyMap<String, Any?>()),
            "payload" to (task["payload"] ?: emptyMap<String, Any?>()),
            "retryCount" to ((task["retryCount"] as? Number)?.toInt() ?: 0),
            "createdAt" to ((task["createdAt"] as? Number)?.toLong() ?: 0L),
            "updatedAt" to ((task["updatedAt"] as? Number)?.toLong() ?: 0L),
            "outputUri" to task["outputUri"],
            "notificationId" to task["notificationId"],
            "lastErrorCode" to task["lastErrorCode"],
            "error" to task["error"],
        )
    }

    private fun defaultProgress(status: String): Double = when (status) {
        "succeeded" -> 1.0
        "running" -> 0.0
        else -> 0.0
    }

    private companion object {
        val SUPPORTED_TYPES = setOf(
            "audioExtraction",
            "videoCompression",
            "media",
            "update",
            "sync",
            "generic",
        )
        val TERMINAL_STATUSES = setOf("succeeded", "failed", "cancelled")
    }
}
