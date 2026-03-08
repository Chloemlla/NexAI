/// NexAI Cloud Sync Provider
/// Orchestrates syncing local data to/from the cloud backend
import 'package:flutter/foundation.dart';

import '../services/nexai_sync_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'chat_provider.dart';
import 'notes_provider.dart';
import 'password_provider.dart';
import 'translation_provider.dart';
import 'short_url_provider.dart';

enum SyncStatus { idle, uploading, downloading, success, error }

class SyncProvider extends ChangeNotifier {
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
      final data = _collectLocalData(
        settingsProvider: settingsProvider,
        chatProvider: chatProvider,
        notesProvider: notesProvider,
        passwordProvider: passwordProvider,
        translationProvider: translationProvider,
        shortUrlProvider: shortUrlProvider,
      );

      final success = await NexaiSyncApi.putSyncData(
        accessToken: authProvider.accessToken!,
        data: data,
      );

      if (success) {
        _status = SyncStatus.success;
        _lastSyncedAt = DateTime.now();
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
      final data = await NexaiSyncApi.getSyncData(
        accessToken: authProvider.accessToken!,
      );

      if (data == null) {
        _status = SyncStatus.error;
        _errorMessage = '云端暂无同步数据';
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
      _lastSyncedAt = DateTime.now();
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
    if (authProvider.accessToken == null) return false;

    try {
      return await NexaiSyncApi.patchSyncData(
        accessToken: authProvider.accessToken!,
        category: category,
        data: data,
      );
    } catch (e) {
      debugPrint('NexAI Sync: uploadCategory [$category] error: $e');
      return false;
    }
  }

  /// 获取同步元信息
  Future<void> fetchSyncMeta({required AuthProvider authProvider}) async {
    if (authProvider.accessToken == null) return;
    try {
      final meta = await NexaiSyncApi.getSyncMeta(
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
      final success = await NexaiSyncApi.deleteSyncData(
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

  // ── 内部: 收集本地数据 ──

  Map<String, dynamic> _collectLocalData({
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) {
    return {
      'settings': {
        'baseUrl': settingsProvider.baseUrl,
        'apiKey': settingsProvider.apiKey,
        'models': settingsProvider.models.join(','),
        'selectedModel': settingsProvider.selectedModel,
        'themeMode': settingsProvider.themeMode.name,
        'temperature': settingsProvider.temperature,
        'maxTokens': settingsProvider.maxTokens,
        'systemPrompt': settingsProvider.systemPrompt,
        'accentColorValue': settingsProvider.accentColorValue,
        'fontSize': settingsProvider.fontSize,
        'fontFamily': settingsProvider.fontFamily,
        'borderlessMode': settingsProvider.borderlessMode,
        'fullScreenMode': settingsProvider.fullScreenMode,
        'smartAutoScroll': settingsProvider.smartAutoScroll,
        'syncEnabled': settingsProvider.syncEnabled,
        'syncMethod': settingsProvider.syncMethod,
        'webdavServer': settingsProvider.webdavServer,
        'webdavUser': settingsProvider.webdavUser,
        'webdavPassword': settingsProvider.webdavPassword,
        'upstashUrl': settingsProvider.upstashUrl,
        'upstashToken': settingsProvider.upstashToken,
        'vertexApiKey': settingsProvider.vertexApiKey,
        'apiMode': settingsProvider.apiMode,
        'vertexProjectId': settingsProvider.vertexProjectId,
        'vertexLocation': settingsProvider.vertexLocation,
        'notesAutoSave': settingsProvider.notesAutoSave,
        'aiTitleGeneration': settingsProvider.aiTitleGeneration,
      },
      'notes': notesProvider.notes.map((n) => n.toJson()).toList(),
      'conversations': chatProvider.conversations
          .map((c) => c.toJson())
          .toList(),
      'translationHistory': translationProvider.exportToJsonList(),
      'savedPasswords': passwordProvider.passwords
          .map((p) => p.toJson())
          .toList(),
      'shortUrls': shortUrlProvider.exportToJsonList(),
    };
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
      final s = data['settings'] as Map<String, dynamic>;
      if (s['baseUrl'] != null) await settingsProvider.setBaseUrl(s['baseUrl']);
      if (s['apiKey'] != null) await settingsProvider.setApiKey(s['apiKey']);
      if (s['models'] != null) await settingsProvider.setModels(s['models']);
      if (s['selectedModel'] != null) {
        await settingsProvider.setSelectedModel(s['selectedModel']);
      }
      if (s['temperature'] != null) {
        await settingsProvider.setTemperature(
          (s['temperature'] as num).toDouble(),
        );
      }
      if (s['maxTokens'] != null) {
        await settingsProvider.setMaxTokens(s['maxTokens'] as int);
      }
      if (s['systemPrompt'] != null) {
        await settingsProvider.setSystemPrompt(s['systemPrompt']);
      }
      if (s['fontSize'] != null) {
        await settingsProvider.setFontSize((s['fontSize'] as num).toDouble());
      }
      if (s['fontFamily'] != null) {
        await settingsProvider.setFontFamily(s['fontFamily']);
      }
      if (s['borderlessMode'] != null) {
        await settingsProvider.setBorderlessMode(s['borderlessMode']);
      }
      if (s['fullScreenMode'] != null) {
        await settingsProvider.setFullScreenMode(s['fullScreenMode']);
      }
      if (s['smartAutoScroll'] != null) {
        await settingsProvider.setSmartAutoScroll(s['smartAutoScroll']);
      }
      if (s['vertexApiKey'] != null) {
        await settingsProvider.setVertexApiKey(s['vertexApiKey']);
      }
      if (s['apiMode'] != null) await settingsProvider.setApiMode(s['apiMode']);
      if (s['vertexProjectId'] != null) {
        await settingsProvider.setVertexProjectId(s['vertexProjectId']);
      }
      if (s['vertexLocation'] != null) {
        await settingsProvider.setVertexLocation(s['vertexLocation']);
      }
      if (s['notesAutoSave'] != null) {
        await settingsProvider.setNotesAutoSave(s['notesAutoSave']);
      }
      if (s['aiTitleGeneration'] != null) {
        await settingsProvider.setAiTitleGeneration(s['aiTitleGeneration']);
      }
      if (s.containsKey('accentColorValue')) {
        await settingsProvider.setAccentColor(s['accentColorValue'] as int?);
      }
      if (s['syncEnabled'] != null) {
        await settingsProvider.setSyncEnabled(s['syncEnabled']);
      }
      if (s['syncMethod'] != null) {
        await settingsProvider.setSyncMethod(s['syncMethod']);
      }
      if (s['webdavServer'] != null) {
        await settingsProvider.setWebdavServer(s['webdavServer']);
      }
      if (s['webdavUser'] != null) {
        await settingsProvider.setWebdavUser(s['webdavUser']);
      }
      if (s['webdavPassword'] != null) {
        await settingsProvider.setWebdavPassword(s['webdavPassword']);
      }
      if (s['upstashUrl'] != null) {
        await settingsProvider.setUpstashUrl(s['upstashUrl']);
      }
      if (s['upstashToken'] != null) {
        await settingsProvider.setUpstashToken(s['upstashToken']);
      }
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

    // 恢复密码
    if (data['savedPasswords'] is List) {
      final passwordsJson = (data['savedPasswords'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      await passwordProvider.importFromJson(
        passwordsJson.map((e) => e).toList().toString(),
      );
    }

    // 恢复短链接
    if (data['shortUrls'] is List) {
      await shortUrlProvider.restoreFromList(data['shortUrls'] as List);
    }
  }
}
