import 'package:flutter/material.dart';

import '../../theme/lumen_tokens.dart';

/// Soft ActionCard surface from Project-Lumen.
class LumenActionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final BorderSide? borderSide;

  const LumenActionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.elevation = 0,
    this.borderRadius,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = borderRadius ?? LumenTokens.cardBorderRadius;
    final side = borderSide ?? BorderSide.none;

    return Card(
      elevation: elevation,
      color: color ?? cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}
