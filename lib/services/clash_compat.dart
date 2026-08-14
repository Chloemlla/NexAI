import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

/// Android ClashMeta VPN auto-adapt bridge for NexAI.
abstract final class ClashCompat {
  static const MethodChannel _method =
      MethodChannel('com.chloemlla.nexai/clash_compat');
  static const EventChannel _events =
      EventChannel('com.chloemlla.nexai/clash_compat_events');

  static StreamSubscription<dynamic>? _sub;
  static bool clashInstalled = false;
  static bool vpnActive = false;
  static bool clashVpnRunning = false;
  static bool partnerAppAutoAdapt = true;
  static bool partnerStatusAvailable = false;
  static bool processBound = false;
  static bool autoAdaptEnabled = true;
  static String? profileName;
  static String? clashPackage;

  /// True when Clash VPN path should own traffic (skip manual HTTP proxy).
  ///
  /// Prefer the StatusProvider result when available so a non-Clash VPN is not
  /// treated as "Clash routing".
  static bool get isClashVpnRouting {
    if (!Platform.isAndroid) return false;
    if (partnerStatusAvailable) return clashVpnRunning;
    return clashInstalled && vpnActive;
  }

  /// When true, force app HTTP stacks to DIRECT and rely on VPN process binding.
  static bool get shouldBypassAppProxy =>
      Platform.isAndroid && autoAdaptEnabled && isClashVpnRouting;

  static final StreamController<void> _statusChanged =
      StreamController<void>.broadcast();
  static Stream<void> get onStatusChanged => _statusChanged.stream;

  static Future<void> ensureStarted() async {
    if (!Platform.isAndroid) return;
    // Subscribe first so native network watch + binding stay live, then snapshot.
    _sub ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) {
        if (kDebugMode) debugPrint('ClashCompat event error: $e');
      },
    );
    await refresh();
  }

  static Future<void> refresh() async {
    if (!Platform.isAndroid) return;
    try {
      final raw = await _method.invokeMethod<dynamic>('getStatus');
      if (raw is Map) {
        _applyMap(Map<Object?, Object?>.from(raw));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ClashCompat.refresh: $e');
    }
  }

  /// Push the user toggle to native SharedPreferences and re-apply binding.
  static Future<void> setAutoAdaptEnabled(bool enabled) async {
    if (!Platform.isAndroid) {
      autoAdaptEnabled = enabled;
      return;
    }
    try {
      final raw = await _method.invokeMethod<dynamic>(
        'setAutoAdaptEnabled',
        <String, dynamic>{'enabled': enabled},
      );
      if (raw is Map) {
        _applyMap(Map<Object?, Object?>.from(raw));
      } else {
        autoAdaptEnabled = enabled;
      }
      if (!_statusChanged.isClosed) {
        _statusChanged.add(null);
      }
    } catch (e) {
      autoAdaptEnabled = enabled;
      if (kDebugMode) debugPrint('ClashCompat.setAutoAdaptEnabled: $e');
    }
  }

  static void _onEvent(dynamic event) {
    if (event is Map) {
      _applyMap(Map<Object?, Object?>.from(event));
      if (!_statusChanged.isClosed) {
        _statusChanged.add(null);
      }
    }
  }

  static void _applyMap(Map<Object?, Object?> map) {
    // Read all values first using safe casts to avoid mid-assignment TypeError
    // leaving static fields inconsistent.
    final newClashInstalled = map['clashInstalled'] == true;
    final newVpnActive = map['vpnActive'] == true;
    final newClashVpnRunning = map['clashVpnRunning'] == true;
    final newPartnerAppAutoAdapt = map['partnerAppAutoAdapt'] != false;
    final newPartnerStatusAvailable = map['partnerStatusAvailable'] == true;
    final newProcessBound = map['processBound'] == true;
    final newAutoAdaptEnabled = map['autoAdaptEnabled'] != false;
    final newProfileName = map['profileName'] as String?;
    final newClashPackage = map['clashPackage'] as String?;

    clashInstalled = newClashInstalled;
    vpnActive = newVpnActive;
    clashVpnRunning = newClashVpnRunning;
    partnerAppAutoAdapt = newPartnerAppAutoAdapt;
    partnerStatusAvailable = newPartnerStatusAvailable;
    processBound = newProcessBound;
    autoAdaptEnabled = newAutoAdaptEnabled;
    profileName = newProfileName;
    clashPackage = newClashPackage;
  }

  static String statusLabel({required bool autoAdaptEnabled}) {
    if (!Platform.isAndroid) return '仅 Android 支持';
    if (!autoAdaptEnabled) return '已关闭自动适配';
    if (!clashInstalled) return '未检测到 Clash Meta';
    if (isClashVpnRouting) {
      final profile = profileName;
      if (profile != null && profile.isNotEmpty) {
        return 'VPN 已连接 · $profile';
      }
      return 'VPN 已连接 · 流量自动经 Clash';
    }
    return '已安装 Clash · 等待开启 VPN';
  }
}
