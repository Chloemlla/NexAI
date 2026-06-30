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
                result.success(
                    taskStore.get(taskId)?.let { NativeResult.ok(it) }
                        ?: NativeResult.error("task_not_found", "Task not found"),
                )
            }
            "listTasks" -> result.success(NativeResult.ok(taskStore.list()))
            "cancelTask" -> {
                val taskId = call.argument<String>("taskId")
                    ?: return result.success(NativeResult.invalidArgument("taskId is required"))
                taskStore.updateStatus(taskId, "cancelled", "cancelled by user")
                events.emit(
                    mapOf(
                        "taskId" to taskId,
                        "type" to "cancelled",
                        "progress" to 0.0,
                        "message" to "cancelled by user",
                        "payload" to emptyMap<String, Any?>(),
                    ),
                )
                result.success(NativeResult.ok(taskStore.get(taskId)))
            }
            else -> result.notImplemented()
        }
    }

    private fun enqueueTask(call: MethodCall, result: MethodChannel.Result) {
        val type = call.argument<String>("type")
            ?: return result.success(NativeResult.invalidArgument("type is required"))
        val taskId = call.argument<String>("taskId") ?: "task-${UUID.randomUUID()}"
        val task = mapOf(
            "taskId" to taskId,
            "type" to type,
            "status" to "queued",
            "constraints" to (call.argument<Map<String, Any?>>("constraints") ?: emptyMap()),
            "payload" to (call.argument<Map<String, Any?>>("payload") ?: emptyMap()),
            "retryCount" to (call.argument<Int>("retryCount") ?: 0),
            "createdAt" to System.currentTimeMillis(),
            "updatedAt" to System.currentTimeMillis(),
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
        result.success(NativeResult.ok(task))
    }
}
