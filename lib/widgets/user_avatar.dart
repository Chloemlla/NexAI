import 'package:flutter/material.dart';

/// Circular avatar that never crashes on network image failures.
///
/// Prefer this over [CircleAvatar.backgroundImage] with [NetworkImage]: a failed
/// [NetworkImage] reports a [FlutterError] that our crash reporter treats as a
/// crash (common when Google profile photos are unreachable offline).
class UserAvatar extends StatelessWidget {
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

  String get _initial {
    final display = displayName?.trim() ?? '';
    if (display.isNotEmpty) {
      return String.fromCharCode(display.runes.first).toUpperCase();
    }
    final user = username?.trim() ?? '';
    if (user.isNotEmpty) {
      return String.fromCharCode(user.runes.first).toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = radius * 2;
    final fallback = _FallbackAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      initial: _initial,
    );

    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: size,
          height: size,
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
          },
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
