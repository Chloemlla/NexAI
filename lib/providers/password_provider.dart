import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/saved_password.dart';

class PasswordProvider extends ChangeNotifier {
  final List<SavedPassword> _passwords = [];
  
  List<SavedPassword> get passwords => _passwords;

  // Load passwords from local storage
  Future<void> loadPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    final passwordsJson = prefs.getString('saved_passwords');
    
    if (passwordsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(passwordsJson);
        _passwords.clear();
        _passwords.addAll(decoded.map((e) => SavedPassword.fromJson(e)));
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading passwords: $e');
      }
    }
  }

  // Save passwords to local storage
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final passwordsJson = jsonEncode(_passwords.map((e) => e.toJson()).toList());
    await prefs.setString('saved_passwords', passwordsJson);
  }

  // Add a new password
  Future<void> addPassword(SavedPassword password) async {
    _passwords.insert(0, password);
    notifyListeners();
    await _saveToStorage();
  }

  // Delete a password
  Future<void> deletePassword(String id) async {
    _passwords.removeWhere((p) => p.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  // Clear all passwords
  Future<void> clearAllPasswords() async {
    _passwords.clear();
    notifyListeners();
    await _saveToStorage();
  }

  // Export passwords to JSON
  String exportToJson() {
    return jsonEncode(_passwords.map((e) => e.toJson()).toList());
  }

  // Export passwords to CSV
  String exportToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('用途,密码,强度,备注,创建时间');
    
    for (final password in _passwords) {
      final strength = password.strength < 40 ? '弱' : password.strength < 70 ? '中等' : '强';
      buffer.writeln(
        '"${password.category}","${password.password}","$strength","${password.note}","${password.createdAt}"',
      );
    }
    
    return buffer.toString();
  }

  // Import passwords from JSON
  Future<bool> importFromJson(String jsonString) async {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final imported = decoded.map((e) => SavedPassword.fromJson(e)).toList();
      
      _passwords.addAll(imported);
      notifyListeners();
      await _saveToStorage();
      return true;
    } catch (e) {
      debugPrint('Error importing passwords: $e');
      return false;
    }
  }

  // Create backup
  Future<String> createBackup() async {
    final backup = {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'passwords': _passwords.map((e) => e.toJson()).toList(),
      'checksum': _generateChecksum(),
    };
    return jsonEncode(backup);
  }

  // Restore from backup
  Future<bool> restoreFromBackup(String backupString) async {
    try {
      final backup = jsonDecode(backupString);
      final checksum = backup['checksum'] as String;
      
      // Verify checksum
      final passwordsJson = jsonEncode(backup['passwords']);
      final calculatedChecksum = sha256.convert(utf8.encode(passwordsJson)).toString();
      
      if (checksum != calculatedChecksum) {
        debugPrint('Backup checksum mismatch');
        return false;
      }
      
      final List<dynamic> passwordsList = backup['passwords'];
      _passwords.clear();
      _passwords.addAll(passwordsList.map((e) => SavedPassword.fromJson(e)));
      
      notifyListeners();
      await _saveToStorage();
      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }

  String _generateChecksum() {
    final passwordsJson = jsonEncode(_passwords.map((e) => e.toJson()).toList());
    return sha256.convert(utf8.encode(passwordsJson)).toString();
  }

  // Get passwords by category
  List<SavedPassword> getPasswordsByCategory(String category) {
    return _passwords.where((p) => p.category == category).toList();
  }

  // Get all categories
  List<String> getAllCategories() {
    final categories = _passwords.map((p) => p.category).toSet().toList();
    categories.sort();
    return categories;
  }
}
