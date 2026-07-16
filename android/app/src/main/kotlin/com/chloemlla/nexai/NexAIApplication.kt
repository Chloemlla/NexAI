package com.chloemlla.nexai

import android.content.Context
import com.chloemlla.lumen.crash.LumenCrash
import com.chloemlla.lumen.crash.LumenCrashConfig
import com.chloemlla.nexai.core.mmkv.NexAIMmkv
import com.chloemlla.nexai.security.StartupSecurityBootstrap
import io.flutter.app.FlutterApplication

class NexAIApplication : FlutterApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        // Host startup must stay non-fatal even if author integrity fail-closes.
        runCatching {
            installLumenCrashSdk()
            LumenCrash.recordBreadcrumb("Application.attachBaseContext")
        }
    }

    override fun onCreate() {
        super.onCreate()
        runCatching {
            installLumenCrashSdk()
            LumenCrash.recordBreadcrumb("Application.onCreate")
        }
        // Early non-fatal security/provider snapshot for diagnostics + crash breadcrumbs.
        runCatching {
            StartupSecurityBootstrap.ensureInitialized(this)
            LumenCrash.recordBreadcrumb("Startup security snapshot ready")
        }.onFailure { error ->
            runCatching {
                LumenCrash.recordBreadcrumb(
                    "Startup security snapshot failed: ${error.javaClass.simpleName}",
                )
            }
        }
        runCatching { NexAIMmkv.initialize(this) }
            .onSuccess { LumenCrash.recordBreadcrumb("MMKV initialized") }
            .onFailure { error ->
                runCatching {
                    LumenCrash.recordBreadcrumb(
                        "MMKV initialize failed: ${error.javaClass.simpleName}",
                    )
                }
                runCatching { LumenCrash.record(error) }
            }
    }

    private fun installLumenCrashSdk() {
        if (LumenCrash.isInstalled()) return
        val appName = runCatching { getString(R.string.app_name) }.getOrDefault("NexAI")
        // installSafely keeps integrity fail-closed inside the SDK while preventing
        // one failed install path from process-killing cold start (white screen).
        LumenCrash.installSafely(
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