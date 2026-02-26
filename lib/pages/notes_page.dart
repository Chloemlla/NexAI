import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import 'note_detail_page.dart';
import 'graph_page.dart';

final _taskItemRegex = RegExp(r'^\s*-\s+\[([ xX])\]\s+', multiLine: true);

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

enum _NotesTab { all, starred, recent, tags }

class _NotesPageState extends State<NotesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _selectedTag;
  bool _showSearch = true;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTag = null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notesProvider = context.watch<NotesProvider>();

    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
            const _ToggleSearchIntent(),
      },
      child: Actions(
        actions: {
          _ToggleSearchIntent: CallbackAction<_ToggleSearchIntent>(
            onInvoke: (_) {
              setState(() {
                _showSearch = !_showSearch;
                if (_showSearch) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
                }
              });
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              surfaceTintColor: cs.surfaceTint,
              title: Row(
                children: [
                  Icon(Icons.note_alt_rounded, size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  const Text('笔记', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                ],
              ),
              actions: [
                // 知识图谱按钮
                IconButton(
                  icon: Icon(Icons.hub_rounded, size: 22, color: cs.onSurfaceVariant),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GraphPage()),
                    );
                  },
                  tooltip: '知识图谱',
                ),
              ],
            ),
            body: Column(
              children: [
                // Search bar (toggleable)
                if (_showSearch) _buildSearchBar(cs),
                // Tab bar
                _buildTabBar(cs),
                // Content
                Expanded(child: _buildTabContent(cs, notesProvider)),
              ],
            ),
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 知识图谱浮动按钮
                FloatingActionButton(
                  heroTag: 'graph_fab',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GraphPage()),
                    );
                  },
                  child: const Icon(Icons.hub_rounded),
                  tooltip: '知识图谱',
                  elevation: 2,
                ),
                const SizedBox(height: 12),
                // 创建笔记按钮
                FloatingActionButton.extended(
                  heroTag: 'create_fab',
                  onPressed: () => _createAndOpen(context, notesProvider),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('创建笔记'),
                  elevation: 4,
                  tooltip: '创建新笔记',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SearchBar(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (v) => setState(() => _searchQuery = v),
        hintText: '搜索笔记...',
        hintStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 14, color: cs.onSurfaceVariant.withAlpha(160)),
        ),
        leading: Icon(Icons.search_rounded, size: 22, color: cs.onSurfaceVariant),
        trailing: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, size: 20, color: cs.onSurfaceVariant),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              tooltip: '清除',
            ),
          IconButton(
            icon: Icon(Icons.tune_rounded, size: 20, color: cs.onSurfaceVariant),
            onPressed: _showSearchHelp,
            tooltip: '搜索提示',
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _showSearch = false;
              });
            },
            tooltip: '关闭搜索',
          ),
        ],
        elevation: WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerLow),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
      ),
    );
  }

  void _showSearchHelp() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.help_outline_rounded, color: cs.primary),
        title: const Text('搜索提示'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _searchTip(cs, '"精确短语"', '查找精确匹配'),
              _searchTip(cs, 'tag:项目', '按标签筛选'),
              _searchTip(cs, 'is:starred', '显示星标笔记'),
              _searchTip(cs, '/正则表达式/', '使用正则表达式'),
              _searchTip(cs, '术语1 AND 术语2', '两个术语都必须匹配'),
              _searchTip(cs, '术语1 OR 术语2', '任一术语匹配'),
              _searchTip(cs, 'NOT 术语', '排除术语'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('明白了'),
          ),
        ],
      ),
    );
  }

  Widget _searchTip(ColorScheme cs, String syntax, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cs.outlineVariant.withAlpha(100)),
            ),
            child: Text(
              syntax,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withAlpha(60), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        unselectedLabelStyle: const TextStyle(fontSize: 13, letterSpacing: 0.1),
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.primary, width: 3),
          ),
        ),
        dividerHeight: 0,
        tabs: const [
          Tab(text: '全部', icon: Icon(Icons.notes_rounded, size: 20)),
          Tab(text: '星标', icon: Icon(Icons.star_rounded, size: 20)),
          Tab(text: '最近', icon: Icon(Icons.history_rounded, size: 20)),
          Tab(text: '标签', icon: Icon(Icons.local_offer_rounded, size: 20)),
        ],
      ),
    );
  }

  Widget _buildTabContent(ColorScheme cs, NotesProvider provider) {
    // If searching, show search results across all notes
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults(cs, provider);
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAllNotes(cs, provider),
        _buildStarredNotes(cs, provider),
        _buildRecentNotes(cs, provider),
        _buildTagsView(cs, provider),
      ],
    );
  }

  Widget _buildSearchResults(ColorScheme cs, NotesProvider provider) {
    final results = provider.searchNotes(_searchQuery);
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('未找到 "$_searchQuery" 的结果', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 4),
            Text('尝试："精确匹配"、tag:名称、is:starred、/正则表达式/',
                style: TextStyle(color: cs.outlineVariant, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, idx) {
        final r = results[idx];
        return _NoteCard(
          note: r.note,
          highlightTerms: _extractHighlightTerms(_searchQuery),
        );
      },
    );
  }

  List<String> _extractHighlightTerms(String query) {
    final terms = <String>[];
    final cleaned = query
        .replaceAll(RegExp(r'\b(and|or|not|tag:\S+|is:\S+)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[/"]'), '')
        .trim();
    if (cleaned.isNotEmpty) {
      terms.addAll(cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty));
    }
    return terms;
  }

  Widget _buildAllNotes(ColorScheme cs, NotesProvider provider) {
    final notes = provider.notes;
    if (notes.isEmpty) return _buildEmptyState(cs, provider);
    
    // 如果有笔记且有链接，显示知识图谱提示卡片
    final graphData = provider.getGraphData();
    final showGraphHint = notes.length >= 3 && graphData.edges.isNotEmpty;
    
    if (showGraphHint) {
      return Column(
        children: [
          // 知识图谱提示卡片
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Card(
              elevation: 0,
              color: cs.tertiaryContainer.withAlpha(120),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.tertiary.withAlpha(60), width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GraphPage()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.hub_rounded, size: 20, color: cs.onTertiaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '查看 ${graphData.nodes.length} 个笔记的 ${graphData.edges.length} 条连接',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: cs.tertiary, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildNotesList(notes)),
        ],
      );
    }
    
    return _buildNotesList(notes);
  }

  Widget _buildStarredNotes(ColorScheme cs, NotesProvider provider) {
    final notes = provider.starredNotes;
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline_rounded, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('没有星标笔记', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 4),
            Text('为重要笔记加星标以便快速访问',
                style: TextStyle(color: cs.outlineVariant, fontSize: 12)),
          ],
        ),
      );
    }
    return _buildNotesList(notes);
  }

  Widget _buildRecentNotes(ColorScheme cs, NotesProvider provider) {
    final notes = provider.recentNotes;
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('没有最近的笔记', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 4),
            Text('您打开的笔记将显示在此处',
                style: TextStyle(color: cs.outlineVariant, fontSize: 12)),
          ],
        ),
      );
    }
    return _buildNotesList(notes);
  }

  Widget _buildTagsView(ColorScheme cs, NotesProvider provider) {
    final tags = provider.allTags;

    if (_selectedTag != null) {
      final notes = provider.notesByTag(_selectedTag!);
      return Column(
        children: [
          // Back to tags list
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _selectedTag = null),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text('标签', style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 16, color: cs.outline),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('#$_selectedTag',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                ),
                const Spacer(),
                Text('${notes.length}', style: TextStyle(fontSize: 12, color: cs.outline)),
              ],
            ),
          ),
          Expanded(child: _buildNotesList(notes)),
        ],
      );
    }

    if (tags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag_rounded, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('还没有标签', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 4),
            Text('在笔记中使用 #tag 来组织它们',
                style: TextStyle(color: cs.outlineVariant, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 知识图谱卡片
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Card(
            elevation: 0,
            color: cs.primaryContainer.withAlpha(120),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.primary.withAlpha(60), width: 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GraphPage()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withAlpha(60),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.hub_rounded, size: 24, color: cs.onPrimary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '知识图谱',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '可视化笔记之间的连接关系',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onPrimaryContainer.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: cs.primary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 标签列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            itemCount: tags.length,
            itemBuilder: (_, idx) {
              final tag = tags[idx];
              final isNested = tag.name.contains('/');
              return _TagTile(
                tag: tag,
                isNested: isNested,
                onTap: () => setState(() => _selectedTag = tag.name),
                onRename: () => _showRenameTagDialog(tag.name),
                onDelete: () => _showDeleteTagDialog(tag.name),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRenameTagDialog(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名标签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('所有 #$oldTag 的出现都将被替换。',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '新标签名称',
                prefixText: '#',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final newTag = controller.text.trim();
              if (newTag.isNotEmpty && newTag != oldTag) {
                context.read<NotesProvider>().renameTag(oldTag, newTag);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTagDialog(String tag) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('从所有笔记中删除 #$tag?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              context.read<NotesProvider>().deleteTag(tag);
              Navigator.of(ctx).pop();
              setState(() => _selectedTag = null);
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, NotesProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primaryContainer, cs.secondaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withAlpha(40),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.note_add_rounded,
                  size: 48,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有笔记',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 20,
                letterSpacing: 0.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '创建您的第一条笔记以开始',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                letterSpacing: 0.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _createAndOpen(context, provider),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('创建笔记'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList(List<Note> notes) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, index) => _NoteCard(note: notes[index]),
    );
  }

  void _createAndOpen(BuildContext context, NotesProvider provider) {
    final note = provider.createNote();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: note.id)),
    );
  }
}

class _ToggleSearchIntent extends Intent {
  const _ToggleSearchIntent();
}

class _TagTile extends StatelessWidget {
  final TagInfo tag;
  final bool isNested;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TagTile({
    required this.tag,
    required this.isNested,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = tag.name.split('/');

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    isNested ? Icons.folder_outlined : Icons.tag_rounded,
                    size: 16, color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNested)
                      Row(
                        children: [
                          for (int i = 0; i < parts.length; i++) ...[
                            if (i > 0) Icon(Icons.chevron_right_rounded, size: 14, color: cs.outline),
                            Text(parts[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: i == parts.length - 1 ? FontWeight.w600 : FontWeight.w400,
                                  color: i == parts.length - 1 ? cs.onSurface : cs.onSurfaceVariant,
                                )),
                          ],
                        ],
                      )
                    else
                      Text('#${tag.name}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    Text('${tag.count} 条笔记${tag.count != 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 11, color: cs.outline)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: cs.outline),
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final List<String> highlightTerms;

  const _NoteCard({required this.note, this.highlightTerms = const []});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = note.content.length > 120
        ? '${note.content.substring(0, 120)}...'
        : note.content;
    final timeStr = _formatTime(note.updatedAt);
    final tags = note.tags;

    final tasks = _taskItemRegex.allMatches(note.content);
    final taskTotal = tasks.length;
    final taskDone = tasks.where((m) => m.group(1)!.trim().toLowerCase() == 'x').length;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          context.read<NotesProvider>().markViewed(note.id);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: note.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: taskTotal > 0
                            ? [cs.tertiaryContainer, cs.tertiary.withAlpha(100)]
                            : [cs.primaryContainer, cs.primary.withAlpha(100)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (taskTotal > 0 ? cs.tertiary : cs.primary).withAlpha(30),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        taskTotal > 0 ? Icons.checklist_rounded : Icons.description_rounded,
                        size: 20,
                        color: taskTotal > 0 ? cs.onTertiaryContainer : cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: highlightTerms.isEmpty
                        ? Text(
                            note.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: cs.onSurface,
                              letterSpacing: 0.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : _HighlightText(
                            text: note.title,
                            terms: highlightTerms,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: cs.onSurface,
                              letterSpacing: 0.15,
                            ),
                            highlightColor: cs.primary.withAlpha(80),
                          ),
                  ),
                  // Star button
                  IconButton(
                    icon: Icon(
                      note.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 22,
                      color: note.isStarred ? Colors.amber.shade600 : cs.onSurfaceVariant,
                    ),
                    onPressed: () => context.read<NotesProvider>().toggleStar(note.id),
                    visualDensity: VisualDensity.compact,
                    tooltip: note.isStarred ? '取消星标' : '星标',
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDelete(context);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
                            const SizedBox(width: 12),
                            Text('删除', style: TextStyle(color: cs.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 12),
                highlightTerms.isEmpty
                    ? Text(
                        preview,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                          letterSpacing: 0.25,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      )
                    : _HighlightText(
                        text: preview,
                        terms: highlightTerms,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                          letterSpacing: 0.25,
                        ),
                        highlightColor: cs.primary.withAlpha(80),
                        maxLines: 3,
                      ),
              ],
              // Tags row
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: tags.take(5).map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: cs.secondary.withAlpha(60),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tag_rounded,
                            size: 12,
                            color: cs.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Divider(height: 1, color: cs.outlineVariant.withAlpha(60)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (taskTotal > 0) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: taskDone == taskTotal
                            ? Colors.green.withAlpha(40)
                            : cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: taskDone == taskTotal
                              ? Colors.green.withAlpha(100)
                              : cs.tertiary.withAlpha(60),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            taskDone == taskTotal
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 12,
                            color: taskDone == taskTotal
                                ? Colors.green.shade700
                                : cs.onTertiaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$taskDone/$taskTotal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: taskDone == taskTotal
                                  ? Colors.green.shade700
                                  : cs.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.text_fields_rounded, size: 14, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${note.content.trim().isEmpty ? 0 : note.content.trim().split(RegExp(r'\s+')).length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('删除 "${note.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              context.read<NotesProvider>().deleteNote(note.id);
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

/// Highlights search terms in text
class _HighlightText extends StatelessWidget {
  final String text;
  final List<String> terms;
  final TextStyle style;
  final Color highlightColor;
  final int? maxLines;

  const _HighlightText({
    required this.text,
    required this.terms,
    required this.style,
    required this.highlightColor,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
    }

    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    int pos = 0;

    while (pos < text.length) {
      int earliest = text.length;
      String? matchedTerm;
      for (final term in terms) {
        final idx = lower.indexOf(term.toLowerCase(), pos);
        if (idx != -1 && idx < earliest) {
          earliest = idx;
          matchedTerm = term;
        }
      }

      if (matchedTerm == null) {
        spans.add(TextSpan(text: text.substring(pos)));
        break;
      }

      if (earliest > pos) {
        spans.add(TextSpan(text: text.substring(pos, earliest)));
      }
      spans.add(TextSpan(
        text: text.substring(earliest, earliest + matchedTerm.length),
        style: TextStyle(backgroundColor: highlightColor, fontWeight: FontWeight.w600),
      ));
      pos = earliest + matchedTerm.length;
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}
