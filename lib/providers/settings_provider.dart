import 'package:fluent_ui/fluent_ui.dart';
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

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  List<String> get models => _models;
  String get selectedModel => _selectedModel;
  ThemeMode get themeMode => _themeMode;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;
  String get systemPrompt => _systemPrompt;
  int? get accentColorValue => _accentColorValue;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('baseUrl') ?? _baseUrl;
    _apiKey = prefs.getString('apiKey') ?? _apiKey;
    _selectedModel = prefs.getString('selectedModel') ?? _selectedModel;
    _temperature = prefs.getDouble('temperature') ?? _temperature;
    _maxTokens = prefs.getInt('maxTokens') ?? _maxTokens;
    _systemPrompt = prefs.getString('systemPrompt') ?? _systemPrompt;

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
    if (_accentColorValue != null) {
      await prefs.setInt('accentColorValue', _accentColorValue!);
    } else {
      await prefs.remove('accentColorValue');
    }
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
}
