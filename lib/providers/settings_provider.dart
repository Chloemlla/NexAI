import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_knowledge.dart';
import '../utils/local_data_presence.dart';

class SettingsProvider extends ChangeNotifier {
  static const String defaultOpenaiBaseUrl =
      'https://tts.chloemlla.com/api/nexai';
  static const String _legacyOpenaiBaseUrl = 'https://api.openai.com/v1';
  static const String monospaceFontFamily = 'JetBrainsMonoNexAI';

  // ── Available font families (from pubspec.yaml) ──────────────────────────
  static const List<String> availableFonts = ['System'];

  // ── Secure storage (Android Keystore / iOS Keychain) ─────────────────────
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
  static const _kSecApiKey = 'sec.apiKey';
  static const _kSecWebdavPass = 'sec.webdavPassword';
  static const _kSecUpstashToken = 'sec.upstashToken';
  static const _kSecVertexApiKey = 'sec.vertexApiKey';
  static const _kSecToolSecrets = 'sec.toolSecretsJson';
  static const _kSecAccessToken = 'nexai_access_token';
  static const _kSecRefreshToken = 'nexai_refresh_token';
  static const _kSecUserJson = 'nexai_user_json';
  static const _kSecUserId = 'nexai_user_id';

  String _selectedModel = 'gpt-4o';
  ThemeMode _themeMode = ThemeMode.system;
  double _temperature = 0.7;
  int _maxTokens = 4096;
  String _systemPrompt =
      'You are a helpful assistant. When responding with mathematical or chemical formulas, use LaTeX notation.';
  int? _accentColorValue;

  // OpenAI specific settings
  String _openaiBaseUrl = defaultOpenaiBaseUrl;
  String _openaiApiKey = '';
  List<String> _openaiModels = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-3.5-turbo',
  ];

  // Vertex AI specific settings
  String _vertexApiKey = '';
  String _vertexProjectId = '';
  String _vertexLocation = 'global';
  List<String> _vertexModels = [
    'gemini-2.0-flash-exp',
    'gemini-1.5-pro',
    'gemini-1.5-flash',
  ];

  // Appearance
  double _fontSize = 14.0;
  String _fontFamily = 'System';
  bool _borderlessMode = false;
  bool _fullScreenMode = false;
  bool _smartAutoScroll = true;
  bool _developerDebugModeUnlocked = false;

  // Android passkey: only use Google Password Manager, never fall back to OEM/system providers.
  bool _passkeyGoogleOnly = true;

  // Cloud Sync
  bool _syncEnabled = false;
  String _syncMethod = 'NexAI'; // NexAI only; WebDAV/UpStash reserved
  String _webdavServer = '';
  String _webdavUser = '';
  String _webdavPassword = '';
  String _upstashUrl = '';
  String _upstashToken = '';

  // API Mode
  String _apiMode = 'OpenAI'; // 'OpenAI' or 'Vertex'

  // Getters - return current mode's settings
  String get baseUrl => _apiMode == 'OpenAI' ? _openaiBaseUrl : '';
  String get apiKey => _apiMode == 'OpenAI' ? _openaiApiKey : _vertexApiKey;
  List<String> get models =>
      _apiMode == 'OpenAI' ? _openaiModels : _vertexModels;
  String get selectedModel => _selectedModel;
  ThemeMode get themeMode => _themeMode;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;
  String get systemPrompt => _systemPrompt;
  int? get accentColorValue => _accentColorValue;

  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  String? get effectiveFontFamily =>
      _fontFamily == 'System' ? null : _fontFamily;
  bool get borderlessMode => _borderlessMode;
  bool get fullScreenMode => _fullScreenMode;
  bool get smartAutoScroll => _smartAutoScroll;
  bool get developerDebugModeUnlocked => _developerDebugModeUnlocked;
  bool get passkeyGoogleOnly => _passkeyGoogleOnly;

  bool get syncEnabled => _syncEnabled;
  String get syncMethod => _syncMethod;
  String get webdavServer => _webdavServer;
  String get webdavUser => _webdavUser;
  String get webdavPassword => _webdavPassword;
  String get upstashUrl => _upstashUrl;
  String get upstashToken => _upstashToken;

  // Mode-specific getters
  String get openaiBaseUrl => _openaiBaseUrl;
  String get openaiApiKey => _openaiApiKey;
  List<String> get openaiModels => _openaiModels;

  String get vertexApiKey => _vertexApiKey;
  String get vertexProjectId => _vertexProjectId;
  String get vertexLocation => _vertexLocation;
  List<String> get vertexModels => _vertexModels;

  String get apiMode => _apiMode;

  // Notes auto-save setting
  bool _clashAutoAdapt = true;
  bool _notesAutoSave = true;
  bool get clashAutoAdapt => _clashAutoAdapt;
  bool get notesAutoSave => _notesAutoSave;

  // AI title generation setting
  bool _aiTitleGeneration = true;
  bool get aiTitleGeneration => _aiTitleGeneration;

  // Chat tool-calling toggles (OpenAI mode)
  // Product defaults are conservative for first rollout.
  bool _chatToolsEnabled = false;
  bool _toolWebSearchEnabled = false;
  bool _toolNotesEnabled = true;
  bool _toolImageEnabled = false;
  bool _toolArtifactsEnabled = false;
  bool _toolFetchUrlEnabled = false;
  bool _toolCreateNoteEnabled = true;
  bool _toolKnowledgeEnabled = false;
  bool _remoteMcpEnabled = false;
  int _maxToolRounds = 4;
  static const int maxCompareModels = 3;
  String _imageToolModel = '';
  List<McpServerConfig> _mcpServers = [];
  List<WebSearchProviderConfig> _webSearchProviders = [
    const WebSearchProviderConfig(
      id: 'ddg',
      name: 'DuckDuckGo',
      type: 'duckduckgo',
      enabled: true,
    ),
  ];
  String _activeWebSearchProviderId = 'ddg';
  String _toolGatewayBaseUrl = '';
  bool _composerShowToolChips = true;
  bool _semanticKnowledgeSearch = true;
  double _reasoningBudget = 0.5; // 0..1 soft preference

  bool get chatToolsEnabled => _chatToolsEnabled;
  bool get toolWebSearchEnabled => _toolWebSearchEnabled;
  bool get toolNotesEnabled => _toolNotesEnabled;
  bool get toolImageEnabled => _toolImageEnabled;
  bool get toolArtifactsEnabled => _toolArtifactsEnabled;
  bool get toolFetchUrlEnabled => _toolFetchUrlEnabled;
  bool get toolCreateNoteEnabled => _toolCreateNoteEnabled;
  bool get toolKnowledgeEnabled => _toolKnowledgeEnabled;
  bool get remoteMcpEnabled => _remoteMcpEnabled;
  int get maxToolRounds => _maxToolRounds;
  int get compareModelLimit => maxCompareModels;
  String get imageToolModel => _imageToolModel;
  List<McpServerConfig> get mcpServers => List.unmodifiable(_mcpServers);
  List<WebSearchProviderConfig> get webSearchProviders =>
      List.unmodifiable(_webSearchProviders);
  String get activeWebSearchProviderId => _activeWebSearchProviderId;
  String get toolGatewayBaseUrl => _toolGatewayBaseUrl;
  bool get composerShowToolChips => _composerShowToolChips;
  bool get semanticKnowledgeSearch => _semanticKnowledgeSearch;
  double get reasoningBudget => _reasoningBudget;

  bool _loaded = false;
  bool get loaded => _loaded;

  // First-install open-source notice acknowledgment.
  static const String _ossNoticeAcknowledgedKey = 'ossNoticeAcknowledged';
  bool _ossNoticeAcknowledged = false;
  bool get ossNoticeAcknowledged => _ossNoticeAcknowledged;

  // First-entry chat tools rollout guide (soft banner).
  static const String _chatToolsOnboardingDismissedKey =
      'chatToolsOnboardingDismissed';
  bool _chatToolsOnboardingDismissed = false;
  bool get chatToolsOnboardingDismissed => _chatToolsOnboardingDismissed;

  /// Prefs that prove a real prior install/user configuration.
  /// Do NOT include keys that `loadSettings()` may auto-create on first run.
  static const Set<String> _existingInstallPrefSignals = {
    'themeMode',
    'selectedModel',
    'openaiModels',
    'apiMode',
    'syncEnabled',
    'syncMethod',
    'borderlessMode',
    'fullScreenMode',
    'smartAutoScroll',
    'fontFamily',
    'fontSize',
    'accentColorValue',
    'webdavServer',
    'webdavUser',
    'upstashUrl',
    'notesAutoSave',
    'aiTitleGeneration',
    'chatToolsEnabled',
    'toolWebSearchEnabled',
    'toolNotesEnabled',
    'toolImageEnabled',
    'toolArtifactsEnabled',
    'toolFetchUrlEnabled',
    'toolCreateNoteEnabled',
    'maxToolRounds',
    'imageToolModel',
    'developerDebugModeUnlocked',
    'passkeyGoogleOnly',
    'vertexProjectId',
    'vertexLocation',
    'vertexModels',
    'systemPrompt',
    'temperature',
    'maxTokens',
    // Only safe because first-run resolution runs before auto-write.
    'openaiBaseUrl',
    'nexai_short_url_history',
    'nexai_translation_history',
    // Legacy plaintext keys that older builds may still carry.
    'apiKey',
    'webdavPassword',
    'upstashToken',
    'vertexApiKey',
    'notes',
    'saved_passwords',
  };

  bool get isConfigured => _apiMode == 'OpenAI'
      ? _openaiApiKey.isNotEmpty
      : _vertexApiKey.isNotEmpty;

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Resolve first-install state BEFORE any default prefs writes below.
      // Fresh installs must persist `false` immediately so a kill-before-ack
      // relaunch does not get misclassified as an upgrade.
      await _resolveOssNoticeAcknowledged(prefs);

      // ── Migrate legacy plaintext secrets to secure storage (one-time) ──────
      await _migrateLegacySecrets(prefs);

      // ── Read sensitive fields from FlutterSecureStorage ────────────────────
      _openaiApiKey = await _secure.read(key: _kSecApiKey) ?? '';
      _webdavPassword = await _secure.read(key: _kSecWebdavPass) ?? '';
      _upstashToken = await _secure.read(key: _kSecUpstashToken) ?? '';
      _vertexApiKey = await _secure.read(key: _kSecVertexApiKey) ?? '';

      // ── Read non-sensitive fields from SharedPreferences ───────────────────
      final savedOpenaiBaseUrl = prefs.getString('openaiBaseUrl');
      final normalizedOpenaiBaseUrl = savedOpenaiBaseUrl == null
          ? defaultOpenaiBaseUrl
          : _normalizeBaseUrl(savedOpenaiBaseUrl);
      _openaiBaseUrl =
          normalizedOpenaiBaseUrl.isEmpty ||
              normalizedOpenaiBaseUrl == _legacyOpenaiBaseUrl
          ? defaultOpenaiBaseUrl
          : normalizedOpenaiBaseUrl;
      if (savedOpenaiBaseUrl != _openaiBaseUrl) {
        await prefs.setString('openaiBaseUrl', _openaiBaseUrl);
      }
      _vertexProjectId = prefs.getString('vertexProjectId') ?? '';
      _vertexLocation = prefs.getString('vertexLocation') ?? 'global';

      _selectedModel = prefs.getString('selectedModel') ?? _selectedModel;
      _temperature = prefs.getDouble('temperature') ?? _temperature;
      _maxTokens = prefs.getInt('maxTokens') ?? _maxTokens;
      _systemPrompt = prefs.getString('systemPrompt') ?? _systemPrompt;
      _clashAutoAdapt = prefs.getBool('clashAutoAdapt') ?? _clashAutoAdapt;
      _notesAutoSave = prefs.getBool('notesAutoSave') ?? _notesAutoSave;
      _aiTitleGeneration =
          prefs.getBool('aiTitleGeneration') ?? _aiTitleGeneration;
      _chatToolsEnabled = prefs.getBool('chatToolsEnabled') ?? _chatToolsEnabled;
      _toolWebSearchEnabled =
          prefs.getBool('toolWebSearchEnabled') ?? _toolWebSearchEnabled;
      _toolNotesEnabled = prefs.getBool('toolNotesEnabled') ?? _toolNotesEnabled;
      _toolImageEnabled = prefs.getBool('toolImageEnabled') ?? _toolImageEnabled;
      _toolArtifactsEnabled =
          prefs.getBool('toolArtifactsEnabled') ?? _toolArtifactsEnabled;
      _toolFetchUrlEnabled =
          prefs.getBool('toolFetchUrlEnabled') ?? _toolFetchUrlEnabled;
      _toolCreateNoteEnabled =
          prefs.getBool('toolCreateNoteEnabled') ?? _toolCreateNoteEnabled;
      _toolKnowledgeEnabled =
          prefs.getBool('toolKnowledgeEnabled') ?? _toolKnowledgeEnabled;
      _remoteMcpEnabled = prefs.getBool('remoteMcpEnabled') ?? _remoteMcpEnabled;
      _maxToolRounds = prefs.getInt('maxToolRounds') ?? _maxToolRounds;
      _imageToolModel = prefs.getString('imageToolModel') ?? _imageToolModel;
      _chatToolsOnboardingDismissed =
          prefs.getBool(_chatToolsOnboardingDismissedKey) ??
              _chatToolsOnboardingDismissed;
      final mcpRaw = prefs.getString('mcpServersJson');
      final searchRaw = prefs.getString('webSearchProvidersJson');
      if (searchRaw != null && searchRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(searchRaw);
          if (decoded is List) {
            _webSearchProviders = decoded
                .whereType<Object>()
                .map((e) => WebSearchProviderConfig.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ))
                .toList();
          }
        } catch (_) {}
      }
      _activeWebSearchProviderId =
          prefs.getString('activeWebSearchProviderId') ?? _activeWebSearchProviderId;
      _toolGatewayBaseUrl = prefs.getString('toolGatewayBaseUrl') ?? _toolGatewayBaseUrl;
      _composerShowToolChips =
          prefs.getBool('composerShowToolChips') ?? _composerShowToolChips;
      _semanticKnowledgeSearch =
          prefs.getBool('semanticKnowledgeSearch') ?? _semanticKnowledgeSearch;
      _reasoningBudget = prefs.getDouble('reasoningBudget') ?? _reasoningBudget;
      await _restoreToolSecrets();
      if (mcpRaw != null && mcpRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(mcpRaw);
          if (decoded is List) {
            _mcpServers = decoded
                .whereType<Map>()
                .map((e) => McpServerConfig.fromJson(
                      e.map((k, v) => MapEntry(k.toString(), v)),
                    ))
                .toList();
          }
        } catch (_) {}
      }

      _fontSize = prefs.getDouble('fontSize') ?? 14.0;
      _fontFamily = _normalizeFontFamily(prefs.getString('fontFamily'));
      _borderlessMode = prefs.getBool('borderlessMode') ?? false;
      _fullScreenMode = prefs.getBool('fullScreenMode') ?? false;
      _smartAutoScroll = prefs.getBool('smartAutoScroll') ?? true;
      _developerDebugModeUnlocked =
          prefs.getBool('developerDebugModeUnlocked') ?? false;
      _passkeyGoogleOnly = prefs.getBool('passkeyGoogleOnly') ?? true;

      _syncEnabled = prefs.getBool('syncEnabled') ?? false;
      _syncMethod = prefs.getString('syncMethod') ?? 'NexAI';
      _webdavServer = prefs.getString('webdavServer') ?? '';
      _webdavUser = prefs.getString('webdavUser') ?? '';
      _upstashUrl = prefs.getString('upstashUrl') ?? '';

      _apiMode = prefs.getString('apiMode') ?? 'OpenAI';

      final accentVal = prefs.getInt('accentColorValue');
      _accentColorValue = accentVal;

      // Load OpenAI models
      final openaiModelsStr = prefs.getString('openaiModels');
      if (openaiModelsStr != null && openaiModelsStr.isNotEmpty) {
        _openaiModels = openaiModelsStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Load Vertex models
      final vertexModelsStr = prefs.getString('vertexModels');
      if (vertexModelsStr != null && vertexModelsStr.isNotEmpty) {
        _vertexModels = vertexModelsStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Ensure selectedModel exists in the current mode's models list
      if (models.isNotEmpty && !models.contains(_selectedModel)) {
        _selectedModel = models.first;
      }

      final themeModeStr = prefs.getString('themeMode') ?? 'system';
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeModeStr,
        orElse: () => ThemeMode.system,
      );
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _resolveOssNoticeAcknowledged(SharedPreferences prefs) async {
    final stored = prefs.getBool(_ossNoticeAcknowledgedKey);
    if (stored != null) {
      _ossNoticeAcknowledged = stored;
      return;
    }

    // Persist a safe default first. If we crash mid-detection after
    // loadSettings() auto-writes prefs, a missing flag must not become a
    // false "upgrade" skip on next launch.
    _ossNoticeAcknowledged = false;
    await prefs.setBool(_ossNoticeAcknowledgedKey, false);

    final looksExisting = await _hasDurableExistingInstallSignals(prefs);
    if (!looksExisting) return;

    _ossNoticeAcknowledged = true;
    await prefs.setBool(_ossNoticeAcknowledgedKey, true);
  }

  Future<bool> _hasDurableExistingInstallSignals(
    SharedPreferences prefs,
  ) async {
    // Prefer value-aware checks so empty/default leftovers do not auto-skip.
    if (_prefsContainUserConfiguration(prefs)) {
      return true;
    }

    if (await hasLocalDocumentDataTraces()) {
      return true;
    }

    try {
      final secureKeys = <String>[
        _kSecApiKey,
        _kSecVertexApiKey,
        _kSecWebdavPass,
        _kSecUpstashToken,
        _kSecAccessToken,
        _kSecRefreshToken,
        _kSecUserJson,
        _kSecUserId,
      ];
      for (final key in secureKeys) {
        final value = await _secure.read(key: key);
        if (value != null && value.isNotEmpty) {
          return true;
        }
      }
    } catch (_) {
      // Ignore secure-storage probe failures for first-run classification.
    }

    return false;
  }

  bool _prefsContainUserConfiguration(SharedPreferences prefs) {
    for (final key in prefs.getKeys()) {
      if (!_existingInstallPrefSignals.contains(key)) continue;

      final value = prefs.get(key);
      if (value == null) continue;

      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) continue;
        // Ignore pure default strings that do not prove user activity.
        if (key == 'vertexLocation' && trimmed == 'global') continue;
        if (key == 'syncMethod' &&
            (trimmed == 'WebDAV' || trimmed == 'UpStash')) {
          // Presence of method alone is weak; require server/url keys instead.
          continue;
        }
        if (key == 'apiMode' && (trimmed == 'OpenAI' || trimmed == 'Vertex')) {
          continue;
        }
        if (key == 'fontFamily' && trimmed == 'System') continue;
        // openaiBaseUrl presence before first-run write is strong enough:
        // fresh installs do not have this key yet at resolution time.
        return true;
      }

      if (value is bool || value is num) {
        // Any explicit bool/num preference means a prior settings write.
        return true;
      }
    }
    return false;
  }

  /// One-time migration: move legacy plaintext secrets from SharedPreferences
  /// into FlutterSecureStorage, then delete them from SharedPreferences.
  static Future<void> _migrateLegacySecrets(SharedPreferences prefs) async {
    Future<void> migrate(String prefKey, String secKey) async {
      final val = prefs.getString(prefKey);
      if (val != null && val.isNotEmpty) {
        await _secure.write(key: secKey, value: val);
        await prefs.remove(prefKey);
      }
    }

    await migrate('apiKey', _kSecApiKey);
    await migrate('webdavPassword', _kSecWebdavPass);
    await migrate('upstashToken', _kSecUpstashToken);
    await migrate('vertexApiKey', _kSecVertexApiKey);
  }


  Map<String, String> _collectToolSecrets() {
    final secrets = <String, String>{};
    for (final p in _webSearchProviders) {
      final key = (p.apiKey ?? '').trim();
      if (key.isNotEmpty) secrets['search:${p.id}'] = key;
    }
    for (final s in _mcpServers) {
      final token = (s.bearerToken ?? '').trim();
      if (token.isNotEmpty) secrets['mcp:${s.id}'] = token;
    }
    return secrets;
  }

  List<WebSearchProviderConfig> _providersWithoutSecrets(
    List<WebSearchProviderConfig> input,
  ) {
    return input
        .map(
          (p) => WebSearchProviderConfig(
            id: p.id,
            name: p.name,
            type: p.type,
            endpoint: p.endpoint,
            apiKey: null,
            enabled: p.enabled,
          ),
        )
        .toList();
  }

  List<McpServerConfig> _mcpWithoutSecrets(List<McpServerConfig> input) {
    return input
        .map(
          (s) => McpServerConfig(
            id: s.id,
            name: s.name,
            url: s.url,
            enabled: s.enabled,
            bearerToken: null,
            allowTools: s.allowTools,
            lastHealthyAt: s.lastHealthyAt,
            lastError: s.lastError,
          ),
        )
        .toList();
  }

  Future<void> _persistToolSecrets() async {
    final secrets = _collectToolSecrets();
    await _secure.write(key: _kSecToolSecrets, value: jsonEncode(secrets));
  }

  Future<void> _restoreToolSecrets() async {
    final raw = await _secure.read(key: _kSecToolSecrets);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final secrets = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      _webSearchProviders = _webSearchProviders.map((p) {
        final key = secrets['search:${p.id}'];
        if (key == null || key.isEmpty) return p;
        return WebSearchProviderConfig(
          id: p.id,
          name: p.name,
          type: p.type,
          endpoint: p.endpoint,
          apiKey: key,
          enabled: p.enabled,
        );
      }).toList();
      _mcpServers = _mcpServers.map((s) {
        final token = secrets['mcp:${s.id}'];
        if (token == null || token.isEmpty) return s;
        return McpServerConfig(
          id: s.id,
          name: s.name,
          url: s.url,
          enabled: s.enabled,
          bearerToken: token,
          allowTools: s.allowTools,
          lastHealthyAt: s.lastHealthyAt,
          lastError: s.lastError,
        );
      }).toList();
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // ── Sensitive: write to secure storage ─────────────────────────────────
    await _secure.write(key: _kSecApiKey, value: _openaiApiKey);
    await _secure.write(key: _kSecWebdavPass, value: _webdavPassword);
    await _secure.write(key: _kSecUpstashToken, value: _upstashToken);
    await _secure.write(key: _kSecVertexApiKey, value: _vertexApiKey);

    // ── Non-sensitive: write to SharedPreferences ──────────────────────────
    await prefs.setString('openaiBaseUrl', _openaiBaseUrl);
    await prefs.setString('openaiModels', _openaiModels.join(','));
    await prefs.setString('vertexModels', _vertexModels.join(','));
    await prefs.setString('selectedModel', _selectedModel);
    await prefs.setString('themeMode', _themeMode.name);
    await prefs.setDouble('temperature', _temperature);
    await prefs.setInt('maxTokens', _maxTokens);
    await prefs.setString('systemPrompt', _systemPrompt);
    await prefs.setBool('clashAutoAdapt', _clashAutoAdapt);
    await prefs.setBool('notesAutoSave', _notesAutoSave);
    await prefs.setBool('aiTitleGeneration', _aiTitleGeneration);
    await prefs.setBool('chatToolsEnabled', _chatToolsEnabled);
    await prefs.setBool('toolWebSearchEnabled', _toolWebSearchEnabled);
    await prefs.setBool('toolNotesEnabled', _toolNotesEnabled);
    await prefs.setBool('toolImageEnabled', _toolImageEnabled);
    await prefs.setBool('toolArtifactsEnabled', _toolArtifactsEnabled);
    await prefs.setBool('toolFetchUrlEnabled', _toolFetchUrlEnabled);
    await prefs.setBool('toolCreateNoteEnabled', _toolCreateNoteEnabled);
    await prefs.setBool('toolKnowledgeEnabled', _toolKnowledgeEnabled);
    await prefs.setBool('remoteMcpEnabled', _remoteMcpEnabled);
    await prefs.setInt('maxToolRounds', _maxToolRounds);
    await prefs.setString('imageToolModel', _imageToolModel);
    await _persistToolSecrets();
    await prefs.setString(
      'mcpServersJson',
      jsonEncode(_mcpWithoutSecrets(_mcpServers).map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'webSearchProvidersJson',
      jsonEncode(_providersWithoutSecrets(_webSearchProviders).map((e) => e.toJson()).toList()),
    );
    await prefs.setString('activeWebSearchProviderId', _activeWebSearchProviderId);
    await prefs.setString('toolGatewayBaseUrl', _toolGatewayBaseUrl);
    await prefs.setBool('composerShowToolChips', _composerShowToolChips);
    await prefs.setBool('semanticKnowledgeSearch', _semanticKnowledgeSearch);
    await prefs.setDouble('reasoningBudget', _reasoningBudget);

    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setBool('borderlessMode', _borderlessMode);
    await prefs.setBool('fullScreenMode', _fullScreenMode);
    await prefs.setBool('smartAutoScroll', _smartAutoScroll);
    await prefs.setBool(
      'developerDebugModeUnlocked',
      _developerDebugModeUnlocked,
    );
    await prefs.setBool('passkeyGoogleOnly', _passkeyGoogleOnly);

    await prefs.setBool('syncEnabled', _syncEnabled);
    await prefs.setString('syncMethod', _syncMethod);
    await prefs.setString('webdavServer', _webdavServer);
    await prefs.setString('webdavUser', _webdavUser);
    await prefs.setString('upstashUrl', _upstashUrl);

    await prefs.setString('apiMode', _apiMode);
    await prefs.setString('vertexProjectId', _vertexProjectId);
    await prefs.setString('vertexLocation', _vertexLocation);

    if (_accentColorValue != null) {
      await prefs.setInt('accentColorValue', _accentColorValue!);
    } else {
      await prefs.remove('accentColorValue');
    }

    await prefs.setBool(_ossNoticeAcknowledgedKey, _ossNoticeAcknowledged);
    await prefs.setBool(
      _chatToolsOnboardingDismissedKey,
      _chatToolsOnboardingDismissed,
    );
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    await _save();
  }

  static String _normalizeFontFamily(String? family) {
    if (family == null || family.isEmpty) return 'System';
    return availableFonts.contains(family) ? family : 'System';
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = _normalizeFontFamily(family);
    notifyListeners();
    await _save();
  }

  Future<void> setBorderlessMode(bool value) async {
    _borderlessMode = value;
    notifyListeners();
    await _save();
  }

  Future<void> setFullScreenMode(bool value) async {
    _fullScreenMode = value;
    notifyListeners();
    await _save();
  }

  Future<void> setSmartAutoScroll(bool value) async {
    _smartAutoScroll = value;
    notifyListeners();
    await _save();
  }

  Future<void> unlockDeveloperDebugMode() async {
    if (_developerDebugModeUnlocked) return;
    _developerDebugModeUnlocked = true;
    notifyListeners();
    await _save();
  }

  Future<void> setPasskeyGoogleOnly(bool value) async {
    if (_passkeyGoogleOnly == value) return;
    _passkeyGoogleOnly = value;
    notifyListeners();
    await _save();
  }

  Future<void> setBaseUrl(String url) async {
    final normalized = _normalizeBaseUrl(url);
    if (_apiMode == 'OpenAI') {
      _openaiBaseUrl = normalized;
    }
    notifyListeners();
    await _save();
  }

  Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    if (_apiMode == 'OpenAI') {
      _openaiApiKey = trimmed;
    } else {
      _vertexApiKey = trimmed;
    }
    notifyListeners();
    await _save();
  }

  Future<void> setModels(String modelsStr) async {
    final parsed = modelsStr
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parsed.isEmpty) return; // Don't allow empty models list

    if (_apiMode == 'OpenAI') {
      _openaiModels = parsed;
      if (!_openaiModels.contains(_selectedModel)) {
        _selectedModel = _openaiModels.first;
      }
    } else {
      _vertexModels = parsed;
      if (!_vertexModels.contains(_selectedModel)) {
        _selectedModel = _vertexModels.first;
      }
    }
    notifyListeners();
    await _save();
  }

  Future<void> setSelectedModel(String model) async {
    _selectedModel = model;
    notifyListeners();
    await _save();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> setTemperature(double temp) async {
    _temperature = temp;
    notifyListeners();
    await _save();
  }

  Future<void> setMaxTokens(int tokens) async {
    _maxTokens = tokens;
    notifyListeners();
    await _save();
  }

  Future<void> setSystemPrompt(String prompt) async {
    _systemPrompt = prompt;
    notifyListeners();
    await _save();
  }

  Future<void> setAccentColor(int? colorValue) async {
    _accentColorValue = colorValue;
    notifyListeners();
    await _save();
  }

  Future<void> setClashAutoAdapt(bool value) async {
    if (_clashAutoAdapt == value) return;
    _clashAutoAdapt = value;
    notifyListeners();
    await _save();
  }

  Future<void> setNotesAutoSave(bool value) async {
    _notesAutoSave = value;
    notifyListeners();
    await _save();
  }

  Future<void> setAiTitleGeneration(bool value) async {
    _aiTitleGeneration = value;
    notifyListeners();
    await _save();
  }

  
  Future<void> setChatToolsEnabled(bool value) async {
    _chatToolsEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setToolWebSearchEnabled(bool value) async {
    _toolWebSearchEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setToolNotesEnabled(bool value) async {
    _toolNotesEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setToolImageEnabled(bool value) async {
    _toolImageEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setToolArtifactsEnabled(bool value) async {
    _toolArtifactsEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setToolFetchUrlEnabled(bool value) async {
    _toolFetchUrlEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setToolCreateNoteEnabled(bool value) async {
    _toolCreateNoteEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setToolKnowledgeEnabled(bool value) async {
    _toolKnowledgeEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setWebSearchProviders(List<WebSearchProviderConfig> providers) async {
    _webSearchProviders = List<WebSearchProviderConfig>.from(providers);
    if (!_webSearchProviders.any((p) => p.id == _activeWebSearchProviderId) &&
        _webSearchProviders.isNotEmpty) {
      _activeWebSearchProviderId = _webSearchProviders.first.id;
    }
    notifyListeners();
    await _save();
  }

  Future<void> setActiveWebSearchProviderId(String id) async {
    _activeWebSearchProviderId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setToolGatewayBaseUrl(String value) async {
    _toolGatewayBaseUrl = value.trim();
    notifyListeners();
    await _save();
  }

  Future<void> setComposerShowToolChips(bool value) async {
    _composerShowToolChips = value;
    notifyListeners();
    await _save();
  }

  Future<void> setSemanticKnowledgeSearch(bool value) async {
    _semanticKnowledgeSearch = value;
    notifyListeners();
    await _save();
  }

  Future<void> setReasoningBudget(double value) async {
    _reasoningBudget = value.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setRemoteMcpEnabled(bool value) async {
    _remoteMcpEnabled = value;
    notifyListeners();
    await _save();
  }

  /// Recommended safe preset for first-time tool chat.
  /// Notes only (read/search + create). Network/write-heavy tools stay off.
  Future<void> enableRecommendedChatTools() async {
    _chatToolsEnabled = true;
    _toolNotesEnabled = true;
    _toolCreateNoteEnabled = true;
    _toolWebSearchEnabled = false;
    _toolImageEnabled = false;
    _toolArtifactsEnabled = false;
    _toolFetchUrlEnabled = false;
    _toolKnowledgeEnabled = false;
    _remoteMcpEnabled = false;
    _maxToolRounds = 4;
    _chatToolsOnboardingDismissed = true;
    notifyListeners();
    await _save();
  }

  Future<void> dismissChatToolsOnboarding() async {
    if (_chatToolsOnboardingDismissed) return;
    _chatToolsOnboardingDismissed = true;
    notifyListeners();
    await _save();
  }

  Future<void> disableAllChatTools() async {
    _chatToolsEnabled = false;
    notifyListeners();
    await _save();
  }


  Future<void> setMcpServers(List<McpServerConfig> servers) async {
    _mcpServers = List<McpServerConfig>.from(servers);
    notifyListeners();
    await _save();
  }

  Future<void> upsertMcpServer(McpServerConfig server) async {
    final idx = _mcpServers.indexWhere((s) => s.id == server.id);
    if (idx == -1) {
      _mcpServers = [..._mcpServers, server];
    } else {
      final next = List<McpServerConfig>.from(_mcpServers);
      next[idx] = server;
      _mcpServers = next;
    }
    notifyListeners();
    await _save();
  }

  Future<void> removeMcpServer(String id) async {
    _mcpServers = _mcpServers.where((s) => s.id != id).toList();
    notifyListeners();
    await _save();
  }

  Future<void> setMaxToolRounds(int value) async {
    _maxToolRounds = value.clamp(1, 8);
    notifyListeners();
    await _save();
  }

  Future<void> setImageToolModel(String value) async {
    _imageToolModel = value.trim();
    notifyListeners();
    await _save();
  }

  Future<void> acknowledgeOssNotice() async {
    if (_ossNoticeAcknowledged) return;
    _ossNoticeAcknowledged = true;
    notifyListeners();
    await _save();
  }

  Future<void> setSyncEnabled(bool value) async {
    _syncEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setSyncMethod(String value) async {
    _syncMethod = value;
    notifyListeners();
    await _save();
  }

  Future<void> setWebdavServer(String value) async {
    _webdavServer = value;
    notifyListeners();
    await _save();
  }

  Future<void> setWebdavUser(String value) async {
    _webdavUser = value;
    notifyListeners();
    await _save();
  }

  Future<void> setWebdavPassword(String value) async {
    _webdavPassword = value;
    notifyListeners();
    await _save();
  }

  Future<void> setUpstashUrl(String value) async {
    _upstashUrl = value;
    notifyListeners();
    await _save();
  }

  Future<void> setUpstashToken(String value) async {
    _upstashToken = value;
    notifyListeners();
    await _save();
  }

  Future<void> setVertexApiKey(String value) async {
    _vertexApiKey = value;
    notifyListeners();
    await _save();
  }

  Future<void> setApiMode(String mode) async {
    _apiMode = mode;
    // Switch selectedModel to match the new mode's models
    if (models.isNotEmpty && !models.contains(_selectedModel)) {
      _selectedModel = models.first;
    }
    notifyListeners();
    await _save();
  }

  Future<void> setVertexProjectId(String projectId) async {
    _vertexProjectId = projectId;
    notifyListeners();
    await _save();
  }

  Future<void> setVertexLocation(String location) async {
    _vertexLocation = location;
    notifyListeners();
    await _save();
  }
}
