/// Unified app security manager.
///
/// Provides:
///   1. APK integrity check (signature TOFU — no hardcoded fingerprint in binary)
///   2. Root / jailbreak detection (honeypot mode — doesn't block, just flags)
///   3. Secure screen toggle (FLAG_SECURE on Android)
///   4. Security context accessible app-wide via [AppSecurity.instance]
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _channel = MethodChannel('com.chloemlla.nexai/security');

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  wOptions: WindowsOptions(useBackwardCompatibility: false),
);

const _sigPinKey = 'nexai.apk.signature.v1';

// ─── AppSecurity singleton ────────────────────────────────────────────────────

class AppSecurity {
  AppSecurity._();
  static final AppSecurity instance = AppSecurity._();

  /// True if device shows root/jailbreak indicators.
  /// Used for honeypot mode — requests will carry [isCompromised] flag.
  bool isCompromised = false;

  /// True if APK signature matches the first-run pinned value.
  bool isSignatureValid = true;

  /// Initialise security checks. Call once in [main] before [runApp].
  Future<void> init() async {
    if (kIsWeb) return;
    await Future.wait([_checkApkSignature(), _checkRootStatus()]);
  }

  // ── APK Signature (TOFU) ────────────────────────────────────────────────────

  Future<void> _checkApkSignature() async {
    if (!Platform.isAndroid) return;
    try {
      final current = await _channel.invokeMethod<String>(
        'getApkSignatureFingerprint',
      );
      if (current == null || current.isEmpty) return;

      final stored = await _storage.read(key: _sigPinKey);

      if (stored == null) {
        // TOFU first run — trust and pin current signature
        await _storage.write(key: _sigPinKey, value: current);
        debugPrint('AppSecurity: APK signature pinned (TOFU) ✓');
        isSignatureValid = true;
      } else if (stored != current) {
        // Mismatch → APK was repackaged / re-signed
        debugPrint('AppSecurity: ⚠️  APK SIGNATURE MISMATCH (possible repack)');
        isSignatureValid = false;
        // Strategy: set compromised flag instead of hard-exit,
        // so honeypot requests can be tracked server-side.
        isCompromised = true;
      } else {
        isSignatureValid = true;
      }
    } catch (e) {
      debugPrint('AppSecurity: signature check error: $e');
    }
  }

  /// Force-clear stored APK signature (call after legitimate app update
  /// where keystore changes — extremely rare, but supported).
  Future<void> clearSignaturePin() => _storage.delete(key: _sigPinKey);

  // ── Root / Jailbreak Detection ───────────────────────────────────────────────

  Future<void> _checkRootStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (Platform.isAndroid) {
        final rooted = await _channel.invokeMethod<bool>('isRooted') ?? false;
        if (rooted) {
          debugPrint('AppSecurity: ⚠️  Root indicators detected');
          isCompromised = true;
        }
      }
      // iOS: MethodChannel not yet wired — can extend similarly
    } catch (e) {
      debugPrint('AppSecurity: root check error: $e');
    }
  }

  // ── Secure Screen ────────────────────────────────────────────────────────────

  /// Enable/disable [FLAG_SECURE] (prevents screenshots & screen recording).
  /// Call with [enable]=true on login and settings pages.
  Future<void> setSecureScreen({required bool enable}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {'enable': enable});
    } catch (e) {
      debugPrint('AppSecurity: setSecureScreen error: $e');
    }
  }
}
