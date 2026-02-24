import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('About')),
      children: [
        // Hero card
        Card(
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: [
                  theme.accentColor.withOpacity(isDark ? 0.35 : 0.15),
                  theme.accentColor.lighter.withOpacity(isDark ? 0.15 : 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.accentColor, theme.accentColor.lighter],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(FluentIcons.robot, size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'NexAI',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.typography.body?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'v1.0.0',
                  style: TextStyle(fontSize: 14, color: theme.inactiveColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'A beautiful AI chat client with Fluent Design',
                  style: TextStyle(fontSize: 14, color: theme.inactiveColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Author card
        _buildInfoCard(
          theme,
          icon: FluentIcons.contact,
          title: 'Author',
          children: [
            _infoRow(theme, 'Developer', 'Chloemlla'),
            const SizedBox(height: 12),
            _infoRow(theme, 'GitHub', 'github.com/Chloemlla'),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: () => _openUrl('https://github.com/Chloemlla'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.open_in_new_tab, size: 14),
                      SizedBox(width: 8),
                      Text('Author Profile'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Project card
        _buildInfoCard(
          theme,
          icon: FluentIcons.repo,
          title: 'Project',
          children: [
            _infoRow(theme, 'Repository', 'Chloemlla/NexAI'),
            const SizedBox(height: 12),
            _infoRow(theme, 'License', 'MIT'),
            const SizedBox(height: 12),
            _infoRow(theme, 'Framework', 'Flutter + Fluent UI'),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: () => _openUrl('https://github.com/Chloemlla/NexAI'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.open_in_new_tab, size: 14),
                      SizedBox(width: 8),
                      Text('View on GitHub'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Button(
                  onPressed: () => _openUrl('https://github.com/Chloemlla/NexAI/issues'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.bug, size: 14),
                      SizedBox(width: 8),
                      Text('Report Issue'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Features card
        _buildInfoCard(
          theme,
          icon: FluentIcons.sparkle,
          title: 'Features',
          children: [
            _featureItem(theme, FluentIcons.chat, 'OpenAI-compatible API with custom base URL'),
            const SizedBox(height: 10),
            _featureItem(theme, FluentIcons.variable2, 'LaTeX math & chemical formula rendering'),
            const SizedBox(height: 10),
            _featureItem(theme, FluentIcons.color, 'Material You dynamic color (Android)'),
            const SizedBox(height: 10),
            _featureItem(theme, FluentIcons.code, 'Markdown with syntax-highlighted code'),
            const SizedBox(height: 10),
            _featureItem(theme, FluentIcons.design, 'Fluent Design with Mica/Acrylic effects'),
            const SizedBox(height: 10),
            _featureItem(theme, FluentIcons.settings, 'Configurable models, temperature & tokens'),
          ],
        ),
        const SizedBox(height: 12),

        // Tech stack
        _buildInfoCard(
          theme,
          icon: FluentIcons.developer_tools,
          title: 'Tech Stack',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(theme, 'Flutter'),
                _chip(theme, 'Fluent UI'),
                _chip(theme, 'Provider'),
                _chip(theme, 'flutter_math_fork'),
                _chip(theme, 'flutter_markdown'),
                _chip(theme, 'dynamic_color'),
                _chip(theme, 'shared_preferences'),
                _chip(theme, 'window_manager'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoCard(FluentThemeData theme, {required IconData icon, required String title, required List<Widget> children}) {
    return Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.accentColor),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(FluentThemeData theme, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 13, color: theme.inactiveColor)),
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _featureItem(FluentThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.accentColor),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Widget _chip(FluentThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accentColor.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: theme.accentColor)),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
