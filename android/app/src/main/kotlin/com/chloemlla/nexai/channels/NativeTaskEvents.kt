package com.chloemlla.nexai.channels

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

class NativeTaskEvents : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun emit(event: Map<String, Any?>) {
        mainHandler.post {
            sink?.success(event)
        }
    }
}
