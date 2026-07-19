import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_password.dart';

class PasswordBackupException implements Exception {
  PasswordBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PasswordProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'nexai_passwords';

  /// Encrypted backup format constants (AES-256-GCM + PBKDF2-HMAC-SHA256).
  static const encryptedBackupFormat = 'nexai-password-backup-v2';
  static const encryptedBackupVersion = '2.0';
  static const _kdfIterations = 120000;

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

  /// 全量恢复（云同步覆盖本地密码库）
  Future<void> restoreFromList(List<dynamic> list) async {
    _passwords
      ..clear()
      ..addAll(
        list.map((item) {
          if (item is SavedPassword) return item;
          return SavedPassword.fromJson(Map<String, dynamic>.from(item as Map));
        }),
      );
    notifyListeners();
    await _saveToStorage();
  }

  /// 增量合并：按 id upsert
  Future<void> mergeItems(List<dynamic> list) async {
    for (final item in list) {
      final incoming = SavedPassword.fromJson(item as Map<String, dynamic>);
      final idx = _passwords.indexWhere((p) => p.id == incoming.id);
      if (idx == -1) {
        _passwords.insert(0, incoming);
      } else {
        _passwords[idx] = incoming;
      }
    }
    notifyListeners();
    await _saveToStorage();
  }

  /// Creates a passphrase-protected AES-256-GCM backup.
  ///
  /// The returned JSON never contains plaintext passwords. Requires a strong
  /// passphrase (minimum 8 characters).
  Future<String> createBackup({required String passphrase}) async {
    final normalized = passphrase.trim();
    if (normalized.length < 8) {
      throw PasswordBackupException('备份口令至少需要 8 个字符');
    }

    final plaintext = utf8.encode(
      jsonEncode({
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'passwords': _passwords.map((e) => e.toJson()).toList(),
      }),
    );

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final keyBytes = _deriveKey(
      passphrase: normalized,
      salt: salt,
      iterations: _kdfIterations,
    );
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm),
    );
    final encrypted = encrypter.encryptBytes(
      plaintext,
      iv: enc.IV(nonce),
    );

    final backup = {
      'version': encryptedBackupVersion,
      'format': encryptedBackupFormat,
      'timestamp': DateTime.now().toIso8601String(),
      'crypto': {
        'alg': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': _kdfIterations,
        'salt': base64Url.encode(salt).replaceAll('=', ''),
        'nonce': base64Url.encode(nonce).replaceAll('=', ''),
        'ciphertext': base64Url.encode(encrypted.bytes).replaceAll('=', ''),
      },
    };
    return jsonEncode(backup);
  }

  Future<bool> restoreFromBackup(
    String backupString, {
    String? passphrase,
  }) async {
    try {
      final decoded = jsonDecode(backupString);
      if (decoded is! Map) {
        return false;
      }
      final backup = Map<String, dynamic>.from(decoded);

      if (backup['format'] == encryptedBackupFormat ||
          backup['version'] == encryptedBackupVersion) {
        final normalized = passphrase?.trim() ?? '';
        if (normalized.length < 8) {
          throw PasswordBackupException('请输入正确的备份口令（至少 8 个字符）');
        }
        final passwordsList = _decryptBackupPayload(backup, normalized);
        _passwords
          ..clear()
          ..addAll(passwordsList.map((e) => SavedPassword.fromJson(e)));
        notifyListeners();
        await _saveToStorage();
        return true;
      }

      // Legacy v1: plaintext JSON + SHA-256 checksum (integrity only).
      final checksum = backup['checksum'] as String?;
      final passwordsJson = jsonEncode(backup['passwords']);
      if (checksum == null) {
        return false;
      }
      final calculatedChecksum = sha256
          .convert(utf8.encode(passwordsJson))
          .toString();
      if (checksum != calculatedChecksum) {
        debugPrint('NexAI: backup checksum mismatch');
        return false;
      }
      final List<dynamic> passwordsList = backup['passwords'] as List<dynamic>;
      _passwords
        ..clear()
        ..addAll(passwordsList.map((e) => SavedPassword.fromJson(e)));
      notifyListeners();
      await _saveToStorage();
      return true;
    } on PasswordBackupException {
      rethrow;
    } catch (e) {
      debugPrint('NexAI: error restoring backup: $e');
      return false;
    }
  }

  /// Pure helper for unit tests: encrypt/decrypt round-trip without storage.
  @visibleForTesting
  static String encryptBackupPayloadForTest({
    required List<Map<String, dynamic>> passwords,
    required String passphrase,
    int iterations = _kdfIterations,
    List<int>? salt,
    List<int>? nonce,
  }) {
    final saltBytes = Uint8List.fromList(salt ?? _randomBytes(16));
    final nonceBytes = Uint8List.fromList(nonce ?? _randomBytes(12));
    final plaintext = utf8.encode(
      jsonEncode({
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'passwords': passwords,
      }),
    );
    final keyBytes = _deriveKey(
      passphrase: passphrase,
      salt: saltBytes,
      iterations: iterations,
    );
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm),
    );
    final encrypted = encrypter.encryptBytes(
      plaintext,
      iv: enc.IV(nonceBytes),
    );
    return jsonEncode({
      'version': encryptedBackupVersion,
      'format': encryptedBackupFormat,
      'timestamp': DateTime.now().toIso8601String(),
      'crypto': {
        'alg': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'salt': base64Url.encode(saltBytes).replaceAll('=', ''),
        'nonce': base64Url.encode(nonceBytes).replaceAll('=', ''),
        'ciphertext': base64Url.encode(encrypted.bytes).replaceAll('=', ''),
      },
    });
  }

  @visibleForTesting
  static List<Map<String, dynamic>> decryptBackupPayloadForTest(
    String backupString,
    String passphrase,
  ) {
    final decoded = jsonDecode(backupString);
    if (decoded is! Map) {
      throw PasswordBackupException('备份格式无效');
    }
    return _decryptBackupPayload(
      Map<String, dynamic>.from(decoded),
      passphrase,
    );
  }

  static List<Map<String, dynamic>> _decryptBackupPayload(
    Map<String, dynamic> backup,
    String passphrase,
  ) {
    final crypto = backup['crypto'];
    if (crypto is! Map) {
      throw PasswordBackupException('备份缺少加密字段');
    }
    final cryptoMap = Map<String, dynamic>.from(crypto);
    if (cryptoMap['alg'] != 'AES-256-GCM' ||
        cryptoMap['kdf'] != 'PBKDF2-HMAC-SHA256') {
      throw PasswordBackupException('不支持的备份加密算法');
    }

    final iterations = cryptoMap['iterations'];
    if (iterations is! int || iterations < 10000) {
      throw PasswordBackupException('备份 KDF 参数无效');
    }
    final salt = _base64UrlDecode(cryptoMap['salt'] as String? ?? '');
    final nonce = _base64UrlDecode(cryptoMap['nonce'] as String? ?? '');
    final ciphertext = _base64UrlDecode(
      cryptoMap['ciphertext'] as String? ?? '',
    );
    if (salt.isEmpty || nonce.isEmpty || ciphertext.isEmpty) {
      throw PasswordBackupException('备份密文不完整');
    }

    try {
      final keyBytes = _deriveKey(
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
      );
      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(keyBytes), mode: enc.AESMode.gcm),
      );
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(ciphertext),
        iv: enc.IV(nonce),
      );
      final payload = jsonDecode(utf8.decode(decrypted));
      if (payload is! Map) {
        throw PasswordBackupException('解密后的备份格式无效');
      }
      final passwords = payload['passwords'];
      if (passwords is! List) {
        throw PasswordBackupException('解密后的备份缺少密码列表');
      }
      return passwords
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    } catch (e) {
      if (e is PasswordBackupException) rethrow;
      throw PasswordBackupException('口令错误或备份已损坏');
    }
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018) using package:crypto only.
  static Uint8List _deriveKey({
    required String passphrase,
    required Uint8List salt,
    required int iterations,
  }) {
    const keyLength = 32;
    final password = utf8.encode(passphrase);
    final hmacLength = sha256.convert(<int>[]).bytes.length;
    final blockCount = (keyLength + hmacLength - 1) ~/ hmacLength;
    final derived = BytesBuilder(copy: false);

    for (var block = 1; block <= blockCount; block++) {
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      var u = Hmac(sha256, password).convert(
        <int>[...salt, ...blockBytes.buffer.asUint8List()],
      ).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = Hmac(sha256, password).convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      derived.add(t);
    }

    return Uint8List.fromList(derived.toBytes().sublist(0, keyLength));
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _base64UrlDecode(String value) {
    if (value.isEmpty) return Uint8List(0);
    final normalized = value.padRight(
      value.length + (4 - value.length % 4) % 4,
      '=',
    );
    return Uint8List.fromList(base64Url.decode(normalized));
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
