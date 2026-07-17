import 'dart:convert';

import 'package:flutter/material.dart';

/// Structured NexAI API / pipeline error for UI dialogs.
class NexaiApiError implements Exception {
  NexaiApiError({
    required this.stage,
    required this.code,
    required this.message,
    this.statusCode,
    this.path,
    this.method,
    this.cause,
  });

  final String stage;
  final String code;
  final String message;
  final int? statusCode;
  final String? path;
  final String? method;
  final Object? cause;

  static const stageLabelsZh = <String, String>{
    'tls_pinning': '安全连接（证书钉扎）',
    'request_build': '请求构造',
    'request_sign': '请求签名',
    'transport': '网络传输',
    'http_status': 'HTTP 响应',
    'response_parse': '响应解析',
    'auth_session': '登录会话',
    'rate_limit': '频率限制',
    'server_signature': '服务端签名校验',
    'server_auth': '服务端登录鉴权',
    'server_validation': '服务端参数校验',
    'server_internal': '服务端内部错误',
    'risk_policy': '风险策略拦截',
  };

  String get stageLabel => stageLabelsZh[stage] ?? stage;

  String toDialogBody() {
    final lines = <String>[
      '【环节】$stageLabel',
      '【原因】$message',
      '【代码】$code',
    ];
    if (statusCode != null) {
      lines.add('【HTTP】$statusCode');
    }
    if (path != null && path!.isNotEmpty) {
      lines.add('【路径】${method == null ? path : '$method $path'}');
    }
    return lines.join('\n');
  }

  @override
  String toString() => 'NexaiApiError($stage/$code): $message';
}

/// Show a blocking dialog with stage + reason + code.
Future<void> showNexaiErrorDialog(
  BuildContext context,
  Object error, {
  String title = '请求失败',
}) async {
  if (!context.mounted) return;
  final apiError = error is NexaiApiError
      ? error
      : NexaiApiError(
          stage: 'http_status',
          code: 'CLIENT_UNKNOWN',
          message: error.toString(),
        );

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SelectableText(apiError.toDialogBody()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// Best-effort parse of server JSON error envelope.
NexaiApiError nexaiErrorFromResponse({
  required int statusCode,
  required String body,
  String? path,
  String? method,
}) {
  try {
    if (body.isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final map = decoded.map((k, v) => MapEntry(k.toString(), v));
        final code =
            (map['code'] ?? map['errorCode'] ?? 'HTTP_$statusCode').toString();
        final stage =
            (map['stage'] ?? _stageFromStatus(statusCode, code)).toString();
        final message =
            (map['error'] ?? map['message'] ?? '请求失败').toString();
        return NexaiApiError(
          stage: stage,
          code: code,
          message: message,
          statusCode: statusCode,
          path: path,
          method: method,
        );
      }
    }
  } catch (_) {}

  return NexaiApiError(
    stage: _stageFromStatus(statusCode, null),
    code: 'HTTP_$statusCode',
    message: body.isNotEmpty ? body : 'HTTP $statusCode',
    statusCode: statusCode,
    path: path,
    method: method,
  );
}

String _stageFromStatus(int statusCode, String? code) {
  if (code != null && code.startsWith('NEXAI_SIG_')) return 'server_signature';
  if (statusCode == 429) return 'rate_limit';
  if (statusCode == 401 || statusCode == 403) return 'server_auth';
  if (statusCode >= 500) return 'server_internal';
  if (statusCode >= 400) return 'server_validation';
  return 'http_status';
}
