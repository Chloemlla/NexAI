import 'package:flutter/material.dart';
import 'video_compressor_page.dart';
import 'video_to_audio_page.dart';
import 'date_time_converter_page.dart';
import 'base64_converter_page.dart';
import 'password_generator_page.dart';
import 'short_url_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final hPad = isNarrow ? 20.0 : 28.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withAlpha(50),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.build_circle_rounded, size: 24, color: cs.onPrimary),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '工具箱',
                            style: tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '实用工具集合，提升效率',
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Section: 媒体处理 ──
          SliverToBoxAdapter(
            child: _SectionHeader(
              cs: cs,
              icon: Icons.movie_filter_rounded,
              title: '媒体处理',
              subtitle: '视频与多媒体工具',
              padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 12),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isNarrow ? 180 : 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildListDelegate([
                _ToolCard(
                  icon: Icons.video_file_rounded,
                  title: '视频压缩',
                  description: '减小视频体积',
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.secondaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VideoCompressorPage()),
                  ),
                ),
                _ToolCard(
                  icon: Icons.audiotrack_rounded,
                  title: '视频转音频',
                  description: '批量提取音频',
                  gradient: LinearGradient(
                    colors: [cs.tertiaryContainer, cs.secondaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VideoToAudioPage()),
                  ),
                ),
              ]),
            ),
          ),

          // ── Section: 编码转换 ──
          SliverToBoxAdapter(
            child: _SectionHeader(
              cs: cs,
              icon: Icons.swap_horiz_rounded,
              title: '编码转换',
              subtitle: '格式转换与编解码',
              padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 12),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isNarrow ? 180 : 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildListDelegate([
                _ToolCard(
                  icon: Icons.access_time_rounded,
                  title: '日期时间转换',
                  description: '多种格式互转',
                  gradient: LinearGradient(
                    colors: [cs.tertiaryContainer, cs.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DateTimeConverterPage()),
                  ),
                ),
                _ToolCard(
                  icon: Icons.code_rounded,
                  title: 'Base64 编解码',
                  description: '字符串编码解码',
                  gradient: LinearGradient(
                    colors: [cs.secondaryContainer, cs.tertiaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const Base64ConverterPage()),
                  ),
                ),
              ]),
            ),
          ),

          // ── Section: 安全工具 ──
          SliverToBoxAdapter(
            child: _SectionHeader(
              cs: cs,
              icon: Icons.shield_rounded,
              title: '安全工具',
              subtitle: '密码与加密相关',
              padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 12),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isNarrow ? 180 : 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildListDelegate([
                _ToolCard(
                  icon: Icons.password_rounded,
                  title: '密码生成器',
                  description: '安全随机密码',
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.tertiaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PasswordGeneratorPage()),
                  ),
                ),
              ]),
            ),
          ),

          // ── Section: 网络工具 ──
          SliverToBoxAdapter(
            child: _SectionHeader(
              cs: cs,
              icon: Icons.language_rounded,
              title: '网络工具',
              subtitle: '网络辅助与转换',
              padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 12),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 40),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isNarrow ? 180 : 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildListDelegate([
                _ToolCard(
                  icon: Icons.link_rounded,
                  title: '短链接生成',
                  description: '快速缩短 URL',
                  gradient: LinearGradient(
                    colors: [cs.secondaryContainer, cs.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShortUrlPage()),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header widget ──
class _SectionHeader extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String title;
  final String subtitle;
  final EdgeInsets padding;

  const _SectionHeader({
    required this.cs,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(140),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(child: Icon(icon, size: 16, color: cs.primary)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.outline,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tool card widget ──
class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: cs.outlineVariant.withAlpha(40),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withAlpha(35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, size: 32, color: cs.onPrimaryContainer),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
