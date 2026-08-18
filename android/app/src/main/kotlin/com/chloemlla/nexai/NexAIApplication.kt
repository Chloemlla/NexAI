package com.chloemlla.nexai

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.chloemlla.lumen.crash.LumenCrash
import com.chloemlla.lumen.crash.LumenCrashConfig
import com.chloemlla.nexai.channels.ClashCompatChannel
import com.chloemlla.nexai.core.mmkv.NexAIMmkv
import com.chloemlla.nexai.security.HardeningGuard
import com.chloemlla.nexai.security.StartupSecurityBootstrap
import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.util.GeneratedPluginRegister
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class NexAIApplication : FlutterApplication() {
    private var hardeningGuard: HardeningGuard? = null
    private val prewarmClashCompatChannelRef = AtomicReference<ClashCompatChannel?>(null)
    private val prewarmLock = Any()

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
        // Run on background thread to avoid ANR (APK SHA-256, subprocesses, PM queries).
        runCatching {
            Thread { StartupSecurityBootstrap.ensureInitialized(this) }.start()
            LumenCrash.recordBreadcrumb("Startup security snapshot dispatched")
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
        // Start native hardening watchdog (non-fatal on failure).
        runCatching {
            HardeningGuard(this).also {
                hardeningGuard = it
                it.start()
            }
            LumenCrash.recordBreadcrumb("Hardening watchdog started")
        }
        // Warm the Flutter engine off the main thread so the multi-second
        // cold-start engine creation does not stall the main looper.
        startFlutterEnginePreWarm()
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
                startupHangWatchdogEnabled = true,
            ),
        )
    }

    /**
     * Pre-creates the default Flutter engine and caches it.
     * CrashGateActivity waits for it so MainActivity attaches to a ready engine
     * instead of creating one during cold start.
     */
    private fun startFlutterEnginePreWarm() {
        // FlutterEngine construction touches FlutterJNI methods annotated
        // @UiThread; Android 16 enforces this and crashes off-main-thread
        // creation ("nexai-flutter-prewarm"). Post the work to the main
        // looper. CrashGateActivity already shows a spinner while it waits,
        // and engine creation here is the only main-thread work scheduled,
        // so the gate remains responsive.
        Handler(Looper.getMainLooper()).post {
            synchronized(prewarmLock) {
                runCatching {
                    val engine = FlutterEngine(applicationContext)
                    GeneratedPluginRegister.registerGeneratedPlugins(engine)
                    // Dart's startup bootstrap calls ClashCompat before MainActivity
                    // attaches; register the channel now so auto-adapt is not skipped.
                    prewarmClashCompatChannelRef.set(
                        ClashCompatChannel(applicationContext, engine.dartExecutor.binaryMessenger),
                    )
                    engine.dartExecutor.executeDartEntrypoint(
                        DartExecutor.DartEntrypoint.createDefault(),
                    )
                    FlutterEngineCache.getInstance().put(PREWARM_ENGINE_ID, engine)
                    engineReady.set(true)
                }.onFailure { error ->
                    runCatching { LumenCrash.record(error) }
                }
                engineLatch.countDown()
            }
        }
    }

    /** Disposes channels registered during pre-warm before MainActivity re-registers them. */
    fun disposePrewarmChannels() {
        val channel = prewarmClashCompatChannelRef.getAndSet(null) ?: return
        runCatching { channel.dispose() }
    }

    override fun onTerminate() {
        disposePrewarmChannels()
        runCatching { hardeningGuard?.stop() }
        super.onTerminate()
    }

    companion object {
        const val PREWARM_ENGINE_ID = "nexai_default_engine"

        private val engineReady = AtomicBoolean(false)
        private val engineLatch = CountDownLatch(1)

        fun enginePreWarmReady(): Boolean = engineReady.get()

        fun awaitEnginePreWarm(timeoutMillis: Long): Boolean =
            try {
                engineLatch.await(timeoutMillis, TimeUnit.MILLISECONDS) && engineReady.get()
            } catch (_: InterruptedException) {
                false
            }
    }
}
