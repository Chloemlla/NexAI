/// NexAI Cloud Sync Provider
/// Orchestrates syncing local data to/from the cloud backend
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        await _saveLastSyncedAt(_lastSyncedAt!.toIso8601String());
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

  // ── 持久化 lastSyncedAt ──

  static const _lastSyncKey = 'nexai_last_synced_at';

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

  /// 增量同步：只上传变更的条目，合并服务端变更
  Future<bool> incrementalSync({
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
      final savedSince = await _getSavedLastSyncedAt();
      // 如果从未同步过，退回到全量上传
      if (savedSince == null) {
        debugPrint(
          'NexAI Sync: no lastSyncedAt found, falling back to full upload',
        );
        return await uploadAll(
          authProvider: authProvider,
          settingsProvider: settingsProvider,
          chatProvider: chatProvider,
          notesProvider: notesProvider,
          passwordProvider: passwordProvider,
          translationProvider: translationProvider,
          shortUrlProvider: shortUrlProvider,
        );
      }

      // 收集本地自 lastSyncedAt 以来变更的条目
      final changedData = _collectChangedData(
        since: savedSince,
        settingsProvider: settingsProvider,
        chatProvider: chatProvider,
        notesProvider: notesProvider,
        passwordProvider: passwordProvider,
        translationProvider: translationProvider,
        shortUrlProvider: shortUrlProvider,
      );

      // 发送到服务端，获取服务端变更
      final serverChanges = await NexaiSyncApi.postIncrementalSync(
        accessToken: authProvider.accessToken!,
        lastSyncedAt: savedSince,
        data: changedData,
      );

      if (serverChanges == null) {
        _status = SyncStatus.error;
        _errorMessage = '增量同步失败';
        notifyListeners();
        return false;
      }

      // 合并服务端返回的变更到本地
      await _mergeServerChanges(
        changes: serverChanges,
        settingsProvider: settingsProvider,
        chatProvider: chatProvider,
        notesProvider: notesProvider,
        passwordProvider: passwordProvider,
        translationProvider: translationProvider,
        shortUrlProvider: shortUrlProvider,
      );

      // 保存 serverTime 作为新的 lastSyncedAt
      final serverTime = serverChanges['serverTime'] as String?;
      if (serverTime != null) {
        await _saveLastSyncedAt(serverTime);
      }

      _status = SyncStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = '增量同步失败: $e';
      notifyListeners();
      return false;
    }
  }

  // ── 内部: 收集自 since 以来变更的数据 ──

  Map<String, dynamic> _collectChangedData({
    required String since,
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) {
    final result = <String, dynamic>{};

    // 笔记：按 updatedAt 过滤
    final changedNotes = notesProvider.notes
        .where((n) => n.updatedAt.toIso8601String().compareTo(since) > 0)
        .map((n) => n.toJson())
        .toList();
    if (changedNotes.isNotEmpty) result['notes'] = changedNotes;

    // 对话：按最后消息时间过滤
    final changedConvs = chatProvider.conversations
        .where((c) {
          final lastMsg = c.messages.isNotEmpty
              ? c.messages.last.timestamp
              : c.createdAt;
          return lastMsg.toIso8601String().compareTo(since) > 0;
        })
        .map((c) {
          final json = c.toJson();
          // 确保 conversation 有 updatedAt
          json['updatedAt'] = c.messages.isNotEmpty
              ? c.messages.last.timestamp.toIso8601String()
              : c.createdAt.toIso8601String();
          return json;
        })
        .toList();
    if (changedConvs.isNotEmpty) result['conversations'] = changedConvs;

    // 翻译历史：按 createdAt 过滤（翻译记录创建后不变）
    final changedTrans = translationProvider.history
        .where((t) => t.createdAt.toIso8601String().compareTo(since) > 0)
        .map((t) {
          final json = t.toJson();
          json['updatedAt'] = json['createdAt']; // 补充 updatedAt
          return json;
        })
        .toList();
    if (changedTrans.isNotEmpty) result['translationHistory'] = changedTrans;

    // 保存的密码：按 createdAt 过滤
    final changedPasswords = passwordProvider.passwords
        .where((p) {
          final json = p.toJson();
          final ts = json['createdAt'] as String? ?? '';
          return ts.compareTo(since) > 0;
        })
        .map((p) {
          final json = p.toJson();
          json['updatedAt'] = json['createdAt']; // 补充 updatedAt
          return json;
        })
        .toList();
    if (changedPasswords.isNotEmpty)
      result['savedPasswords'] = changedPasswords;

    // 短链接：按 createdAt 过滤
    final changedUrls = shortUrlProvider.history
        .where((u) => u.createdAt.toIso8601String().compareTo(since) > 0)
        .map((u) {
          final json = u.toJson();
          json['updatedAt'] = json['createdAt']; // 补充 updatedAt
          return json;
        })
        .toList();
    if (changedUrls.isNotEmpty) result['shortUrls'] = changedUrls;

    // Settings: 设置变更比较复杂，简单起见每次都带上
    result['settings'] = _collectSettings(settingsProvider);
    result['settingsUpdatedAt'] = DateTime.now().toIso8601String();

    return result;
  }

  Map<String, dynamic> _collectSettings(SettingsProvider s) {
    return {
      'baseUrl': s.baseUrl,
      'apiKey': s.apiKey,
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
      'webdavPassword': s.webdavPassword,
      'upstashUrl': s.upstashUrl,
      'upstashToken': s.upstashToken,
      'vertexApiKey': s.vertexApiKey,
      'apiMode': s.apiMode,
      'vertexProjectId': s.vertexProjectId,
      'vertexLocation': s.vertexLocation,
      'notesAutoSave': s.notesAutoSave,
      'aiTitleGeneration': s.aiTitleGeneration,
    };
  }

  // ── 内部: 合并服务端返回的变更 ──

  Future<void> _mergeServerChanges({
    required Map<String, dynamic> changes,
    required SettingsProvider settingsProvider,
    required ChatProvider chatProvider,
    required NotesProvider notesProvider,
    required PasswordProvider passwordProvider,
    required TranslationProvider translationProvider,
    required ShortUrlProvider shortUrlProvider,
  }) async {
    // 合并 settings
    if (changes['settings'] is Map<String, dynamic>) {
      await _restoreSettings(changes['settings'], settingsProvider);
    }

    // 合并笔记（服务端版本更新的条目）
    if (changes['notes'] is List && (changes['notes'] as List).isNotEmpty) {
      await notesProvider.mergeItems(changes['notes'] as List);
    }

    // 合并对话
    if (changes['conversations'] is List &&
        (changes['conversations'] as List).isNotEmpty) {
      await chatProvider.mergeItems(changes['conversations'] as List);
    }

    // 合并翻译历史
    if (changes['translationHistory'] is List &&
        (changes['translationHistory'] as List).isNotEmpty) {
      await translationProvider.mergeItems(
        changes['translationHistory'] as List,
      );
    }

    // 合并密码
    if (changes['savedPasswords'] is List &&
        (changes['savedPasswords'] as List).isNotEmpty) {
      await passwordProvider.mergeItems(changes['savedPasswords'] as List);
    }

    // 合并短链接
    if (changes['shortUrls'] is List &&
        (changes['shortUrls'] as List).isNotEmpty) {
      await shortUrlProvider.mergeItems(changes['shortUrls'] as List);
    }
  }

  Future<void> _restoreSettings(
    Map<String, dynamic> s,
    SettingsProvider sp,
  ) async {
    if (s['baseUrl'] != null) await sp.setBaseUrl(s['baseUrl']);
    if (s['apiKey'] != null) await sp.setApiKey(s['apiKey']);
    if (s['models'] != null) await sp.setModels(s['models']);
    if (s['selectedModel'] != null)
      await sp.setSelectedModel(s['selectedModel']);
    if (s['temperature'] != null)
      await sp.setTemperature((s['temperature'] as num).toDouble());
    if (s['maxTokens'] != null) await sp.setMaxTokens(s['maxTokens'] as int);
    if (s['systemPrompt'] != null) await sp.setSystemPrompt(s['systemPrompt']);
    if (s['fontSize'] != null)
      await sp.setFontSize((s['fontSize'] as num).toDouble());
    if (s['fontFamily'] != null) await sp.setFontFamily(s['fontFamily']);
    if (s['borderlessMode'] != null)
      await sp.setBorderlessMode(s['borderlessMode']);
    if (s['fullScreenMode'] != null)
      await sp.setFullScreenMode(s['fullScreenMode']);
    if (s['smartAutoScroll'] != null)
      await sp.setSmartAutoScroll(s['smartAutoScroll']);
    if (s['vertexApiKey'] != null) await sp.setVertexApiKey(s['vertexApiKey']);
    if (s['apiMode'] != null) await sp.setApiMode(s['apiMode']);
    if (s['vertexProjectId'] != null)
      await sp.setVertexProjectId(s['vertexProjectId']);
    if (s['vertexLocation'] != null)
      await sp.setVertexLocation(s['vertexLocation']);
    if (s['notesAutoSave'] != null)
      await sp.setNotesAutoSave(s['notesAutoSave']);
    if (s['aiTitleGeneration'] != null)
      await sp.setAiTitleGeneration(s['aiTitleGeneration']);
    if (s.containsKey('accentColorValue'))
      await sp.setAccentColor(s['accentColorValue'] as int?);
    if (s['syncEnabled'] != null) await sp.setSyncEnabled(s['syncEnabled']);
    if (s['syncMethod'] != null) await sp.setSyncMethod(s['syncMethod']);
    if (s['webdavServer'] != null) await sp.setWebdavServer(s['webdavServer']);
    if (s['webdavUser'] != null) await sp.setWebdavUser(s['webdavUser']);
    if (s['webdavPassword'] != null)
      await sp.setWebdavPassword(s['webdavPassword']);
    if (s['upstashUrl'] != null) await sp.setUpstashUrl(s['upstashUrl']);
    if (s['upstashToken'] != null) await sp.setUpstashToken(s['upstashToken']);
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
