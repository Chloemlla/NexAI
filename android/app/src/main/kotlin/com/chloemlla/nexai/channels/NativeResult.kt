package com.chloemlla.nexai.channels

object NativeResult {
    fun ok(data: Any? = null): Map<String, Any?> = mapOf(
        "ok" to true,
        "data" to data,
        "error" to null,
    )

    fun error(
        code: String,
        message: String,
        recoverable: Boolean = true,
    ): Map<String, Any?> = mapOf(
        "ok" to false,
        "data" to null,
        "error" to mapOf(
            "code" to code,
            "message" to message,
            "recoverable" to recoverable,
        ),
    )

    fun unsupported(message: String = "Android native capability is not supported"): Map<String, Any?> =
        error("unsupported_android_version", message)

    fun invalidArgument(message: String): Map<String, Any?> =
        error("invalid_argument", message)

    fun nativeFailure(message: String): Map<String, Any?> =
        error("native_failure", message)
}
