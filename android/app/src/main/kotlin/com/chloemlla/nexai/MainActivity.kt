package com.chloemlla.nexai

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import com.chloemlla.lumen.crash.LumenCrash
import com.chloemlla.nexai.channels.NativeChannelRegistry
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nativeChannelRegistry: NativeChannelRegistry? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Use the Activity edge-to-edge helper so IME / system bar insets
        // continue to flow into Flutter as MediaQuery.viewInsets.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        runCatching { LumenCrash.recordBreadcrumb("MainActivity.onCreate") }

        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT < 36) {
            @Suppress("DEPRECATION")
            window.statusBarColor = Color.TRANSPARENT
            @Suppress("DEPRECATION")
            window.navigationBarColor = Color.TRANSPARENT
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeChannelRegistry = NativeChannelRegistry(this, flutterEngine).also {
            it.register()
        }
        runCatching { LumenCrash.recordBreadcrumb("MainActivity.configureFlutterEngine") }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (nativeChannelRegistry?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (nativeChannelRegistry?.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults,
            ) == true
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
