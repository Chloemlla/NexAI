import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'navigation_helper.dart';

/// Soft-mode (`NEXAI_REQUEST_SIGNING=soft`) may accept requests while reporting
/// signature failure via response headers:
///   X-NexAI-Sig-Result: fail
///   X-NexAI-Sig-Code: NEXAI_SIG_*
///
/// This helper turns those headers into a throttled user-visible toast.
class NexaiSoftSigNotice {
  NexaiSoftSigNotice._();

  static DateTime? _lastShownAt;
  static String? _lastCode;
  static const _throttle = Duration(seconds: 12);

  static const _codeHints = <String, String>{
    'NEXAI_SIG_MISSING': '缺少请求签名参数',
    'NEXAI_SIG_VERSION': '签名版本不受支持',
    'NEXAI_SIG_EXPIRED': '请求时间戳过期，请校准系统时间',
    'NEXAI_SIG_REPLAY': '检测到重放请求',
    'NEXAI_SIG_INVALID': '请求签名无效',
    'NEXAI_SIG_KEY': '缺少可用签名密钥',
  };

  /// Call for every backend response. No-op unless soft-fail headers present.
  static void maybeNotifyFromHeaders({
    required Map<String, String> headers,
    String? path,
    String? method,
  }) {
    final result = _header(headers, 'x-nexai-sig-result');
    final code = _header(headers, 'x-nexai-sig-code');
    if (result == null && code == null) return;

    debugPrint(
      'NexAI Backend: soft sig header result=${result ?? "-"} '
      'code=${code ?? "-"} path=${path ?? "-"} method=${method ?? "-"}',
    );

    final normalized = (result ?? '').toLowerCase();
    final isFail = normalized == 'fail' ||
        normalized == 'false' ||
        (code != null && code.startsWith('NEXAI_SIG_'));
    if (!isFail) return;

    final now = DateTime.now();
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!) < _throttle &&
        _lastCode == code) {
      return;
    }
    _lastShownAt = now;
    _lastCode = code;

    final hint = _codeHints[code ?? ''] ?? '服务端处于 soft 模式，签名未通过但请求仍被放行';
    final pathPart = (path == null || path.isEmpty) ? '' : ' · $path';
    final text = '签名校验提示：$hint${code == null ? '' : '（$code）'}$pathPart';

    // Prefer SmartDialog toast (global, no BuildContext needed).
    try {
      SmartDialog.showToast(text, displayTime: const Duration(seconds: 4));
      return;
    } catch (_) {
      // Fall through if SmartDialog not ready during early bootstrap.
    }

    final ctx = NavigationHelper.navigatorKey.currentContext;
    if (ctx == null) return;
    // Soft dependency: only if a ScaffoldMessenger ancestor exists.
    try {
      // ignore: use_build_context_synchronously
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {}
  }

  static String? _header(Map<String, String> headers, String name) {
    final direct = headers[name];
    if (direct != null) return direct;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }
}
