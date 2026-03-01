import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show isAndroid;

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version); // e.g. "1.0.6-abc1234"
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildM3About(context);
    return _buildFluentAbout(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildM3About(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 600;
    final hPad = isWide ? mq.size.width * 0.1 : 16.0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── Collapsing hero AppBar ──
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            expandedHeight: 230,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Text(
                '关于',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer.withAlpha(130),
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
                      const SizedBox(height: 20),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withAlpha(70),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.smart_toy_rounded,
                            size: 38,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'NexAI',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Badge(
                            label: _version.isNotEmpty ? 'v$_version' : '...',
                            bg: cs.secondaryContainer,
                            fg: cs.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          _Badge(
                            label: 'MIT',
                            bg: cs.tertiaryContainer,
                            fg: cs.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          _Badge(
                            label: 'Flutter',
                            bg: cs.primaryContainer,
                            fg: cs.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Quick action row ──
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        cs: cs,
                        icon: Icons.code_rounded,
                        label: 'GitHub',
                        sublabel: '查看源代码',
                        color: cs.primaryContainer,
                        iconColor: cs.onPrimaryContainer,
                        onTap: () =>
                            _openUrl('https://github.com/Chloemlla/NexAI'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionCard(
                        cs: cs,
                        icon: Icons.bug_report_rounded,
                        label: '问题',
                        sublabel: '报告错误',
                        color: cs.errorContainer,
                        iconColor: cs.onErrorContainer,
                        onTap: () => _openUrl(
                          'https://github.com/Chloemlla/NexAI/issues',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionCard(
                        cs: cs,
                        icon: Icons.person_rounded,
                        label: '作者',
                        sublabel: 'Chloemlla',
                        color: cs.tertiaryContainer,
                        iconColor: cs.onTertiaryContainer,
                        onTap: () => _openUrl('https://github.com/Chloemlla'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── App Info section ──
                _m3Section(cs, tt, Icons.info_outline_rounded, '应用信息', [
                  _m3InfoRow(cs, '版本', _version.isNotEmpty ? _version : '...'),
                  const SizedBox(height: 8),
                  _m3InfoRow(cs, '许可证', 'MIT'),
                  const SizedBox(height: 8),
                  _m3InfoRow(cs, '框架', 'Flutter'),
                ]),
                const SizedBox(height: 12),

                // ── Features section ──
                _m3Section(cs, tt, Icons.auto_awesome_rounded, '功能', [
                  _m3Feature(
                    cs,
                    Icons.chat_rounded,
                    'OpenAI 兼容 API，支持自定义基础 URL',
                  ),
                  const SizedBox(height: 8),
                  _m3Feature(cs, Icons.functions_rounded, 'LaTeX 数学和化学公式渲染'),
                  const SizedBox(height: 8),
                  _m3Feature(
                    cs,
                    Icons.color_lens_rounded,
                    'Material You 动态颜色（Android）',
                  ),
                  const SizedBox(height: 8),
                  _m3Feature(cs, Icons.code_rounded, '支持语法高亮的 Markdown 代码'),
                  const SizedBox(height: 8),
                  _m3Feature(cs, Icons.settings_rounded, '可配置的模型、温度和令牌'),
                ]),
                const SizedBox(height: 12),

                // ── Tech Stack section ──
                _m3Section(cs, tt, Icons.layers_rounded, '技术栈', [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in [
                        'Flutter',
                        'Provider',
                        'flutter_math_fork',
                        'flutter_markdown',
                        'dynamic_color',
                        'shared_preferences',
                      ])
                        _m3Chip(cs, label),
                    ],
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _m3Section(
    ColorScheme cs,
    TextTheme tt,
    IconData icon,
    String title,
    List<Widget> children,
  ) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _m3Chip(ColorScheme cs, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
      ),
    );
  }

  Widget _m3InfoRow(ColorScheme cs, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 13, color: cs.outline)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _m3Feature(ColorScheme cs, IconData icon, String text) {
    return Row(
      children: [
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
      ],
    );
  }

  // ─── Desktop: Fluent UI ───
  Widget _buildFluentAbout(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return fluent.ScaffoldPage.scrollable(
      header: const fluent.PageHeader(title: Text('关于')),
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
                  theme.accentColor.withValues(alpha: isDark ? 0.35 : 0.15),
                  theme.accentColor.lighter.withValues(
                    alpha: isDark ? 0.15 : 0.05,
                  ),
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
                        color: theme.accentColor.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      fluent.FluentIcons.robot,
                      size: 40,
                      color: fluent.Colors.white,
                    ),
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
                  _version.isNotEmpty ? 'v$_version' : '',
                  style: TextStyle(fontSize: 14, color: theme.inactiveColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '一个美观的 AI 聊天客户端，采用 Fluent Design',
                  style: TextStyle(fontSize: 14, color: theme.inactiveColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Author
        _fluentInfoCard(theme, fluent.FluentIcons.contact, '作者', [
          _fluentInfoRow(theme, '开发者', 'Chloemlla'),
          const SizedBox(height: 12),
          _fluentInfoRow(theme, 'GitHub', 'github.com/Chloemlla'),
          const SizedBox(height: 16),
          Row(
            children: [
              fluent.FilledButton(
                onPressed: () => _openUrl('https://github.com/Chloemlla'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(fluent.FluentIcons.open_in_new_tab, size: 14),
                    SizedBox(width: 8),
                    Text('作者资料'),
                  ],
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 12),

        // Project
        _fluentInfoCard(theme, fluent.FluentIcons.repo, '项目', [
          _fluentInfoRow(theme, '仓库', 'Chloemlla/NexAI'),
          const SizedBox(height: 12),
          _fluentInfoRow(theme, '许可证', 'MIT'),
          const SizedBox(height: 12),
          _fluentInfoRow(theme, '框架', 'Flutter + Fluent UI'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              fluent.FilledButton(
                onPressed: () => _openUrl('https://github.com/Chloemlla/NexAI'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(fluent.FluentIcons.open_in_new_tab, size: 14),
                    SizedBox(width: 8),
                    Text('在 GitHub 上查看'),
                  ],
                ),
              ),
              fluent.Button(
                onPressed: () =>
                    _openUrl('https://github.com/Chloemlla/NexAI/issues'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(fluent.FluentIcons.bug, size: 14),
                    SizedBox(width: 8),
                    Text('报告问题'),
                  ],
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 12),

        // Features
        _fluentInfoCard(theme, fluent.FluentIcons.sunny, '功能', [
          _fluentFeature(
            theme,
            fluent.FluentIcons.chat,
            'OpenAI 兼容 API，支持自定义基础 URL',
          ),
          const SizedBox(height: 10),
          _fluentFeature(
            theme,
            fluent.FluentIcons.variable2,
            'LaTeX 数学和化学公式渲染',
          ),
          const SizedBox(height: 10),
          _fluentFeature(
            theme,
            fluent.FluentIcons.color,
            'Material You 动态颜色（Android）',
          ),
          const SizedBox(height: 10),
          _fluentFeature(theme, fluent.FluentIcons.code, '支持语法高亮的 Markdown 代码'),
          const SizedBox(height: 10),
          _fluentFeature(
            theme,
            fluent.FluentIcons.design,
            'Fluent Design with Mica/Acrylic effects',
          ),
          const SizedBox(height: 10),
          _fluentFeature(theme, fluent.FluentIcons.settings, '可配置的模型、温度和令牌'),
        ]),
        const SizedBox(height: 12),

        // Tech stack
        _fluentInfoCard(theme, fluent.FluentIcons.developer_tools, '技术栈', [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in [
                'Flutter',
                'Fluent UI',
                'Provider',
                'flutter_math_fork',
                'flutter_markdown',
                'dynamic_color',
                'shared_preferences',
                'window_manager',
              ])
                _fluentChip(theme, label),
            ],
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _fluentInfoCard(
    fluent.FluentThemeData theme,
    IconData icon,
    String title,
    List<Widget> children,
  ) {
    return fluent.Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.accentColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _fluentInfoRow(
    fluent.FluentThemeData theme,
    String label,
    String value,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: theme.inactiveColor),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _fluentFeature(
    fluent.FluentThemeData theme,
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.accentColor),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Widget _fluentChip(fluent.FluentThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: theme.accentColor),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.cs,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(150),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, size: 18, color: iconColor)),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(fontSize: 10, color: cs.outline),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
