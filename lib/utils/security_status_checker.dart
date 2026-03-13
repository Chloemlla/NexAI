/// Security Status Checker
///
/// Periodically checks device security status with the backend server.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/nexai_security_service.dart';

class SecurityStatusChecker {
  final NexAISecurityService _service;
  Timer? _timer;

  SecurityStatusChecker(this._service);

  /// Start periodic security status check
  void startPeriodicCheck({
    Duration interval = const Duration(minutes: 30),
    required BuildContext context,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      await checkStatus(context);
    });

    // Check immediately on start
    checkStatus(context);
  }

  /// Stop periodic check
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Check security status once
  Future<void> checkStatus(BuildContext context) async {
    try {
      final status = await _service.getSecurityStatus();
      if (context.mounted) {
        _handleSecurityStatus(status, context);
      }
    } catch (e) {
      debugPrint('SecurityStatusChecker: Failed to check status: $e');
    }
  }

  void _handleSecurityStatus(
    SecurityStatusResponse status,
    BuildContext context,
  ) {
    debugPrint('SecurityStatusChecker: Status=${status.status}, Risk=${status.riskLevel}');

    switch (status.status) {
      case 'blocked':
        if (context.mounted) {
          _showBlockDialog(status.message, context);
        }
        break;

      case 'flagged':
        if (context.mounted) {
          _handleRestrictions(status.restrictions, context);
        }
        break;

      case 'normal':
        // Normal operation
        break;

      default:
        debugPrint('SecurityStatusChecker: Unknown status: ${status.status}');
    }
  }

  void _handleRestrictions(
    List<String> restrictions,
    BuildContext context,
  ) {
    if (restrictions.isEmpty) return;

    debugPrint('SecurityStatusChecker: Restrictions applied: $restrictions');

    // Show warning dialog
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('安全限制'),
            ],
          ),
          content: Text(
            '您的设备已被标记，部分功能受到限制：\n\n'
            '${restrictions.map((r) => '• ${_getRestrictionDescription(r)}').join('\n')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        ),
      );
    }
  }

  String _getRestrictionDescription(String restriction) {
    switch (restriction) {
      case 'payment_disabled':
        return '支付功能已禁用';
      case 'api_rate_limited':
        return 'API 请求速率受限';
      case 'all_operations_blocked':
        return '所有操作已被阻止';
      default:
        return restriction;
    }
  }

  void _showBlockDialog(String message, BuildContext context) {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text('服务已停止'),
            ],
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Exit app
                // SystemNavigator.pop();
              },
              child: const Text('退出'),
            ),
          ],
        ),
      );
    }
  }

  void dispose() {
    stop();
  }
}
