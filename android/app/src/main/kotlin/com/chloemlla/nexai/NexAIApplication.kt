package com.chloemlla.nexai

import android.content.Context
import com.chloemlla.lumen.crash.LumenCrash
import com.chloemlla.lumen.crash.LumenCrashConfig
import com.chloemlla.nexai.core.mmkv.NexAIMmkv
import io.flutter.app.FlutterApplication

class NexAIApplication : FlutterApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        installLumenCrashSdk()
        LumenCrash.recordBreadcrumb("Application.attachBaseContext")
    }

    override fun onCreate() {
        super.onCreate()
        installLumenCrashSdk()
        LumenCrash.recordBreadcrumb("Application.onCreate")
        runCatching { NexAIMmkv.initialize(this) }
            .onSuccess { LumenCrash.recordBreadcrumb("MMKV initialized") }
            .onFailure { error ->
                LumenCrash.recordBreadcrumb("MMKV initialize failed: ${error.javaClass.simpleName}")
                runCatching { LumenCrash.record(error) }
            }
    }

    private fun installLumenCrashSdk() {
        if (LumenCrash.isInstalled()) return
        val appName = runCatching { getString(R.string.app_name) }.getOrDefault("NexAI")
        LumenCrash.install(
            this,
            LumenCrashConfig(
                appDisplayName = appName,
                versionName = BuildConfig.VERSION_NAME,
                versionCode = BuildConfig.VERSION_CODE,
                commitHash = BuildConfig.SHORT_HASH,
                fileProviderAuthority = "${packageName}.fileprovider",
                shareSubject = runCatching { getString(R.string.crash_report_share_subject) }.getOrNull(),
                reportTitle = runCatching { getString(R.string.crash_report_title) }.getOrNull(),
                reportMessage = runCatching { getString(R.string.crash_report_message) }.getOrNull(),
            ),
        )
    }
}
