import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../models/note.dart';

/// Generates a random UUID v4 without external dependencies.
String _newId() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant bits
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];
  // Backlink index: targetNoteId -> set of sourceNoteIds
  Map<String, Set<String>> _backlinks = {};

  // Dio instance for AI title generation
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

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

  // ─── Backlinks ───

  /// Rebuild the backlink index by scanning all notes for wiki-links
  void _rebuildBacklinks() {
    _backlinks = {};
    for (final note in _notes) {
      for (final link in note.wikiLinks) {
        final target = _findNoteByTitle(link.target);
        if (target != null) {
          _backlinks.putIfAbsent(target.id, () => {}).add(note.id);
        }
      }
    }
  }

  /// Find a note by title (case-insensitive)
  Note? _findNoteByTitle(String title) {
    final lower = title.toLowerCase().trim();
    return _notes
        .where((n) => n.title.toLowerCase().trim() == lower)
        .firstOrNull;
  }

  /// Find a note by title (public)
  Note? findNoteByTitle(String title) => _findNoteByTitle(title);

  /// Get all notes that link TO the given note (backlinks / incoming)
  List<Note> getBacklinks(String noteId) {
    final ids = _backlinks[noteId];
    if (ids == null || ids.isEmpty) return [];
    return _notes.where((n) => ids.contains(n.id)).toList();
  }

  /// Get all notes that the given note links TO (outgoing)
  List<Note> getOutgoingLinks(String noteId) {
    final note = _notes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) return [];
    final targets = <Note>[];
    for (final link in note.wikiLinks) {
      final target = _findNoteByTitle(link.target);
      if (target != null && target.id != noteId) targets.add(target);
    }
    return targets.toSet().toList();
  }

  /// Find unlinked mentions: notes whose title appears in the given note's
  /// content but are not linked via [[...]]
  List<Note> getUnlinkedMentions(String noteId) {
    final note = _notes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) return [];
    final linkedNames = note.linkedNoteNames;
    final body = note.bodyContent.toLowerCase();
    final result = <Note>[];
    for (final other in _notes) {
      if (other.id == noteId) continue;
      if (other.title.trim().isEmpty || other.title == 'Untitled Note') {
        continue;
      }
      final otherTitle = other.title.toLowerCase().trim();
      if (linkedNames.contains(otherTitle)) continue; // already linked
      if (body.contains(otherTitle)) {
        result.add(other);
      }
    }
    return result;
  }

  /// Create a link from sourceNote to targetNote title at cursor position
  void addLinkToNote(String sourceNoteId, String targetTitle) {
    final idx = _notes.indexWhere((n) => n.id == sourceNoteId);
    if (idx == -1) return;
    final note = _notes[idx];
    // Replace first unlinked mention with wiki-link
    final pattern = RegExp(RegExp.escape(targetTitle), caseSensitive: false);
    final match = pattern.firstMatch(note.content);
    if (match != null) {
      // Check it's not already inside [[ ]]
      final before = note.content.substring(0, match.start);
      final after = note.content.substring(match.end);
      if (!before.endsWith('[[') || !after.startsWith(']]')) {
        note.content = '$before[[$targetTitle]]$after';
        note.updatedAt = DateTime.now();
        _rebuildBacklinks();
        notifyListeners();
        _save();
      }
    }
  }

  // ─── Graph data ───

  /// Get graph data: nodes and edges for all notes
  GraphData getGraphData({String? tagFilter, bool? starredOnly}) {
    var filtered = _notes.toList();
    if (tagFilter != null) {
      filtered = filtered.where((n) => n.tags.contains(tagFilter)).toList();
    }
    if (starredOnly == true) {
      filtered = filtered.where((n) => n.isStarred).toList();
    }
    final filteredIds = filtered.map((n) => n.id).toSet();

    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];

    for (final note in filtered) {
      final backlinkCount = _backlinks[note.id]?.length ?? 0;
      final outCount = note.wikiLinks.length;
      nodes.add(
        GraphNode(
          id: note.id,
          title: note.title,
          linkCount: backlinkCount + outCount,
          tags: note.tags,
          isStarred: note.isStarred,
          updatedAt: note.updatedAt,
        ),
      );

      for (final link in note.wikiLinks) {
        final target = _findNoteByTitle(link.target);
        if (target != null && filteredIds.contains(target.id)) {
          edges.add(GraphEdge(sourceId: note.id, targetId: target.id));
        }
      }
    }

    return GraphData(nodes: nodes, edges: edges);
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nexai_notes.json');
  }

  Future<void> loadNotes() async {
    try {
      final file = await _getFile();

      if (await file.exists()) {
        // Normal load from file
        final jsonStr = await file.readAsString();
        if (jsonStr.isNotEmpty) {
          _notes = Note.decodeList(jsonStr);
        }
      } else {
        // One-time migration from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString('notes');
        if (legacy != null && legacy.isNotEmpty) {
          _notes = Note.decodeList(legacy);
          await _save(); // write to file
          await prefs.remove('notes'); // remove old key
          debugPrint(
            'NexAI: migrated ${_notes.length} notes from SharedPreferences → file',
          );
        }
      }

      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('NexAI: error loading notes: $e');
    }
    _rebuildBacklinks();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      await file.writeAsString(Note.encodeList(_notes));
    } catch (e) {
      debugPrint('NexAI: error saving notes: $e');
    }
  }

  Note createNote({String title = '', String content = ''}) {
    final now = DateTime.now();
    final note = Note(
      id: _newId(),
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
    _rebuildBacklinks();
    notifyListeners();
    _save();
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    _rebuildBacklinks();
    notifyListeners();
    _save();
  }

  void appendToNote(String id, String text) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final note = _notes[idx];
    note.content = note.content.isEmpty
        ? text
        : '${note.content}\n\n---\n\n$text';
    note.updatedAt = DateTime.now();
    _rebuildBacklinks();
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
      candidates = candidates
          .where(
            (n) => n.tags.any(
              (t) => t.toLowerCase().contains(tagFilter!.toLowerCase()),
            ),
          )
          .toList();
    }
    if (starFilter == true) {
      candidates = candidates.where((n) => n.isStarred).toList();
    }

    if (searchQuery.isEmpty) {
      return candidates
          .map((n) => NoteSearchResult(note: n, matches: []))
          .toList();
    }

    // Check if regex search (wrapped in /.../)
    RegExp? regexSearch;
    if (searchQuery.startsWith('/') &&
        searchQuery.endsWith('/') &&
        searchQuery.length > 2) {
      try {
        regexSearch = RegExp(
          searchQuery.substring(1, searchQuery.length - 1),
          caseSensitive: false,
        );
      } catch (_) {
        // Invalid regex, fall through to text search
      }
    }

    for (final note in candidates) {
      final fullText = '${note.title}\n${note.content}';
      final matches = <SearchMatch>[];

      if (regexSearch != null) {
        for (final m in regexSearch.allMatches(fullText)) {
          matches.add(
            SearchMatch(start: m.start, end: m.end, text: m.group(0)!),
          );
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
              matches.add(
                SearchMatch(
                  start: pos,
                  end: pos + term.length,
                  text: fullText.substring(pos, pos + term.length),
                ),
              );
              pos += term.length;
            }
          }
        }
      }

      if (matches.isNotEmpty ||
          (regexSearch == null && _evaluateQuery(searchQuery, fullText))) {
        results.add(NoteSearchResult(note: note, matches: matches));
      }
    }

    return results;
  }

  bool _evaluateQuery(String query, String text) {
    try {
      return _QueryParser(query, text).parse();
    } catch (_) {
      // Malformed query — fall back to simple contains
      return text.toLowerCase().contains(query.trim().toLowerCase());
    }
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

  // ─── AI Title Generation ───

  /// Generate a title for a note using AI if it's untitled
  Future<void> generateTitleIfNeeded({
    required String noteId,
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx == -1) return;

    final note = _notes[idx];

    // Only generate title if it's "Untitled Note" and has content
    if (note.title != 'Untitled Note' || note.content.trim().isEmpty) {
      return;
    }

    try {
      // Extract first 500 characters of content for title generation
      final contentPreview = note.bodyContent.length > 500
          ? note.bodyContent.substring(0, 500)
          : note.bodyContent;

      final response = await _dio.post(
        '$baseUrl/chat/completions',
        data: {
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a helpful assistant that generates concise, descriptive titles for notes. Generate a title that is 3-8 words long, capturing the main topic. Respond with ONLY the title, no quotes or extra text.',
            },
            {
              'role': 'user',
              'content':
                  'Generate a concise title for this note:\n\n$contentPreview',
            },
          ],
          'temperature': 0.7,
          'max_tokens': 50,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final generatedTitle = message?['content'] as String?;

          if (generatedTitle != null && generatedTitle.trim().isNotEmpty) {
            // Clean up the title (remove quotes, trim, limit length)
            var cleanTitle = generatedTitle
                .trim()
                .replaceAll(RegExp(r'^["\x27]|["\x27]$'), '')
                .trim();

            if (cleanTitle.length > 60) {
              cleanTitle = cleanTitle.substring(0, 60);
            }

            if (cleanTitle.isNotEmpty) {
              _notes[idx].title = cleanTitle;
              _notes[idx].updatedAt = DateTime.now();
              notifyListeners();
              _save();
              debugPrint('NexAI: Generated title for note: $cleanTitle');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('NexAI: Failed to generate title: $e');
      // Silently fail - keep "Untitled Note" if generation fails
    }
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

// ─── Graph data classes ───

class GraphNode {
  final String id;
  final String title;
  final int linkCount;
  final List<String> tags;
  final bool isStarred;
  final DateTime updatedAt;
  // Layout position (mutable, set by layout algorithm)
  double x = 0;
  double y = 0;

  GraphNode({
    required this.id,
    required this.title,
    required this.linkCount,
    required this.tags,
    required this.isStarred,
    required this.updatedAt,
  });
}

class GraphEdge {
  final String sourceId;
  final String targetId;
  GraphEdge({required this.sourceId, required this.targetId});
}

class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  GraphData({required this.nodes, required this.edges});
}

// ─── Boolean query parser ───
// Grammar (lowest to highest precedence):
//   expr   := or_expr
//   or_expr  := and_expr  ( 'OR'  and_expr  )*
//   and_expr := not_expr  ( 'AND' not_expr  )*   |  not_expr not_expr*  (implicit AND)
//   not_expr := 'NOT' not_expr  |  atom
//   atom     := '(' expr ')'  |  '"' phrase '"'  |  word

class _QueryParser {
  final String _lower; // normalised haystack
  final List<String> _tokens;
  int _pos = 0;

  _QueryParser(String query, String text)
    : _lower = text.toLowerCase(),
      _tokens = _tokenise(query);

  // Split query into tokens: words, quoted strings, parens, operators
  static List<String> _tokenise(String q) {
    final tokens = <String>[];
    final re = RegExp(r'"[^"]*"|\(|\)|[^\s()]+');
    for (final m in re.allMatches(q.trim())) {
      tokens.add(m.group(0)!);
    }
    return tokens;
  }

  bool parse() {
    if (_tokens.isEmpty) return false;
    final result = _parseOr();
    return result;
  }

  bool _parseOr() {
    var left = _parseAnd();
    while (_peek()?.toUpperCase() == 'OR') {
      _consume();
      final right = _parseAnd();
      left = left || right;
    }
    return left;
  }

  bool _parseAnd() {
    var left = _parseNot();
    while (_pos < _tokens.length) {
      final next = _peek()?.toUpperCase();
      // Explicit AND or implicit AND (next token is not OR / closing paren)
      if (next == 'AND') {
        _consume();
        final right = _parseNot();
        left = left && right;
      } else if (next != null && next != 'OR' && next != ')') {
        final right = _parseNot();
        left = left && right;
      } else {
        break;
      }
    }
    return left;
  }

  bool _parseNot() {
    if (_peek()?.toUpperCase() == 'NOT') {
      _consume();
      return !_parseNot();
    }
    return _parseAtom();
  }

  bool _parseAtom() {
    final token = _peek();
    if (token == null) return false;

    if (token == '(') {
      _consume(); // consume '('
      final result = _parseOr();
      if (_peek() == ')') _consume(); // consume ')'
      return result;
    }

    _consume();

    // Quoted phrase: exact match
    if (token.startsWith('"') && token.endsWith('"') && token.length >= 2) {
      final phrase = token.substring(1, token.length - 1).toLowerCase();
      return phrase.isEmpty ? false : _lower.contains(phrase);
    }

    // Plain word: case-insensitive contains
    return _lower.contains(token.toLowerCase());
  }

  String? _peek() => _pos < _tokens.length ? _tokens[_pos] : null;
  void _consume() {
    if (_pos < _tokens.length) _pos++;
  }
}
