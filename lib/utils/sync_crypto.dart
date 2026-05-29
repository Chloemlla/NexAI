import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SyncCrypto {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  static const _keyStorageKey = 'nexai.sync.v2.key';
  static const algorithm = 'AES-256-GCM';
  static const keyId = 'local-secure-storage-v1';

  const SyncCrypto();

  Future<Map<String, dynamic>> encryptRecord({
    required String id,
    required String category,
    required String updatedAt,
    required Map<String, dynamic> payload,
  }) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(12);
    final aad = utf8.encode('$category:$id:$updatedAt');
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final plaintext = utf8.encode(jsonEncode(payload));
    final encrypted = encrypter.encryptBytes(
      plaintext,
      iv: iv,
      associatedData: Uint8List.fromList(aad),
    );

    return {
      'id': id,
      'category': category,
      'updatedAt': updatedAt,
      'deleted': false,
      'crypto': {
        'alg': algorithm,
        'kdf': 'none',
        'keyId': keyId,
        'nonce': _base64UrlNoPadding(iv.bytes),
        'aad': _base64UrlNoPadding(aad),
        'ciphertext': _base64UrlNoPadding(encrypted.bytes),
      },
    };
  }

  Future<Map<String, dynamic>?> decryptRecord(Map<String, dynamic> record) async {
    final crypto = record['crypto'];
    if (crypto is! Map<String, dynamic>) return null;
    if (crypto['alg'] != algorithm) return null;

    final storedKey = await _storage.read(key: _keyStorageKey);
    if (storedKey == null || storedKey.isEmpty) return null;

    final key = enc.Key(_base64UrlDecode(storedKey));
    final nonce = crypto['nonce'] as String?;
    final ciphertext = crypto['ciphertext'] as String?;
    if (nonce == null || ciphertext == null) return null;

    final aad = crypto['aad'] is String
        ? _base64UrlDecode(crypto['aad'] as String)
        : utf8.encode(
            '${record['category']}:${record['id']}:${record['updatedAt']}',
          );

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(_base64UrlDecode(ciphertext)),
      iv: enc.IV(_base64UrlDecode(nonce)),
      associatedData: Uint8List.fromList(aad),
    );

    final decoded = jsonDecode(utf8.decode(decrypted));
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<enc.Key> _getOrCreateKey() async {
    final existing = await _storage.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return enc.Key(_base64UrlDecode(existing));
    }

    final key = enc.Key.fromSecureRandom(32);
    await _storage.write(key: _keyStorageKey, value: _base64UrlNoPadding(key.bytes));
    return key;
  }

  static String _base64UrlNoPadding(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _base64UrlDecode(String value) {
    final normalized = value.padRight(value.length + (4 - value.length % 4) % 4, '=');
    return Uint8List.fromList(base64Url.decode(normalized));
  }
}
