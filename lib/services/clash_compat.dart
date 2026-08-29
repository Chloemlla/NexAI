import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

/// CMFA 授予的 `partnerStatus` 读取层级，对应 provider 的 `accessTier`。
enum ClashAccess { unavailable, denied, basic, full }

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

  /// CMFA 授予的 `partnerStatus` 读取层级（Android 才有意义）。
  static ClashAccess partnerAccess = ClashAccess.unavailable;
  static String? partnerDeniedReason;

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
    final newPartnerAccess = _parseAccess(map['partnerAccess'] as String?);
    final newPartnerDeniedReason = map['partnerDeniedReason'] as String?;

    clashInstalled = newClashInstalled;
    vpnActive = newVpnActive;
    clashVpnRunning = newClashVpnRunning;
    partnerAppAutoAdapt = newPartnerAppAutoAdapt;
    partnerStatusAvailable = newPartnerStatusAvailable;
    processBound = newProcessBound;
    autoAdaptEnabled = newAutoAdaptEnabled;
    profileName = newProfileName;
    clashPackage = newClashPackage;
    partnerAccess = newPartnerAccess;
    partnerDeniedReason = newPartnerDeniedReason;
  }

  static ClashAccess _parseAccess(String? raw) => switch (raw) {
    'denied' => ClashAccess.denied,
    'basic' => ClashAccess.basic,
    'full' => ClashAccess.full,
    _ => ClashAccess.unavailable,
  };

  /// 把 CMFA 的机器可读 `deniedReason` 翻成用户能照着做的一句中文。
  static String describeDeniedReason(String? reason) => switch (reason) {
    'pending_user_approval' => '等待在 Clash 中确认配对：打开 Clash 主页或点击配对通知即可授权',
    'denied_by_user' => '已在 Clash 中拒绝授权，可在 Clash 主页「伙伴应用」里撤销',
    'signer_unverified' => 'Clash 未登记 NexAI 的签名证书，只开放基础状态；在「伙伴应用」里允许即可读取完整状态',
    'not_partner' => 'Clash 没把 NexAI 认成伙伴应用，请更新 Clash 到支持伙伴配对的版本',
    'no_signature' => 'Clash 读不到 NexAI 的签名信息，无法完成配对',
    null => 'Clash 未说明原因',
    _ => 'Clash 返回原因：$reason',
  };

  static String statusLabel({required bool autoAdaptEnabled}) {
    if (!Platform.isAndroid) return '仅 Android 支持';
    if (!autoAdaptEnabled) return '已关闭自动适配';
    if (!clashInstalled) return '未检测到 Clash Meta';
    if (partnerAccess == ClashAccess.denied) {
      return '读不到 Clash 状态 · ${describeDeniedReason(partnerDeniedReason)}';
    }
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
