import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/navigation_helper.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  static const _focusDuration = Duration(minutes: 20);

  Timer? _timer;
  Duration _remaining = _focusDuration;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final next = _remaining - const Duration(seconds: 1);
        _remaining = next.isNegative ? _focusDuration : next;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final settings = context.watch<SettingsProvider>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset('assets/icon.png', width: 52, height: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NexAI',
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          settings.isConfigured
                              ? 'Markdown / Code / Formula / Vision'
                              : 'API CONFIG REQUIRED',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontFamily: SettingsProvider.monospaceFontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (settings.isConfigured)
                    FilledButton.icon(
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        await context.read<ChatProvider>().newConversation();
                      },
                      icon: const Icon(Icons.add_comment_rounded, size: 18),
                      label: const Text('新建'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        NavigationHelper.goToSettings();
                      },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('设置'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _DashboardCardFlow(
                colorScheme: cs,
                countdown: _formatCountdown(_remaining),
              ),
              if (settings.isConfigured) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      NavigationHelper.goToSettings();
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('调整模型'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _DashboardCardFlow extends StatelessWidget {
  final ColorScheme colorScheme;
  final String countdown;

  const _DashboardCardFlow({
    required this.colorScheme,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 760 ? 4 : (maxWidth >= 390 ? 2 : 1);
        final cardWidth = (maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _SurfaceMetricCard(
              width: cardWidth,
              colorScheme: colorScheme,
              icon: Icons.visibility_rounded,
              title: '实时瞳距测算',
              value: '-- mm',
              status: 'CAM OFF',
            ),
            _SurfaceMetricCard(
              width: cardWidth,
              colorScheme: colorScheme,
              icon: Icons.light_mode_rounded,
              title: '环境光强 Lux',
              value: '-- lux',
              status: 'SENSOR OFF',
            ),
            _SurfaceMetricCard(
              width: cardWidth,
              colorScheme: colorScheme,
              icon: Icons.timer_rounded,
              title: '20分钟倒计时',
              value: countdown,
              status: 'FOCUS',
              highlighted: true,
            ),
            _SurfaceMetricCard(
              width: cardWidth,
              colorScheme: colorScheme,
              icon: Icons.bar_chart_rounded,
              title: '历史违规统计',
              value: '0',
              status: 'TODAY',
            ),
          ],
        );
      },
    );
  }
}

class _SurfaceMetricCard extends StatelessWidget {
  final double width;
  final ColorScheme colorScheme;
  final IconData icon;
  final String title;
  final String value;
  final String status;
  final bool highlighted;

  const _SurfaceMetricCard({
    required this.width,
    required this.colorScheme,
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlighted ? colorScheme.primary : colorScheme.secondary;

    return SizedBox(
      width: width,
      height: 112,
      child: Card(
        color: highlighted
            ? colorScheme.primaryContainer.withAlpha(120)
            : colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(28),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: accent,
                        fontFamily: SettingsProvider.monospaceFontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlighted
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontFamily: SettingsProvider.monospaceFontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlighted
                      ? colorScheme.onPrimaryContainer.withAlpha(190)
                      : colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
