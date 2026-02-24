import 'package:flutter/material.dart';
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

class _NotesPageState extends State<NotesPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final cs = Theme.of(context).colorScheme;

    final allNotes = notesProvider.notes;
    final notes = _searchQuery.isEmpty
        ? allNotes
        : allNotes.where((n) =>
            n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            n.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (allNotes.isEmpty) {
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
            Text('Create a note or save AI replies here', style: TextStyle(color: cs.outlineVariant, fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => _createAndOpen(context, notesProvider),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Note'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withAlpha(140),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        // Notes list
        Expanded(
          child: notes.isEmpty
              ? Center(child: Text('No matching notes', style: TextStyle(color: cs.outline)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) => _NoteCard(note: notes[index]),
                ),
        ),
      ],
    );
  }

  void _createAndOpen(BuildContext context, NotesProvider provider) {
    final note = provider.createNote();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: note.id)),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = note.content.length > 120
        ? '${note.content.substring(0, 120)}...'
        : note.content;
    final timeStr = _formatTime(note.updatedAt);

    // Task stats
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
                    child: Text(
                      note.title,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                Text(
                  preview,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
                        color: taskDone == taskTotal
                            ? Colors.green.withAlpha(30)
                            : cs.primaryContainer.withAlpha(120),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$taskDone/$taskTotal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: taskDone == taskTotal ? Colors.green : cs.primary,
                        ),
                      ),
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
