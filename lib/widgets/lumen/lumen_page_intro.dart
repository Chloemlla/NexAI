import 'package:flutter/material.dart';

import 'lumen_action_card.dart';
import 'lumen_icon_chip.dart';

/// Secondary-page overview card.
///
/// Holds the page "behind-the-scenes" intro copy that used to live in large
/// marketing heroes. Keep the description — just place it under a plain AppBar.
class LumenPageIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> chips;

  const LumenPageIntro({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.chips = const <String>[],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LumenActionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LumenIconChip(
                icon: icon,
                size: 44,
                iconSize: 24,
                shape: LumenIconChipShape.rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (chip) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withAlpha(160),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chip,
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
