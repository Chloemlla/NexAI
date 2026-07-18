/// Network safety helpers for chat tools (SSRF guards, URL validation).
library;

class NetworkSafety {
  NetworkSafety._();

  static const int maxRedirects = 3;
  static const int maxDownloadBytes = 2 * 1024 * 1024; // 2MB
  static const int maxImageBytes = 4 * 1024 * 1024; // 4MB
  static const int maxImagesPerMessage = 4;

  /// Returns null if safe; otherwise an error code string.
  static String? validatePublicHttpUrl(
    String raw, {
    bool requireHttps = false,
  }) {
    final value = raw.trim();
    if (value.isEmpty) return 'url_required';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return 'invalid_url';
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return 'invalid_scheme';
    if (requireHttps && scheme != 'https') return 'https_required';
    if (uri.userInfo.isNotEmpty) return 'userinfo_not_allowed';
    if (_isBlockedHost(uri.host)) return 'private_or_local_host_blocked';
    return null;
  }

  static bool _isBlockedHost(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return true;
    if (h == 'localhost' || h == 'localhost.' || h.endsWith('.localhost')) {
      return true;
    }
    if (h == '0.0.0.0' || h == '::' || h == '::1') return true;
    if (h.endsWith('.local') || h.endsWith('.internal')) return true;

    // IPv4
    final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    final m = ipv4.firstMatch(h);
    if (m != null) {
      final parts = List<int>.generate(4, (i) => int.parse(m.group(i + 1)!));
      if (parts.any((p) => p < 0 || p > 255)) return true;
      final a = parts[0], b = parts[1];
      if (a == 10) return true; // 10.0.0.0/8
      if (a == 127) return true; // loopback
      if (a == 0) return true;
      if (a == 169 && b == 254) return true; // link-local / metadata
      if (a == 172 && b >= 16 && b <= 31) return true; // 172.16/12
      if (a == 192 && b == 168) return true; // 192.168/16
      if (a == 100 && b >= 64 && b <= 127) return true; // CGNAT
      if (a >= 224) return true; // multicast/reserved
      return false;
    }

    // IPv6 compressed forms commonly used for local/link-local.
    if (h.contains(':')) {
      if (h == '::1') return true;
      if (h.startsWith('fc') || h.startsWith('fd')) return true; // unique local
      if (h.startsWith('fe80')) return true; // link-local
      if (h.startsWith('ff')) return true; // multicast
    }
    return false;
  }

  static String redactSecrets(String input) {
    var out = input;
    out = out.replaceAll(
      RegExp(r'Bearer\s+\S+', caseSensitive: false),
      'Bearer <redacted>',
    );
    out = out.replaceAllMapped(
      RegExp(
        r'([?&](?:key|api_key|apikey|access_token|token|password|secret)=)[^&\s]+',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}<redacted>',
    );
    out = out.replaceAll(
      RegExp(
        r'(?i)("?(?:api[_-]?key|access[_-]?token|refresh[_-]?token|authorization|password|secret|token)"?\s*[:=]\s*")([^"]+)(")',
      ),
      r'$1<redacted>$3',
    );
    out = out.replaceAll(RegExp(r'sk-[A-Za-z0-9_-]{12,}'), 'sk-<redacted>');
    out = out.replaceAll(RegExp(r'AIza[0-9A-Za-z_-]{20,}'), 'AIza<redacted>');
    return out;
  }
}
