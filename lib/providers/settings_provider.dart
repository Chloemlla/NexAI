import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  String _baseUrl = 'https://api.openai.com/v1';
  String _apiKey = '';
  List<String> _models = ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'];
  String _selectedModel = 'gpt-4o';
  ThemeMode _themeMode = ThemeMode.system;
  double _temperature = 0.7;
  int _maxTokens = 4096;
  String _systemPrompt = 'You are a helpful assistant. When responding with mathematical or chemical formulas, use LaTeX notation.';
  int? _accentColorValue;
  
  // Appearance
  double _fontSize = 14.0;
  String _fontFamily = 'System';
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

  // Gemini AI Translation
  String _vertexApiKey = '';

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  List<String> get models => _models;
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

  String get vertexApiKey => _vertexApiKey;

  // Notes auto-save setting
  bool _notesAutoSave = true;
  bool get notesAutoSave => _notesAutoSave;

  // AI title generation setting
  bool _aiTitleGeneration = true;
  bool get aiTitleGeneration => _aiTitleGeneration;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('baseUrl') ?? _baseUrl;
    _apiKey = prefs.getString('apiKey') ?? _apiKey;
    _selectedModel = prefs.getString('selectedModel') ?? _selectedModel;
    _temperature = prefs.getDouble('temperature') ?? _temperature;
    _maxTokens = prefs.getInt('maxTokens') ?? _maxTokens;
    _systemPrompt = prefs.getString('systemPrompt') ?? _systemPrompt;
    _notesAutoSave = prefs.getBool('notesAutoSave') ?? _notesAutoSave;
    _aiTitleGeneration = prefs.getBool('aiTitleGeneration') ?? _aiTitleGeneration;

    _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    _fontFamily = prefs.getString('fontFamily') ?? 'System';
    _borderlessMode = prefs.getBool('borderlessMode') ?? false;
    _fullScreenMode = prefs.getBool('fullScreenMode') ?? false;
    _smartAutoScroll = prefs.getBool('smartAutoScroll') ?? true;

    _syncEnabled = prefs.getBool('syncEnabled') ?? false;
    _syncMethod = prefs.getString('syncMethod') ?? 'WebDAV';
    _webdavServer = prefs.getString('webdavServer') ?? '';
    _webdavUser = prefs.getString('webdavUser') ?? '';
    _webdavPassword = prefs.getString('webdavPassword') ?? '';
    _upstashUrl = prefs.getString('upstashUrl') ?? '';
    _upstashToken = prefs.getString('upstashToken') ?? '';

    _vertexApiKey = prefs.getString('vertexApiKey') ?? '';

    final accentVal = prefs.getInt('accentColorValue');
    _accentColorValue = accentVal;

    final modelsStr = prefs.getString('models');
    if (modelsStr != null && modelsStr.isNotEmpty) {
      _models = modelsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    // Ensure selectedModel exists in the models list
    if (_models.isNotEmpty && !_models.contains(_selectedModel)) {
      _selectedModel = _models.first;
    }

    final themeModeStr = prefs.getString('themeMode') ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == themeModeStr,
      orElse: () => ThemeMode.system,
    );

    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', _baseUrl);
    await prefs.setString('apiKey', _apiKey);
    await prefs.setString('models', _models.join(','));
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
    await prefs.setString('webdavPassword', _webdavPassword);
    await prefs.setString('upstashUrl', _upstashUrl);
    await prefs.setString('upstashToken', _upstashToken);

    await prefs.setString('vertexApiKey', _vertexApiKey);

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
    _baseUrl = url.trimRight().endsWith('/') ? url.trimRight().substring(0, url.trimRight().length - 1) : url.trim();
    notifyListeners();
    await _save();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    notifyListeners();
    await _save();
  }

  Future<void> setModels(String modelsStr) async {
    final parsed = modelsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parsed.isEmpty) return; // Don't allow empty models list
    _models = parsed;
    if (!_models.contains(_selectedModel)) {
      _selectedModel = _models.first;
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
}
