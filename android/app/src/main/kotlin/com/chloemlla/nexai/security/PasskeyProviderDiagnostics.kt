package com.chloemlla.nexai.security

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * Diagnoses available Credential Manager / passkey providers on OEM-skewed devices.
 *
 * Google Password Manager is preferred when present; OEM replacements are reported as risk.
 */
object PasskeyProviderDiagnostics {
    const val GOOGLE_PLAY_SERVICES_PACKAGE = "com.google.android.gms"
    const val GOOGLE_PASSWORD_MANAGER_CLASS =
        "com.google.android.gms.auth.api.credentials.credman.service.PasswordAndPasskeyService"

    val googlePasswordManagerComponent: ComponentName =
        ComponentName(GOOGLE_PLAY_SERVICES_PACKAGE, GOOGLE_PASSWORD_MANAGER_CLASS)

    private val knownOemCredentialPackages = listOf(
        "com.vivo.password",
        "com.vivo.assistant",
        "com.coloros.phonemanager",
        "com.oplus.password",
        "com.oneplus.account",
        "com.miui.cloudservice",
        "com.xiaomi.account",
        "com.huawei.hwid",
        "com.hihonor.id",
        "com.samsung.android.lool",
        "com.samsung.android.sm.devicesecurity",
    )

    fun diagnose(context: Context, googleOnlyPreferred: Boolean = true): Map<String, Any?> {
        val pm = context.packageManager
        val googleAvailable = isPackageInstalled(pm, GOOGLE_PLAY_SERVICES_PACKAGE)
        val googleServiceEnabled = googleAvailable && isComponentEnabled(pm, googlePasswordManagerComponent)
        val oemProviders = knownOemCredentialPackages
            .filter { isPackageInstalled(pm, it) }
            .map { packageName ->
                mapOf(
                    "packageName" to packageName,
                    "label" to packageLabel(pm, packageName),
                    "enabled" to isPackageEnabled(pm, packageName),
                )
            }

        val risk = when {
            !googleAvailable -> "google_missing"
            !googleServiceEnabled -> "google_disabled_or_hidden"
            oemProviders.isNotEmpty() -> "oem_providers_present"
            else -> "low"
        }

        val recommendedMode = when {
            googleOnlyPreferred && googleAvailable -> "google_password_manager_only"
            googleAvailable -> "google_password_manager_first"
            else -> "system_default"
        }

        return mapOf(
            "checkedAt" to System.currentTimeMillis(),
            "sdkInt" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "googlePlayServicesInstalled" to googleAvailable,
            "googlePasswordManagerComponent" to googlePasswordManagerComponent.flattenToString(),
            "googlePasswordManagerEnabled" to googleServiceEnabled,
            "googleOnlyPreferred" to googleOnlyPreferred,
            "recommendedProviderMode" to recommendedMode,
            "oemProviders" to oemProviders,
            "oemProviderCount" to oemProviders.size,
            "risk" to risk,
            "source" to "android_kotlin_native",
            "notes" to buildNotes(googleAvailable, googleServiceEnabled, oemProviders.isNotEmpty(), googleOnlyPreferred),
        )
    }

    fun isGooglePasswordManagerAvailable(context: Context): Boolean {
        val pm = context.packageManager
        return isPackageInstalled(pm, GOOGLE_PLAY_SERVICES_PACKAGE)
    }

    private fun buildNotes(
        googleAvailable: Boolean,
        googleServiceEnabled: Boolean,
        oemPresent: Boolean,
        googleOnlyPreferred: Boolean,
    ): List<String> {
        val notes = mutableListOf<String>()
        if (!googleAvailable) {
            notes += "Google Play Services not installed; passkeys will use OEM/system providers."
        } else if (!googleServiceEnabled) {
            notes += "Google Password Manager component appears disabled/hidden by OEM policy."
        } else {
            notes += "Google Password Manager is available."
        }
        if (oemPresent) {
            notes += "OEM credential-related packages detected; prefer Google-only mode on release builds."
        }
        if (googleOnlyPreferred) {
            notes += "Current preference is Google-only (no OEM fallback)."
        }
        return notes
    }

    private fun isPackageInstalled(pm: PackageManager, packageName: String): Boolean =
        try {
            pm.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }

    private fun isPackageEnabled(pm: PackageManager, packageName: String): Boolean =
        runCatching {
            pm.getApplicationInfo(packageName, 0).enabled
        }.getOrDefault(false)

    private fun isComponentEnabled(pm: PackageManager, component: ComponentName): Boolean =
        runCatching {
            when (pm.getComponentEnabledSetting(component)) {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_UNTIL_USED,
                -> false
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                else -> {
                    // Default: treat installed Google package as available.
                    isPackageInstalled(pm, component.packageName)
                }
            }
        }.getOrDefault(false)

    private fun packageLabel(pm: PackageManager, packageName: String): String =
        runCatching {
            val info = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(info).toString()
        }.getOrDefault(packageName)
}