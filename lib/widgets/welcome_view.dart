import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';

import '../main.dart' show isAndroid;

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildM3Welcome(context);
    return _buildFluentWelcome(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildM3Welcome(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 52) / 2;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withAlpha(60),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.smart_toy_rounded,
                  size: 40,
                  color: cs.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Welcome to NexAI',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your intelligent AI assistant',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _m3Card(
                  cs,
                  Icons.chat_rounded,
                  'Chat',
                  'Ask anything',
                  cardWidth,
                ),
                _m3Card(
                  cs,
                  Icons.functions_rounded,
                  'Math',
                  'LaTeX formulas',
                  cardWidth,
                ),
                _m3Card(
                  cs,
                  Icons.science_rounded,
                  'Chemistry',
                  'Equations',
                  cardWidth,
                ),
                _m3Card(
                  cs,
                  Icons.code_rounded,
                  'Code',
                  'Syntax highlight',
                  cardWidth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _m3Card(
    ColorScheme cs,
    IconData icon,
    String title,
    String subtitle,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHighest.withAlpha(200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(icon, size: 22, color: cs.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Desktop: Fluent UI ───
  Widget _buildFluentWelcome(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.accentColor.withValues(alpha: 0.8),
                  theme.accentColor.lighter,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                fluent.FluentIcons.robot,
                size: 36,
                color: fluent.Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to NexAI',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.typography.body?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your intelligent AI assistant',
            style: TextStyle(fontSize: 14, color: theme.inactiveColor),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _fluentCard(
                theme,
                isDark,
                fluent.FluentIcons.chat,
                'Chat',
                'Ask anything you want',
              ),
              _fluentCard(
                theme,
                isDark,
                fluent.FluentIcons.variable2,
                'Math',
                'Render LaTeX formulas',
              ),
              _fluentCard(
                theme,
                isDark,
                fluent.FluentIcons.test_beaker,
                'Chemistry',
                'Chemical equations',
              ),
              _fluentCard(
                theme,
                isDark,
                fluent.FluentIcons.code,
                'Code',
                'Syntax highlighted code',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fluentCard(
    fluent.FluentThemeData theme,
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return SizedBox(
      width: 180,
      child: fluent.Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 24, color: theme.accentColor),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: theme.inactiveColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
