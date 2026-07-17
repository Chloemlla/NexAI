import 'package:flutter/material.dart';

import '../../theme/lumen_tokens.dart';
import 'lumen_action_card.dart';
import 'lumen_icon_chip.dart';

/// Collapsible soft section used by Lumen secondary pages / settings.
///
/// Layout language matches Project-Lumen [SettingsSection]:
/// soft ActionCard, header chip, title, chevron, optional summary + body.
class LumenSettingsSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;
  final bool forceExpanded;
  final Widget? headerAccessory;

  const LumenSettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = true,
    this.forceExpanded = false,
    this.headerAccessory,
  });

  @override
  State<LumenSettingsSection> createState() => _LumenSettingsSectionState();
}

class _LumenSettingsSectionState extends State<LumenSettingsSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.forceExpanded || widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant LumenSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceExpanded && !_expanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final expanded = widget.forceExpanded ? true : _expanded;

    return LumenActionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: cs.surfaceContainerHighest.withAlpha(140),
            borderRadius: LumenTokens.cardBorderRadius,
            child: InkWell(
              borderRadius: LumenTokens.cardBorderRadius,
              onTap: widget.forceExpanded
                  ? null
                  : () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    LumenIconChip(
                      icon: widget.icon,
                      size: 40,
                      iconSize: 22,
                      shape: LumenIconChipShape.rounded,
                      backgroundColor: cs.primaryContainer.withAlpha(184),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.headerAccessory != null) ...[
                      widget.headerAccessory!,
                      const SizedBox(width: 4),
                    ],
                    if (!widget.forceExpanded)
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.children.length; i++) ...[
                    widget.children[i],
                    if (i != widget.children.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}
