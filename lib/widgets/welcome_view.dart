import 'package:fluent_ui/fluent_ui.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
                  theme.accentColor.withOpacity(0.8),
                  theme.accentColor.lighter,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(FluentIcons.robot, size: 36, color: Colors.white),
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
              _buildHintCard(theme, isDark, FluentIcons.chat, 'Chat', 'Ask anything you want'),
              _buildHintCard(theme, isDark, FluentIcons.variable2, 'Math', 'Render LaTeX formulas'),
              _buildHintCard(theme, isDark, FluentIcons.test_beaker, 'Chemistry', 'Chemical equations supported'),
              _buildHintCard(theme, isDark, FluentIcons.code, 'Code', 'Syntax highlighted code'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHintCard(FluentThemeData theme, bool isDark, IconData icon, String title, String subtitle) {
    return SizedBox(
      width: 180,
      child: Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 24, color: theme.accentColor),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
