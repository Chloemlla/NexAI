package com.chloemlla.nexai.channels

import android.os.Build
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
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
            else -> result.notImplemented()
        }
    }

    private fun register(call: MethodCall, result: MethodChannel.Result) {
        unsupportedAndroidVersion()?.let {
            return result.success(it)
        }

        val requestJson = requestJson(call)
            ?: return result.success(NativeResult.invalidArgument("requestJson is required"))

        scope.launch {
            try {
                val request = CreatePublicKeyCredentialRequest(
                    requestJson = requestJson,
                    preferImmediatelyAvailableCredentials = false,
                )
                val response = credentialManager.createCredential(activity, request)
                if (response is CreatePublicKeyCredentialResponse) {
                    result.success(
                        NativeResult.ok(
                            mapOf(
                                "responseJson" to response.registrationResponseJson,
                                "responseType" to response.javaClass.name,
                                "credentialManagerApi" to "createCredential",
                            ),
                        ),
                    )
                } else {
                    result.success(
                        NativeResult.error(
                            "unexpected_create_response",
                            "Credential Manager returned ${response.javaClass.name}",
                            recoverable = false,
                            details = mapOf("responseType" to response.javaClass.name),
                        ),
                    )
                }
            } catch (error: CreateCredentialException) {
                result.success(passkeyError("create_credential", error, credentialDetails(error)))
            } catch (error: IllegalArgumentException) {
                result.success(
                    NativeResult.invalidArgument(
                        error.message ?: "Invalid passkey registration requestJson",
                    ),
                )
            } catch (error: Exception) {
                result.success(passkeyError("native_failure", error, throwableDetails(error)))
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

        scope.launch {
            try {
                val option = GetPublicKeyCredentialOption(
                    requestJson = requestJson,
                )
                val request = GetCredentialRequest(
                    listOf(option),
                    preferImmediatelyAvailableCredentials = false,
                )
                val response = credentialManager.getCredential(activity, request)
                val credential = response.credential
                if (credential is PublicKeyCredential) {
                    result.success(
                        NativeResult.ok(
                            mapOf(
                                "responseJson" to credential.authenticationResponseJson,
                                "credentialType" to credential.type,
                                "credentialManagerApi" to "getCredential",
                            ),
                        ),
                    )
                } else {
                    result.success(
                        NativeResult.error(
                            "unexpected_get_credential",
                            "Credential Manager returned ${credential.javaClass.name}",
                            recoverable = false,
                            details = mapOf("credentialType" to credential.javaClass.name),
                        ),
                    )
                }
            } catch (error: GetCredentialException) {
                result.success(passkeyError("get_credential", error, credentialDetails(error)))
            } catch (error: IllegalArgumentException) {
                result.success(
                    NativeResult.invalidArgument(
                        error.message ?: "Invalid passkey authentication requestJson",
                    ),
                )
            } catch (error: Exception) {
                result.success(passkeyError("native_failure", error, throwableDetails(error)))
            }
        }
    }

    private fun requestJson(call: MethodCall): String? {
        return call.argument<String>("requestJson")?.takeIf { it.isNotBlank() }
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
        val name = error.javaClass.simpleName
            .removeSuffix("Exception")
            .ifBlank { "unknown" }
            .replace(Regex("([a-z0-9])([A-Z])"), "$1_$2")
            .lowercase()
        return "${prefix}_$name"
    }

    private fun isRecoverable(error: Throwable): Boolean {
        val name = error.javaClass.simpleName.lowercase()
        return !name.contains("unsupported") && !name.contains("security")
    }

    companion object {
        private const val ANDROID_15_API = 35
    }
}
