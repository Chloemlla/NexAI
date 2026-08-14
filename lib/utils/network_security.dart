/// Network security utilities: proxy/VPN detection, network environment checks.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';

import '../services/android_native/android_security_service.dart';

class NetworkSecurity {
  NetworkSecurity._();
  static final NetworkSecurity instance = NetworkSecurity._();

  /// True if proxy or VPN is detected
  bool isProxyDetected = false;
  bool isVpnDetected = false;

  /// Check network security environment
  Future<void> checkNetworkEnvironment() async {
    if (kIsWeb) return;

    await Future.wait([
      _checkProxy(),
      _checkVpn(),
    ]);
  }

  /// Detect system proxy settings
  Future<void> _checkProxy() async {
    try {
      // Check environment variables for proxy
      final httpProxy = Platform.environment['HTTP_PROXY'] ??
          Platform.environment['http_proxy'];
      final httpsProxy = Platform.environment['HTTPS_PROXY'] ??
          Platform.environment['https_proxy'];

      if (httpProxy != null || httpsProxy != null) {
        isProxyDetected = true;
        debugPrint('NetworkSecurity: Proxy detected');
        // Redact credentials before logging proxy URLs
        final redactedHttp = _redactProxyUrl(httpProxy);
        final redactedHttps = _redactProxyUrl(httpsProxy);
        debugPrint('  HTTP_PROXY: $redactedHttp');
        debugPrint('  HTTPS_PROXY: $redactedHttps');
      }
    } catch (e) {
      debugPrint('NetworkSecurity: proxy check error: $e');
    }
  }

  /// Detect VPN via Android native security snapshot (NetworkCapabilities).
  Future<void> _checkVpn() async {
    try {
      if (!Platform.isAndroid) return;
      final result = await AndroidSecurityService().getSecuritySnapshot();
      if (result.ok && result.data != null) {
        isVpnDetected = result.data!.vpnActive;
        if (isVpnDetected) {
          debugPrint('NetworkSecurity: VPN connection detected (native)');
        }
      }
    } catch (e) {
      debugPrint('NetworkSecurity: VPN check error: $e');
    }
  }

  /// Check if current network environment is high-risk
  bool get isHighRiskEnvironment => isProxyDetected || isVpnDetected;

  /// Redact userinfo (credentials) from a proxy URL for safe logging.
  static String? _redactProxyUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.userInfo.isEmpty) return url;
    return url.replaceFirst('${uri.userInfo}@', '***@');
  }
}
