package com.chloemlla.nexai

import com.chloemlla.nexai.core.mmkv.NexAIMmkv
import io.flutter.app.FlutterApplication

class NexAIApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        NexAIMmkv.initialize(this)
    }
}
