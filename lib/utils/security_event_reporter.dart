/// Security Event Reporter
///
/// Reports security events to the backend server.
library;

import 'package:flutter/foundation.dart';
import '../services/nexai_security_service.dart';
import '../utils/app_security.dart';

class SecurityEventReporter {
  final NexAISecurityService _service;

  SecurityEventReporter(this._service);

  /// Report integrity failure
  Future<void> reportIntegrityFailure({
    required bool signatureValid,
    required bool hashValid,
    String? expectedHash,
    String? actualHash,
  }) async {
    try {
      await _service.reportSecurityEvent(
        SecurityEventRequest(
          eventType: 'integrity_fail',
          details: {
            'signature_valid': signatureValid,
            'hash_valid': hashValid,
            if (expectedHash != null) 'expected_hash': expectedHash,
            if (actualHash != null) 'actual_hash': actualHash,
          },
          timestamp: DateTime.now().toIso8601String(),
        ),
      );
      debugPrint('SecurityEventReporter: Integrity failure reported');
    } catch (e) {
      debugPrint('SecurityEventReporter: Failed to report integrity failure: $e');
    }
  }

  /// Report root detection
  Future<void> reportRootDetection() async {
    try {
      await _service.reportSecurityEvent(
        SecurityEventRequest(
          eventType: 'root_detected',
          details: {
            'detection_method': 'su_binary',
          },
          timestamp: DateTime.now().toIso8601String(),
        ),
      );
      debugPrint('SecurityEventReporter: Root detection reported');
    } catch (e) {
      debugPrint('SecurityEventReporter: Failed to report root detection: $e');
    }
  }

  /// Report debugger detection
  Future<void> reportDebuggerDetection() async {
    try {
      await _service.reportSecurityEvent(
        SecurityEventRequest(
          eventType: 'debugger_detected',
          timestamp: DateTime.now().toIso8601String(),
        ),
      );
      debugPrint('SecurityEventReporter: Debugger detection reported');
    } catch (e) {
      debugPrint('SecurityEventReporter: Failed to report debugger detection: $e');
    }
  }

  /// Report emulator detection
  Future<void> reportEmulatorDetection() async {
    try {
      await _service.reportSecurityEvent(
        SecurityEventRequest(
          eventType: 'emulator_detected',
          timestamp: DateTime.now().toIso8601String(),
        ),
      );
      debugPrint('SecurityEventReporter: Emulator detection reported');
    } catch (e) {
      debugPrint('SecurityEventReporter: Failed to report emulator detection: $e');
    }
  }

  /// Report Frida detection
  Future<void> reportFridaDetection() async {
    try {
      await _service.reportSecurityEvent(
        SecurityEventRequest(
          eventType: 'frida_detected',
          timestamp: DateTime.now().toIso8601String(),
        ),
      );
      debugPrint('SecurityEventReporter: Frida detection reported');
    } catch (e) {
      debugPrint('SecurityEventReporter: Failed to report Frida detection: $e');
    }
  }

  /// Report Xposed detection
  Future<void> reportXposedDetection() async {
    try {
      await _service.reportSecurityEvent(
        SecurityEventRequest(
          eventType: 'xposed_detected',
          timestamp: DateTime.now().toIso8601String(),
        ),
      );
      debugPrint('SecurityEventReporter: Xposed detection reported');
    } catch (e) {
      debugPrint('SecurityEventReporter: Failed to report Xposed detection: $e');
    }
  }

  /// Report all detected security issues
  Future<void> reportAllIssues() async {
    final security = AppSecurity.instance;

    if (!security.isSignatureValid || !security.isApkHashValid) {
      await reportIntegrityFailure(
        signatureValid: security.isSignatureValid,
        hashValid: security.isApkHashValid,
      );
    }

    if (security.isCompromised) {
      await reportRootDetection();
    }

    if (security.isDebuggerAttached) {
      await reportDebuggerDetection();
    }

    if (security.isEmulator) {
      await reportEmulatorDetection();
    }
  }
}
