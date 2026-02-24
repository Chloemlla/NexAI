import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];

  List<Note> get notes => _notes;

  /// All starred notes
  List<Note> get starredNotes => _notes.where((n) => n.isStarred).toList();

  /// Recently viewed notes (last 20, sorted by lastViewedAt)
  List<Note> get recentNotes {
    final viewed = _notes.where((n) => n.lastViewedAt != null).toList();
    viewed.sort((a, b) => b.lastViewedAt!.compareTo(a.lastViewedAt!));
    return viewed.take(20).toList();
  }

  /// All unique tags across all notes, sorted by frequency descending
  List<TagInfo> get allTags {
    final freq = <String, int>{};
    for (final note in _notes) {
      for (final tag in note.tags) {
        freq[tag] = (freq[tag] ?? 0) + 1;
      }
    }
    final entries = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => TagInfo(e.key, e.value)).toList();
  }

  /// Get notes filtered by tag
  List<Note> notesByTag(String tag) =>
      _notes.where((n) => n.tags.contains(tag)).toList();

  Future<void> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notes');
    if (data != null && data.isNotEmpty) {
      _notes = Note.decodeList(data);
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes', Note.encodeList(_notes));
  }

  Note createNote({String title = '', String content = ''}) {
    final now = DateTime.now();
    final note = Note(
      id: now.millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Untitled Note' : title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    _notes.insert(0, note);
    notifyListeners();
    _save();
    return note;
  }

  void updateNote(String id, {String? title, String? content}) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    if (title != null) _notes[idx].title = title;
    if (content != null) _notes[idx].content = content;
    _notes[idx].updatedAt = DateTime.now();
    notifyListeners();
    _save();
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    _save();
  }

  void appendToNote(String id, String text) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final note = _notes[idx];
    note.content = note.content.isEmpty ? text : '${note.content}\n\n---\n\n$text';
    note.updatedAt = DateTime.now();
    notifyListeners();
    _save();
  }

  // ─── Star ───

  void toggleStar(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notes[idx].isStarred = !_notes[idx].isStarred;
    notifyListeners();
    _save();
  }

  // ─── Recent ───

  void markViewed(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notes[idx].lastViewedAt = DateTime.now();
    // Don't notifyListeners here to avoid rebuild loops
    _save();
  }

  // ─── Tag operations ───

  /// Rename a tag across all notes
  void renameTag(String oldTag, String newTag) {
    if (oldTag == newTag || newTag.isEmpty) return;
    for (final note in _notes) {
      if (note.tags.contains(oldTag)) {
        note.content = note.content.replaceAll('#$oldTag', '#$newTag');
        note.updatedAt = DateTime.now();
      }
    }
    notifyListeners();
    _save();
  }

  /// Merge sourceTag into targetTag (replace all occurrences)
  void mergeTags(String sourceTag, String targetTag) {
    renameTag(sourceTag, targetTag);
  }

  /// Delete a tag from all notes
  void deleteTag(String tag) {
    for (final note in _notes) {
      if (note.tags.contains(tag)) {
        // Remove the tag but keep surrounding text clean
        note.content = note.content.replaceAll(RegExp('#$tag(?![\\w/])'), '');
        // Clean up double spaces
        note.content = note.content.replaceAll(RegExp(r'  +'), ' ');
        note.updatedAt = DateTime.now();
      }
    }
    notifyListeners();
    _save();
  }

  // ─── Advanced search ───

  /// Search notes with support for:
  /// - Simple text search
  /// - Regex (wrapped in /pattern/)
  /// - Operators: AND, OR, NOT (case insensitive)
  /// - Tag filter: tag:tagname
  /// - Star filter: is:starred
  List<NoteSearchResult> searchNotes(String query) {
    if (query.trim().isEmpty) return [];

    final results = <NoteSearchResult>[];

    // Check for special filters
    String? tagFilter;
    bool? starFilter;
    var searchQuery = query;

    // Extract tag: filter
    final tagMatch = RegExp(r'tag:(\S+)').firstMatch(searchQuery);
    if (tagMatch != null) {
      tagFilter = tagMatch.group(1);
      searchQuery = searchQuery.replaceFirst(tagMatch.group(0)!, '').trim();
    }

    // Extract is:starred filter
    if (searchQuery.contains('is:starred')) {
      starFilter = true;
      searchQuery = searchQuery.replaceAll('is:starred', '').trim();
    }

    // Filter candidates
    var candidates = _notes.toList();
    if (tagFilter != null) {
      candidates = candidates.where((n) => n.tags.any((t) =>
          t.toLowerCase().contains(tagFilter!.toLowerCase()))).toList();
    }
    if (starFilter == true) {
      candidates = candidates.where((n) => n.isStarred).toList();
    }

    if (searchQuery.isEmpty) {
      return candidates.map((n) => NoteSearchResult(note: n, matches: [])).toList();
    }

    // Check if regex search (wrapped in /.../)
    RegExp? regexSearch;
    if (searchQuery.startsWith('/') && searchQuery.endsWith('/') && searchQuery.length > 2) {
      try {
        regexSearch = RegExp(searchQuery.substring(1, searchQuery.length - 1), caseSensitive: false);
      } catch (_) {
        // Invalid regex, fall through to text search
      }
    }

    for (final note in candidates) {
      final fullText = '${note.title}\n${note.content}';
      final matches = <SearchMatch>[];

      if (regexSearch != null) {
        for (final m in regexSearch.allMatches(fullText)) {
          matches.add(SearchMatch(start: m.start, end: m.end, text: m.group(0)!));
        }
      } else {
        // Parse AND/OR/NOT operators
        final matched = _evaluateQuery(searchQuery, fullText);
        if (matched) {
          // Find positions of individual terms for highlighting
          final terms = _extractTerms(searchQuery);
          for (final term in terms) {
            final lower = fullText.toLowerCase();
            int pos = 0;
            while (true) {
              pos = lower.indexOf(term.toLowerCase(), pos);
              if (pos == -1) break;
              matches.add(SearchMatch(start: pos, end: pos + term.length, text: fullText.substring(pos, pos + term.length)));
              pos += term.length;
            }
          }
        }
      }

      if (matches.isNotEmpty || (regexSearch == null && _evaluateQuery(searchQuery, fullText))) {
        results.add(NoteSearchResult(note: note, matches: matches));
      }
    }

    return results;
  }

  bool _evaluateQuery(String query, String text) {
    final lower = text.toLowerCase();
    final q = query.trim();

    // Handle NOT
    if (q.toLowerCase().startsWith('not ')) {
      return !_evaluateQuery(q.substring(4), text);
    }

    // Handle OR
    final orParts = q.split(RegExp(r'\s+or\s+', caseSensitive: false));
    if (orParts.length > 1) {
      return orParts.any((part) => _evaluateQuery(part.trim(), text));
    }

    // Handle AND (default for space-separated terms)
    final andParts = q.split(RegExp(r'\s+and\s+', caseSensitive: false));
    if (andParts.length > 1) {
      return andParts.every((part) => _evaluateQuery(part.trim(), text));
    }

    // Handle quoted exact match
    if (q.startsWith('"') && q.endsWith('"') && q.length > 2) {
      return lower.contains(q.substring(1, q.length - 1).toLowerCase());
    }

    // Simple contains
    return lower.contains(q.toLowerCase());
  }

  List<String> _extractTerms(String query) {
    final terms = <String>[];
    // Remove operators
    final cleaned = query
        .replaceAll(RegExp(r'\b(and|or|not)\b', caseSensitive: false), ' ')
        .trim();
    // Extract quoted terms and individual words
    final quotedPattern = RegExp(r'"([^"]+)"');
    for (final m in quotedPattern.allMatches(cleaned)) {
      terms.add(m.group(1)!);
    }
    final remaining = cleaned.replaceAll(quotedPattern, '').trim();
    if (remaining.isNotEmpty) {
      terms.addAll(remaining.split(RegExp(r'\s+')).where((t) => t.isNotEmpty));
    }
    return terms;
  }
}

class TagInfo {
  final String name;
  final int count;
  TagInfo(this.name, this.count);
}

class NoteSearchResult {
  final Note note;
  final List<SearchMatch> matches;
  NoteSearchResult({required this.note, required this.matches});
}

class SearchMatch {
  final int start;
  final int end;
  final String text;
  SearchMatch({required this.start, required this.end, required this.text});
}
