import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/rich_content_view.dart';

/// Regex to find headings in markdown for outline generation
final _headingRegex = RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true);

/// Regex to find task list items
final _taskItemRegex = RegExp(r'^(\s*)-\s+\[([ xX])\]\s+(.+)$', multiLine: true);

class NoteDetailPage extends StatefulWidget {
  final String noteId;
  const NoteDetailPage({super.key, required this.noteId});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

enum _ViewMode { edit, preview, split }

class _NoteDetailPageState extends State<NoteDetailPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _editorFocus;
  late ScrollController _editorScroll;
  late ScrollController _previewScroll;

  _ViewMode _viewMode = _ViewMode.edit;
  bool _focusMode = false;
  bool _initialized = false;
  bool _showToolbar = true;

  // Stats
  int _wordCount = 0;
  int _charCount = 0;
  int _taskTotal = 0;
  int _taskDone = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _editorFocus = FocusNode();
    _editorScroll = ScrollController();
    _previewScroll = ScrollController();
    _contentController.addListener(_onContentChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final note = context.read<NotesProvider>().notes
          .where((n) => n.id == widget.noteId).firstOrNull;
      if (note != null) {
        _titleController.text = note.title;
        _contentController.text = note.content;
        _viewMode = note.content.isEmpty ? _ViewMode.edit : _ViewMode.split;
        _updateStats(note.content);
        // Mark as recently viewed
        context.read<NotesProvider>().markViewed(widget.noteId);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    // Auto-save based on settings
    final settings = context.read<SettingsProvider>();
    if (settings.notesAutoSave) {
      _saveNote();
    }
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    _previewScroll.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    _updateStats(_contentController.text);
  }

  void _updateStats(String text) {
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).length;
    final chars = text.length;
    final tasks = _taskItemRegex.allMatches(text);
    final total = tasks.length;
    final done = tasks.where((m) => m.group(2)!.trim().toLowerCase() == 'x').length;

    if (words != _wordCount || chars != _charCount || total != _taskTotal || done != _taskDone) {
      setState(() {
        _wordCount = words;
        _charCount = chars;
        _taskTotal = total;
        _taskDone = done;
      });
    }
  }

  void _saveNote() {
    final provider = context.read<NotesProvider>();
    provider.updateNote(
      widget.noteId,
      title: _titleController.text.trim().isEmpty
          ? 'Untitled Note'
          : _titleController.text.trim(),
      content: _contentController.text,
    );
  }

  // ─── Toolbar formatting helpers ───

  void _wrapSelection(String before, String after) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    final selected = sel.textInside(text);
    final newText = '$before$selected$after';
    _contentController.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, newText),
      selection: TextSelection.collapsed(
        offset: sel.start + before.length + selected.length,
      ),
    );
    _editorFocus.requestFocus();
  }

  void _insertAtCursor(String insert) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    final offset = sel.isValid ? sel.baseOffset : text.length;

    _contentController.value = TextEditingValue(
      text: text.replaceRange(offset, offset, insert),
      selection: TextSelection.collapsed(offset: offset + insert.length),
    );
    _editorFocus.requestFocus();
  }

  void _prependLine(String prefix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    // Find start of current line
    int lineStart = sel.baseOffset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    _contentController.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: sel.baseOffset + prefix.length),
    );
    _editorFocus.requestFocus();
  }

  void _toggleTaskItem() {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    int lineStart = sel.baseOffset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = sel.baseOffset;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    final line = text.substring(lineStart, lineEnd);
    String newLine;
    if (line.contains(RegExp(r'^\s*-\s+\[ \]'))) {
      newLine = line.replaceFirst('- [ ]', '- [x]');
    } else if (line.contains(RegExp(r'^\s*-\s+\[[xX]\]'))) {
      newLine = line.replaceFirst(RegExp(r'-\s+\[[xX]\]'), '- [ ]');
    } else {
      newLine = '- [ ] $line';
    }

    _contentController.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, newLine),
      selection: TextSelection.collapsed(offset: lineStart + newLine.length),
    );
    _editorFocus.requestFocus();
  }

  // ─── Outline extraction ───

  List<_HeadingEntry> _extractOutline(String text) {
    final entries = <_HeadingEntry>[];
    for (final match in _headingRegex.allMatches(text)) {
      final level = match.group(1)!.length;
      final title = match.group(2)!.trim();
      entries.add(_HeadingEntry(level: level, title: title, offset: match.start));
    }
    return entries;
  }

  void _jumpToOffset(int offset) {
    // Switch to edit mode and move cursor
    setState(() {
      if (_viewMode == _ViewMode.preview) _viewMode = _ViewMode.split;
    });
    _contentController.selection = TextSelection.collapsed(offset: offset);
    _editorFocus.requestFocus();
    // Scroll to approximate position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editorScroll.hasClients) {
        final totalLen = _contentController.text.length;
        if (totalLen > 0) {
          final ratio = offset / totalLen;
          final target = _editorScroll.position.maxScrollExtent * ratio;
          _editorScroll.animateTo(target,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic);
        }
      }
    });
  }

  void _showOutlineDrawer() {
    final cs = Theme.of(context).colorScheme;
    final outline = _extractOutline(_contentController.text);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLow,
      builder: (ctx) {
        if (outline.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.segment_rounded, size: 36, color: cs.outlineVariant),
                    const SizedBox(height: 12),
                    Text('未找到标题', style: TextStyle(color: cs.outline)),
                    const SizedBox(height: 4),
                    Text('使用 # 创建标题', style: TextStyle(color: cs.outlineVariant, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.segment_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Text('大纲', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${outline.length} 个标题', style: TextStyle(fontSize: 12, color: cs.outline)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Divider(height: 1, color: cs.outlineVariant.withAlpha(80)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: outline.length,
                  itemBuilder: (_, idx) {
                    final h = outline[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.only(left: 16.0 + (h.level - 1) * 16.0, right: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withAlpha(h.level <= 2 ? 255 : 140),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('H${h.level}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
                        ),
                      ),
                      title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: h.level <= 2 ? 14 : 13, fontWeight: h.level <= 2 ? FontWeight.w600 : FontWeight.w400)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _jumpToOffset(h.offset);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = context.watch<NotesProvider>().notes
        .where((n) => n.id == widget.noteId).firstOrNull;
    if (note == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('笔记')),
        body: const Center(child: Text('未找到笔记')),
      );
    }

    // Sync content if changed externally while in preview mode
    if (_viewMode == _ViewMode.preview && _contentController.text != note.content) {
      _contentController.text = note.content;
    }

    final isLandscape = MediaQuery.of(context).size.width > 600;

    if (_focusMode) {
      return _buildFocusMode(cs, note.content);
    }

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): const _FormatIntent('bold'),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): const _FormatIntent('italic'),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): const _FormatIntent('link'),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): const _FormatIntent('code'),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): const _FormatIntent('save'),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): const _FormatIntent('preview'),
        const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true): const _FormatIntent('strikethrough'),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FormatIntent: CallbackAction<_FormatIntent>(onInvoke: (intent) {
            switch (intent.type) {
              case 'bold': _wrapSelection('**', '**'); break;
              case 'italic': _wrapSelection('*', '*'); break;
              case 'link': _wrapSelection('[', '](url)'); break;
              case 'code': _wrapSelection('`', '`'); break;
              case 'strikethrough': _wrapSelection('~~', '~~'); break;
              case 'save': _saveNote(); break;
              case 'preview':
                if (_viewMode != _ViewMode.preview) _saveNote();
                setState(() => _viewMode = _viewMode == _ViewMode.preview ? _ViewMode.edit : _ViewMode.preview);
                break;
            }
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
      appBar: AppBar(
        surfaceTintColor: cs.surfaceTint,
        elevation: 0,
        titleSpacing: 0,
        backgroundColor: cs.surface,
        title: _viewMode == _ViewMode.edit || _viewMode == _ViewMode.split
            ? TextField(
                controller: _titleController,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: cs.onSurface,
                  letterSpacing: 0.15,
                ),
                decoration: InputDecoration(
                  hintText: '笔记标题...',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withAlpha(140),
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              )
            : Text(
                note.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: cs.onSurface,
                  letterSpacing: 0.15,
                ),
              ),
        actions: [
          // Save button (manual save)
          IconButton(
            icon: Icon(Icons.save_rounded, size: 22, color: cs.primary),
            onPressed: () {
              _saveNote();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('笔记已保存'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            visualDensity: VisualDensity.comfortable,
            tooltip: '保存笔记 (Ctrl+S)',
          ),
          // Star button with animation
          IconButton(
            icon: Icon(
              note.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 24,
              color: note.isStarred ? Colors.amber.shade600 : cs.onSurfaceVariant,
            ),
            onPressed: () => context.read<NotesProvider>().toggleStar(widget.noteId),
            visualDensity: VisualDensity.comfortable,
            tooltip: note.isStarred ? '取消星标' : '星标',
          ),
          const SizedBox(width: 4),
          // View mode toggle with better styling
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SegmentedButton<_ViewMode>(
              segments: [
                ButtonSegment(
                  value: _ViewMode.edit,
                  icon: Icon(Icons.edit_rounded, size: 18),
                  tooltip: '编辑',
                ),
                ButtonSegment(
                  value: _ViewMode.split,
                  icon: Icon(Icons.vertical_split_rounded, size: 18),
                  tooltip: '分割视图',
                ),
                ButtonSegment(
                  value: _ViewMode.preview,
                  icon: Icon(Icons.visibility_rounded, size: 18),
                  tooltip: '预览',
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (s) {
                if (_viewMode != _ViewMode.preview && s.first == _ViewMode.preview) _saveNote();
                setState(() => _viewMode = s.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 22, color: cs.onSurfaceVariant),
            onSelected: _onMenuAction,
            tooltip: '更多选项',
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'outline',
                child: _menuRow(Icons.segment_rounded, '大纲'),
              ),
              PopupMenuItem(
                value: 'backlinks',
                child: _menuRow(Icons.link_rounded, '链接和反向链接'),
              ),
              PopupMenuItem(
                value: 'frontmatter',
                child: _menuRow(Icons.data_object_rounded, '插入前置元数据'),
              ),
              PopupMenuItem(
                value: 'tags',
                child: _menuRow(Icons.local_offer_rounded, '管理标签'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'focus',
                child: _menuRow(Icons.fullscreen_rounded, '专注模式'),
              ),
              PopupMenuItem(
                value: 'stats',
                child: _menuRow(Icons.analytics_outlined, '统计信息'),
              ),
              PopupMenuItem(
                value: 'export',
                child: _menuRow(Icons.download_rounded, '导出'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: _menuRow(Icons.delete_outline_rounded, '删除', isDestructive: true),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Task progress bar
          if (_taskTotal > 0) _buildTaskProgress(cs),
          // Tags bar
          if (note.tags.isNotEmpty) _buildTagsBar(cs, note.tags),
          // Toolbar
          if (_showToolbar && _viewMode != _ViewMode.preview) _buildToolbar(cs),
          // Content area
          Expanded(
            child: _viewMode == _ViewMode.split
                ? (isLandscape ? _buildSplitHorizontal(cs) : _buildSplitVertical(cs))
                : _viewMode == _ViewMode.edit
                    ? _buildEditor(cs)
                    : _buildPreview(cs, note.content),
          ),
          // Bottom stats bar
          _buildBottomBar(cs),
        ],
      ),
    ),
    ),
    ),
    );
  }

  Widget _menuRow(IconData icon, String label, {bool isDestructive = false}) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : cs.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'outline':
        _showOutlineDrawer();
        break;
      case 'backlinks':
        _showBacklinksSheet();
        break;
      case 'frontmatter':
        _insertFrontmatter();
        break;
      case 'tags':
        _showTagsSheet();
        break;
      case 'focus':
        _saveNote();
        setState(() => _focusMode = true);
        break;
      case 'stats':
        _showStatsDialog();
        break;
      case 'export':
        _showExportDialog();
        break;
      case 'delete':
        context.read<NotesProvider>().deleteNote(widget.noteId);
        Navigator.of(context).pop();
        break;
    }
  }

  void _showExportDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.download_rounded, color: cs.primary),
        title: const Text('导出笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.description_outlined, color: cs.primary),
              title: const Text('导出为 Markdown'),
              subtitle: const Text('保存为 .md 文件'),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportAsMarkdown();
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy_rounded, color: cs.primary),
              title: const Text('复制到剪贴板'),
              subtitle: const Text('复制内容'),
              onTap: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(ClipboardData(text: _contentController.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已复制到剪贴板'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _exportAsMarkdown() {
    // This is a placeholder - actual file export would require platform-specific implementation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('导出功能即将推出'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showStatsDialog() {
    final lines = _contentController.text.split('\n').length;
    final headings = _extractOutline(_contentController.text).length;
    final note = context.read<NotesProvider>().notes
        .where((n) => n.id == widget.noteId).firstOrNull;
    final tagCount = note?.tags.length ?? 0;
    final hasFm = _contentController.text.trimLeft().startsWith('---');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('统计信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow(Icons.text_fields_rounded, '单词', '$_wordCount'),
            _statRow(Icons.abc_rounded, '字符', '$_charCount'),
            _statRow(Icons.format_list_numbered_rounded, '行数', '$lines'),
            _statRow(Icons.segment_rounded, '标题', '$headings'),
            _statRow(Icons.tag_rounded, '标签', '$tagCount'),
            if (_taskTotal > 0)
              _statRow(Icons.check_box_outlined, '任务', '$_taskDone / $_taskTotal'),
            _statRow(Icons.data_object_rounded, '前置元数据', hasFm ? '是' : '否'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.primary)),
        ],
      ),
    );
  }

  // ─── Frontmatter ───

  void _insertFrontmatter() {
    final text = _contentController.text;
    // Check if frontmatter already exists
    if (text.trimLeft().startsWith('---')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('前置元数据已存在'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final title = _titleController.text.trim().isEmpty ? '无标题' : _titleController.text.trim();
    final fm = '---\ntitle: $title\ntags: \ndate: $dateStr\nauthor: \n---\n\n';

    _contentController.value = TextEditingValue(
      text: '$fm$text',
      selection: TextSelection.collapsed(offset: fm.indexOf('tags: ') + 6),
    );
    setState(() {
      if (_viewMode == _ViewMode.preview) _viewMode = _ViewMode.edit;
    });
    _editorFocus.requestFocus();
  }

  // ─── Tags sheet ───

  void _showTagsSheet() {
    final cs = Theme.of(context).colorScheme;
    final note = context.read<NotesProvider>().notes
        .where((n) => n.id == widget.noteId).firstOrNull;
    if (note == null) return;

    final tags = note.tags;
    final tagController = TextEditingController();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLow,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.tag_rounded, size: 20, color: cs.primary),
                        const SizedBox(width: 10),
                        Text('标签', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${tags.length} 个标签', style: TextStyle(fontSize: 12, color: cs.outline)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Add tag input
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tagController,
                            decoration: InputDecoration(
                              hintText: '添加标签（例如 project/web）',
                              prefixText: '#',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: cs.surfaceContainerHighest.withAlpha(140),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () {
                            final tag = tagController.text.trim();
                            if (tag.isEmpty) return;
                            // Append tag to content
                            _insertAtCursor(' #$tag');
                            _saveNote();
                            tagController.clear();
                            setSheetState(() {});
                          },
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: cs.outlineVariant.withAlpha(80)),
                  if (tags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('此笔记中没有标签', style: TextStyle(color: cs.outline)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: tags.length,
                        itemBuilder: (_, idx) {
                          final tag = tags[idx];
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            leading: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(child: Icon(Icons.tag_rounded, size: 14, color: cs.onSecondaryContainer)),
                            ),
                            title: Text('#$tag', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Backlinks sheet ───

  void _showBacklinksSheet() {
    final cs = Theme.of(context).colorScheme;
    final provider = context.read<NotesProvider>();
    final backlinks = provider.getBacklinks(widget.noteId);
    final outgoing = provider.getOutgoingLinks(widget.noteId);
    final unlinked = provider.getUnlinkedMentions(widget.noteId);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerLow,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Text('链接', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Divider(height: 1, color: cs.outlineVariant.withAlpha(80)),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      // Backlinks section
                      _linkSectionHeader(cs, Icons.arrow_back_rounded, '反向链接', backlinks.length),
                      if (backlinks.isEmpty)
                        _emptyLinkHint(cs, '没有笔记链接到此笔记')
                      else
                        ...backlinks.map((n) => _linkTile(cs, n)),
                      const SizedBox(height: 12),
                      // Outgoing links
                      _linkSectionHeader(cs, Icons.arrow_forward_rounded, '传出链接', outgoing.length),
                      if (outgoing.isEmpty)
                        _emptyLinkHint(cs, '此笔记没有 wiki 链接')
                      else
                        ...outgoing.map((n) => _linkTile(cs, n)),
                      const SizedBox(height: 12),
                      // Unlinked mentions
                      _linkSectionHeader(cs, Icons.link_off_rounded, '未链接的提及', unlinked.length),
                      if (unlinked.isEmpty)
                        _emptyLinkHint(cs, '未找到未链接的提及')
                      else
                        ...unlinked.map((n) => _unlinkedTile(cs, n, provider)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _linkSectionHeader(ColorScheme cs, IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }

  Widget _emptyLinkHint(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 12, color: cs.outline)),
    );
  }

  Widget _linkTile(ColorScheme cs, Note note) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Icon(Icons.description_outlined, size: 14, color: cs.onPrimaryContainer)),
      ),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        note.content.length > 60 ? '${note.content.substring(0, 60)}...' : note.content,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: cs.outline),
      ),
      onTap: () {
        Navigator.of(context).pop(); // close sheet
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: note.id)),
        );
      },
    );
  }

  Widget _unlinkedTile(ColorScheme cs, Note note, NotesProvider provider) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Icon(Icons.link_off_rounded, size: 14, color: cs.onTertiaryContainer)),
      ),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      trailing: FilledButton.tonal(
        onPressed: () {
          provider.addLinkToNote(widget.noteId, note.title);
          // Refresh the content controller
          final updatedNote = provider.notes.where((n) => n.id == widget.noteId).firstOrNull;
          if (updatedNote != null) {
            _contentController.text = updatedNote.content;
          }
          Navigator.of(context).pop(); // close sheet
        },
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('链接', style: TextStyle(fontSize: 12)),
      ),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: note.id)),
        );
      },
    );
  }

  // ─── Tags bar ───

  Widget _buildTagsBar(ColorScheme cs, List<String> tags) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(60),
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withAlpha(40))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Center(child: Icon(Icons.tag_rounded, size: 14, color: cs.outline)),
          const SizedBox(width: 6),
          ...tags.map((t) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withAlpha(160),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('#$t',
                    style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer, fontWeight: FontWeight.w500)),
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ─── Task progress ───

  Widget _buildTaskProgress(ColorScheme cs) {
    final progress = _taskTotal > 0 ? _taskDone / _taskTotal : 0.0;
    final isComplete = progress >= 1.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isComplete
              ? [Colors.green.shade50, Colors.green.shade100]
              : [cs.primaryContainer.withAlpha(60), cs.secondaryContainer.withAlpha(60)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: isComplete ? Colors.green.withAlpha(100) : cs.outlineVariant.withAlpha(60),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isComplete ? Colors.green.shade100 : cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isComplete ? Icons.check_circle_rounded : Icons.checklist_rounded,
              size: 18,
              color: isComplete ? Colors.green.shade700 : cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isComplete ? '所有任务已完成！' : '任务进度',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isComplete ? Colors.green.shade700 : cs.onSurface,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_taskDone/$_taskTotal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isComplete ? Colors.green.shade700 : cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: cs.surfaceContainerHighest.withAlpha(120),
                    color: isComplete ? Colors.green.shade600 : cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Toolbar ───

  Widget _buildToolbar(ColorScheme cs) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withAlpha(80), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _toolBtn(Icons.format_bold_rounded, '粗体 (Ctrl+B)', () => _wrapSelection('**', '**')),
          _toolBtn(Icons.format_italic_rounded, '斜体 (Ctrl+I)', () => _wrapSelection('*', '*')),
          _toolBtn(Icons.strikethrough_s_rounded, '删除线', () => _wrapSelection('~~', '~~')),
          _toolDivider(cs),
          _toolBtn(Icons.title_rounded, '标题', () => _prependLine('## ')),
          _toolBtn(Icons.format_quote_rounded, '引用', () => _prependLine('> ')),
          _toolBtn(Icons.code_rounded, '行内代码', () => _wrapSelection('`', '`')),
          _toolBtn(Icons.data_object_rounded, '代码块', () => _wrapSelection('```\n', '\n```')),
          _toolDivider(cs),
          _toolBtn(Icons.format_list_bulleted_rounded, '项目符号列表', () => _prependLine('- ')),
          _toolBtn(Icons.format_list_numbered_rounded, '编号列表', () => _prependLine('1. ')),
          _toolBtn(Icons.check_box_outlined, '任务项', _toggleTaskItem),
          _toolDivider(cs),
          _toolBtn(Icons.horizontal_rule_rounded, '分隔线', () => _insertAtCursor('\n---\n')),
          _toolBtn(Icons.link_rounded, '链接', () => _wrapSelection('[', '](url)')),
          _toolBtn(Icons.image_outlined, '图片', () => _insertAtCursor('![alt](url)')),
          _toolBtn(Icons.table_chart_outlined, '表格', () => _insertAtCursor('\n| 标题 | 标题 |\n|--------|--------|\n| 单元格   | 单元格   |\n')),
          _toolDivider(cs),
          _toolBtn(Icons.functions_rounded, '行内数学', () => _wrapSelection(r'$', r'$')),
          _toolBtn(Icons.calculate_outlined, '块数学', () => _wrapSelection('\$\$\n', '\n\$\$')),
          _toolDivider(cs),
          _toolBtn(Icons.local_offer_rounded, '标签', () => _insertAtCursor('#')),
          _toolBtn(Icons.add_link_rounded, 'Wiki 链接', () => _insertAtCursor('[[')),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tooltip, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Icon(icon, size: 22, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _toolDivider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Container(
        width: 1,
        height: 24,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.outlineVariant.withAlpha(0),
              cs.outlineVariant.withAlpha(120),
              cs.outlineVariant.withAlpha(0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  // ─── Editor ───

  Widget _buildEditor(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: _contentController,
        focusNode: _editorFocus,
        scrollController: _editorScroll,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.7, fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: '在此处写 markdown...\n\n支持：\n- **粗体**、*斜体*、~~删除线~~\n- \$E=mc^2\$ (行内数学)\n- \$\$\\\\int_0^1 f(x)dx\$\$ (块数学)\n- - [ ] 任务列表\n- 代码块、表格、链接...',
          hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(100), fontSize: 13),
          border: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ─── Preview ───

  Widget _buildPreview(ColorScheme cs, String content) {
    if (content.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('空笔记', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _viewMode = _ViewMode.edit),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('开始写作'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: _previewScroll,
      padding: const EdgeInsets.all(16),
      child: RichContentView(content: content, enableWikiLinks: true),
    );
  }

  // ─── Split views ───

  Widget _buildSplitHorizontal(ColorScheme cs) {
    return Row(
      children: [
        Expanded(child: _buildEditor(cs)),
        VerticalDivider(width: 1, color: cs.outlineVariant.withAlpha(80)),
        Expanded(child: _buildPreview(cs, _contentController.text)),
      ],
    );
  }

  Widget _buildSplitVertical(ColorScheme cs) {
    return Column(
      children: [
        Expanded(flex: 5, child: _buildEditor(cs)),
        Divider(height: 1, color: cs.outlineVariant.withAlpha(80)),
        Expanded(flex: 4, child: _buildPreview(cs, _contentController.text)),
      ],
    );
  }

  // ─── Bottom bar ───

  Widget _buildBottomBar(ColorScheme cs) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withAlpha(80), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          _statChip(cs, Icons.text_fields_rounded, '$_wordCount 个单词'),
          const SizedBox(width: 12),
          _statChip(cs, Icons.abc_rounded, '$_charCount 个字符'),
          if (_taskTotal > 0) ...[
            const SizedBox(width: 12),
            _statChip(
              cs,
              Icons.check_box_outlined,
              '$_taskDone/$_taskTotal 个任务',
              color: _taskDone == _taskTotal ? Colors.green : null,
            ),
          ],
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _showToolbar = !_showToolbar),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showToolbar ? '隐藏工具栏' : '显示工具栏',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showToolbar ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(ColorScheme cs, IconData icon, String label, {Color? color}) {
    final chipColor = color ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withAlpha(60),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Focus mode ───

  Widget _buildFocusMode(ColorScheme cs, String noteContent) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Minimal top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                    onPressed: () => setState(() => _focusMode = false),
                    tooltip: '退出专注模式',
                  ),
                  const Spacer(),
                  Text('$_wordCount 个单词', style: TextStyle(fontSize: 12, color: cs.outline)),
                  const SizedBox(width: 12),
                  // Toggle between edit and preview in focus mode
                  SegmentedButton<_ViewMode>(
                    segments: const [
                      ButtonSegment(value: _ViewMode.edit, icon: Icon(Icons.edit_rounded, size: 14)),
                      ButtonSegment(value: _ViewMode.preview, icon: Icon(Icons.visibility_rounded, size: 14)),
                    ],
                    selected: {_viewMode == _ViewMode.preview ? _ViewMode.preview : _ViewMode.edit},
                    onSelectionChanged: (s) {
                      if (s.first == _ViewMode.preview) _saveNote();
                      setState(() => _viewMode = s.first);
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(horizontal: 6)),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _viewMode == _ViewMode.preview
                    ? _buildPreview(cs, noteContent)
                    : TextField(
                        controller: _contentController,
                        focusNode: _editorFocus,
                        scrollController: _editorScroll,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurface,
                          height: 1.8,
                          fontFamily: 'monospace',
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper classes ───

class _HeadingEntry {
  final int level;
  final String title;
  final int offset;
  _HeadingEntry({required this.level, required this.title, required this.offset});
}

class _FormatIntent extends Intent {
  final String type;
  const _FormatIntent(this.type);
}
