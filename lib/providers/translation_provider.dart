import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TranslationRecord — 翻译历史记录模型
class TranslationRecord {
  final String id;
  final String sourceLanguage;
  final String targetLanguage;
  final String sourceText;
  final String translatedText;
  final DateTime createdAt;

  TranslationRecord({
    required this.id,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceText,
    required this.translatedText,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'sourceText': sourceText,
    'translatedText': translatedText,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TranslationRecord.fromJson(Map<String, dynamic> json) =>
      TranslationRecord(
        id: json['id'] as String,
        sourceLanguage: json['sourceLanguage'] as String,
        targetLanguage: json['targetLanguage'] as String,
        sourceText: json['sourceText'] as String,
        translatedText: json['translatedText'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// TranslationProvider — 翻译历史持久化
class TranslationProvider extends ChangeNotifier {
  static const _key = 'nexai_translation_history';

  final List<TranslationRecord> _history = [];
  List<TranslationRecord> get history => _history;

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        _history.clear();
        _history.addAll(decoded.map((e) => TranslationRecord.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NexAI: error loading translation history: $e');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_history.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addRecord(TranslationRecord record) async {
    _history.insert(0, record);
    // 最多保留 200 条记录
    if (_history.length > 200) {
      _history.removeRange(200, _history.length);
    }
    notifyListeners();
    await _save();
  }

  Future<void> deleteRecord(String id) async {
    _history.removeWhere((r) => r.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    await _save();
  }

  /// 从JSON数据恢复（同步用）
  Future<void> restoreFromList(List<dynamic> list) async {
    _history.clear();
    _history.addAll(list.map((e) => TranslationRecord.fromJson(e)));
    notifyListeners();
    await _save();
  }

  /// 增量合并：按 id upsert
  Future<void> mergeItems(List<dynamic> list) async {
    for (final item in list) {
      final incoming = TranslationRecord.fromJson(item as Map<String, dynamic>);
      final idx = _history.indexWhere((r) => r.id == incoming.id);
      if (idx == -1) {
        _history.insert(0, incoming);
      } else {
        _history[idx] = incoming;
      }
    }
    if (_history.length > 200) _history.removeRange(200, _history.length);
    notifyListeners();
    await _save();
  }

  List<Map<String, dynamic>> exportToJsonList() {
    return _history.map((e) => e.toJson()).toList();
  }
}
