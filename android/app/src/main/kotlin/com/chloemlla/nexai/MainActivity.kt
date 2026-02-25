package com.chloemlla.nexai

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Android 16 (API 36) enforces edge-to-edge automatically, no manual setup needed.
        // For API 30-35, explicitly enable it.
        if (Build.VERSION.SDK_INT in Build.VERSION_CODES.R until 36) {
            @Suppress("DEPRECATION")
            window.setDecorFitsSystemWindows(false)
        }

        // Transparent system bars (skip on API 36+ where it's handled by the system)
        if (Build.VERSION.SDK_INT in Build.VERSION_CODES.LOLLIPOP until 36) {
            @Suppress("DEPRECATION")
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            @Suppress("DEPRECATION")
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
    }
}
