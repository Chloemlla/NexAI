package com.chloemlla.nexai

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.chloemlla.lumen.crash.CrashReport
import com.chloemlla.lumen.crash.LumenCrash
import com.chloemlla.lumen.crash.ui.LumenCrashReportScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Launcher gate required by lumen-crash:
 * show [LumenCrashReportScreen] for any pending native report before Flutter starts.
 */
class CrashGateActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        runCatching { LumenCrash.recordBreadcrumb("CrashGateActivity.onCreate") }
        enableEdgeToEdge()

        // Prefer the SDK host-safe loader so integrity/install failures do not kill launch.
        val pendingReport = LumenCrash.loadPendingReportSafely()
        if (pendingReport == null) {
            setContent {
                MaterialTheme(
                    colorScheme = if (isSystemInDarkTheme()) darkColorScheme() else lightColorScheme(),
                ) {
                    // Keep the main thread responsive while the pre-warmed engine
                    // becomes ready. Proceed even on timeout: MainActivity then
                    // falls back to a freshly created engine.
                    LaunchedEffect(Unit) {
                        withContext(Dispatchers.IO) {
                            NexAIApplication.awaitEnginePreWarm(ENGINE_WAIT_TIMEOUT_MS)
                        }
                        openMainAndFinish()
                    }
                    EngineWarmupIndicator()
                }
            }
            return
        }

        setContent {
            // Explicit nullable type: continue path assigns null to leave the gate.
            var report by remember { mutableStateOf<CrashReport?>(pendingReport) }
            val crashReport = report
            if (crashReport == null) {
                LaunchedEffect(Unit) { openMainAndFinish() }
                return@setContent
            }

            MaterialTheme(
                colorScheme = if (isSystemInDarkTheme()) darkColorScheme() else lightColorScheme(),
            ) {
                LumenCrashReportScreen(
                    report = crashReport,
                    onContinue = {
                        runCatching { LumenCrash.clearPendingReport() }
                        report = null
                    },
                    clearStoredReportOnContinue = true,
                )
            }
        }
    }

    private fun openMainAndFinish() {
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
        )
        finish()
    }

    private companion object {
        const val ENGINE_WAIT_TIMEOUT_MS = 6_000L
    }
}

@Composable
private fun EngineWarmupIndicator() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator()
        Text(
            text = "正在启动…",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
