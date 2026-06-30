package com.chloemlla.nexai.background

import android.content.Context
import org.json.JSONObject

class NativeTaskStore(context: Context) {
    private val prefs = context.getSharedPreferences("nexai_native_tasks", Context.MODE_PRIVATE)

    fun put(task: Map<String, Any?>) {
        val taskId = task["taskId"] as? String ?: return
        prefs.edit().putString(taskId, JSONObject(task).toString()).apply()
    }

    fun get(taskId: String): Map<String, Any?>? {
        val raw = prefs.getString(taskId, null) ?: return null
        return jsonToMap(JSONObject(raw))
    }

    fun list(): List<Map<String, Any?>> =
        prefs.all.values.mapNotNull { value ->
            val raw = value as? String ?: return@mapNotNull null
            runCatching { jsonToMap(JSONObject(raw)) }.getOrNull()
        }.sortedByDescending { it["updatedAt"] as? Long ?: 0L }

    fun updateStatus(taskId: String, status: String, message: String? = null) {
        val existing = get(taskId)?.toMutableMap() ?: mutableMapOf("taskId" to taskId)
        existing["status"] = status
        existing["updatedAt"] = System.currentTimeMillis()
        if (message != null) existing["message"] = message
        put(existing)
    }

    private fun jsonToMap(json: JSONObject): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.get(key)
            result[key] = if (value == JSONObject.NULL) null else value
        }
        return result
    }
}
