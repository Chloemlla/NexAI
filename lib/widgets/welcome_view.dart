import 'package:fluent_ui/fluent_ui.dart';

import '../main.dart' show isAndroid;

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final logoSize = isAndroid ? 64.0 : 80.0;
    final logoIconSize = isAndroid ? 28.0 : 36.0;
    final titleSize = isAndroid ? 22.0 : 28.0;
    final cardWidth = isAndroid
        ? (screenWidth < 400 ? (screenWidth - 56) / 2 : 150.0)
        : 180.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isAndroid ? 16 : 24,
          vertical: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.accentColor.withOpacity(0.8),
                    theme.accentColor.lighter,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isAndroid ? 20 : 24),
                boxShadow: [
                  BoxShadow(
                    color: theme.accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(FluentIcons.robot, size: logoIconSize, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to NexAI',
              style: TextStyle(
                fontSize: titleSize,
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
                _buildHintCard(theme, isDark, FluentIcons.chat, 'Chat', 'Ask anything you want', cardWidth),
                _buildHintCard(theme, isDark, FluentIcons.variable2, 'Math', 'Render LaTeX formulas', cardWidth),
                _buildHintCard(theme, isDark, FluentIcons.test_beaker, 'Chemistry', 'Chemical equations', cardWidth),
                _buildHintCard(theme, isDark, FluentIcons.code, 'Code', 'Syntax highlighted code', cardWidth),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintCard(FluentThemeData theme, bool isDark, IconData icon, String title, String subtitle, double width) {
    return SizedBox(
      width: width,
      child: Card(
        padding: EdgeInsets.all(isAndroid ? 12 : 16),
        child: Column(
          children: [
            Icon(icon, size: isAndroid ? 20 : 24, color: theme.accentColor),
            SizedBox(height: isAndroid ? 8 : 10),
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
