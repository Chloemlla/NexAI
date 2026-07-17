import 'package:flutter/material.dart';

import '../../theme/lumen_tokens.dart';

enum LumenIconChipShape { circle, rounded }

/// Circular/rounded primary-container icon chip used by Lumen section headers.
class LumenIconChip extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final LumenIconChipShape shape;

  const LumenIconChip({
    super.key,
    required this.icon,
    this.size = 32,
    this.iconSize = 18,
    this.backgroundColor,
    this.foregroundColor,
    this.shape = LumenIconChipShape.circle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.primaryContainer;
    final fg = foregroundColor ?? cs.onPrimaryContainer;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: shape == LumenIconChipShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: shape == LumenIconChipShape.rounded
            ? LumenTokens.chipBorderRadius
            : null,
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: fg),
      ),
    );
  }
}
