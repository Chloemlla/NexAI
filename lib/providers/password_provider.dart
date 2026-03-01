import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

import '../models/saved_password.dart';

class PasswordProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'nexai_passwords';

  final List<SavedPassword> _passwords = [];

  List<SavedPassword> get passwords => _passwords;

  Future<void> loadPasswords() async {
    try {
      // One-time migration from plaintext SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString('saved_passwords');
      if (legacy != null) {
        await _storage.write(key: _key, value: legacy);
        await prefs.remove('saved_passwords');
        debugPrint(
          'NexAI: migrated passwords from SharedPreferences → secure storage',
        );
      }

      final data = await _storage.read(key: _key);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        _passwords.clear();
        _passwords.addAll(decoded.map((e) => SavedPassword.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NexAI: error loading passwords: $e');
    }
  }

  Future<void> _saveToStorage() async {
    final passwordsJson = jsonEncode(
      _passwords.map((e) => e.toJson()).toList(),
    );
    await _storage.write(key: _key, value: passwordsJson);
  }

  Future<void> addPassword(SavedPassword password) async {
    _passwords.insert(0, password);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> deletePassword(String id) async {
    _passwords.removeWhere((p) => p.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> clearAllPasswords() async {
    _passwords.clear();
    notifyListeners();
    await _saveToStorage();
  }

  String exportToJson() {
    return jsonEncode(_passwords.map((e) => e.toJson()).toList());
  }

  String exportToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('用途,密码,强度,备注,创建时间');
    for (final password in _passwords) {
      final strength = password.strength < 40
          ? '弱'
          : password.strength < 70
          ? '中等'
          : '强';
      buffer.writeln(
        '"${password.category}","${password.password}","$strength","${password.note}","${password.createdAt}"',
      );
    }
    return buffer.toString();
  }

  Future<bool> importFromJson(String jsonString) async {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final imported = decoded.map((e) => SavedPassword.fromJson(e)).toList();
      _passwords.addAll(imported);
      notifyListeners();
      await _saveToStorage();
      return true;
    } catch (e) {
      debugPrint('NexAI: error importing passwords: $e');
      return false;
    }
  }

  Future<String> createBackup() async {
    final backup = {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'passwords': _passwords.map((e) => e.toJson()).toList(),
      'checksum': _generateChecksum(),
    };
    return jsonEncode(backup);
  }

  Future<bool> restoreFromBackup(String backupString) async {
    try {
      final backup = jsonDecode(backupString);
      final checksum = backup['checksum'] as String;
      final passwordsJson = jsonEncode(backup['passwords']);
      final calculatedChecksum = sha256
          .convert(utf8.encode(passwordsJson))
          .toString();
      if (checksum != calculatedChecksum) {
        debugPrint('NexAI: backup checksum mismatch');
        return false;
      }
      final List<dynamic> passwordsList = backup['passwords'];
      _passwords.clear();
      _passwords.addAll(passwordsList.map((e) => SavedPassword.fromJson(e)));
      notifyListeners();
      await _saveToStorage();
      return true;
    } catch (e) {
      debugPrint('NexAI: error restoring backup: $e');
      return false;
    }
  }

  String _generateChecksum() {
    final passwordsJson = jsonEncode(
      _passwords.map((e) => e.toJson()).toList(),
    );
    return sha256.convert(utf8.encode(passwordsJson)).toString();
  }

  List<SavedPassword> getPasswordsByCategory(String category) {
    return _passwords.where((p) => p.category == category).toList();
  }

  List<String> getAllCategories() {
    final categories = _passwords.map((p) => p.category).toSet().toList();
    categories.sort();
    return categories;
  }
}
