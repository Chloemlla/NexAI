/// Device fingerprint generator using aggressive multi-dimensional approach.
///
/// Generates a permanent, unique device identifier by combining:
/// - Hardware characteristics (CPU, sensors, screen, battery, camera)
/// - Software characteristics (installed apps, system properties, fonts)
/// - Storage characteristics (partition info, file system)
/// - Sensor noise fingerprinting (accelerometer, gyroscope patterns)
///
/// WARNING: This implementation prioritizes uniqueness over performance.
library;

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _channel = MethodChannel('com.chloemlla.nexai/security');

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  wOptions: WindowsOptions(useBackwardCompatibility: false),
);

const _fingerprintKey = 'nexai.device.fingerprint.v1';

class DeviceFingerprint {
  DeviceFingerprint._();
  static final DeviceFingerprint instance = DeviceFingerprint._();

  String? _cachedFingerprint;

  /// Get or generate device fingerprint
  Future<String> getFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;

    // Try to load from secure storage
    final stored = await _storage.read(key: _fingerprintKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedFingerprint = stored;
      return stored;
    }

    // Generate new fingerprint
    final fingerprint = await _generateFingerprint();
    await _storage.write(key: _fingerprintKey, value: fingerprint);
    _cachedFingerprint = fingerprint;

    return fingerprint;
  }

  /// Generate comprehensive device fingerprint
  Future<String> _generateFingerprint() async {
    final components = <String, dynamic>{};

    // Layer 1: Basic device info
    components['basic'] = await _getBasicInfo();

    // Layer 2: Hardware characteristics
    components['hardware'] = await _getHardwareInfo();

    // Layer 3: Software characteristics
    components['software'] = await _getSoftwareInfo();

    // Layer 4: Storage characteristics
    components['storage'] = await _getStorageInfo();

    // Layer 5: Sensor fingerprinting
    components['sensors'] = await _getSensorFingerprint();

    // Layer 6: Network characteristics
    components['network'] = await _getNetworkInfo();

    // Layer 7: System properties (Android)
    if (Platform.isAndroid) {
      components['system'] = await _getSystemProperties();
    }

    // Combine all components and hash
    final combined = json.encode(components);
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Layer 1: Basic device information
  Future<Map<String, dynamic>> _getBasicInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return {
        'brand': info.brand,
        'device': info.device,
        'model': info.model,
        'product': info.product,
        'hardware': info.hardware,
        'manufacturer': info.manufacturer,
        'board': info.board,
        'bootloader': info.bootloader,
        'fingerprint': info.fingerprint,
        'id': info.id,
        'display': info.display,
        'tags': info.tags,
        'type': info.type,
        'androidId': info.id, // Unique to device + user
      };
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      return {
        'computerName': info.computerName,
        'numberOfCores': info.numberOfCores,
        'systemMemoryInMegabytes': info.systemMemoryInMegabytes,
      };
    }

    return {};
  }

  /// Layer 2: Hardware characteristics
  Future<Map<String, dynamic>> _getHardwareInfo() async {
    if (!Platform.isAndroid) return {};

    try {
      final hardware = await _channel.invokeMethod<Map>('getHardwareInfo');
      return Map<String, dynamic>.from(hardware ?? {});
    } catch (e) {
      debugPrint('DeviceFingerprint: hardware info error: $e');
      return {};
    }
  }

  /// Layer 3: Software characteristics
  Future<Map<String, dynamic>> _getSoftwareInfo() async {
    if (!Platform.isAndroid) return {};

    try {
      final software = await _channel.invokeMethod<Map>('getSoftwareInfo');
      return Map<String, dynamic>.from(software ?? {});
    } catch (e) {
      debugPrint('DeviceFingerprint: software info error: $e');
      return {};
    }
  }

  /// Layer 4: Storage characteristics
  Future<Map<String, dynamic>> _getStorageInfo() async {
    if (!Platform.isAndroid) return {};

    try {
      final storage = await _channel.invokeMethod<Map>('getStorageInfo');
      return Map<String, dynamic>.from(storage ?? {});
    } catch (e) {
      debugPrint('DeviceFingerprint: storage info error: $e');
      return {};
    }
  }

  /// Layer 5: Sensor fingerprinting (unique noise patterns)
  Future<Map<String, dynamic>> _getSensorFingerprint() async {
    if (!Platform.isAndroid) return {};

    try {
      final sensors = await _channel.invokeMethod<Map>('getSensorFingerprint');
      return Map<String, dynamic>.from(sensors ?? {});
    } catch (e) {
      debugPrint('DeviceFingerprint: sensor fingerprint error: $e');
      return {};
    }
  }

  /// Layer 6: Network characteristics
  Future<Map<String, dynamic>> _getNetworkInfo() async {
    if (!Platform.isAndroid) return {};

    try {
      final network = await _channel.invokeMethod<Map>('getNetworkInfo');
      return Map<String, dynamic>.from(network ?? {});
    } catch (e) {
      debugPrint('DeviceFingerprint: network info error: $e');
      return {};
    }
  }

  /// Layer 7: System properties (Android Build.PROP)
  Future<Map<String, dynamic>> _getSystemProperties() async {
    try {
      final props = await _channel.invokeMethod<Map>('getSystemProperties');
      return Map<String, dynamic>.from(props ?? {});
    } catch (e) {
      debugPrint('DeviceFingerprint: system properties error: $e');
      return {};
    }
  }

  /// Force regenerate fingerprint (for testing)
  Future<void> regenerate() async {
    await _storage.delete(key: _fingerprintKey);
    _cachedFingerprint = null;
    await getFingerprint();
  }
}
