package com.chloemlla.nexai.channels

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.Credential
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.SignalAllAcceptedCredentialIdsRequest
import androidx.credentials.SignalCurrentUserDetailsRequest
import androidx.credentials.SignalCredentialStateRequest
import androidx.credentials.SignalUnknownCredentialRequest
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.publickeycredential.SignalCredentialRateLimitExceededException
import androidx.credentials.exceptions.publickeycredential.SignalCredentialStateException
import com.chloemlla.nexai.MainActivity
import com.chloemlla.nexai.security.PasskeyProviderDiagnostics
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class PasskeyChannel(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    private val credentialManager = CredentialManager.create(activity)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "register" -> register(call, result)
            "authenticate" -> authenticate(call, result)
            "signalUnknownCredential" -> signalUnknownCredential(call, result)
            "signalAllAcceptedCredentials" -> signalAllAcceptedCredentials(call, result)
            "signalCurrentUserDetails" -> signalCurrentUserDetails(call, result)
            "diagnoseProviders" -> diagnoseProviders(call, result)
            else -> result.notImplemented()
        }
    }

    private fun register(call: MethodCall, result: MethodChannel.Result) {
        unsupportedAndroidVersion()?.let {
            return result.success(it)
        }

        val requestJson = requestJson(call)
            ?: return result.success(NativeResult.invalidArgument("requestJson is required"))
        val googleOnly = googleOnly(call)

        scope.launch {
            try {
                val outcome = createPasskeyPreferringGoogle(requestJson, googleOnly = googleOnly)
                val response = outcome.response
                if (response is CreatePublicKeyCredentialResponse) {
                    result.success(
                        NativeResult.ok(
                            mapOf(
                                "responseJson" to response.registrationResponseJson,
                                "responseType" to response.javaClass.name,
                                "credentialManagerApi" to "createCredential",
                                "providerPreference" to outcome.providerPreference,
                                "usedGooglePasswordManager" to outcome.usedGooglePasswordManager,
                            ) + providerDiagnosticsDetails(googleOnly),
                        ),
                    )
                } else {
                    result.success(
                        NativeResult.error(
                            "unexpected_create_response",
                            "Credential Manager returned ${response.javaClass.name}",
                            recoverable = false,
                            details = mapOf(
                                "responseType" to response.javaClass.name,
                                "providerPreference" to outcome.providerPreference,
                                "usedGooglePasswordManager" to outcome.usedGooglePasswordManager,
                            ) + providerDiagnosticsDetails(googleOnly),
                        ),
                    )
                }
            } catch (error: CreateCredentialException) {
                result.success(
                    passkeyError(
                        "create_credential",
                        error,
                        credentialDetails(error) + mapOf(
                            "providerPreference" to preferredProviderMode(googleOnly),
                            "googlePasswordManagerAvailable" to isGooglePasswordManagerAvailable(),
                            "googleOnly" to googleOnly,
                        ) + providerDiagnosticsDetails(googleOnly),
                    ),
                )
            } catch (error: IllegalArgumentException) {
                result.success(
                    NativeResult.invalidArgument(
                        error.message ?: "Invalid passkey registration requestJson",
                    ),
                )
            } catch (error: Exception) {
                result.success(
                    passkeyError(
                        "native_failure",
                        error,
                        throwableDetails(error) + providerDiagnosticsDetails(googleOnly),
                    ),
                )
            }
        }
    }

    private fun signalUnknownCredential(call: MethodCall, result: MethodChannel.Result) {
        signalCredentialState(
            call,
            result,
            "unknownCredential",
        ) { requestJson -> SignalUnknownCredentialRequest(requestJson) }
    }

    private fun signalAllAcceptedCredentials(call: MethodCall, result: MethodChannel.Result) {
        signalCredentialState(
            call,
            result,
            "allAcceptedCredentials",
        ) { requestJson -> SignalAllAcceptedCredentialIdsRequest(requestJson) }
    }

    private fun signalCurrentUserDetails(call: MethodCall, result: MethodChannel.Result) {
        signalCredentialState(
            call,
            result,
            "currentUserDetails",
        ) { requestJson -> SignalCurrentUserDetailsRequest(requestJson) }
    }

    private fun signalCredentialState(
        call: MethodCall,
        result: MethodChannel.Result,
        requestType: String,
        buildRequest: (String) -> SignalCredentialStateRequest,
    ) {
        unsupportedSignalAndroidVersion()?.let {
            return result.success(it)
        }

        val requestJson = requestJson(call)
            ?: return result.success(NativeResult.invalidArgument("requestJson is required"))

        scope.launch {
            try {
                credentialManager.signalCredentialState(buildRequest(requestJson))
                result.success(
                    NativeResult.ok(
                        mapOf(
                            "credentialManagerApi" to "signalCredentialState",
                            "signalRequestType" to requestType,
                        ),
                    ),
                )
            } catch (error: SignalCredentialStateException) {
                result.success(
                    passkeyError(
                        "signal_credential_state",
                        error,
                        signalCredentialDetails(error),
                    ),
                )
            } catch (error: IllegalArgumentException) {
                result.success(
                    NativeResult.invalidArgument(
                        error.message ?: "Invalid signal credential state requestJson",
                    ),
                )
            } catch (error: SecurityException) {
                result.success(
                    NativeResult.error(
                        "signal_credential_state_security",
                        error.message ?: "Signal Credential Manager security failure",
                        recoverable = false,
                        details = throwableDetails(error),
                    ),
                )
            } catch (error: Exception) {
                result.success(
                    passkeyError(
                        "signal_credential_state",
                        error,
                        throwableDetails(error),
                    ),
                )
            }
        }
    }

    private fun authenticate(call: MethodCall, result: MethodChannel.Result) {
        unsupportedAndroidVersion()?.let {
            return result.success(it)
        }

        val requestJson = requestJson(call)
            ?: return result.success(NativeResult.invalidArgument("requestJson is required"))
        val googleOnly = googleOnly(call)

        scope.launch {
            try {
                val outcome = getPasskeyPreferringGoogle(requestJson, googleOnly = googleOnly)
                val credential = outcome.credential
                if (credential is PublicKeyCredential) {
                    result.success(
                        NativeResult.ok(
                            mapOf(
                                "responseJson" to credential.authenticationResponseJson,
                                "credentialType" to credential.type,
                                "credentialManagerApi" to "getCredential",
                                "providerPreference" to outcome.providerPreference,
                                "usedGooglePasswordManager" to outcome.usedGooglePasswordManager,
                            ) + providerDiagnosticsDetails(googleOnly),
                        ),
                    )
                } else {
                    result.success(
                        NativeResult.error(
                            "unexpected_get_credential",
                            "Credential Manager returned ${credential.javaClass.name}",
                            recoverable = false,
                            details = mapOf(
                                "credentialType" to credential.javaClass.name,
                                "providerPreference" to outcome.providerPreference,
                                "usedGooglePasswordManager" to outcome.usedGooglePasswordManager,
                            ) + providerDiagnosticsDetails(googleOnly),
                        ),
                    )
                }
            } catch (error: GetCredentialException) {
                result.success(
                    passkeyError(
                        "get_credential",
                        error,
                        credentialDetails(error) + mapOf(
                            "providerPreference" to preferredProviderMode(googleOnly),
                            "googlePasswordManagerAvailable" to isGooglePasswordManagerAvailable(),
                            "googleOnly" to googleOnly,
                        ) + providerDiagnosticsDetails(googleOnly),
                    ),
                )
            } catch (error: IllegalArgumentException) {
                result.success(
                    NativeResult.invalidArgument(
                        error.message ?: "Invalid passkey authentication requestJson",
                    ),
                )
            } catch (error: Exception) {
                result.success(
                    passkeyError(
                        "native_failure",
                        error,
                        throwableDetails(error) + providerDiagnosticsDetails(googleOnly),
                    ),
                )
            }
        }
    }

    /**
     * Prefer Google Password Manager when installed.
     *
     * OEM skins frequently replace/tamper the system credential provider UI. When GMS is present,
     * pin create/get requests to Google first, then fall back to the unrestricted provider set.
     */
    private suspend fun createPasskeyPreferringGoogle(
        requestJson: String,
        googleOnly: Boolean,
    ): CreatePasskeyOutcome {
        val googleAvailable = isGooglePasswordManagerAvailable()
        if (googleAvailable) {
            try {
                val response = credentialManager.createCredential(
                    activity,
                    createPublicKeyRequest(
                        requestJson = requestJson,
                        allowedProviders = GOOGLE_PASSWORD_MANAGER_PROVIDERS,
                    ),
                )
                return CreatePasskeyOutcome(
                    response = response,
                    providerPreference = if (googleOnly) {
                        PROVIDER_PREFERENCE_GOOGLE_ONLY
                    } else {
                        PROVIDER_PREFERENCE_GOOGLE_FIRST
                    },
                    usedGooglePasswordManager = true,
                )
            } catch (error: CreateCredentialException) {
                if (googleOnly || isUserCancellation(error) || !shouldFallbackFromGoogleProvider(error)) {
                    throw error
                }
            } catch (error: SecurityException) {
                if (isUserCancellation(error) || !shouldFallbackFromAllowedProvidersSecurity(error)) {
                    throw error
                }
                // Continue to unrestricted provider set.
            }
        } else if (googleOnly) {
            error("Google Password Manager is required but not available on this device")
        }

        val response = credentialManager.createCredential(
            activity,
            createPublicKeyRequest(
                requestJson = requestJson,
                allowedProviders = emptySet(),
            ),
        )
        return CreatePasskeyOutcome(
            response = response,
            providerPreference = if (googleAvailable) {
                PROVIDER_PREFERENCE_FALLBACK_AFTER_GOOGLE
            } else {
                PROVIDER_PREFERENCE_SYSTEM_DEFAULT
            },
            usedGooglePasswordManager = false,
        )
    }

    private suspend fun getPasskeyPreferringGoogle(
        requestJson: String,
        googleOnly: Boolean,
    ): GetPasskeyOutcome {
        val googleAvailable = isGooglePasswordManagerAvailable()
        if (googleAvailable) {
            try {
                val response = credentialManager.getCredential(
                    activity,
                    getPublicKeyRequest(
                        requestJson = requestJson,
                        allowedProviders = GOOGLE_PASSWORD_MANAGER_PROVIDERS,
                    ),
                )
                return GetPasskeyOutcome(
                    credential = response.credential,
                    providerPreference = if (googleOnly) {
                        PROVIDER_PREFERENCE_GOOGLE_ONLY
                    } else {
                        PROVIDER_PREFERENCE_GOOGLE_FIRST
                    },
                    usedGooglePasswordManager = true,
                )
            } catch (error: GetCredentialException) {
                if (googleOnly || isUserCancellation(error) || !shouldFallbackFromGoogleProvider(error)) {
                    throw error
                }
            } catch (error: SecurityException) {
                // Permission/OEM denials around allowedProviders must never hard-fail login.
                if (isUserCancellation(error) || !shouldFallbackFromAllowedProvidersSecurity(error)) {
                    throw error
                }
            }
        } else if (googleOnly) {
            error("Google Password Manager is required but not available on this device")
        }

        val response = credentialManager.getCredential(
            activity,
            getPublicKeyRequest(
                requestJson = requestJson,
                allowedProviders = emptySet(),
            ),
        )
        return GetPasskeyOutcome(
            credential = response.credential,
            providerPreference = if (googleAvailable) {
                PROVIDER_PREFERENCE_FALLBACK_AFTER_GOOGLE
            } else {
                PROVIDER_PREFERENCE_SYSTEM_DEFAULT
            },
            usedGooglePasswordManager = false,
        )
    }

    private fun createPublicKeyRequest(
        requestJson: String,
        @Suppress("UNUSED_PARAMETER") allowedProviders: Set<ComponentName>,
    ): CreatePublicKeyCredentialRequest {
        // androidx.credentials 1.7.0-alpha02 CreatePublicKeyCredentialRequest does not expose
        // allowedProviders. Google-first create still runs first and falls back on failure; get
        // paths continue to pin providers via GetPublicKeyCredentialOption.allowedProviders.
        return CreatePublicKeyCredentialRequest(requestJson)
    }

    private fun getPublicKeyRequest(
        requestJson: String,
        allowedProviders: Set<ComponentName>,
    ): GetCredentialRequest {
        val option = if (allowedProviders.isEmpty()) {
            GetPublicKeyCredentialOption(requestJson)
        } else {
            GetPublicKeyCredentialOption(
                requestJson = requestJson,
                clientDataHash = null,
                allowedProviders = allowedProviders,
            )
        }
        return GetCredentialRequest(listOf(option))
    }

    private fun isGooglePasswordManagerAvailable(): Boolean =
        PasskeyProviderDiagnostics.isGooglePasswordManagerAvailable(activity)

    private fun providerDiagnosticsDetails(googleOnly: Boolean): Map<String, Any?> =
        runCatching {
            mapOf(
                "providerDiagnostics" to PasskeyProviderDiagnostics.diagnose(
                    context = activity,
                    googleOnlyPreferred = googleOnly,
                ),
            )
        }.getOrElse { error ->
            mapOf(
                "providerDiagnosticsError" to mapOf(
                    "exceptionClass" to error.javaClass.name,
                    "simpleName" to error.javaClass.simpleName,
                    "message" to error.message,
                ),
            )
        }

    private fun diagnoseProviders(call: MethodCall, result: MethodChannel.Result) {
        val googleOnly = googleOnly(call)
        result.success(
            runCatching {
                NativeResult.ok(
                    PasskeyProviderDiagnostics.diagnose(
                        context = activity,
                        googleOnlyPreferred = googleOnly,
                    ),
                )
            }.getOrElse { error ->
                NativeResult.nativeFailure(
                    error.message ?: "Failed to diagnose passkey providers",
                )
            },
        )
    }

    private fun preferredProviderMode(googleOnly: Boolean = true): String {
        return when {
            googleOnly && isGooglePasswordManagerAvailable() -> PROVIDER_PREFERENCE_GOOGLE_ONLY
            googleOnly -> PROVIDER_PREFERENCE_GOOGLE_ONLY
            isGooglePasswordManagerAvailable() -> PROVIDER_PREFERENCE_GOOGLE_FIRST
            else -> PROVIDER_PREFERENCE_SYSTEM_DEFAULT
        }
    }

    private fun shouldFallbackFromGoogleProvider(error: Throwable): Boolean {
        if (isUserCancellation(error)) return false

        val type = when (error) {
            is CreateCredentialException -> error.type
            is GetCredentialException -> error.type
            else -> null
        }?.lowercase().orEmpty()
        val name = error.javaClass.simpleName.lowercase()
        val message = (error.message ?: "").lowercase()

        return type.contains("no_create_option") ||
            type.contains("no_credential") ||
            type.contains("provider_configuration") ||
            type.contains("unsupported") ||
            type.contains("interrupted") ||
            name.contains("noprovider") ||
            name.contains("noconfig") ||
            name.contains("unsupported") ||
            message.contains("no provider") ||
            message.contains("not available") ||
            message.contains("no credentials available") ||
            message.contains("cannot find a provider")
    }

    private fun shouldFallbackFromAllowedProvidersSecurity(error: Throwable): Boolean {
        if (isUserCancellation(error)) return false
        if (error is SecurityException) return true

        val message = (error.message ?: "").lowercase()
        return message.contains("credential_manager_set_allowed_providers") ||
            message.contains("does not have android.permission.credential_manager_set_allowed_providers") ||
            message.contains("allowedproviders") ||
            message.contains("allowed providers")
    }

    private fun requestJson(call: MethodCall): String? {
        return call.argument<String>("requestJson")?.takeIf { it.isNotBlank() }
    }

    private fun googleOnly(call: MethodCall): Boolean {
        return call.argument<Boolean>("googleOnly") ?: true
    }

    private fun unsupportedAndroidVersion(): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) return null

        return NativeResult.error(
            "unsupported_android_version",
            "Passkeys require Android 9 (API 28) or higher",
            recoverable = false,
            details = mapOf(
                "sdkInt" to Build.VERSION.SDK_INT,
                "requiredSdkInt" to Build.VERSION_CODES.P,
            ),
        )
    }

    private fun unsupportedSignalAndroidVersion(): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT >= ANDROID_15_API) return null

        return NativeResult.error(
            "unsupported_android_version",
            "Credential Manager Signal API requires Android 15 (API 35) or higher",
            recoverable = false,
            details = mapOf(
                "sdkInt" to Build.VERSION.SDK_INT,
                "requiredSdkInt" to ANDROID_15_API,
            ),
        )
    }

    private fun passkeyError(
        prefix: String,
        error: Throwable,
        details: Map<String, Any?>,
    ): Map<String, Any?> {
        return NativeResult.error(
            errorCode(prefix, error),
            error.message ?: error.javaClass.simpleName,
            recoverable = isRecoverable(error),
            details = details,
        )
    }

    private fun credentialDetails(error: CreateCredentialException): Map<String, Any?> =
        throwableDetails(error) + mapOf(
            "type" to error.type,
        )

    private fun credentialDetails(error: GetCredentialException): Map<String, Any?> =
        throwableDetails(error) + mapOf(
            "type" to error.type,
        )

    private fun signalCredentialDetails(error: SignalCredentialStateException): Map<String, Any?> {
        val details = mutableMapOf<String, Any?>(
            "type" to error.type,
        )
        if (error is SignalCredentialRateLimitExceededException) {
            details["retryMillis"] = error.retryMillis
        }
        return throwableDetails(error) + details
    }

    private fun throwableDetails(error: Throwable): Map<String, Any?> =
        mapOf(
            "exceptionClass" to error.javaClass.name,
            "simpleName" to error.javaClass.simpleName,
            "message" to error.message,
            "localizedMessage" to error.localizedMessage,
            "causeClass" to error.cause?.javaClass?.name,
            "causeMessage" to error.cause?.message,
        )

    private fun errorCode(prefix: String, error: Throwable): String {
        if (isUserCancellation(error)) {
            return "user_canceled"
        }

        val name = error.javaClass.simpleName
            .removeSuffix("Exception")
            .ifBlank { "unknown" }
            .replace(Regex("([a-z0-9])([A-Z])"), "$1_$2")
            .lowercase()
        return "${prefix}_$name"
    }

    private fun isRecoverable(error: Throwable): Boolean {
        if (isUserCancellation(error)) return true
        val name = error.javaClass.simpleName.lowercase()
        return !name.contains("unsupported") && !name.contains("security")
    }

    private fun isUserCancellation(error: Throwable): Boolean {
        val simpleName = error.javaClass.simpleName.lowercase()
        if (simpleName.contains("cancellation") || simpleName.contains("canceled") ||
            simpleName.contains("cancelled")
        ) {
            return true
        }

        val type = when (error) {
            is CreateCredentialException -> error.type
            is GetCredentialException -> error.type
            else -> null
        }?.lowercase().orEmpty()

        if (type.contains("user_canceled") || type.contains("user_cancelled") ||
            type.contains("type_user_canceled")
        ) {
            return true
        }

        val message = (error.message ?: "").lowercase()
        return message.contains("user cancelled") ||
            message.contains("user canceled") ||
            message.contains("cancelled the selector") ||
            message.contains("canceled the selector")
    }

    companion object {
        private const val ANDROID_15_API = 35
        private const val PROVIDER_PREFERENCE_GOOGLE_ONLY = "google_password_manager_only"
        private const val PROVIDER_PREFERENCE_GOOGLE_FIRST = "google_password_manager_first"
        private const val PROVIDER_PREFERENCE_FALLBACK_AFTER_GOOGLE = "fallback_after_google"
        private const val PROVIDER_PREFERENCE_SYSTEM_DEFAULT = "system_default"

        // Official Google Password Manager Credential Manager provider component.
        private val GOOGLE_PASSWORD_MANAGER_PROVIDERS: Set<ComponentName> = setOf(
            PasskeyProviderDiagnostics.googlePasswordManagerComponent,
        )
    }

    private data class CreatePasskeyOutcome(
        val response: CreateCredentialResponse,
        val providerPreference: String,
        val usedGooglePasswordManager: Boolean,
    )

    private data class GetPasskeyOutcome(
        val credential: Credential,
        val providerPreference: String,
        val usedGooglePasswordManager: Boolean,
    )
}
