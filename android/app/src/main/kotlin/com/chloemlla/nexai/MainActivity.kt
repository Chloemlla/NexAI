package com.chloemlla.nexai

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import com.chloemlla.lumen.crash.LumenCrash
import com.chloemlla.nexai.channels.NativeChannelRegistry
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nativeChannelRegistry: NativeChannelRegistry? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // FlutterActivity is not a ComponentActivity, so androidx.activity.enableEdgeToEdge()
        // cannot be used here. WindowCompat + transparent system bars give Flutter the same
        // edge-to-edge / IME inset behavior via MediaQuery.viewInsets.
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
        // Runs before the Dart entrypoint, so every channel is in place by the
        // time main() reaches its startup bootstrap.
        nativeChannelRegistry = NativeChannelRegistry(this, flutterEngine).also {
            it.register()
        }
        runCatching { LumenCrash.recordBreadcrumb("MainActivity.configureFlutterEngine") }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        // First frame is on screen; end the startup-hang window so a responsive
        // app is never misreported as hung.
        runCatching { LumenCrash.markStartupComplete() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nativeChannelRegistry?.dispose()
        nativeChannelRegistry = null
        super.cleanUpFlutterEngine(flutterEngine)
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
