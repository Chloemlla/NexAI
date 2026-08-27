import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/avatar_cache.dart';

/// Circular avatar that never crashes on network image failures.
///
/// Prefer this over [CircleAvatar.backgroundImage] with [NetworkImage]: a failed
/// [NetworkImage] reports a [FlutterError] that our crash reporter treats as a
/// crash (common when Google profile photos are unreachable offline).
///
/// Remote photos are served from the on-disk cache (see [loadCachedAvatar]) so
/// they survive restarts and still render while offline.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.displayName,
    this.username,
    this.radius = 24,
  });

  final String? imageUrl;
  final String? displayName;
  final String? username;
  final double radius;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Uint8List? _bytes;
  bool _loading = false;
  String _url = '';

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl?.trim() != widget.imageUrl?.trim()) {
      _resolve();
    }
  }

  void _resolve() {
    final url = widget.imageUrl?.trim() ?? '';
    _url = url;
    _bytes = null;
    _loading = url.isNotEmpty && avatarCacheSupported;
    if (!_loading) {
      return;
    }

    loadCachedAvatar(url).then((bytes) {
      if (!mounted || _url != url) {
        return;
      }
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    });
  }

  String get _initial {
    final display = widget.displayName?.trim() ?? '';
    if (display.isNotEmpty) {
      return String.fromCharCode(display.runes.first).toUpperCase();
    }
    final user = widget.username?.trim() ?? '';
    if (user.isNotEmpty) {
      return String.fromCharCode(user.runes.first).toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = widget.radius;
    final size = radius * 2;
    final fallback = _FallbackAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      initial: _initial,
    );

    if (_url.isEmpty) {
      return fallback;
    }

    // Decode at display resolution: profile photos are often 512px+ but render
    // at a ~48px avatar, so full-size decoding wastes heap and decode time.
    // Only the width is constrained so the source aspect ratio is preserved.
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final bytes = _bytes;

    final Widget child;
    if (bytes != null) {
      child = Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: decodeWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          // A truncated or non-image file would otherwise keep failing until
          // the cache expires.
          evictCachedAvatar(_url).ignore();
          return fallback;
        },
      );
    } else if (_loading) {
      child = _progress(cs, radius);
    } else {
      child = Image.network(
        _url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: decodeWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          final expected = loadingProgress.expectedTotalBytes;
          final value = expected == null || expected <= 0
              ? null
              : loadingProgress.cumulativeBytesLoaded / expected;
          return _progress(cs, radius, value: value);
        },
      );
    }

    return ClipOval(
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _progress(ColorScheme cs, double radius, {double? value}) {
    return ColoredBox(
      color: cs.primaryContainer,
      child: Center(
        child: SizedBox(
          width: radius,
          height: radius,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: value,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.initial,
  });

  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
