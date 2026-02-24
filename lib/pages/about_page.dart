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

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // Large collapsing hero AppBar
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            expandedHeight: 220,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer.withAlpha(120),
                      cs.tertiaryContainer.withAlpha(60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Hero(
                        tag: 'nexai_logo',
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.tertiary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: cs.primary.withAlpha(70), blurRadius: 24, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Center(child: Icon(Icons.smart_toy_rounded, size: 40, color: cs.onPrimary)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('NexAI', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _VersionBadge(cs: cs, tt: tt, label: 'v1.0.0'),
                        const SizedBox(width: 8),
                        _VersionBadge(cs: cs, tt: tt, label: 'MIT', color: cs.tertiaryContainer, textColor: cs.onTertiaryContainer),
                      ]),
                    ],
                  ),
                ),
              ),
              title: Text('About', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Quick action buttons ──
                Row(children: [
                  Expanded(
                    child: _ActionCard(
                      cs: cs, tt: tt,
                      icon: Icons.code_rounded,
                      label: 'GitHub',
                      sublabel: 'View source',
                      onTap: () => _openUrl('https://github.com/Chloemlla/NexAI'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      cs: cs, tt: tt,
                      icon: Icons.bug_report_rounded,
                      label: 'Issues',
                      sublabel: 'Report a bug',
                      onTap: () => _openUrl('https://github.com/Chloemlla/NexAI/issues'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      cs: cs, tt: tt,
                      icon: Icons.person_rounded,
                      label: 'Author',
                      sublabel: 'Chloemlla',
                      onTap: () => _openUrl('https://github.com/Chloemlla'),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── App info ──
                _AboutCard(cs: cs, tt: tt, icon: Icons.info_outline_rounded, title: 'App Info', children: [
                  _InfoRow(cs: cs, tt: tt, label: 'Version', value: '1.0.0'),
                  _InfoRow(cs: cs, tt: tt, label: 'Developer', value: 'Chloemlla'),
                  _InfoRow(cs: cs, tt: tt, label: 'License', value: 'MIT'),
                  _InfoRow(cs: cs, tt: tt, label: 'Framework', value: 'Flutter + Material 3'),
                  _InfoRow(cs: cs, tt: tt, label: 'Repository', value: 'Chloemlla/NexAI', isLast: true),
                ]),
                const SizedBox(height: 14),

                // ── Features ──
                _AboutCard(cs: cs, tt: tt, icon: Icons.auto_awesome_rounded, title: 'Features', children: [
                  _FeatureRow(cs: cs, icon: Icons.chat_rounded, text: 'OpenAI-compatible API with custom base URL'),
                  _FeatureRow(cs: cs, icon: Icons.functions_rounded, text: 'LaTeX math & chemical formula rendering'),
                  _FeatureRow(cs: cs, icon: Icons.palette_rounded, text: 'Material You dynamic color (Android)'),
                  _FeatureRow(cs: cs, icon: Icons.code_rounded, text: 'Markdown with syntax-highlighted code'),
                  _FeatureRow(cs: cs, icon: Icons.desktop_windows_rounded, text: 'Fluent Design with Mica/Acrylic (Desktop)'),
                  _FeatureRow(cs: cs, icon: Icons.tune_roundcon, String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
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
            Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2)),
          ]),
          const SizedBox(height: 18),
          ...children,
        ]),
      ),
    );
  }

  Widget _m3InfoRow(ColorScheme cs, String label, String value) {
    return Row(children: [
      SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: cs.outline))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _m3Feature(ColorScheme cs, IconData icon, String text) {
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withAlpha(100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Icon(icon, size: 14, color: cs.primary)),
      ),
      const SizedBox(width: 12),
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
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
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
