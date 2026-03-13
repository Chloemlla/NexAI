/// Certificate pinning for api.951100.xyz using TOFU + FlutterSecureStorage.
///
/// Lifecycle:
///   First run      → system CA verifies TLS; stores cert fingerprint + expiry
///                    in FlutterSecureStorage (Android Keystore / Win Credential).
///   Subsequent     → SecurityContext(withTrustedRoots:false) enforces pinning.
///   Expiry check   → On every [buildPinnedHttpClient] call:
///                      · Expired pin  → clear & TOFU-re-pin automatically.
///                      · ≤14 days left→ background re-pin probe (silent renewal).
///   Rotation guard → If the server rotates before the old cert expires,
///                    call [clearCertPin] from a safe admin path to force TOFU.
///
/// APK contains NO plaintext fingerprint — pin lives only in secure storage.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const String _pinnedHost = 'api.951100.xyz';

/// Storage keys
const String _pinKey = 'nexai.cert.sha256.v1';
const String _pinExpiryKey = 'nexai.cert.expiry.v1'; // ISO-8601 DateTime
const String _backupPin1Key = 'nexai.cert.backup1.v1';
const String _backupPin2Key = 'nexai.cert.backup2.v1';

/// Start background re-pin this many days before expiry.
const int _renewWithinDays = 30; // Increased from 14 to 30 days

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  wOptions: WindowsOptions(useBackwardCompatibility: false),
);

// ─── Public API ───────────────────────────────────────────────────────────────

/// Returns a certificate-pinned [http.Client] for [_pinnedHost].
///
/// Decision tree (called on each [NexaiAuthApi] lazy init or app restart):
/// ```
///  stored pin?
///    no  → TOFU mode (first run)
///    yes → check expiry
///            expired?  → clear + TOFU (re-pin to new cert automatically)
///            ≤14 days? → strict mode + background re-pin probe
///            else      → strict mode
/// ```
Future<http.Client> buildPinnedHttpClient() async {
  if (kIsWeb) return http.Client(); // Web: dart:io unavailable

  final stored = await _storage.read(key: _pinKey);

  if (stored == null) {
    debugPrint('NexAI Pinning: no stored pin → TOFU mode');
    return _ToFuClient();
  }

  // ── Expiry check ──────────────────────────────────────────────────────────
  final expiryStr = await _storage.read(key: _pinExpiryKey);
  if (expiryStr != null) {
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry != null) {
      final now = DateTime.now();

      if (now.isAfter(expiry)) {
        // Cert expired → auto-clear pin and TOFU-re-pin to whatever is current
        debugPrint(
          'NexAI Pinning: stored cert EXPIRED (${expiry.toIso8601String()}) → re-entering TOFU',
        );
        await _clearPin();
        return _ToFuClient();
      }

      final daysLeft = expiry.difference(now).inDays;
      if (daysLeft <= _renewWithinDays) {
        debugPrint(
          'NexAI Pinning: cert expires in $daysLeft day(s) — background re-pin started',
        );
        // Fire-and-forget: silently update pin so next restart uses new cert
        _probeAndPin(_pinnedHost, 443).ignore();
      } else {
        debugPrint(
          'NexAI Pinning: strict mode active (expires in $daysLeft days)',
        );
      }
    }
  }

  return _PinnedClient(stored);
}

/// Force-clears the stored pin. Call before intentional certificate rotation
/// or after a failed connection due to a legitimate cert change.
Future<void> clearCertPin() => _clearPin();

// ─── TOFU Client ─────────────────────────────────────────────────────────────

class _ToFuClient extends http.BaseClient {
  final IOClient _inner = IOClient(
    HttpClient()..badCertificateCallback = (_, __, ___) => false,
  );
  bool _probeStarted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final resp = await _inner.send(request);
    if (!_probeStarted && request.url.host == _pinnedHost) {
      _probeStarted = true;
      final port = request.url.hasPort ? request.url.port : 443;
      _probeAndPin(_pinnedHost, port).ignore();
    }
    return resp;
  }

  @override
  void close() => _inner.close();
}

// ─── Strict Pinned Client ─────────────────────────────────────────────────────

class _PinnedClient extends http.BaseClient {
  late final IOClient _inner;

  _PinnedClient(String expectedFp) {
    // withTrustedRoots:false → every cert becomes "untrusted" → callback fires
    // for ALL certs (including valid public-CA certs), enabling fingerprint check.
    final ctx = SecurityContext(withTrustedRoots: false);
    _inner = IOClient(
      HttpClient(context: ctx)
        ..badCertificateCallback = (X509Certificate cert, String host, int _) {
          if (host != _pinnedHost) return false;
          final actual = _sha256Hex(cert.der);

          // Check primary pin
          if (_timingSafeEq(actual, expectedFp)) return true;

          // Check backup pins (synchronous read from cache)
          final ok = _checkBackupPins(actual);
          if (!ok) {
            debugPrint(
              'NexAI Pinning: ⚠️  CERT MISMATCH at $host\n'
              '  stored : $expectedFp\n'
              '  current: $actual\n'
              '  → connection rejected (possible MITM or unannounced rotation)',
            );
          }
          return ok;
        },
    );
  }

  bool _checkBackupPins(String actual) {
    // Note: This is a simplified check. In production, you'd cache backup pins
    // during initialization to avoid async operations in the callback.
    // For now, we'll enhance this in the next iteration.
    return false;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest req) => _inner.send(req);

  @override
  void close() => _inner.close();
}

// ─── Probe & Pin ─────────────────────────────────────────────────────────────

/// Opens a SecureSocket to [host]:[port], extracts the server certificate,
/// stores its SHA-256 fingerprint AND expiry in FlutterSecureStorage.
///
/// Called:
///   · After first successful request (_ToFuClient) to establish initial pin.
///   · When the stored pin is within [_renewWithinDays] of expiry (silent renewal).
Future<void> _probeAndPin(String host, int port) async {
  try {
    final socket = await SecureSocket.connect(
      host,
      port,
      timeout: const Duration(seconds: 10),
      onBadCertificate: (_) => false, // accept cert to read its contents
    );
    final cert = socket.peerCertificate;
    socket.destroy();

    if (cert != null) {
      final fp = _sha256Hex(cert.der);
      final expiry = cert.endValidity;

      await _storage.write(key: _pinKey, value: fp);
      await _storage.write(key: _pinExpiryKey, value: expiry.toIso8601String());

      debugPrint(
        'NexAI Pinning: pin updated ✓\n'
        '  fingerprint: $fp\n'
        '  expires    : ${expiry.toIso8601String()}',
      );
    }
  } catch (e) {
    debugPrint('NexAI Pinning: probe error: $e');
  }
}

// ─── Storage helpers ──────────────────────────────────────────────────────────

Future<void> _clearPin() async {
  await Future.wait([
    _storage.delete(key: _pinKey),
    _storage.delete(key: _pinExpiryKey),
  ]);
  debugPrint('NexAI Pinning: stored pin cleared');
}

// ─── Cryptographic helpers ────────────────────────────────────────────────────

String _sha256Hex(List<int> der) {
  final d = sha256.convert(der);
  return d.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Constant-time comparison — prevents timing side-channel extraction.
bool _timingSafeEq(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}
