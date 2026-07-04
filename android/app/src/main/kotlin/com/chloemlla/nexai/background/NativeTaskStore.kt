package com.chloemlla.nexai.background

import android.content.Context
import com.chloemlla.nexai.core.mmkv.NexAIMmkv
import org.json.JSONObject

class NativeTaskStore(context: Context) {
    private val appContext = context.applicationContext
    private val mmkv = NexAIMmkv.mmkvWithId(STORE_ID)

    init {
        migrateLegacySharedPreferences()
    }

    fun put(task: Map<String, Any?>) {
        val taskId = task["taskId"] as? String ?: return
        mmkv.encode(taskId, JSONObject(task).toString())
    }

    fun get(taskId: String): Map<String, Any?>? {
        val raw = mmkv.decodeString(taskId) ?: return null
        return jsonToMap(JSONObject(raw))
    }

    fun list(): List<Map<String, Any?>> =
        mmkv.allKeys()?.asSequence()
            ?.filter { key -> key != KEY_MMKV_MIGRATION_COMPLETE }
            ?.mapNotNull { key ->
                val raw = mmkv.decodeString(key) ?: return@mapNotNull null
                runCatching { jsonToMap(JSONObject(raw)) }.getOrNull()
            }
            ?.sortedByDescending { it["updatedAt"] as? Long ?: 0L }
            ?.toList()
            ?: emptyList()

    fun updateStatus(taskId: String, status: String, message: String? = null) {
        val existing: MutableMap<String, Any?> =
            get(taskId)?.toMutableMap() ?: mutableMapOf<String, Any?>("taskId" to taskId)
        existing["status"] = status
        existing["updatedAt"] = System.currentTimeMillis()
        if (message != null) existing["message"] = message
        put(existing)
    }

    private fun migrateLegacySharedPreferences() {
        if (mmkv.decodeBool(KEY_MMKV_MIGRATION_COMPLETE, false)) return
        synchronized(migrationLock) {
            if (mmkv.decodeBool(KEY_MMKV_MIGRATION_COMPLETE, false)) return
            val legacyPrefs = appContext.getSharedPreferences(
                LEGACY_PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            legacyPrefs.all.forEach { (key, value) ->
                val raw = value as? String ?: return@forEach
                if (raw.isBlank() || mmkv.containsKey(key)) return@forEach
                mmkv.encode(key, raw)
            }
            mmkv.encode(KEY_MMKV_MIGRATION_COMPLETE, true)
            legacyPrefs.edit().clear().apply()
        }
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

    private companion object {
        val migrationLock = Any()
        const val STORE_ID = "nexai_native_tasks"
        const val LEGACY_PREFS_NAME = "nexai_native_tasks"
        const val KEY_MMKV_MIGRATION_COMPLETE = "__mmkv_migration_complete"
    }
}
