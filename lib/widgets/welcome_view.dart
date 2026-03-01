import 'package:flutter/material.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildWelcome(context);
  }

  Widget _buildWelcome(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;
    final cardWidth = isWide ? 180.0 : (screenWidth - 52) / 2;

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
                _welcomeCard(
                  cs,
                  Icons.chat_rounded,
                  'Chat',
                  'Ask anything',
                  cardWidth,
                ),
                _welcomeCard(
                  cs,
                  Icons.functions_rounded,
                  'Math',
                  'LaTeX formulas',
                  cardWidth,
                ),
                _welcomeCard(
                  cs,
                  Icons.science_rounded,
                  'Chemistry',
                  'Equations',
                  cardWidth,
                ),
                _welcomeCard(
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

  Widget _welcomeCard(
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
}
