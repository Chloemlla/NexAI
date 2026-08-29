import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../models/chat_knowledge.dart';
import '../models/message.dart';
import '../models/note.dart';
import '../providers/chat_provider.dart';
import '../providers/knowledge_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/password_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/short_url_provider.dart';
import '../providers/translation_provider.dart';

class LocalBackupException implements Exception {
  const LocalBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalBackupService {
  static const format = 'nexai-local-backup-v1';
  static const schemaVersion = 1;
  static const minPassphraseLength = 12;
  static const _kdfIterations = 120000;

  const LocalBackupService();

  Future<String> createBackup({
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required KnowledgeProvider knowledgeProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
    required String passphrase,
  }) async {
    final normalized = _validatePassphrase(passphrase);
    final payload = {
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'settings': settingsProvider.exportForLocalBackup(),
      'conversations': chatProvider.conversations.map((item) => item.toJson()).toList(),
      'notes': notesProvider.notes.map((item) => item.toJson()).toList(),
      'knowledgeBases': knowledgeProvider.bases.map((item) => item.toJson()).toList(),
      'knowledgeDocs': knowledgeProvider.docs.map((item) => item.toJson()).toList(),
      'activeKnowledgeBaseId': knowledgeProvider.activeBaseId,
      'savedPasswords': passwordProvider.passwords.map((item) => item.toJson()).toList(),
      'translationHistory': translationProvider.history.map((item) => item.toJson()).toList(),
      'shortUrls': shortUrlProvider.history.map((item) => item.toJson()).toList(),
    };

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = _deriveKey(normalized, salt, _kdfIterations);
    final encrypted = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
    ).encrypt(
      jsonEncode(payload),
      iv: enc.IV(nonce),
    );

    return jsonEncode({
      'format': format,
      'version': schemaVersion,
      'createdAt': payload['createdAt'],
      'crypto': {
        'algorithm': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': _kdfIterations,
        'salt': _encode(salt),
        'nonce': _encode(nonce),
        'ciphertext': _encode(encrypted.bytes),
      },
    });
  }

  Future<void> restoreBackup({
    required String raw,
    required String passphrase,
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required KnowledgeProvider knowledgeProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) async {
    final normalized = _validatePassphrase(passphrase);
    final payload = _decryptPayload(raw, normalized);
    final settings = _map(payload['settings'], 'settings');
    final conversations = _maps(payload['conversations'], 'conversations');
    final notes = _maps(payload['notes'], 'notes');
    final bases = _maps(payload['knowledgeBases'], 'knowledgeBases');
    final docs = _maps(payload['knowledgeDocs'], 'knowledgeDocs');
    final passwords = _maps(payload['savedPasswords'], 'savedPasswords');
    final translations = _maps(payload['translationHistory'], 'translationHistory');
    final shortUrls = _maps(payload['shortUrls'], 'shortUrls');

    final parsedConversations = conversations.map(Conversation.fromJson).toList();
    final parsedNotes = notes.map(Note.fromJson).toList();
    final parsedBases = bases.map(KnowledgeBase.fromJson).toList();
    final parsedDocs = docs.map(KnowledgeDoc.fromJson).toList();
    final parsedPasswords = passwords;
    final parsedTranslations = translations;
    final parsedShortUrls = shortUrls;

    await settingsProvider.restoreFromLocalBackup(settings);
    await notesProvider.restoreFromList(
      parsedNotes.map((item) => item.toJson()).toList(),
    );
    await chatProvider.restoreFromList(
      parsedConversations.map((item) => item.toJson()).toList(),
    );
    final activeBaseId = payload['activeKnowledgeBaseId'];
    await knowledgeProvider.restoreFromLocalBackup(
      bases: parsedBases,
      docs: parsedDocs,
      activeBaseId: activeBaseId is String ? activeBaseId : null,
    );
    await passwordProvider.restoreFromList(parsedPasswords);
    await translationProvider.restoreFromList(parsedTranslations);
    await shortUrlProvider.restoreFromList(parsedShortUrls);
  }

  String _validatePassphrase(String passphrase) {
    final normalized = passphrase.trim();
    if (normalized.length < minPassphraseLength) {
      throw const LocalBackupException('备份口令至少需要 12 个字符');
    }
    return normalized;
  }

  Map<String, dynamic> _decryptPayload(String raw, String passphrase) {
    try {
      final decoded = jsonDecode(raw);
      final backup = _map(decoded, 'backup');
      if (backup['format'] != format || backup['version'] != schemaVersion) {
        throw const LocalBackupException('不支持的 NexAI 备份格式或版本');
      }
      final crypto = _map(backup['crypto'], 'crypto');
      final iterations = crypto['iterations'];
      if (iterations is! int || iterations < 100000 || iterations > 500000) {
        throw const LocalBackupException('备份加密参数无效');
      }
      final salt = _decode(crypto['salt'], expectedLength: 16);
      final nonce = _decode(crypto['nonce'], expectedLength: 12);
      final ciphertext = _decode(crypto['ciphertext']);
      final key = _deriveKey(passphrase, salt, iterations);
      final plaintext = enc.Encrypter(
        enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
      ).decryptBytes(
        enc.Encrypted(ciphertext),
        iv: enc.IV(nonce),
      );
      final payload = _map(jsonDecode(utf8.decode(plaintext)), 'payload');
      if (payload['schemaVersion'] != schemaVersion) {
        throw const LocalBackupException('备份数据版本不兼容');
      }
      return payload;
    } on LocalBackupException {
      rethrow;
    } catch (_) {
      throw const LocalBackupException('备份口令错误或文件已损坏');
    }
  }

  static Map<String, dynamic> _map(Object? value, String name) {
    if (value is! Map) {
      throw LocalBackupException('备份数据格式无效：$name');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _maps(Object? value, String name) {
    if (value is! List) {
      throw LocalBackupException('备份数据格式无效：$name 不是列表');
    }
    return value.map((item) => _map(item, name)).toList(growable: false);
  }

  static String _encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _decode(Object? value, {int? expectedLength}) {
    if (value is! String || value.isEmpty) {
      throw const LocalBackupException('备份加密数据缺失');
    }
    try {
      final bytes = base64Url.decode(base64Url.normalize(value));
      if (expectedLength != null && bytes.length != expectedLength) {
        throw const LocalBackupException('备份加密参数长度无效');
      }
      return bytes;
    } on LocalBackupException {
      rethrow;
    } catch (_) {
      throw const LocalBackupException('备份加密数据无效');
    }
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static List<int> _deriveKey(
    String passphrase,
    List<int> salt,
    int iterations,
  ) {
    final hmac = Hmac(sha256, utf8.encode(passphrase));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(block);
    for (var i = 1; i < iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return result;
  }
}
