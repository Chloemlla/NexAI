import 'package:flutter/material.dart';

import 'artifacts_page.dart';
import 'base64_converter_page.dart';
import 'date_time_converter_page.dart';
import 'image_generation_page.dart';
import 'password_generator_page.dart';
import 'short_url_page.dart';
import 'translation_page.dart';
import 'video_compressor_page.dart';
import 'video_to_audio_page.dart';
import '../theme/lumen_tokens.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  final _searchController = TextEditingController();
  _ToolCategory? _selectedCategory;
  String _searchQuery = '';

  late final List<_ToolEntry> _tools = [
    _ToolEntry(
      title: '视频压缩',
      description: '减小视频体积',
      keywords: const ['视频', '压缩', '媒体', '体积'],
      category: _ToolCategory.media,
      icon: Icons.video_file_rounded,
      pageBuilder: () => const VideoCompressorPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.primaryContainer, cs.secondaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _ToolEntry(
      title: '视频转音频',
      description: '批量提取音频',
      keywords: const ['视频', '音频', '提取', '媒体'],
      category: _ToolCategory.media,
      icon: Icons.audiotrack_rounded,
      pageBuilder: () => const VideoToAudioPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.tertiaryContainer, cs.secondaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _ToolEntry(
      title: '日期时间转换',
      description: '多种格式互转',
      keywords: const ['时间戳', '日期', '时间', '转换'],
      category: _ToolCategory.convert,
      icon: Icons.access_time_rounded,
      pageBuilder: () => const DateTimeConverterPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.tertiaryContainer, cs.primaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _ToolEntry(
      title: 'Base64 编解码',
      description: '字符串编码解码',
      keywords: const ['base64', '编码', '解码', '转换'],
      category: _ToolCategory.convert,
      icon: Icons.code_rounded,
      pageBuilder: () => const Base64ConverterPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.secondaryContainer, cs.tertiaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _ToolEntry(
      title: '密码生成器',
      description: '安全随机密码',
      keywords: const ['密码', '随机', '安全'],
      category: _ToolCategory.security,
      icon: Icons.password_rounded,
      pageBuilder: () => const PasswordGeneratorPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.primaryContainer, cs.tertiaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _ToolEntry(
      title: '短链接生成',
      description: '缩短长链接，便于分享',
      keywords: const ['短链', '短链接', '链接', 'URL', '分享'],
      category: _ToolCategory.network,
      icon: Icons.link_rounded,
      pageBuilder: () => const ShortUrlPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.secondaryContainer, cs.primaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _ToolEntry(
      title: '内容分享',
      description: '分享代码与文档',
      keywords: const ['分享', 'artifact', '文档', '代码'],
      category: _ToolCategory.network,
      icon: Icons.share_rounded,
      pageBuilder: () => const ArtifactsPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.tertiaryContainer, cs.primaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _ToolEntry(
      title: 'AI 翻译',
      description: 'Vertex AI 翻译',
      keywords: const ['翻译', 'AI', '语言'],
      category: _ToolCategory.ai,
      icon: Icons.translate_rounded,
      pageBuilder: () => const TranslationPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.primaryContainer, cs.secondaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _ToolEntry(
      title: 'AI 绘图',
      description: '使用 NexAI API 端点生成图片',
      keywords: const ['图片', '图像', '生成', 'AI', '绘图'],
      category: _ToolCategory.ai,
      icon: Icons.brush_rounded,
      pageBuilder: () => const ImageGenerationPage(),
      gradientBuilder: (cs) => LinearGradient(
        colors: [cs.tertiaryContainer, cs.secondaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  final List<String> _featuredToolTitles = const [
    'AI 翻译',
    '短链接生成',
    '密码生成器',
    'AI 绘图',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ToolEntry> get _filteredTools {
    final query = _searchQuery.trim().toLowerCase();

    return _tools.where((tool) {
      final categoryMatches =
          _selectedCategory == null || tool.category == _selectedCategory;
      if (!categoryMatches) return false;
      if (query.isEmpty) return true;
      return tool.searchText.contains(query);
    }).toList();
  }

  List<_ToolEntry> get _featuredTools => _featuredToolTitles
      .map((title) => _tools.firstWhere((tool) => tool.title == title))
      .toList();

  Map<_ToolCategory, List<_ToolEntry>> _groupTools(List<_ToolEntry> tools) {
    final grouped = <_ToolCategory, List<_ToolEntry>>{};
    for (final category in _ToolCategory.values) {
      final entries = tools.where((tool) => tool.category == category).toList();
      if (entries.isNotEmpty) {
        grouped[category] = entries;
      }
    }
    return grouped;
  }

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty || _selectedCategory != null;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
    });
  }

  void _openTool(_ToolEntry tool) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => tool.pageBuilder()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final hPad = LumenTokens.horizontalPaddingForWidth(
      MediaQuery.of(context).size.width,
    );
    final filteredTools = _filteredTools;
    final groupedTools = _groupTools(filteredTools);

    return Scaffold(
      backgroundColor: cs.brightness == Brightness.dark
          ? LumenTokens.backgroundDark
          : LumenTokens.background,
      body: CustomScrollView(
        key: const PageStorageKey('tools_page_scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                LumenTokens.pagePaddingTop + 8,
                hPad,
                0,
              ),
              child: Column(
                children: [
                  _buildIntroCard(cs, tt),
                  const SizedBox(height: LumenTokens.sectionGap),
                  _buildSearchPanel(cs, tt, filteredTools.length),
                ],
              ),
            ),
          ),
          if (filteredTools.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
                child: _buildEmptyState(cs),
              ),
            )
          else
            ...groupedTools.entries.expand((entry) {
              final category = entry.key;
              final tools = entry.value;
              return [
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    cs: cs,
                    icon: category.icon,
                    title: category.title,
                    subtitle: category.subtitle,
                    padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 12),
                    trailing: '${tools.length} 项',
                  ),
                ),
                SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isNarrow ? 180 : 200,
                        mainAxisSpacing: LumenTokens.sectionGap,
                        crossAxisSpacing: LumenTokens.sectionGap,
                        childAspectRatio: 0.92,
                      ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final tool = tools[index];
                      return _ToolCard(
                        icon: tool.icon,
                        title: tool.title,
                        description: tool.description,
                        gradient: tool.gradientBuilder(cs),
                        onTap: () => _openTool(tool),
                      );
                    }, childCount: tools.length),
                  ),
                ),
              ];
            }),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildIntroCard(ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: LumenTokens.cardBorderRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: LumenTokens.chipBorderRadius,
            ),
            child: Icon(
              Icons.build_circle_rounded,
              size: 24,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '按任务而不是按记忆找工具。',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '先搜再筛，常用能力放在前面，减少来回滚动和反复试错。',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(ColorScheme cs, TextTheme tt, int resultCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: LumenTokens.cardBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快速定位',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SearchBar(
            controller: _searchController,
            hintText: '搜索工具、功能或关键词',
            leading: const Icon(Icons.search_rounded, size: 20),
            trailing: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  onPressed: _resetFilters,
                  tooltip: '清除搜索',
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(
              cs.surfaceContainerHighest.withAlpha(180),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('全部'),
                selected: _selectedCategory == null,
                onSelected: (_) => setState(() => _selectedCategory = null),
              ),
              ..._ToolCategory.values.map(
                (category) => ChoiceChip(
                  label: Text(category.shortTitle),
                  avatar: Icon(category.icon, size: 16),
                  selected: _selectedCategory == category,
                  onSelected: (_) => setState(() {
                    _selectedCategory = _selectedCategory == category
                        ? null
                        : category;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _hasActiveFilter
                      ? '当前显示 $resultCount 个匹配工具'
                      : '共 ${_tools.length} 个工具，优先推荐常用入口',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              if (_hasActiveFilter)
                TextButton(onPressed: _resetFilters, child: const Text('重置')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _featuredTools
                .map(
                  (tool) => ActionChip(
                    avatar: Icon(tool.icon, size: 16, color: cs.primary),
                    label: Text(tool.title),
                    onPressed: () => _openTool(tool),
                    side: BorderSide(color: cs.outlineVariant.withAlpha(70)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: LumenTokens.cardBorderRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 34,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配工具',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '换个关键词，或者先清除分类筛选再试一次。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('清除筛选'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ToolCategory { media, convert, security, network, ai }

extension on _ToolCategory {
  String get shortTitle => switch (this) {
    _ToolCategory.media => '媒体',
    _ToolCategory.convert => '转换',
    _ToolCategory.security => '安全',
    _ToolCategory.network => '网络',
    _ToolCategory.ai => 'AI',
  };

  String get title => switch (this) {
    _ToolCategory.media => '媒体处理',
    _ToolCategory.convert => '编码转换',
    _ToolCategory.security => '安全工具',
    _ToolCategory.network => '网络工具',
    _ToolCategory.ai => 'AI 工具',
  };

  String get subtitle => switch (this) {
    _ToolCategory.media => '视频与多媒体工具',
    _ToolCategory.convert => '格式转换与编解码',
    _ToolCategory.security => '密码与加密相关',
    _ToolCategory.network => '网络辅助与内容分享',
    _ToolCategory.ai => '人工智能辅助',
  };

  IconData get icon => switch (this) {
    _ToolCategory.media => Icons.movie_filter_rounded,
    _ToolCategory.convert => Icons.swap_horiz_rounded,
    _ToolCategory.security => Icons.shield_rounded,
    _ToolCategory.network => Icons.language_rounded,
    _ToolCategory.ai => Icons.auto_awesome_rounded,
  };
}

class _ToolEntry {
  final String title;
  final String description;
  final List<String> keywords;
  final _ToolCategory category;
  final IconData icon;
  final Widget Function() pageBuilder;
  final Gradient Function(ColorScheme colorScheme) gradientBuilder;

  const _ToolEntry({
    required this.title,
    required this.description,
    required this.keywords,
    required this.category,
    required this.icon,
    required this.pageBuilder,
    required this.gradientBuilder,
  });

  String get searchText =>
      '$title $description ${keywords.join(' ')} ${category.title} ${category.shortTitle}'
          .toLowerCase();
}

class _SectionHeader extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String title;
  final String subtitle;
  final EdgeInsets padding;
  final String? trailing;

  const _SectionHeader({
    required this.cs,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.padding,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    letterSpacing: 0,
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
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.outline,
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
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
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: '打开${widget.title}',
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Card(
          color: _hovered ? cs.surfaceContainer : cs.surfaceContainerLow,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: LumenTokens.cardBorderRadius,
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHover: (value) => setState(() => _hovered = value),
            borderRadius: LumenTokens.cardBorderRadius,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: LumenTokens.cardBorderRadius,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: widget.gradient,
                      borderRadius: BorderRadius.circular(
                        LumenTokens.radiusMd,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 30,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.description,
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
                  const SizedBox(height: 10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: _hovered ? cs.primary : cs.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
