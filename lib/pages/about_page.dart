import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show isAndroid;

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildM3About(context);
    return _buildFluentAbout(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildM3About(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Hero card
        Card(
          elevation: 0,
          color: cs.primaryContainer.withAlpha((0.4 * 255).round()),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(child: Icon(Icons.smart_toy_rounded, size: 40, color: cs.onPrimaryContainer)),
                ),
                const SizedBox(height: 20),
                Text('NexAI', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('v1.0.0', style: tt.bodySmall?.copyWith(color: cs.outline)),
                const SizedBox(height: 6),
                Text('A beautiful AI chat client', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Author
        _m3Section(cs, tt, Icons.person_outline, 'Author', [
          _m3InfoRow(cs, 'Developer', 'Chloemlla'),
          const SizedBox(height: 10),
          _m3InfoRow(cs, 'GitHub', 'github.com/Chloemlla'),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: () => _openUrl('https://github.com/Chloemlla'),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.open_in_new_rounded, size: 16), SizedBox(width: 8), Text('Author Profile')]),
          ),
        ]),
        const SizedBox(height: 12),

        // Project
        _m3Section(cs, tt, Icons.folder_outlined, 'Project', [
          _m3InfoRow(cs, 'Repository', 'Chloemlla/NexAI'),
          const SizedBox(height: 10),
          _m3InfoRow(cs, 'License', 'MIT'),
          const SizedBox(height: 10),
          _m3InfoRow(cs, 'Framework', 'Flutter + Material 3'),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonal(
              onPressed: () => _openUrl('https://github.com/Chloemlla/NexAI'),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.open_in_new_rounded, size: 16), SizedBox(width: 8), Text('GitHub')]),
            ),
            OutlinedButton(
              onPressed: () => _openUrl('https://github.com/Chloemlla/NexAI/issues'),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bug_report_outlined, size: 16), SizedBox(width: 8), Text('Report Issue')]),
            ),
          ]),
        ]),
        const SizedBox(height: 12),

        // Features
        _m3Section(cs, tt, Icons.auto_awesome_outlined, 'Features', [
          _m3Feature(cs, Icons.chat_rounded, 'OpenAI-compatible API with custom base URL'),
          const SizedBox(height: 8),
          _m3Feature(cs, Icons.functions_rounded, 'LaTeX math & chemical formula rendering'),
          const SizedBox(height: 8),
          _m3Feature(cs, Icons.palette_rounded, 'Material You dynamic color (Android)'),
          const SizedBox(height: 8),
          _m3Feature(cs, Icons.code_rounded, 'Markdown with syntax-highlighted code'),
          const SizedBox(height: 8),
          _m3Feature(cs, Icons.desktop_windows_rounded, 'Fluent Design with Mica/Acrylic (Desktop)'),
          const SizedBox(height: 8),
          _m3Feature(cs, Icons.tune_rounded, 'Configurable models, temperature & tokens'),
        ]),
        const SizedBox(height: 12),

        // Tech stack
        _m3Section(cs, tt, Icons.build_outlined, 'Tech Stack', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final label in ['Flutter', 'Material 3', 'Provider', 'flutter_math_fork', 'flutter_markdown', 'dynamic_color', 'shared_preferences'])
              Chip(
                label: Text(label, style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer)),
                backgroundColor: cs.secondaryContainer,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
          ]),
        ]),
      ],
    );
  }

  Widget _m3Section(ColorScheme cs, TextTheme tt, IconData icon, String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ]),
      ),
    );
  }

  Widget _m3InfoRow(ColorScheme cs, String label, String value) {
    return Row(children: [
      SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: cs.outline))),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _m3Feature(ColorScheme cs, IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: cs.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]);
  }

  // ─── Desktop: Fluent UI ───
  Widget _buildFluentAbout(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return fluent.ScaffoldPage.scrollable(
      header: const fluent.PageHeader(title: Text('About')),
      children: [
        // Hero card
        fluent.Card(
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(theme.accentColor.value >> 16 & 0xFF, theme.accentColor.value >> 8 & 0xFF, theme.accentColor.value & 0xFF, isDark ? 0.35 : 0.15),
                  Color.fromRGBO(theme.accentColor.lighter.value >> 16 & 0xFF, theme.accentColor.lighter.value >> 8 & 0xFF, theme.accentColor.lighter.value & 0xFF, isDark ? 0.15 : 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.accentColor, theme.accentColor.lighter], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Color.fromRGBO(theme.accentColor.value >> 16 & 0xFF, theme.accentColor.value >> 8 & 0xFF, theme.accentColor.value & 0xFF, 0.35), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Center(child: Icon(fluent.FluentIcons.robot, size: 40, color: fluent.Colors.white)),
              ),
              const SizedBox(height: 20),
              Text('NexAI', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.typography.body?.color)),
              const SizedBox(height: 6),
              Text('v1.0.0', style: TextStyle(fontSize: 14, color: theme.inactiveColor)),
              const SizedBox(height: 8),
              Text('A beautiful AI chat client with Fluent Design', style: TextStyle(fontSize: 14, color: theme.inactiveColor)),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Author
        _fluentInfoCard(theme, fluent.FluentIcons.contact, 'Author', [
          _fluentInfoRow(theme, 'Developer', 'Chloemlla'),
          const SizedBox(height: 12),
          _fluentInfoRow(theme, 'GitHub', 'github.com/Chloemlla'),
          const SizedBox(height: 16),
          Row(children: [
            fluent.FilledButton(
              onPressed: () => _openUrl('https://github.com/Chloemlla'),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(fluent.FluentIcons.open_in_new_tab, size: 14), SizedBox(width: 8), Text('Author Profile')]),
            ),
          ]),
        ]),
        const SizedBox(height: 12),

        // Project
        _fluentInfoCard(theme, fluent.FluentIcons.repo, 'Project', [
          _fluentInfoRow(theme, 'Repository', 'Chloemlla/NexAI'),
          const SizedBox(height: 12),
          _fluentInfoRow(theme, 'License', 'MIT'),
          const SizedBox(height: 12),
          _fluentInfoRow(theme, 'Framework', 'Flutter + Fluent UI'),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 8, children: [
            fluent.FilledButton(
              onPressed: () => _openUrl('https://github.com/Chloemlla/NexAI'),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(fluent.FluentIcons.open_in_new_tab, size: 14), SizedBox(width: 8), Text('View on GitHub')]),
            ),
            fluent.Button(
              onPressed: () => _openUrl('https://github.com/Chloemlla/NexAI/issues'),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(fluent.FluentIcons.bug, size: 14), SizedBox(width: 8), Text('Report Issue')]),
            ),
          ]),
        ]),
        const SizedBox(height: 12),

        // Features
        _fluentInfoCard(theme, fluent.FluentIcons.sunny, 'Features', [
          _fluentFeature(theme, fluent.FluentIcons.chat, 'OpenAI-compatible API with custom base URL'),
          const SizedBox(height: 10),
          _fluentFeature(theme, fluent.FluentIcons.variable2, 'LaTeX math & chemical formula rendering'),
          const SizedBox(height: 10),
          _fluentFeature(theme, fluent.FluentIcons.color, 'Material You dynamic color (Android)'),
          const SizedBox(height: 10),
          _fluentFeature(theme, fluent.FluentIcons.code, 'Markdown with syntax-highlighted code'),
          const SizedBox(height: 10),
          _fluentFeature(theme, fluent.FluentIcons.design, 'Fluent Design with Mica/Acrylic effects'),
          const SizedBox(height: 10),
          _fluentFeature(theme, fluent.FluentIcons.settings, 'Configurable models, temperature & tokens'),
        ]),
        const SizedBox(height: 12),

        // Tech stack
        _fluentInfoCard(theme, fluent.FluentIcons.developer_tools, 'Tech Stack', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final label in ['Flutter', 'Fluent UI', 'Provider', 'flutter_math_fork', 'flutter_markdown', 'dynamic_color', 'shared_preferences', 'window_manager'])
              _fluentChip(theme, label),
          ]),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _fluentInfoCard(fluent.FluentThemeData theme, IconData icon, String title, List<Widget> children) {
    return fluent.Card(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: theme.accentColor),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 18),
        ...children,
      ]),
    );
  }

  Widget _fluentInfoRow(fluent.FluentThemeData theme, String label, String value) {
    return Row(children: [
      SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: theme.inactiveColor))),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _fluentFeature(fluent.FluentThemeData theme, IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 14, color: theme.accentColor),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]);
  }

  Widget _fluentChip(fluent.FluentThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color.fromRGBO(theme.accentColor.value >> 16 & 0xFF, theme.accentColor.value >> 8 & 0xFF, theme.accentColor.value & 0xFF, 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color.fromRGBO(theme.accentColor.value >> 16 & 0xFF, theme.accentColor.value >> 8 & 0xFF, theme.accentColor.value & 0xFF, 0.3)),
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
