package com.chloemlla.nexai.channels

import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.edit
import androidx.core.content.getSystemService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Detect ClashMeta install/VPN state for zero-config traffic adaptation.
 *
 * When auto-adapt is enabled and Clash is routing, binds this process to the
 * active VPN network so traffic cannot escape the tunnel via app-level proxy
 * stacks or allowBypass paths.
 */
internal class ClashCompatChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var lastVpnActive: Boolean? = null
    private var lastVpnNetwork: Network? = null
    private var boundVpnNetwork: Network? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        stopNetworkWatch()
        clearProcessNetworkBinding()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        lastVpnActive = null
        lastVpnNetwork = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getStatus" -> {
                    startNetworkWatch()
                    result.success(buildStatus())
                }
                "setAutoAdaptEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    setAutoAdaptEnabled(enabled)
                    // Ensure network watch is active so handle replace rebinds
                    // even if Flutter events were not yet subscribed.
                    startNetworkWatch()
                    result.success(buildStatus())
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("clash_compat_error", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startNetworkWatch()
        emitStatus()
    }

    override fun onCancel(arguments: Any?) {
        // Keep network watch + process binding alive even if Flutter cancels
        // the event stream; only dispose() tears them down.
        eventSink = null
    }

    private fun buildStatus(): Map<String, Any?> {
        val clashInstalled = isClashInstalled()
        val vpnActive = isVpnActive()
        val partner = queryPartnerStatus()
        val partnerStatusAvailable = partner != null
        val clashVpnRunning =
            if (partnerStatusAvailable) {
                partner?.get("vpnRunning") as? Boolean ?: false
            } else {
                clashInstalled && vpnActive
            }
        val partnerAppAutoAdapt = partner?.get("partnerAppAutoAdapt") as? Boolean
            ?: partner?.get("piliPlusAutoAdapt") as? Boolean
            ?: true
        val autoAdaptEnabled = isAutoAdaptEnabled()
        val isClashVpnRouting =
            if (partnerStatusAvailable) {
                clashVpnRunning
            } else {
                clashInstalled && vpnActive
            }

        applyVpnProcessBinding(autoAdaptEnabled = autoAdaptEnabled, routing = isClashVpnRouting)

        return mapOf(
            "clashInstalled" to clashInstalled,
            "vpnActive" to vpnActive,
            "clashVpnRunning" to clashVpnRunning,
            "partnerAppAutoAdapt" to partnerAppAutoAdapt,
            "partnerStatusAvailable" to partnerStatusAvailable,
            "profileName" to partner?.get("name"),
            "clashPackage" to partner?.get("package"),
            "processBound" to (boundVpnNetwork != null),
            "autoAdaptEnabled" to autoAdaptEnabled,
        )
    }

    private fun emitStatus() {
        // Always recompute so process binding tracks VPN handle replacement
        // even when no Flutter listener is attached yet.
        val status = buildStatus()
        val sink = eventSink ?: return
        mainHandler.post { sink.success(status) }
    }

    private fun startNetworkWatch() {
        if (networkCallback != null) return
        val cm = context.getSystemService<ConnectivityManager>() ?: return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = onNetworkMaybeChanged()
            override fun onLost(network: Network) = onNetworkMaybeChanged()
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities,
            ) = onNetworkMaybeChanged()
        }
        networkCallback = callback
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_VPN)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        runCatching { cm.registerNetworkCallback(request, callback) }
            .onFailure {
                runCatching {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        cm.registerDefaultNetworkCallback(callback)
                    }
                }
            }
    }

    private fun stopNetworkWatch() {
        val callback = networkCallback ?: return
        networkCallback = null
        val cm = context.getSystemService<ConnectivityManager>() ?: return
        runCatching { cm.unregisterNetworkCallback(callback) }
    }

    private fun onNetworkMaybeChanged() {
        val cm = context.getSystemService<ConnectivityManager>()
        val vpnActive = isVpnActive()
        val vpnNetwork = cm?.let { findVpnNetwork(it) }
        // Re-evaluate when VPN goes up/down *or* the Network handle is replaced
        // (Clash restart / re-establish) so process binding follows.
        if (lastVpnActive == vpnActive && lastVpnNetwork == vpnNetwork) return
        lastVpnActive = vpnActive
        lastVpnNetwork = vpnNetwork
        emitStatus()
    }

    private fun isVpnActive(): Boolean {
        val cm = context.getSystemService<ConnectivityManager>() ?: return false
        for (network in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return true
        }
        return false
    }

    private fun isClashInstalled(): Boolean {
        val pm = context.packageManager
        return CLASH_PACKAGES.any { pkg ->
            try {
                pm.getApplicationInfo(pkg, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    private fun queryPartnerStatus(): Map<String, Any?>? {
        val resolver = context.contentResolver
        for (pkg in CLASH_PACKAGES) {
            val uri = Uri.Builder().scheme("content").authority("$pkg.status").build()
            val bundle = runCatching {
                resolver.call(uri, METHOD_PARTNER_STATUS, null, null)
            }.getOrNull() ?: continue
            return mapOf(
                "running" to bundle.getBoolean("running", false),
                "vpnRunning" to bundle.getBoolean("vpnRunning", false),
                "partnerAppAutoAdapt" to bundle.getBoolean(
                    "partnerAppAutoAdapt",
                    bundle.getBoolean("piliPlusAutoAdapt", true),
                ),
                "piliPlusAutoAdapt" to bundle.getBoolean("piliPlusAutoAdapt", true),
                "name" to bundle.getString("name"),
                "package" to (bundle.getString("package") ?: pkg),
            )
        }
        return null
    }

    private fun prefs(): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun isAutoAdaptEnabled(): Boolean =
        prefs().getBoolean(KEY_AUTO_ADAPT, true)

    private fun setAutoAdaptEnabled(enabled: Boolean) {
        prefs().edit { putBoolean(KEY_AUTO_ADAPT, enabled) }
    }

    /**
     * Bind (or unbind) this process to the active VPN network while Clash is
     * routing. Without this, [NetworkCapabilities.NET_CAPABILITY_NOT_VPN]
     * requests and VpnService.allowBypass can let Dart/HttpClient leave the
     * tunnel even though Clash is "on".
     */
    private fun applyVpnProcessBinding(autoAdaptEnabled: Boolean, routing: Boolean) {
        val cm = context.getSystemService<ConnectivityManager>() ?: return
        if (!autoAdaptEnabled || !routing) {
            clearProcessNetworkBinding(cm)
            return
        }
        val vpn = findVpnNetwork(cm)
        if (vpn == null) {
            // Status says routing but no VPN Network is visible yet — drop any
            // stale binding so we do not stick to a dead Network handle.
            clearProcessNetworkBinding(cm)
            return
        }
        if (boundVpnNetwork == vpn) return
        runCatching {
            cm.bindProcessToNetwork(vpn)
            boundVpnNetwork = vpn
        }.onFailure {
            boundVpnNetwork = null
        }
    }

    private fun clearProcessNetworkBinding(cm: ConnectivityManager? = null) {
        val connectivity = cm ?: context.getSystemService<ConnectivityManager>() ?: return
        if (boundVpnNetwork == null && connectivity.boundNetworkForProcess == null) return
        runCatching { connectivity.bindProcessToNetwork(null) }
        boundVpnNetwork = null
    }

    private fun findVpnNetwork(cm: ConnectivityManager): Network? {
        for (network in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                return network
            }
        }
        return null
    }

    companion object {
        const val METHOD_CHANNEL = "com.chloemlla.nexai/clash_compat"
        const val EVENT_CHANNEL = "com.chloemlla.nexai/clash_compat_events"
        private const val METHOD_PARTNER_STATUS = "partnerStatus"
        private const val PREFS = "clash_partner_compat"
        private const val KEY_AUTO_ADAPT = "clash_auto_adapt"

        /** Official MetaCubeX packages only. */
        private val CLASH_PACKAGES = listOf(
            "com.github.metacubex.clash",
            "com.github.metacubex.clash.meta",
            "com.github.metacubex.clash.alpha",
        )
    }
}
