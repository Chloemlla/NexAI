/// Network security utilities: proxy/VPN detection, network environment checks.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';

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
        debugPrint('  HTTP_PROXY: $httpProxy');
        debugPrint('  HTTPS_PROXY: $httpsProxy');
      }
    } catch (e) {
      debugPrint('NetworkSecurity: proxy check error: $e');
    }
  }

  /// Detect VPN connection (Android/iOS specific checks via platform channel)
  Future<void> _checkVpn() async {
    try {
      if (Platform.isAndroid) {
        // VPN detection will be implemented via MethodChannel
        // For now, we'll add a placeholder
        // TODO: Add Android VPN detection via NetworkCapabilities
      }
    } catch (e) {
      debugPrint('NetworkSecurity: VPN check error: $e');
    }
  }

  /// Check if current network environment is high-risk
  bool get isHighRiskEnvironment => isProxyDetected || isVpnDetected;
}
