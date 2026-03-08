import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ShortUrlRecord — 短链接历史记录模型
class ShortUrlRecord {
  final String id;
  final String originalUrl;
  final String shortUrl;
  final DateTime createdAt;

  ShortUrlRecord({
    required this.id,
    required this.originalUrl,
    required this.shortUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalUrl': originalUrl,
    'shortUrl': shortUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ShortUrlRecord.fromJson(Map<String, dynamic> json) => ShortUrlRecord(
    id: json['id'] as String,
    originalUrl: json['originalUrl'] as String,
    shortUrl: json['shortUrl'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// ShortUrlProvider — 短链接历史持久化
class ShortUrlProvider extends ChangeNotifier {
  static const _key = 'nexai_short_url_history';

  final List<ShortUrlRecord> _history = [];
  List<ShortUrlRecord> get history => _history;

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        _history.clear();
        _history.addAll(decoded.map((e) => ShortUrlRecord.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NexAI: error loading short url history: $e');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_history.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addRecord(ShortUrlRecord record) async {
    _history.insert(0, record);
    // 最多保留 100 条记录
    if (_history.length > 100) {
      _history.removeRange(100, _history.length);
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
    _history.addAll(list.map((e) => ShortUrlRecord.fromJson(e)));
    notifyListeners();
    await _save();
  }

  List<Map<String, dynamic>> exportToJsonList() {
    return _history.map((e) => e.toJson()).toList();
  }
}
