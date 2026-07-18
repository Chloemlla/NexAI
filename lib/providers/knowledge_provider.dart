/// Local imported-document knowledge provider for chat tools.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_knowledge.dart';
import '../utils/atomic_file_writer.dart';

class KnowledgeProvider extends ChangeNotifier {
  final List<KnowledgeBase> _bases = [];
  final List<KnowledgeDoc> _docs = [];
  bool _loaded = false;
  String _activeBaseId = 'default';

  List<KnowledgeBase> get bases => List.unmodifiable(_bases);
  List<KnowledgeDoc> get docs => List.unmodifiable(_docs);
  bool get loaded => _loaded;
  String get activeBaseId => _activeBaseId;

  List<KnowledgeDoc> docsInBase(String baseId) =>
      _docs.where((d) => d.baseId == baseId).toList(growable: false);

  Future<File> _docsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nexai_knowledge_docs.json');
  }

  Future<File> _basesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nexai_knowledge_bases.json');
  }

  Future<void> load() async {
    try {
      final basesFile = await _basesFile();
      if (await basesFile.exists()) {
        final raw = await basesFile.readAsString();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            _bases
              ..clear()
              ..addAll(
                decoded.whereType<Object>().map(
                  (e) => KnowledgeBase.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                ),
              );
          }
        }
      }

      final file = await _docsFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.isNotEmpty) {
          _docs
            ..clear()
            ..addAll(KnowledgeDoc.decodeList(raw));
        }
      }

      _ensureDefaultBase();
      var dirty = false;
      for (var i = 0; i < _docs.length; i++) {
        if (_docs[i].termWeights.isEmpty && _docs[i].content.isNotEmpty) {
          _docs[i] = _docs[i].copyWith(
            termWeights: _buildWeights(_docs[i].content),
          );
          dirty = true;
        }
      }
      if (dirty) await _saveDocs();
      if (_bases.isNotEmpty && !_bases.any((b) => b.id == _activeBaseId)) {
        _activeBaseId = _bases.first.id;
      }
    } catch (e) {
      debugPrint('NexAI knowledge load failed: $e');
      _ensureDefaultBase();
    }
    _loaded = true;
    notifyListeners();
  }

  void _ensureDefaultBase() {
    if (_bases.any((b) => b.id == 'default')) return;
    final now = DateTime.now();
    _bases.insert(
      0,
      KnowledgeBase(
        id: 'default',
        name: '默认知识库',
        description: '本地导入文档',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _saveDocs() async {
    try {
      final file = await _docsFile();
      await writeTextAtomically(file, KnowledgeDoc.encodeList(_docs));
    } catch (e) {
      debugPrint('NexAI knowledge docs save failed: $e');
    }
  }

  Future<void> _saveBases() async {
    try {
      final file = await _basesFile();
      await writeTextAtomically(
        file,
        jsonEncode(_bases.map((b) => b.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('NexAI knowledge bases save failed: $e');
    }
  }

  String _id() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    return b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  static Map<String, double> _buildWeights(String content) {
    final tokens = content
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
    final freq = <String, int>{};
    for (final t in tokens) {
      freq[t] = (freq[t] ?? 0) + 1;
    }
    if (freq.isEmpty) return const {};
    final maxF = freq.values.reduce((a, b) => a > b ? a : b).toDouble();
    return freq.map((k, v) => MapEntry(k, v / maxF));
  }

  Future<KnowledgeBase> createBase({
    required String name,
    String description = '',
  }) async {
    final now = DateTime.now();
    final base = KnowledgeBase(
      id: _id(),
      name: name.trim().isEmpty ? '未命名知识库' : name.trim(),
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _bases.insert(0, base);
    _activeBaseId = base.id;
    notifyListeners();
    await _saveBases();
    return base;
  }

  Future<void> renameBase(String id, String name) async {
    final idx = _bases.indexWhere((b) => b.id == id);
    if (idx < 0) return;
    _bases[idx] = _bases[idx].copyWith(
      name: name.trim().isEmpty ? _bases[idx].name : name.trim(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _saveBases();
  }

  Future<void> deleteBase(String id) async {
    if (id == 'default') return;
    _bases.removeWhere((b) => b.id == id);
    _docs.removeWhere((d) => d.baseId == id);
    if (_activeBaseId == id) _activeBaseId = 'default';
    notifyListeners();
    await _saveBases();
    await _saveDocs();
  }

  void setActiveBase(String id) {
    if (_activeBaseId == id) return;
    _activeBaseId = id;
    notifyListeners();
  }

  Future<KnowledgeDoc> importText({
    required String title,
    required String content,
    String sourceType = 'paste',
    String sourcePath = '',
    String? baseId,
    String folder = '',
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final doc = KnowledgeDoc(
      id: _id(),
      baseId: baseId ?? _activeBaseId,
      title: title.trim().isEmpty ? 'Imported Doc' : title.trim(),
      sourceType: sourceType,
      sourcePath: sourcePath,
      content: content,
      folder: folder,
      createdAt: now,
      updatedAt: now,
      tags: tags,
      termWeights: _buildWeights(content),
    );
    _docs.insert(0, doc);
    notifyListeners();
    await _saveDocs();
    return doc;
  }

  Future<KnowledgeDoc?> importFile(
    String path, {
    String? baseId,
    String folder = '',
  }) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final name = path.split(RegExp(r'[\\/]')).last;
    final lower = name.toLowerCase();
    if (!(lower.endsWith('.txt') ||
        lower.endsWith('.md') ||
        lower.endsWith('.markdown') ||
        lower.endsWith('.json') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.log') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.docx'))) {
      throw StateError('支持 txt/md/json/csv/log，以及实验性 pdf/docx 文本提取');
    }

    final String content;
    if (lower.endsWith('.pdf') || lower.endsWith('.docx')) {
      final bytes = await file.readAsBytes();
      content = _extractPrintableText(bytes);
      if (content.trim().length < 40) {
        throw StateError(
          '未能从 ${lower.endsWith('.pdf') ? 'PDF' : 'DOCX'} 提取到可用文本',
        );
      }
    } else {
      content = await file.readAsString();
    }

    return importText(
      title: name,
      content: content,
      sourceType: 'file',
      sourcePath: path,
      baseId: baseId,
      folder: folder,
    );
  }

  static String _extractPrintableText(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      if (b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127) || b >= 0xC0) {
        buffer.writeCharCode(b);
      } else {
        buffer.write(' ');
      }
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^\S\r\n]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<void> updateDoc({
    required String id,
    String? title,
    String? content,
    String? folder,
    List<String>? tags,
    String? baseId,
  }) async {
    final idx = _docs.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    final old = _docs[idx];
    final nextContent = content ?? old.content;
    _docs[idx] = old.copyWith(
      title: title,
      content: nextContent,
      folder: folder,
      tags: tags,
      baseId: baseId,
      updatedAt: DateTime.now(),
      termWeights:
          content == null ? old.termWeights : _buildWeights(nextContent),
    );
    notifyListeners();
    await _saveDocs();
  }

  Future<void> deleteDoc(String id) async {
    _docs.removeWhere((d) => d.id == id);
    notifyListeners();
    await _saveDocs();
  }

  KnowledgeDoc? byId(String id) {
    for (final doc in _docs) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  List<KnowledgeSearchHit> search(
    String query, {
    int limit = 8,
    String? baseId,
    bool semantic = true,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final hits = <KnowledgeSearchHit>[];
    for (final doc in _docs) {
      if (baseId != null && baseId.isNotEmpty && doc.baseId != baseId) continue;
      final hay = '${doc.title}\n${doc.folder}\n${doc.content}'.toLowerCase();
      var score = 0;
      for (final term in terms) {
        if (hay.contains(term)) score += 1;
        if (doc.title.toLowerCase().contains(term)) score += 2;
        if (doc.folder.toLowerCase().contains(term)) score += 1;
      }
      var semanticScore = 0.0;
      if (semantic && doc.termWeights.isNotEmpty) {
        for (final term in terms) {
          semanticScore += doc.termWeights[term] ?? 0;
        }
      }
      if (score <= 0 && semanticScore <= 0) continue;
      final idx = hay.indexOf(terms.first);
      final start = idx < 0 ? 0 : (idx - 40).clamp(0, hay.length);
      final end = idx < 0
          ? (doc.content.length < 160 ? doc.content.length : 160)
          : (idx + 120).clamp(0, doc.content.length);
      final snippet = doc.content.substring(
        start.clamp(0, doc.content.length),
        end.clamp(0, doc.content.length),
      );
      hits.add(
        KnowledgeSearchHit(
          doc: doc,
          snippet: snippet,
          score: score + (semanticScore * 10).round(),
          semanticScore: semanticScore,
        ),
      );
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.semanticScore.compareTo(a.semanticScore);
    });
    return hits.take(limit).toList(growable: false);
  }
}
