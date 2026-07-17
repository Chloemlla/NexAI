import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/oss_dependency_credits.dart';
import '../providers/settings_provider.dart';
import '../utils/build_config.dart';
import '../theme/lumen_tokens.dart';
import '../widgets/lumen/lumen.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  int _developerTapCount = 0;

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
    return _buildM3About(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildM3About(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 600;
    final hasLeading = ModalRoute.of(context)?.canPop ?? false;
    final hPad = LumenTokens.horizontalPaddingForWidth(mq.size.width);

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(cs),
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Stack(
          children: [
            Positioned.fill(
              bottom: 58 + mq.padding.bottom,
              child: CustomScrollView(
                slivers: [
                  // ── Collapsing hero AppBar ──
                  SliverAppBar(
                    automaticallyImplyLeading: true,
                    pinned: true,
                    expandedHeight: isWide ? 250 : 270,
                    backgroundColor: cs.surface,
                    surfaceTintColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      titlePadding: EdgeInsets.only(
                        left: hasLeading ? (kToolbarHeight + 20) : 20,
                        right: 16,
                        bottom: 14,
                      ),
                      title: Text(
                        '关于',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      background: Container(
                        color: lumenScaffoldBackground(cs),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              hPad,
                              kToolbarHeight + 16,
                              hPad,
                              28,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: LumenTokens.maxContentWidth,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/app_icon_runtime.png',
                                      width: 76,
                                      height: 76,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'NexAI',
                                      style: tt.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _Badge(
                                          label: _version.isNotEmpty
                                              ? 'v$_version'
                                              : '...',
                                          bg: cs.secondaryContainer,
                                          fg: cs.onSecondaryContainer,
                                          onTap: _handleDeveloperEggTap,
                                        ),
                                        _Badge(
                                          label: 'GPL-3.0 license',
                                          bg: cs.tertiaryContainer,
                                          fg: cs.onTertiaryContainer,
                                        ),
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
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
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
                                onTap: () => _openUrl(
                                  'https://github.com/Chloemlla/NexAI',
                                ),
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                cs: cs,
                                icon: Icons.system_update_rounded,
                                label: '应用下载',
                                sublabel: '获取最新发行版',
                                color: cs.secondaryContainer,
                                iconColor: cs.onSecondaryContainer,
                                onTap: () => _openUrl(
                                  'https://github.com/Chloemlla/NexAI/releases/latest',
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
                                onTap: () =>
                                    _openUrl('https://github.com/Chloemlla'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── App Info section ──
                        _m3Section(cs, tt, Icons.info_outline_rounded, '应用信息', [
                          _m3InfoRow(
                            cs,
                            '版本',
                            _version.isNotEmpty ? _version : '...',
                            onTap: _handleDeveloperEggTap,
                          ),
                          if (BuildConfig.buildTime > 0) ...[
                            const SizedBox(height: 8),
                            _m3InfoRow(cs, '构建号', '${BuildConfig.versionCode}'),
                          ],
                          const SizedBox(height: 8),
                          _m3InfoRow(cs, '许可证', 'GPL-3.0 license'),
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
                          _m3Feature(
                            cs,
                            Icons.functions_rounded,
                            'LaTeX 数学和化学公式渲染',
                          ),
                          const SizedBox(height: 8),
                          _m3Feature(
                            cs,
                            Icons.color_lens_rounded,
                            'Material You 动态颜色（Android）',
                          ),
                          const SizedBox(height: 8),
                          _m3Feature(
                            cs,
                            Icons.code_rounded,
                            '支持语法高亮的 Markdown 代码',
                          ),
                          const SizedBox(height: 8),
                          _m3Feature(
                            cs,
                            Icons.settings_rounded,
                            '可配置的模型、温度和令牌',
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // ── Tech Stack section ──
                        _m3Section(cs, tt, Icons.layers_rounded, '技术栈', [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final credit in kOssDependencyCredits)
                                _m3Chip(cs, credit.name),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // ── Open-source credits ──
                        _m3Section(
                          cs,
                          tt,
                          Icons.favorite_outline_rounded,
                          '开源致谢',
                          [
                            for (var i = 0;
                                i < kOssDependencyCredits.length;
                                i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _CreditRow(
                                name: kOssDependencyCredits[i].name,
                                author: kOssDependencyCredits[i].author,
                                description:
                                    kOssDependencyCredits[i].description,
                                license: kOssDependencyCredits[i].license,
                                onTap: kOssDependencyCredits[i].url == null
                                    ? null
                                    : () => _openUrl(
                                          kOssDependencyCredits[i].url!,
                                        ),
                              ),
                            ],
                          ],
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _AboutFooter(cs: cs, onTap: _handleDeveloperEggTap),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeveloperEggTap() async {
    HapticFeedback.selectionClick();
    final nextCount = _developerTapCount + 1;
    if (nextCount < 7) {
      setState(() => _developerTapCount = nextCount);
      return;
    }

    setState(() => _developerTapCount = 0);
    await context.read<SettingsProvider>().unlockDeveloperDebugMode();
    HapticFeedback.mediumImpact();
    SmartDialog.showToast('您已进入极客开发者世界');
  }

  Widget _m3Section(
    ColorScheme cs,
    TextTheme tt,
    IconData icon,
    String title,
    List<Widget> children,
  ) {
    return LumenActionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LumenSectionHeader(icon: icon, title: title),
          const SizedBox(height: 18),
          ...children,
        ],
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

  Widget _m3InfoRow(
    ColorScheme cs,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final row = Row(
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

    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: row,
      ),
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
            borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
          ),
          child: Center(child: Icon(icon, size: 14, color: cs.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        SmartDialog.showToast('无法打开链接');
      }
    } catch (_) {
      SmartDialog.showToast('无法打开链接');
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  const _Badge({
    required this.label,
    required this.bg,
    required this.fg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LumenTokens.radiusSm);
    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutFooter extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onTap;

  const _AboutFooter({required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: cs.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant.withAlpha(110)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Powered by',
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withAlpha(170),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'NexAI',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    return LumenActionCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        children: [
          LumenIconChip(
            icon: icon,
            size: 36,
            iconSize: 18,
            backgroundColor: color.withAlpha(150),
            foregroundColor: iconColor,
            shape: LumenIconChipShape.rounded,
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
    );
  }
}

class _CreditRow extends StatelessWidget {
  final String name;
  final String author;
  final String description;
  final String license;
  final VoidCallback? onTap;

  const _CreditRow({
    required this.name,
    required this.author,
    required this.description,
    required this.license,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '$author · $license',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 12)),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}
