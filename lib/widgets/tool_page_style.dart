import 'package:flutter/material.dart';

class ToolHeroChipData {
  final IconData icon;
  final String label;

  const ToolHeroChipData({required this.icon, required this.label});
}

class ToolQuickActionData {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const ToolQuickActionData({
    required this.icon,
    required this.label,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
  });
}

class ToolPageHeroSliver extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ToolHeroChipData> chips;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double expandedHeight;

  const ToolPageHeroSliver({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.chips = const <ToolHeroChipData>[],
    this.actions,
    this.bottom,
    this.expandedHeight = 190,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final hasLeading = ModalRoute.of(context)?.canPop ?? false;
    final titleBottom = bottomHeight + 14;
    final titleLeft = hasLeading ? (kToolbarHeight + 20) : 20.0;
    final effectiveExpandedHeight =
        expandedHeight + bottomHeight + (mq.size.width < 600 ? 28 : 0);

    return SliverAppBar(
      pinned: true,
      expandedHeight: effectiveExpandedHeight,
      backgroundColor: cs.surface,
      surfaceTintColor: cs.surfaceTint,
      actions: actions,
      bottom: bottom,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: EdgeInsets.only(
          left: titleLeft,
          right: 16,
          bottom: titleBottom,
        ),
        title: Text(
          title,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primaryContainer.withAlpha(130),
                cs.tertiaryContainer.withAlpha(80),
                cs.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                kToolbarHeight + 16,
                24,
                bottomHeight + 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withAlpha(60),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 32, color: cs.onPrimary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: chips
                              .map(
                                (chip) =>
                                    _ToolHeroChip(chip: chip, colorScheme: cs),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToolQuickActionsBar extends StatelessWidget {
  final List<ToolQuickActionData> actions;

  const ToolQuickActionsBar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = switch (actions.length) {
          1 => 1,
          2 => constraints.maxWidth < 420 ? 1 : 2,
          _ => constraints.maxWidth < 560 ? 2 : 3,
        };
        final gap = 10.0;
        final itemWidth =
            (constraints.maxWidth - (columnCount - 1) * gap) / columnCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  child: _ToolQuickActionCard(action: action, colorScheme: cs),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class ToolSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const ToolSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withAlpha(150),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(icon, size: 18, color: cs.primary)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(trailing!, style: TextStyle(fontSize: 12, color: cs.outline)),
        ],
      ],
    );
  }
}

class ToolPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderSide? borderSide;

  const ToolPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: color ?? cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: borderSide ?? BorderSide(color: cs.outlineVariant.withAlpha(50)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class ToolEmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const ToolEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ToolPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(120),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _ToolHeroChip extends StatelessWidget {
  final ToolHeroChipData chip;
  final ColorScheme colorScheme;

  const _ToolHeroChip({required this.chip, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withAlpha(170),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            chip.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolQuickActionCard extends StatelessWidget {
  final ToolQuickActionData action;
  final ColorScheme colorScheme;

  const _ToolQuickActionCard({required this.action, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final bg = action.backgroundColor ?? colorScheme.primaryContainer;
    final iconColor = action.iconColor ?? colorScheme.onPrimaryContainer;
    final enabled = action.onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(40),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(action.icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
