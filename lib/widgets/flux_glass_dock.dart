import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class FluxGlassDockItem {
  const FluxGlassDockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class FluxGlassDock extends StatefulWidget {
  const FluxGlassDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FluxGlassDockItem> items;

  @override
  State<FluxGlassDock> createState() => _FluxGlassDockState();
}

class _FluxGlassDockState extends State<FluxGlassDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fluxController;

  @override
  void initState() {
    super.initState();
    _fluxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations && _fluxController.isAnimating) {
      _fluxController.stop();
    } else if (!disableAnimations && !_fluxController.isAnimating) {
      _fluxController.repeat();
    }
  }

  @override
  void dispose() {
    _fluxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.isNotEmpty,
      'FluxGlassDock requires at least one item.',
    );

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final compact = media.size.width < 370;
    final horizontalInset = compact ? 12.0 : 16.0;
    final dockHeight = compact ? 68.0 : 72.0;
    final disableAnimations = media.disableAnimations;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(horizontalInset, 8, horizontalInset, 10),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: RepaintBoundary(
            child: SizedBox(
              height: dockHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: (isDark ? cs.surfaceContainerHigh : cs.surface)
                          .withAlpha(isDark ? 176 : 202),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: cs.outlineVariant.withAlpha(isDark ? 94 : 118),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 92 : 28),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: cs.primary.withAlpha(isDark ? 28 : 20),
                          blurRadius: 22,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _fluxController,
                      builder: (context, _) {
                        final phase = disableAnimations
                            ? 0.18
                            : _fluxController.value;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FluxGlassPainter(
                                  colorScheme: cs,
                                  isDark: isDark,
                                  phase: phase,
                                ),
                              ),
                            ),
                            _FluxGlassDockItems(
                              selectedIndex: widget.selectedIndex,
                              items: widget.items,
                              onDestinationSelected:
                                  widget.onDestinationSelected,
                            ),
                          ],
                        );
                      },
                    ),
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

class _FluxGlassDockItems extends StatelessWidget {
  const _FluxGlassDockItems({
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<FluxGlassDockItem> items;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = math.min(math.max(selectedIndex, 0), items.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / items.length;

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 430),
              curve: Curves.easeOutCubic,
              left: itemWidth * selected + 6,
              top: 7,
              width: itemWidth - 12,
              height: constraints.maxHeight - 14,
              child: _FluxGlassSelection(colorScheme: cs, isDark: isDark),
            ),
            Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _FluxGlassDockButton(
                      item: items[i],
                      selected: i == selected,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FluxGlassSelection extends StatelessWidget {
  const _FluxGlassSelection({required this.colorScheme, required this.isDark});

  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withAlpha(isDark ? 74 : 52),
            colorScheme.secondaryContainer.withAlpha(isDark ? 86 : 144),
            colorScheme.tertiary.withAlpha(isDark ? 58 : 42),
          ],
        ),
        border: Border.all(color: Colors.white.withAlpha(isDark ? 28 : 122)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(isDark ? 54 : 36),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _FluxGlassDockButton extends StatelessWidget {
  const _FluxGlassDockButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FluxGlassDockItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = selected ? cs.primary : cs.onSurfaceVariant;
    final labelColor = selected ? cs.primary : cs.onSurfaceVariant;

    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 450),
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            splashColor: cs.primary.withAlpha(28),
            highlightColor: cs.primary.withAlpha(18),
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                scale: selected ? 1.05 : 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) {
                        final scale = Tween<double>(begin: 0.88, end: 1)
                            .animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ),
                            );

                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: scale, child: child),
                        );
                      },
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        key: ValueKey('${item.label}-$selected'),
                        size: selected ? 25 : 23,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.1,
                        letterSpacing: 0,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: labelColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Text(item.label),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FluxGlassPainter extends CustomPainter {
  const _FluxGlassPainter({
    required this.colorScheme,
    required this.isDark,
    required this.phase,
  });

  final ColorScheme colorScheme;
  final bool isDark;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(isDark ? 12 : 92),
          colorScheme.primaryContainer.withAlpha(isDark ? 24 : 42),
          colorScheme.tertiaryContainer.withAlpha(isDark ? 20 : 34),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    _drawGlow(
      canvas,
      size,
      center: Offset(size.width * ((phase * 1.18) % 1), size.height * 0.24),
      radius: size.width * 0.5,
      color: colorScheme.primary,
      alpha: isDark ? 64 : 48,
    );
    _drawGlow(
      canvas,
      size,
      center: Offset(
        size.width * ((phase * 1.18 + 0.48) % 1),
        size.height * 0.78,
      ),
      radius: size.width * 0.42,
      color: colorScheme.tertiary,
      alpha: isDark ? 44 : 34,
    );

    final sweepWidth = size.width * 0.28;
    final sweepX = -sweepWidth + (size.width + sweepWidth * 2) * phase;
    final sweepRect = Rect.fromLTWH(
      sweepX,
      -size.height * 0.32,
      sweepWidth,
      size.height * 1.64,
    );
    final sweepPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withAlpha(0),
          Colors.white.withAlpha(isDark ? 26 : 72),
          Colors.white.withAlpha(0),
        ],
      ).createShader(sweepRect);

    canvas.save();
    canvas.translate(sweepRect.center.dx, sweepRect.center.dy);
    canvas.rotate(-math.pi / 8);
    canvas.translate(-sweepRect.center.dx, -sweepRect.center.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sweepRect, const Radius.circular(999)),
      sweepPaint,
    );
    canvas.restore();

    final topLinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withAlpha(0),
          Colors.white.withAlpha(isDark ? 42 : 154),
          Colors.white.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(14, 0, size.width - 28, 1));
    canvas.drawRect(Rect.fromLTWH(14, 0, size.width - 28, 1), topLinePaint);
  }

  void _drawGlow(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
    required int alpha,
  }) {
    final glowRect = Rect.fromCircle(center: center, radius: radius);
    final glowPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          color.withAlpha(alpha),
          color.withAlpha((alpha * 0.46).round()),
          Colors.transparent,
        ],
        stops: const [0, 0.42, 1],
      ).createShader(glowRect);
    canvas.drawOval(glowRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _FluxGlassPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.isDark != isDark ||
        oldDelegate.colorScheme != colorScheme;
  }
}
