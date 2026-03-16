import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // ── Available font families (from pubspec.yaml) ──────────────────────────
  static const List<String> availableFonts = [
    'vivoSans',
    'HarmonyOS_Sans_SC',
    'OPPO_Sans',
  ];

  // ── Secure storage (Android Keystore / iOS Keychain) ─────────────────────
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _kSecApiKey = 'sec.apiKey';
  static const _kSecWebdavPass = 'sec.webdavPassword';
  static const _kSecUpstashToken = 'sec.upstashToken';
  static const _kSecVertexApiKey = 'sec.vertexApiKey';

  String _selectedModel = 'gpt-4o';
  ThemeMode _themeMode = ThemeMode.system;
  double _temperature = 0.7;
  int _maxTokens = 4096;
  String _systemPrompt =
      'You are a helpful assistant. When responding with mathematical or chemical formulas, use LaTeX notation.';
  int? _accentColorValue;

  // OpenAI specific settings
  String _openaiBaseUrl = 'https://api.openai.com/v1';
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
  String _fontFamily = 'vivoSans';
  bool _borderlessMode = false;
  bool _fullScreenMode = false;
  bool _smartAutoScroll = true;

  // Cloud Sync
  bool _syncEnabled = false;
  String _syncMethod = 'WebDAV'; // 'WebDAV' or 'UpStash'
  String _webdavServer = '';
  String _webdavUser = '';
  String _webdavPassword = '';
  String _upstashUrl = '';
  String _upstashToken = '';

  // API Mode
  String _apiMode = 'OpenAI'; // 'OpenAI' or 'Vertex'

  // Getters - return current mode's settings
  String get baseUrl => _apiMode == 'OpenAI' ? _openaiBaseUrl : '';
  String get apiKey =>
      _apiMode == 'OpenAI' ? _openaiApiKey : _vertexApiKey;
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
  bool get borderlessMode => _borderlessMode;
  bool get fullScreenMode => _fullScreenMode;
  bool get smartAutoScroll => _smartAutoScroll;

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
  bool _notesAutoSave = true;
  bool get notesAutoSave => _notesAutoSave;

  // AI title generation setting
  bool _aiTitleGeneration = true;
  bool get aiTitleGeneration => _aiTitleGeneration;

  bool get isConfigured =>
      _apiMode == 'OpenAI' ? _openaiApiKey.isNotEmpty : _vertexApiKey.isNotEmpty;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // ── Migrate legacy plaintext secrets to secure storage (one-time) ──────
    await _migrateLegacySecrets(prefs);

    // ── Read sensitive fields from FlutterSecureStorage ────────────────────
    _openaiApiKey = await _secure.read(key: _kSecApiKey) ?? '';
    _webdavPassword = await _secure.read(key: _kSecWebdavPass) ?? '';
    _upstashToken = await _secure.read(key: _kSecUpstashToken) ?? '';
    _vertexApiKey = await _secure.read(key: _kSecVertexApiKey) ?? '';

    // ── Read non-sensitive fields from SharedPreferences ───────────────────
    _openaiBaseUrl = prefs.getString('openaiBaseUrl') ?? _openaiBaseUrl;
    _vertexProjectId = prefs.getString('vertexProjectId') ?? '';
    _vertexLocation = prefs.getString('vertexLocation') ?? 'global';

    _selectedModel = prefs.getString('selectedModel') ?? _selectedModel;
    _temperature = prefs.getDouble('temperature') ?? _temperature;
    _maxTokens = prefs.getInt('maxTokens') ?? _maxTokens;
    _systemPrompt = prefs.getString('systemPrompt') ?? _systemPrompt;
    _notesAutoSave = prefs.getBool('notesAutoSave') ?? _notesAutoSave;
    _aiTitleGeneration =
        prefs.getBool('aiTitleGeneration') ?? _aiTitleGeneration;

    _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    _fontFamily = prefs.getString('fontFamily') ?? 'vivoSans';
    _borderlessMode = prefs.getBool('borderlessMode') ?? false;
    _fullScreenMode = prefs.getBool('fullScreenMode') ?? false;
    _smartAutoScroll = prefs.getBool('smartAutoScroll') ?? true;

    _syncEnabled = prefs.getBool('syncEnabled') ?? false;
    _syncMethod = prefs.getString('syncMethod') ?? 'WebDAV';
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

    notifyListeners();
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
    await prefs.setBool('notesAutoSave', _notesAutoSave);
    await prefs.setBool('aiTitleGeneration', _aiTitleGeneration);

    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setBool('borderlessMode', _borderlessMode);
    await prefs.setBool('fullScreenMode', _fullScreenMode);
    await prefs.setBool('smartAutoScroll', _smartAutoScroll);

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
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    await _save();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
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

  Future<void> setBaseUrl(String url) async {
    final normalized = url.trimRight().endsWith('/')
        ? url.trimRight().substring(0, url.trimRight().length - 1)
        : url.trim();
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
