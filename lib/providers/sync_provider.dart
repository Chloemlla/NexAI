/// NexAI Cloud Sync Provider
/// Orchestrates syncing local data to/from the cloud backend
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';
import '../models/note.dart';
import '../services/nexai_sync_service.dart';
import '../utils/sync_crypto.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'chat_provider.dart';
import 'notes_provider.dart';
import 'password_provider.dart';
import 'translation_provider.dart';
import 'short_url_provider.dart';

enum SyncStatus { idle, uploading, downloading, success, error }

class SyncRestoreException implements Exception {
  SyncRestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SyncProvider extends ChangeNotifier {
  static const _syncCrypto = SyncCrypto();

  SyncStatus _status = SyncStatus.idle;
  String? _errorMessage;
  DateTime? _lastSyncedAt;

  SyncStatus get status => _status;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  bool get isSyncing =>
      _status == SyncStatus.uploading || _status == SyncStatus.downloading;

  /// 上传所有本地数据到云端
  Future<bool> uploadAll({
    required AuthProvider authProvider,
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) async {
    if (authProvider.accessToken == null) {
      _errorMessage = '请先登录';
      _status = SyncStatus.error;
      notifyListeners();
      return false;
    }

    _status = SyncStatus.uploading;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _buildEncryptedSnapshot(
        settingsProvider: settingsProvider,
        chatProvider: chatProvider,
        notesProvider: notesProvider,
        translationProvider: translationProvider,
        shortUrlProvider: shortUrlProvider,
      );

      final response = await NexaiSyncApi.putSyncDataV2(
        accessToken: authProvider.accessToken!,
        snapshot: snapshot,
      );
      final success = response != null;

      if (success) {
        _status = SyncStatus.success;
        final syncedAt =
            response['serverTime'] as String? ??
            snapshot['updatedAt'] as String;
        await _saveLastSyncedAt(syncedAt);
      } else {
        _status = SyncStatus.error;
        _errorMessage = '上传失败';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = '上传失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 从云端下载并恢复所有数据到本地
  Future<bool> downloadAll({
    required AuthProvider authProvider,
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) async {
    if (authProvider.accessToken == null) {
      _errorMessage = '请先登录';
      _status = SyncStatus.error;
      notifyListeners();
      return false;
    }

    _status = SyncStatus.downloading;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await NexaiSyncApi.getSyncDataV2(
        accessToken: authProvider.accessToken!,
      );

      if (snapshot == null) {
        _status = SyncStatus.error;
        _errorMessage = '云端暂无同步数据';
        notifyListeners();
        return false;
      }

      final data = await _decryptSnapshot(snapshot);
      await _restoreLocalData(
        data: data,
        settingsProvider: settingsProvider,
        chatProvider: chatProvider,
        notesProvider: notesProvider,
        passwordProvider: passwordProvider,
        translationProvider: translationProvider,
        shortUrlProvider: shortUrlProvider,
      );

      _status = SyncStatus.success;
      final syncedAt =
          snapshot['serverTime'] as String? ??
          snapshot['updatedAt'] as String? ??
          DateTime.now().toIso8601String();
      await _saveLastSyncedAt(syncedAt);
      notifyListeners();
      return true;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = '下载失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 按类别上传
  Future<bool> uploadCategory({
    required AuthProvider authProvider,
    required String category,
    required dynamic data,
  }) async {
    debugPrint(
      'NexAI Sync: uploadCategory [$category] skipped; legacy plaintext sync is disabled',
    );
    return false;
  }

  /// 获取同步元信息
  Future<void> fetchSyncMeta({required AuthProvider authProvider}) async {
    if (authProvider.accessToken == null) return;
    try {
      final meta = await NexaiSyncApi.getSyncMetaV2(
        accessToken: authProvider.accessToken!,
      );
      if (meta != null && meta['lastSyncedAt'] != null) {
        _lastSyncedAt = DateTime.parse(meta['lastSyncedAt']);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NexAI Sync: fetchSyncMeta error: $e');
    }
  }

  /// 清除所有云端同步数据
  Future<bool> clearCloudData({required AuthProvider authProvider}) async {
    if (authProvider.accessToken == null) return false;
    try {
      final success = await NexaiSyncApi.deleteSyncDataV2(
        accessToken: authProvider.accessToken!,
      );
      if (success) {
        _lastSyncedAt = null;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('NexAI Sync: clearCloudData error: $e');
      return false;
    }
  }

  void resetStatus() {
    _status = SyncStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // ── 持久化 lastSyncedAt ──

  static const _lastSyncKey = 'nexai_last_synced_at';
  static const _deviceIdKey = 'nexai_sync_device_id';

  Future<String?> _getSavedLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  Future<void> _saveLastSyncedAt(String isoTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, isoTime);
    _lastSyncedAt = DateTime.parse(isoTime);
  }

  /// 加载本地保存的同步时间
  Future<void> loadLastSyncedAt() async {
    final saved = await _getSavedLastSyncedAt();
    if (saved != null) {
      _lastSyncedAt = DateTime.tryParse(saved);
      notifyListeners();
    }
  }

  // ── 增量同步 ──

  /// 增量同步暂不回落到旧版明文接口，先使用 v2 加密全量上传。
  Future<bool> incrementalSync({
    required AuthProvider authProvider,
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) async {
    debugPrint(
      'NexAI Sync: encrypted incremental sync is not wired; using full v2 upload',
    );
    return uploadAll(
      authProvider: authProvider,
      settingsProvider: settingsProvider,
      chatProvider: chatProvider,
      notesProvider: notesProvider,
      passwordProvider: passwordProvider,
      translationProvider: translationProvider,
      shortUrlProvider: shortUrlProvider,
    );
  }

  Map<String, dynamic> _collectSettings(SettingsProvider s) {
    return {
      'baseUrl': s.baseUrl,
      'models': s.models.join(','),
      'selectedModel': s.selectedModel,
      'themeMode': s.themeMode.name,
      'temperature': s.temperature,
      'maxTokens': s.maxTokens,
      'systemPrompt': s.systemPrompt,
      'accentColorValue': s.accentColorValue,
      'fontSize': s.fontSize,
      'fontFamily': s.fontFamily,
      'borderlessMode': s.borderlessMode,
      'fullScreenMode': s.fullScreenMode,
      'smartAutoScroll': s.smartAutoScroll,
      'syncEnabled': s.syncEnabled,
      'syncMethod': s.syncMethod,
      'webdavServer': s.webdavServer,
      'webdavUser': s.webdavUser,
      'upstashUrl': s.upstashUrl,
      'apiMode': s.apiMode,
      'vertexProjectId': s.vertexProjectId,
      'vertexLocation': s.vertexLocation,
      'notesAutoSave': s.notesAutoSave,
      'aiTitleGeneration': s.aiTitleGeneration,
    };
  }

  Future<Map<String, dynamic>> _buildEncryptedSnapshot({
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) async {
    final snapshotTime = DateTime.now().toUtc().toIso8601String();
    final records = <Map<String, dynamic>>[];

    Future<void> addRecord({
      required String id,
      required String category,
      required String updatedAt,
      required Map<String, dynamic> payload,
    }) async {
      records.add(
        await _syncCrypto.encryptRecord(
          id: id,
          category: category,
          updatedAt: updatedAt,
          payload: payload,
        ),
      );
    }

    await addRecord(
      id: 'settings',
      category: 'settings',
      updatedAt: snapshotTime,
      payload: _collectSettings(settingsProvider),
    );

    for (final note in notesProvider.notes) {
      await addRecord(
        id: note.id,
        category: 'notes',
        updatedAt: note.updatedAt.toUtc().toIso8601String(),
        payload: note.toJson(),
      );
    }

    for (final conversation in chatProvider.conversations) {
      final updatedAt = conversation.messages.isNotEmpty
          ? conversation.messages.last.timestamp
          : conversation.createdAt;
      await addRecord(
        id: conversation.id,
        category: 'conversations',
        updatedAt: updatedAt.toUtc().toIso8601String(),
        payload: conversation.toJson(),
      );
    }

    for (final item in translationProvider.history) {
      await addRecord(
        id: item.id,
        category: 'translationHistory',
        updatedAt: item.createdAt.toUtc().toIso8601String(),
        payload: item.toJson(),
      );
    }

    for (final item in shortUrlProvider.history) {
      await addRecord(
        id: item.id,
        category: 'shortUrls',
        updatedAt: item.createdAt.toUtc().toIso8601String(),
        payload: item.toJson(),
      );
    }

    return {
      'schemaVersion': 2,
      'deviceId': await _getOrCreateDeviceId(),
      'snapshotId': 'snap_${DateTime.now().microsecondsSinceEpoch}',
      'updatedAt': snapshotTime,
      'records': records,
    };
  }

  @visibleForTesting
  Future<Map<String, dynamic>> debugDecryptSnapshot(
    Map<String, dynamic> snapshot,
  ) => _decryptSnapshot(snapshot);

  Future<Map<String, dynamic>> _decryptSnapshot(
    Map<String, dynamic> snapshot,
  ) async {
    final records = snapshot['records'];
    if (records is! List) {
      throw SyncRestoreException('云端同步数据格式无效：records 不是列表');
    }

    Map<String, dynamic>? settings;
    final notes = <Map<String, dynamic>>[];
    final conversations = <Map<String, dynamic>>[];
    final translations = <Map<String, dynamic>>[];
    final shortUrls = <Map<String, dynamic>>[];

    for (final item in records) {
      if (item is! Map) {
        throw SyncRestoreException('云端同步数据包含无效记录');
      }

      final record = Map<String, dynamic>.from(item);
      if (record['deleted'] == true) continue;

      try {
        final payload = await _syncCrypto.decryptRecord(record);
        if (payload == null) {
          throw SyncRestoreException(
            '无法解密 ${record['category'] ?? 'unknown'} 记录',
          );
        }

        switch (record['category']) {
          case 'settings':
            settings = payload;
            break;
          case 'notes':
            notes.add(payload);
            break;
          case 'conversations':
            conversations.add(payload);
            break;
          case 'translationHistory':
            translations.add(payload);
            break;
          case 'shortUrls':
            shortUrls.add(payload);
            break;
          default:
            throw SyncRestoreException('未知同步数据类别: ${record['category']}');
        }
      } catch (e) {
        debugPrint('NexAI Sync: refusing partial restore: $e');
        if (e is SyncRestoreException) rethrow;
        throw SyncRestoreException('无法解密或验证云端同步记录: $e');
      }
    }

    return {
      'settings': ?settings,
      'notes': notes,
      'conversations': conversations,
      'translationHistory': translations,
      'shortUrls': shortUrls,
    };
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final deviceId = 'dev_${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  Future<void> _restoreSettings(
    Map<String, dynamic> s,
    SettingsProvider sp,
  ) async {
    if (s['baseUrl'] != null) await sp.setBaseUrl(s['baseUrl']);
    if (s['models'] != null) await sp.setModels(s['models']);
    if (s['selectedModel'] != null) {
      await sp.setSelectedModel(s['selectedModel']);
    }
    if (s['temperature'] != null) {
      await sp.setTemperature((s['temperature'] as num).toDouble());
    }
    if (s['maxTokens'] != null) await sp.setMaxTokens(s['maxTokens'] as int);
    if (s['systemPrompt'] != null) await sp.setSystemPrompt(s['systemPrompt']);
    if (s['fontSize'] != null) {
      await sp.setFontSize((s['fontSize'] as num).toDouble());
    }
    if (s['fontFamily'] != null) await sp.setFontFamily(s['fontFamily']);
    if (s['borderlessMode'] != null) {
      await sp.setBorderlessMode(s['borderlessMode']);
    }
    if (s['fullScreenMode'] != null) {
      await sp.setFullScreenMode(s['fullScreenMode']);
    }
    if (s['smartAutoScroll'] != null) {
      await sp.setSmartAutoScroll(s['smartAutoScroll']);
    }
    if (s['apiMode'] != null) await sp.setApiMode(s['apiMode']);
    if (s['vertexProjectId'] != null) {
      await sp.setVertexProjectId(s['vertexProjectId']);
    }
    if (s['vertexLocation'] != null) {
      await sp.setVertexLocation(s['vertexLocation']);
    }
    if (s['notesAutoSave'] != null) {
      await sp.setNotesAutoSave(s['notesAutoSave']);
    }
    if (s['aiTitleGeneration'] != null) {
      await sp.setAiTitleGeneration(s['aiTitleGeneration']);
    }
    if (s.containsKey('accentColorValue')) {
      await sp.setAccentColor(s['accentColorValue'] as int?);
    }
    if (s['syncEnabled'] != null) await sp.setSyncEnabled(s['syncEnabled']);
    if (s['syncMethod'] != null) await sp.setSyncMethod(s['syncMethod']);
    if (s['webdavServer'] != null) await sp.setWebdavServer(s['webdavServer']);
    if (s['webdavUser'] != null) await sp.setWebdavUser(s['webdavUser']);
    if (s['upstashUrl'] != null) await sp.setUpstashUrl(s['upstashUrl']);
  }

  // ── 内部: 恢复本地数据 ──

  Future<void> _restoreLocalData({
    required Map<String, dynamic> data,
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) async {
    final settings = data['settings'];
    if (settings != null) {
      _validateSettingsPayload(settings);
    }
    final notes = _validatedList<Note>(
      data['notes'],
      'notes',
      (json) => Note.fromJson(json),
    );
    final conversations = _validatedList<Conversation>(
      data['conversations'],
      'conversations',
      (json) => Conversation.fromJson(json),
    );
    final translations = _validatedList<TranslationRecord>(
      data['translationHistory'],
      'translationHistory',
      (json) => TranslationRecord.fromJson(json),
    );
    final shortUrls = _validatedList<ShortUrlRecord>(
      data['shortUrls'],
      'shortUrls',
      (json) => ShortUrlRecord.fromJson(json),
    );

    // 恢复设置
    if (settings is Map<String, dynamic>) {
      await _restoreSettings(settings, settingsProvider);
    }

    // 恢复笔记
    await notesProvider.restoreFromList(
      notes.map((note) => note.toJson()).toList(),
    );

    // 恢复对话
    await chatProvider.restoreFromList(
      conversations.map((conversation) => conversation.toJson()).toList(),
    );

    // 恢复翻译历史
    await translationProvider.restoreFromList(
      translations.map((item) => item.toJson()).toList(),
    );

    // 旧版云同步不再恢复服务端保存的明文密码。

    // 恢复短链接
    await shortUrlProvider.restoreFromList(
      shortUrls.map((item) => item.toJson()).toList(),
    );
  }

  List<T> _validatedList<T>(
    Object? raw,
    String category,
    T Function(Map<String, dynamic> json) parse,
  ) {
    if (raw == null) return <T>[];
    if (raw is! List) {
      throw SyncRestoreException('云端同步数据格式无效：$category 不是列表');
    }
    return raw
        .map((item) => parse(asStringMap(item, category)))
        .toList(growable: false);
  }

  void _validateSettingsPayload(Object settings) {
    final map = asStringMap(settings, 'settings');
    final stringKeys = {
      'baseUrl',
      'models',
      'selectedModel',
      'themeMode',
      'systemPrompt',
      'fontFamily',
      'syncMethod',
      'webdavServer',
      'webdavUser',
      'upstashUrl',
      'apiMode',
      'vertexProjectId',
      'vertexLocation',
    };
    final boolKeys = {
      'borderlessMode',
      'fullScreenMode',
      'smartAutoScroll',
      'syncEnabled',
      'notesAutoSave',
      'aiTitleGeneration',
    };
    final numKeys = {'temperature', 'fontSize'};

    for (final key in stringKeys) {
      final value = map[key];
      if (value != null && value is! String) {
        throw SyncRestoreException('云端设置字段类型无效: $key');
      }
    }
    for (final key in boolKeys) {
      final value = map[key];
      if (value != null && value is! bool) {
        throw SyncRestoreException('云端设置字段类型无效: $key');
      }
    }
    for (final key in numKeys) {
      final value = map[key];
      if (value != null && value is! num) {
        throw SyncRestoreException('云端设置字段类型无效: $key');
      }
    }
    final maxTokens = map['maxTokens'];
    if (maxTokens != null && maxTokens is! int) {
      throw SyncRestoreException('云端设置字段类型无效: maxTokens');
    }
    final accentColorValue = map['accentColorValue'];
    if (accentColorValue != null && accentColorValue is! int) {
      throw SyncRestoreException('云端设置字段类型无效: accentColorValue');
    }
  }
}
