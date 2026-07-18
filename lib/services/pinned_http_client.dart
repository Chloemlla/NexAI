/// Certificate pinning for tts.chloemlla.com using TOFU + FlutterSecureStorage.
///
/// Lifecycle:
///   First run      → system CA verifies TLS; stores cert fingerprint + expiry
///                    in FlutterSecureStorage (Android Keystore / Win Credential).
///   Subsequent     → SecurityContext(withTrustedRoots:false) enforces pinning.
///   Expiry check   → On every [buildPinnedHttpClient] call:
///                      · Expired pin  → clear & TOFU-re-pin automatically.
///                      · ≤30 days left→ background re-pin probe (silent renewal).
///   Chain fallback → If system CA fails with "unable to get local issuer" but the
///                    leaf matches a known bootstrap fingerprint, accept + pin leaf.
///   Rotation guard → If the server rotates before the old cert expires,
///                    call [clearCertPin] from a safe admin path to force TOFU.
///
/// APK may contain optional bootstrap fingerprints for production host recovery.
/// Runtime pin still lives in secure storage (SHA-256 of leaf DER).
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const String _pinnedHost = 'tts.chloemlla.com';

/// Storage keys
const String _pinKey = 'nexai.cert.sha256.v1';
const String _pinExpiryKey = 'nexai.cert.expiry.v1'; // ISO-8601 DateTime

/// Start background re-pin this many days before expiry.
const int _renewWithinDays = 30;

/// Optional production leaf fingerprints used only when system CA validation
/// fails (commonly incomplete intermediate chain on the server).
///
/// - SHA-256: preferred, hex without separators
/// - SHA-1: accepted for operator-provided fingerprints (colon form normalized)
///
/// SHA-1 provided by ops for current leaf:
/// ED:7E:87:8A:DB:C4:AF:70:6E:FD:6A:64:FC:97:96:D0:F0:B3:61:E3
const Set<String> _bootstrapSha256Hex = <String>{
  // Add SHA-256 leaf fingerprints here when available.
};
const Set<String> _bootstrapSha1Hex = <String>{
  'ed7e878adbc4af706efd6a64fc9796d0f0b361e3',
};

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  wOptions: WindowsOptions(useBackwardCompatibility: false),
);

// ─── Public API ───────────────────────────────────────────────────────────────

/// Returns a certificate-pinned [http.Client] for [_pinnedHost].
Future<http.Client> buildPinnedHttpClient({bool enablePinning = true}) async {
  if (kIsWeb) return http.Client();

  if (!enablePinning) {
    debugPrint('NexAI Pinning: DISABLED (development mode)');
    return http.Client();
  }

  final stored = await _storage.read(key: _pinKey);

  if (stored == null) {
    debugPrint('NexAI Pinning: no stored pin → TOFU mode');
    return _ToFuClient();
  }

  final isValid = await _verifyStoredPin(stored);
  if (!isValid) {
    debugPrint(
      'NexAI Pinning: stored pin is INVALID (cert rotated) → auto-clearing and re-entering TOFU',
    );
    await _clearPin();
    return _ToFuClient();
  }

  final expiryStr = await _storage.read(key: _pinExpiryKey);
  if (expiryStr != null) {
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry != null) {
      final now = DateTime.now();

      if (now.isAfter(expiry)) {
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

/// Force-clears the stored pin.
Future<void> clearCertPin() => _clearPin();

/// Clear pin so callers rebuild clients and re-enter TOFU.
Future<void> invalidatePinnedClientState() async {
  await _clearPin();
  debugPrint('NexAI Pinning: client state invalidated for TOFU retry');
}

// ─── TOFU Client ─────────────────────────────────────────────────────────────

class _ToFuClient extends http.BaseClient {
  final IOClient _systemClient = IOClient(
    HttpClient()..badCertificateCallback = (_, _, _) => false,
  );
  http.Client? _bootstrapClient;
  bool _probeStarted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final resp = await _systemClient.send(request);
      if (!_probeStarted && request.url.host == _pinnedHost) {
        _probeStarted = true;
        final port = request.url.hasPort ? request.url.port : 443;
        _probeAndPin(_pinnedHost, port).ignore();
      }
      return resp;
    } on HandshakeException catch (e) {
      // System CA failed (often missing intermediate). If the leaf matches a
      // known bootstrap fingerprint, continue with leaf-pin client.
      if (request.url.host == _pinnedHost &&
          _isIssuerOrHandshakeFailure(e) &&
          (_bootstrapSha1Hex.isNotEmpty || _bootstrapSha256Hex.isNotEmpty)) {
        debugPrint(
          'NexAI Pinning: system CA handshake failed, trying bootstrap leaf pin\n  $e',
        );
        final pinned = await _tryBootstrapLeafPin(_pinnedHost, 443);
        if (pinned != null) {
          _bootstrapClient ??= _PinnedClient(pinned);
          return _bootstrapClient!.send(request);
        }
      }
      rethrow;
    }
  }

  @override
  void close() {
    _systemClient.close();
    _bootstrapClient?.close();
  }
}

// ─── Strict Pinned Client ─────────────────────────────────────────────────────

class _PinnedClient extends http.BaseClient {
  late final IOClient _inner;
  final String _expectedFp;
  bool _mismatchHandled = false;

  _PinnedClient(this._expectedFp) {
    final ctx = SecurityContext(withTrustedRoots: false);
    _inner = IOClient(
      HttpClient(context: ctx)
        ..badCertificateCallback = (X509Certificate cert, String host, int _) {
          if (host != _pinnedHost) return false;
          final actual = _sha256Hex(cert.der);

          if (_timingSafeEq(actual, _expectedFp)) return true;
          if (_matchesBootstrap(cert)) {
            // Accept bootstrap-known leaf and refresh stored pin asynchronously.
            _storage.write(key: _pinKey, value: actual).ignore();
            _storage
                .write(
                  key: _pinExpiryKey,
                  value: cert.endValidity.toIso8601String(),
                )
                .ignore();
            return true;
          }

          if (!_mismatchHandled) {
            _mismatchHandled = true;
            debugPrint(
              'NexAI Pinning: CERT MISMATCH at $host\n'
              '  stored : $_expectedFp\n'
              '  current: $actual\n'
              '  → attempting auto-recovery (verifying new cert with system CA)',
            );
            _handleCertMismatch(host, 443, actual).ignore();
          }

          return false;
        },
    );
  }

  Future<void> _handleCertMismatch(String host, int port, String newFp) async {
    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );
      final cert = socket.peerCertificate;
      socket.destroy();

      if (cert != null) {
        final verifiedFp = _sha256Hex(cert.der);
        if (verifiedFp == newFp) {
          final expiry = cert.endValidity;
          await _storage.write(key: _pinKey, value: verifiedFp);
          await _storage.write(
            key: _pinExpiryKey,
            value: expiry.toIso8601String(),
          );
          debugPrint(
            'NexAI Pinning: AUTO-RECOVERY successful\n'
            '  New cert verified by system CA and pinned\n'
            '  fingerprint: $verifiedFp\n'
            '  expires    : ${expiry.toIso8601String()}',
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('NexAI Pinning: system-CA recovery failed: $e');
    }

    // Fallback: if leaf matches bootstrap pin, accept rotation.
    try {
      final fp = await _tryBootstrapLeafPin(host, port);
      if (fp != null) {
        debugPrint(
          'NexAI Pinning: AUTO-RECOVERY via bootstrap leaf pin\n  fingerprint: $fp',
        );
      }
    } catch (e) {
      debugPrint('NexAI Pinning: bootstrap recovery failed: $e');
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest req) => _inner.send(req);

  @override
  void close() => _inner.close();
}

// ─── Probe & Pin ─────────────────────────────────────────────────────────────

Future<bool> _verifyStoredPin(String storedFp) async {
  try {
    final socket = await SecureSocket.connect(
      _pinnedHost,
      443,
      timeout: const Duration(seconds: 5),
    );
    final cert = socket.peerCertificate;
    socket.destroy();

    if (cert != null) {
      final currentFp = _sha256Hex(cert.der);
      if (currentFp == storedFp) return true;
      debugPrint(
        'NexAI Pinning: Certificate rotation detected\n'
        '  stored : $storedFp\n'
        '  current: $currentFp\n'
        '  → will re-pin',
      );
      return false;
    }
  } on HandshakeException catch (e) {
    // If system CA can't build chain, keep stored pin when it still matches a
    // bootstrap-known leaf captured via callback-style connect.
    debugPrint('NexAI Pinning: verification probe handshake error: $e');
    final bootstrap = await _tryBootstrapLeafPin(_pinnedHost, 443);
    if (bootstrap != null) {
      // Bootstrap accepted (and re-pinned). Treat as valid path for this process.
      return true;
    }
    // Don't wipe pin on transient network/CA glitches.
    return true;
  } catch (e) {
    debugPrint('NexAI Pinning: verification probe error: $e');
    return true;
  }

  return true;
}

Future<void> _probeAndPin(String host, int port) async {
  try {
    final socket = await SecureSocket.connect(
      host,
      port,
      timeout: const Duration(seconds: 10),
    );
    final cert = socket.peerCertificate;
    socket.destroy();

    if (cert != null) {
      final fp = _sha256Hex(cert.der);
      final expiry = cert.endValidity;
      await _storage.write(key: _pinKey, value: fp);
      await _storage.write(key: _pinExpiryKey, value: expiry.toIso8601String());
      debugPrint(
        'NexAI Pinning: pin updated\n'
        '  fingerprint: $fp\n'
        '  expires    : ${expiry.toIso8601String()}',
      );
      return;
    }
  } on HandshakeException catch (e) {
    debugPrint('NexAI Pinning: probe system-CA failed, try bootstrap: $e');
    await _tryBootstrapLeafPin(host, port);
  } catch (e) {
    debugPrint('NexAI Pinning: probe error: $e');
  }
}

/// Connect without system roots; accept leaf only if it matches bootstrap pins.
/// Returns SHA-256 fingerprint when pinned successfully.
Future<String?> _tryBootstrapLeafPin(String host, int port) async {
  if (_bootstrapSha1Hex.isEmpty && _bootstrapSha256Hex.isEmpty) return null;
  try {
    String? acceptedSha256;
    DateTime? expiry;
    final ctx = SecurityContext(withTrustedRoots: false);
    final socket = await SecureSocket.connect(
      host,
      port,
      context: ctx,
      timeout: const Duration(seconds: 10),
      onBadCertificate: (cert) {
        if (_matchesBootstrap(cert)) {
          acceptedSha256 = _sha256Hex(cert.der);
          expiry = cert.endValidity;
          return true;
        }
        return false;
      },
    );
    socket.destroy();
    final fp = acceptedSha256;
    if (fp == null) return null;
    await _storage.write(key: _pinKey, value: fp);
    if (expiry != null) {
      await _storage.write(key: _pinExpiryKey, value: expiry!.toIso8601String());
    }
    debugPrint(
      'NexAI Pinning: bootstrap leaf pin accepted\n'
      '  fingerprint(sha256): $fp',
    );
    return fp;
  } catch (e) {
    debugPrint('NexAI Pinning: bootstrap leaf pin failed: $e');
    return null;
  }
}

bool _matchesBootstrap(X509Certificate cert) {
  final sha256Fp = _sha256Hex(cert.der);
  if (_bootstrapSha256Hex.contains(sha256Fp)) return true;
  final sha1Fp = _sha1Hex(cert.der);
  return _bootstrapSha1Hex.contains(sha1Fp);
}

bool _isIssuerOrHandshakeFailure(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('certificate_verify_failed') ||
      text.contains('unable to get local issuer certificate') ||
      text.contains('handshake');
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

String _sha1Hex(List<int> der) {
  final d = sha1.convert(der);
  return d.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

bool _timingSafeEq(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}
