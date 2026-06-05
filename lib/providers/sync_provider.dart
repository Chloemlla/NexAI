/// NexAI Cloud Sync Provider
/// Orchestrates syncing local data to/from the cloud backend
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      if (data == null) {
        _status = SyncStatus.error;
        _errorMessage = '无法解密云端同步数据';
        notifyListeners();
        return false;
      }

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

  Future<Map<String, dynamic>?> _decryptSnapshot(
    Map<String, dynamic> snapshot,
  ) async {
    final records = snapshot['records'];
    if (records is! List) return null;

    Map<String, dynamic>? settings;
    final notes = <Map<String, dynamic>>[];
    final conversations = <Map<String, dynamic>>[];
    final translations = <Map<String, dynamic>>[];
    final shortUrls = <Map<String, dynamic>>[];
    var encryptedCount = 0;
    var decryptedCount = 0;

    for (final item in records) {
      if (item is! Map) continue;
      encryptedCount++;

      try {
        final record = Map<String, dynamic>.from(item);
        final payload = await _syncCrypto.decryptRecord(record);
        if (payload == null) continue;

        decryptedCount++;
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
        }
      } catch (e) {
        debugPrint('NexAI Sync: skipping undecryptable record: $e');
      }
    }

    if (encryptedCount > 0 && decryptedCount == 0) return null;

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
    // 恢复设置
    if (data['settings'] is Map<String, dynamic>) {
      await _restoreSettings(
        data['settings'] as Map<String, dynamic>,
        settingsProvider,
      );
    }

    // 恢复笔记
    if (data['notes'] is List) {
      await notesProvider.restoreFromList(data['notes'] as List);
    }

    // 恢复对话
    if (data['conversations'] is List) {
      await chatProvider.restoreFromList(data['conversations'] as List);
    }

    // 恢复翻译历史
    if (data['translationHistory'] is List) {
      await translationProvider.restoreFromList(
        data['translationHistory'] as List,
      );
    }

    // 旧版云同步不再恢复服务端保存的明文密码。

    // 恢复短链接
    if (data['shortUrls'] is List) {
      await shortUrlProvider.restoreFromList(data['shortUrls'] as List);
    }
  }
}
