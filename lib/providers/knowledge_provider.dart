/// Local imported-document knowledge provider for chat tools.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_knowledge.dart';
import '../utils/atomic_file_writer.dart';

class KnowledgeProvider extends ChangeNotifier {
  final List<KnowledgeDoc> _docs = [];
  bool _loaded = false;

  List<KnowledgeDoc> get docs => List.unmodifiable(_docs);
  bool get loaded => _loaded;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nexai_knowledge_docs.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.isNotEmpty) {
          _docs
            ..clear()
            ..addAll(KnowledgeDoc.decodeList(raw));
        }
      }
    } catch (e) {
      debugPrint('NexAI knowledge load failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await writeTextAtomically(file, KnowledgeDoc.encodeList(_docs));
    } catch (e) {
      debugPrint('NexAI knowledge save failed: $e');
    }
  }

  String _id() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    return b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<KnowledgeDoc> importText({
    required String title,
    required String content,
    String sourceType = 'paste',
    String sourcePath = '',
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final doc = KnowledgeDoc(
      id: _id(),
      title: title.trim().isEmpty ? 'Imported Doc' : title.trim(),
      sourceType: sourceType,
      sourcePath: sourcePath,
      content: content,
      createdAt: now,
      updatedAt: now,
      tags: tags,
    );
    _docs.insert(0, doc);
    notifyListeners();
    await _save();
    return doc;
  }

  Future<KnowledgeDoc?> importFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final name = path.split(RegExp(r'[\\/]')).last;
    final lower = name.toLowerCase();
    // Phase-2 scope: text-like docs only (pdf binary parsing deferred).
    if (!(lower.endsWith('.txt') ||
        lower.endsWith('.md') ||
        lower.endsWith('.markdown') ||
        lower.endsWith('.json') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.log'))) {
      throw StateError('仅支持导入文本类文件（txt/md/json/csv/log）');
    }
    final content = await file.readAsString();
    return importText(
      title: name,
      content: content,
      sourceType: 'file',
      sourcePath: path,
    );
  }

  Future<void> deleteDoc(String id) async {
    _docs.removeWhere((d) => d.id == id);
    notifyListeners();
    await _save();
  }

  KnowledgeDoc? byId(String id) {
    for (final doc in _docs) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  List<KnowledgeSearchHit> search(String query, {int limit = 8}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final hits = <KnowledgeSearchHit>[];
    for (final doc in _docs) {
      final hay = '${doc.title}\n${doc.content}'.toLowerCase();
      var score = 0;
      for (final term in terms) {
        if (hay.contains(term)) score += 1;
        if (doc.title.toLowerCase().contains(term)) score += 2;
      }
      if (score <= 0) continue;
      final idx = hay.indexOf(terms.first);
      final start = idx < 0 ? 0 : (idx - 40).clamp(0, hay.length);
      final end = idx < 0
          ? (doc.content.length < 160 ? doc.content.length : 160)
          : (idx + 120).clamp(0, doc.content.length);
      final snippet = doc.content.substring(
        start.clamp(0, doc.content.length),
        end.clamp(0, doc.content.length),
      );
      hits.add(KnowledgeSearchHit(doc: doc, snippet: snippet, score: score));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList(growable: false);
  }
}
