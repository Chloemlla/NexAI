import 'package:flutter/material.dart';

import '../../theme/lumen_tokens.dart';
import 'lumen_icon_chip.dart';

/// Compact soft status row used across Lumen screens.
class LumenStatusLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? detail;
  final Widget? trailing;
  final Color? iconBackgroundColor;
  final Color? iconForegroundColor;

  const LumenStatusLine({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.trailing,
    this.iconBackgroundColor,
    this.iconForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: LumenTokens.cardBorderRadius,
      ),
      child: Row(
        children: [
          LumenIconChip(
            icon: icon,
            size: 32,
            iconSize: 18,
            backgroundColor: iconBackgroundColor,
            foregroundColor: iconForegroundColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
