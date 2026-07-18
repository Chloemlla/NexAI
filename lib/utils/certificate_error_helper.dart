import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../services/crash_breadcrumbs.dart';
import '../services/pinned_http_client.dart';

class CertificateErrorHelper {
  static bool _dialogVisible = false;

  CertificateErrorHelper._();

  static bool isHandshakeCertificateError(Object error) {
    return _containsHandshakeMarker(error);
  }

  static Future<void> maybePromptToClearCertificateCache(Object error) async {
    if (!isHandshakeCertificateError(error) || _dialogVisible) return;
    _dialogVisible = true;
    CrashBreadcrumbs.record('HandshakeException detected in API request');

    try {
      await SmartDialog.show(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            icon: Icon(Icons.verified_user_outlined, color: cs.error),
            title: const Text('检测到证书握手失败'),
            content: const Text(
              'API 请求返回 HandshakeException。常见原因：\n'
              '1) 服务器证书轮换后本地 pin 仍是旧值；\n'
              '2) 服务器证书链缺少中间证书，系统 CA 无法校验。\n\n'
              '应用会尝试自动恢复；若仍失败，请清除证书缓存后重试。',
            ),
            actions: [
              TextButton(
                onPressed: () => SmartDialog.dismiss(),
                child: const Text('稍后处理'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await clearCertPin();
                    CrashBreadcrumbs.record(
                      'Certificate cache cleared by prompt',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('证书缓存已清除，请重新发起请求')),
                      );
                    }
                  } finally {
                    await SmartDialog.dismiss();
                  }
                },
                child: const Text('清除证书缓存'),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogVisible = false;
    }
  }

  static String handshakeUserMessage() {
    return '检测到 TLS 证书握手失败。请在设置 > 安全 > 证书固定中清除证书缓存，'
        '或在弹窗中确认自动清除后重新发起请求。';
  }

  static bool _containsHandshakeMarker(Object? value) {
    if (value == null) return false;
    if (value is DioException) {
      return _containsHandshakeMarker(value.message) ||
          _containsHandshakeMarker(value.error) ||
          _containsHandshakeMarker(value.response?.data) ||
          _containsHandshakeMarker(value.response?.statusMessage);
    }
    if (value is Map) {
      final errorType = value['errorType']?.toString().toLowerCase() ?? '';
      final error = value['error']?.toString().toLowerCase() ?? '';
      final details = value['errorDetails']?.toString().toLowerCase() ?? '';
      if (errorType.contains('handshakeexception') ||
          error.contains('handshakeexception') ||
          details.contains('message=handshake')) {
        return true;
      }
      return value.values.any(_containsHandshakeMarker);
    }
    if (value is Iterable) {
      return value.any(_containsHandshakeMarker);
    }

    final text = value.toString().toLowerCase();
    return text.contains('handshakeexception') ||
        text.contains('handshake exception') ||
        (text.contains('handshake') &&
            (text.contains('certificate') ||
                text.contains('cert') ||
                text.contains('tls') ||
                text.contains('ssl')));
  }
}
