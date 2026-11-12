/// NexAI 官方客户端身份（发给 Synapse 的设备/客户端标识）。
///
/// Synapse 的 `authSessionService.getAuthSessionMetadata()` 用这套头决定一条登录会话属于
/// 谁（`x-client-name` → `x-synapse-client-name` → `x-client`…，设备侧读
/// `x-device-id` / `x-device-name` / `x-platform`）。NexAI 之前一个都不带，于是「设备与会话」
/// 里只剩一串按 User-Agent 反推的 `other`，撤销时也认不出是哪台机器。
///
/// 词表与 Project-Lumen / Synapse-Client 保持同一套写法（客户端名、平台首字母大写、
/// 设备名 `品牌 型号`），这样后台面板里三端看起来是一类东西。
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../utils/request_signer.dart' show deviceFingerprintHex;

class NexaiClientIdentity {
  NexaiClientIdentity._();

  static const String clientName = 'NexAI';

  static String? _cachedDeviceId;
  static String? _cachedDeviceName;
  static Future<Map<String, String>>? _inflight;

  /// 设备标识＝首访闸门用的指纹（同一条 sha256 hex、稳定跨重启）。
  ///
  /// 两处必须同源：令牌绑定的是 (指纹, IP)，设备分组用的是同一个 id；各算一份会让
  /// 「过了闸门的设备」和「会话里的设备」对不上。
  static Future<String> deviceId() async {
    final cached = _cachedDeviceId;
    if (cached != null && cached.isNotEmpty) return cached;
    final resolved = await deviceFingerprintHex();
    _cachedDeviceId = resolved;
    return resolved;
  }

  static String get platformLabel {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return Platform.operatingSystem;
  }

  static Future<String> deviceName() async {
    final cached = _cachedDeviceName;
    if (cached != null && cached.isNotEmpty) return cached;
    final resolved = await _resolveDeviceName();
    _cachedDeviceName = resolved;
    return resolved;
  }

  /// 身份头。取不到设备信息时退化成「客户端名 + 平台」，绝不发空串：
  /// 空的 `X-Device-Id` 会被后端当成一台真实存在的空设备。
  static Future<Map<String, String>> headers() {
    return _inflight ??= _buildHeaders().whenComplete(() => _inflight = null);
  }

  static Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'X-Client-Name': clientName,
      'X-Platform': platformLabel,
    };
    final name = await _safe(deviceName);
    if (name != null && name.isNotEmpty) headers['X-Device-Name'] = name;
    final id = await _safe(deviceId);
    if (id != null && id.isNotEmpty) headers['X-Device-Id'] = id;
    return headers;
  }

  static Future<String> _resolveDeviceName() async {
    if (kIsWeb) return 'Web browser';
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return '${info.manufacturer} ${info.model}'.trim();
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return '${info.name} (${info.utsname.machine})'.trim();
      }
      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return info.computerName.trim();
      }
      if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        return info.computerName.trim();
      }
      if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        return (info.prettyName).trim();
      }
    } catch (_) {
      // 取不到就走下面的兜底。
    }
    return platformLabel;
  }

  static Future<T?> _safe<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (_) {
      return null;
    }
  }
}
