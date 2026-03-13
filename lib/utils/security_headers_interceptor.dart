/// Dio interceptor that automatically adds security headers to all requests.
///
/// Headers added:
/// - X-Device-Fingerprint: Unique device identifier
/// - X-Device-Risk-Score: Risk score (0-100)
/// - X-Device-Risk-Level: Risk level (SAFE/LOW/MEDIUM/HIGH/CRITICAL)
/// - X-Device-Compromised: 1 if device is compromised, 0 otherwise
/// - X-Device-Root: 1 if rooted, 0 otherwise
/// - X-Device-Debugger: 1 if debugger attached, 0 otherwise
/// - X-Device-Emulator: 1 if running on emulator, 0 otherwise
/// - X-Device-VPN: 1 if VPN active, 0 otherwise
/// - X-App-Version: App version
/// - X-App-Build: Build number
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_security.dart';
import '../utils/device_fingerprint.dart';

class SecurityHeadersInterceptor extends Interceptor {
  String? _cachedFingerprint;
  String? _cachedVersion;
  String? _cachedBuildNumber;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Get device fingerprint (cached after first call)
      _cachedFingerprint ??= await DeviceFingerprint.instance.getFingerprint();

      // Get app version (cached)
      if (_cachedVersion == null || _cachedBuildNumber == null) {
        final packageInfo = await PackageInfo.fromPlatform();
        _cachedVersion = packageInfo.version;
        _cachedBuildNumber = packageInfo.buildNumber;
      }

      final security = AppSecurity.instance;

      // Add security headers
      options.headers['X-Device-Fingerprint'] = _cachedFingerprint;
      options.headers['X-Device-Risk-Score'] = security.riskScore.toString();
      options.headers['X-Device-Risk-Level'] = security.riskLevel;
      options.headers['X-Device-Compromised'] = security.isCompromised ? '1' : '0';
      options.headers['X-Device-Root'] = security.isCompromised ? '1' : '0';
      options.headers['X-Device-Debugger'] = security.isDebuggerAttached ? '1' : '0';
      options.headers['X-Device-Emulator'] = security.isEmulator ? '1' : '0';
      options.headers['X-Device-VPN'] = security.isVpnActive ? '1' : '0';
      options.headers['X-Device-Signature-Valid'] = security.isSignatureValid ? '1' : '0';
      options.headers['X-Device-Hash-Valid'] = security.isApkHashValid ? '1' : '0';
      options.headers['X-App-Version'] = _cachedVersion;
      options.headers['X-App-Build'] = _cachedBuildNumber;

      debugPrint('SecurityHeaders: Added security headers to ${options.uri}');
      debugPrint('  Fingerprint: ${_cachedFingerprint?.substring(0, 16)}...');
      debugPrint('  Risk: ${security.riskLevel} (${security.riskScore})');
    } catch (e) {
      debugPrint('SecurityHeaders: Error adding headers: $e');
    }

    handler.next(options);
  }
}

/// Helper to create Dio instance with security headers
Dio createSecureDio({BaseOptions? options}) {
  final dio = Dio(options);
  dio.interceptors.add(SecurityHeadersInterceptor());
  return dio;
}
