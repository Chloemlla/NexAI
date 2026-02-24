import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/notes_provider.dart';
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
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _saveNote();
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
                    Text('No headings found', style: TextStyle(color: cs.outline)),
                    const SizedBox(height: 4),
                    Text('Use # to create headings', style: TextStyle(color: cs.outlineVariant, fontSize: 12)),
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
                    Text('Outline', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${outline.length} headings', style: TextStyle(fontSize: 12, color: cs.outline)),
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
        appBar: AppBar(title: const Text('Note')),
        body: const Center(child: Text('Note not found')),
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
        titleSpacing: 0,
        title: _viewMode == _ViewMode.edit || _viewMode == _ViewMode.split
            ? TextField(
                controller: _titleController,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Note title...',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(140)),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              )
            : Text(note.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: cs.onSurface)),
        actions: [
          // View mode toggle
          SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(value: _ViewMode.edit, icon: Icon(Icons.edit_rounded, size: 16)),
              ButtonSegment(value: _ViewMode.split, icon: Icon(Icons.vertical_split_rounded, size: 16)),
              ButtonSegment(value: _ViewMode.preview, icon: Icon(Icons.visibility_rounded, size: 16)),
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
              padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(horizontal: 6)),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
            onSelected: _onMenuAction,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'outline', child: _menuRow(Icons.segment_rounded, 'Outline')),
              PopupMenuItem(value: 'focus', child: _menuRow(Icons.fullscreen_rounded, 'Focus mode')),
              PopupMenuItem(value: 'stats', child: _menuRow(Icons.analytics_outlined, 'Statistics')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: _menuRow(Icons.delete_outline_rounded, 'Delete', isDestructive: true)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Task progress bar
          if (_taskTotal > 0) _buildTaskProgress(cs),
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
      case 'focus':
        _saveNote();
        setState(() => _focusMode = true);
        break;
      case 'stats':
        _showStatsDialog();
        break;
      case 'delete':
        context.read<NotesProvider>().deleteNote(widget.noteId);
        Navigator.of(context).pop();
        break;
    }
  }

  void _showStatsDialog() {
    final lines = _contentController.text.split('\n').length;
    final headings = _extractOutline(_contentController.text).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow(Icons.text_fields_rounded, 'Words', '$_wordCount'),
            _statRow(Icons.abc_rounded, 'Characters', '$_charCount'),
            _statRow(Icons.format_list_numbered_rounded, 'Lines', '$lines'),
            _statRow(Icons.segment_rounded, 'Headings', '$headings'),
            if (_taskTotal > 0)
              _statRow(Icons.check_box_outlined, 'Tasks', '$_taskDone / $_taskTotal'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
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

  // ─── Task progress ───

  Widget _buildTaskProgress(ColorScheme cs) {
    final progress = _taskTotal > 0 ? _taskDone / _taskTotal : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cs.surfaceContainerHighest.withAlpha(80),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                color: progress >= 1.0 ? Colors.green : cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$_taskDone/$_taskTotal',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ─── Toolbar ───

  Widget _buildToolbar(ColorScheme cs) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(120),
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withAlpha(60))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _toolBtn(Icons.format_bold_rounded, 'Bold', () => _wrapSelection('**', '**')),
          _toolBtn(Icons.format_italic_rounded, 'Italic', () => _wrapSelection('*', '*')),
          _toolBtn(Icons.strikethrough_s_rounded, 'Strikethrough', () => _wrapSelection('~~', '~~')),
          _toolDivider(cs),
          _toolBtn(Icons.title_rounded, 'Heading', () => _prependLine('## ')),
          _toolBtn(Icons.format_quote_rounded, 'Quote', () => _prependLine('> ')),
          _toolBtn(Icons.code_rounded, 'Code', () => _wrapSelection('`', '`')),
          _toolBtn(Icons.data_object_rounded, 'Code block', () => _wrapSelection('```\n', '\n```')),
          _toolDivider(cs),
          _toolBtn(Icons.format_list_bulleted_rounded, 'Bullet list', () => _prependLine('- ')),
          _toolBtn(Icons.format_list_numbered_rounded, 'Numbered list', () => _prependLine('1. ')),
          _toolBtn(Icons.check_box_outlined, 'Task', _toggleTaskItem),
          _toolDivider(cs),
          _toolBtn(Icons.horizontal_rule_rounded, 'Divider', () => _insertAtCursor('\n---\n')),
          _toolBtn(Icons.link_rounded, 'Link', () => _wrapSelection('[', '](url)')),
          _toolBtn(Icons.image_outlined, 'Image', () => _insertAtCursor('![alt](url)')),
          _toolBtn(Icons.table_chart_outlined, 'Table', () => _insertAtCursor('\n| Header | Header |\n|--------|--------|\n| Cell   | Cell   |\n')),
          _toolDivider(cs),
          _toolBtn(Icons.functions_rounded, 'Inline math', () => _wrapSelection(r'$', r'$')),
          _toolBtn(Icons.calculate_outlined, 'Block math', () => _wrapSelection('\$\$\n', '\n\$\$')),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tooltip, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _toolDivider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Container(width: 1, height: 20, color: cs.outlineVariant.withAlpha(100)),
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
          hintText: 'Write markdown here...\n\nSupports:\n- **Bold**, *italic*, ~~strikethrough~~\n- \$E=mc^2\$ (inline math)\n- \$\$\\\\int_0^1 f(x)dx\$\$ (block math)\n- - [ ] Task lists\n- Code blocks, tables, links...',
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
            Text('Empty note', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _viewMode = _ViewMode.edit),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Start writing'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: _previewScroll,
      padding: const EdgeInsets.all(16),
      child: RichContentView(content: content),
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
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(80),
        border: Border(top: BorderSide(color: cs.outlineVariant.withAlpha(60))),
      ),
      child: Row(
        children: [
          Text('$_wordCount words', style: TextStyle(fontSize: 11, color: cs.outline)),
          const SizedBox(width: 12),
          Text('$_charCount chars', style: TextStyle(fontSize: 11, color: cs.outline)),
          if (_taskTotal > 0) ...[
            const SizedBox(width: 12),
            Text('$_taskDone/$_taskTotal tasks', style: TextStyle(fontSize: 11, color: cs.outline)),
          ],
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => setState(() => _showToolbar = !_showToolbar),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(
                _showToolbar ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 16, color: cs.outline,
              ),
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
                    tooltip: 'Exit focus mode',
                  ),
                  const Spacer(),
                  Text('$_wordCount words', style: TextStyle(fontSize: 12, color: cs.outline)),
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
