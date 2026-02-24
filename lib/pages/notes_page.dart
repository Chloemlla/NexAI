import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import 'note_detail_page.dart';

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
          child: Column(
            children: [
              // Search bar (toggleable)
              if (_showSearch) _buildSearchBar(cs),
              // Tab bar
              _buildTabBar(cs),
              // Content
              Expanded(child: _buildTabContent(cs, notesProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search... (tag:name, is:starred, "exact", /regex/)',
                hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withAlpha(120)),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: cs.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withAlpha(140),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _showSearch = false;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return TabBar(
      controller: _tabController,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13),
      indicatorSize: TabBarIndicatorSize.label,
      dividerHeight: 0.5,
      tabs: const [
        Tab(text: 'All', icon: Icon(Icons.notes_rounded, size: 18)),
        Tab(text: 'Starred', icon: Icon(Icons.star_rounded, size: 18)),
        Tab(text: 'Recent', icon: Icon(Icons.history_rounded, size: 18)),
        Tab(text: 'Tags', icon: Icon(Icons.tag_rounded, size: 18)),
      ],
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
            Text('No results for "$_searchQuery"', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 4),
            Text('Try: "exact match", tag:name, is:starred, /regex/',
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
            Text('No starred notes', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 4),
            Text('Star important notes for quick access',
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
            Text('No recent notes', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 4),
            Text('Notes you open will appear here',
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
                        Text('Tags', style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w500)),
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
            Text('No tags yet', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 4),
            Text('Use #tag in notes to organize them',
                style: TextStyle(color: cs.outlineVariant, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    );
  }

  void _showRenameTagDialog(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('All occurrences of #$oldTag will be replaced.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'New tag name',
                prefixText: '#',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final newTag = controller.text.trim();
              if (newTag.isNotEmpty && newTag != oldTag) {
                context.read<NotesProvider>().renameTag(oldTag, newTag);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Rename'),
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
        title: const Text('Delete Tag'),
        content: Text('Remove #$tag from all notes?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<NotesProvider>().deleteTag(tag);
              Navigator.of(ctx).pop();
              setState(() => _selectedTag = null);
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, NotesProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(child: Icon(Icons.note_alt_outlined, size: 32, color: cs.outlineVariant)),
          ),
          const SizedBox(height: 16),
          Text('No notes yet', style: TextStyle(color: cs.outline, fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Create a note or save AI replies here',
              style: TextStyle(color: cs.outlineVariant, fontSize: 13)),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => _createAndOpen(context, provider),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Note'),
          ),
        ],
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
                    Text('${tag.count} note${tag.count != 1 ? 's' : ''}',
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
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
      color: cs.surfaceContainerHighest.withAlpha(160),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.read<NotesProvider>().markViewed(note.id);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: note.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        taskTotal > 0 ? Icons.checklist_rounded : Icons.description_outlined,
                        size: 16, color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: highlightTerms.isEmpty
                        ? Text(note.title,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface),
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : _HighlightText(
                            text: note.title, terms: highlightTerms,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface),
                            highlightColor: cs.primary.withAlpha(60),
                          ),
                  ),
                  // Star button
                  IconButton(
                    icon: Icon(
                      note.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 20,
                      color: note.isStarred ? Colors.amber : cs.outline,
                    ),
                    onPressed: () => context.read<NotesProvider>().toggleStar(note.id),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.outline),
                    onPressed: () => _confirmDelete(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                highlightTerms.isEmpty
                    ? Text(preview,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                        maxLines: 3, overflow: TextOverflow.ellipsis)
                    : _HighlightText(
                        text: preview, terms: highlightTerms,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                        highlightColor: cs.primary.withAlpha(60),
                        maxLines: 3,
                      ),
              ],
              // Tags row
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags.take(5).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withAlpha(160),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('#$t',
                        style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(timeStr, style: TextStyle(fontSize: 11, color: cs.outline)),
                  if (taskTotal > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: taskDone == taskTotal ? Colors.green.withAlpha(30) : cs.primaryContainer.withAlpha(120),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$taskDone/$taskTotal',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: taskDone == taskTotal ? Colors.green : cs.primary)),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${note.content.trim().isEmpty ? 0 : note.content.trim().split(RegExp(r'\s+')).length} words',
                    style: TextStyle(fontSize: 11, color: cs.outline),
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
        title: const Text('Delete Note'),
        content: Text('Delete "${note.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<NotesProvider>().deleteNote(note.id);
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
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
