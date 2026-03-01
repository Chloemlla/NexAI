import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/settings_provider.dart';

class TranslationPage extends StatefulWidget {
  const TranslationPage({super.key});

  @override
  State<TranslationPage> createState() => _TranslationPageState();
}

class _TranslationPageState extends State<TranslationPage> {
  final _sourceController = TextEditingController();
  final _targetController = TextEditingController();
  String _sourceLanguage = 'en';
  String _targetLanguage = 'zh-CN';
  bool _isTranslating = false;

  final _languages = {
    'en': 'English',
    'zh-CN': '简体中文',
    'zh-TW': '繁體中文',
    'ja': '日本語',
    'ko': '한국어',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'ru': 'Русский',
    'ar': 'العربية',
  };

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _sourceController.text.trim();
    if (text.isEmpty) return;

    final settings = context.read<SettingsProvider>();
    if (settings.vertexApiKey.isEmpty) {
      _showError('请先在设置中配置 Vertex AI API Key');
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final dio = Dio();
      final modelId = 'gemini-2.0-flash-001';
      final endpoint = 'https://aiplatform.googleapis.com/v1/publishers/google/models/$modelId:generateContent';

      // Get language names for better translation
      final sourceLang = _languages[_sourceLanguage] ?? _sourceLanguage;
      final targetLang = _languages[_targetLanguage] ?? _targetLanguage;

      final response = await dio.post(
        '$endpoint?key=${settings.vertexApiKey}',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'contents': {
            'role': 'user',
            'parts': [
              {
                'text': 'Translate the following text from $sourceLang to $targetLang. '
                    'Only return the translated text without any explanation or additional content.\n\n'
                    'Text to translate:\n$text'
              }
            ]
          },
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 2048,
          }
        },
      );

      if (response.statusCode == 200) {
        final candidates = response.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final translatedText = parts[0]['text'] as String?;
            if (translatedText != null) {
              setState(() => _targetController.text = translatedText.trim());
              return;
            }
          }
        }
        _showError('翻译失败: 无法解析响应');
      } else {
        _showError('翻译失败: ${response.statusMessage}');
      }
    } catch (e) {
      _showError('翻译错误: $e');
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
      final tempText = _sourceController.text;
      _sourceController.text = _targetController.text;
      _targetController.text = tempText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('AI 翻译'),
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language selectors
            Row(
              children: [
                Expanded(
                  child: _LanguageSelector(
                    value: _sourceLanguage,
                    languages: _languages,
                    onChanged: (v) => setState(() => _sourceLanguage = v!),
                    cs: cs,
                  ),
                ),
                IconButton(
                  onPressed: _swapLanguages,
                  icon: Icon(Icons.swap_horiz_rounded, color: cs.primary),
                ),
                Expanded(
                  child: _LanguageSelector(
                    value: _targetLanguage,
                    languages: _languages,
                    onChanged: (v) => setState(() => _targetLanguage = v!),
                    cs: cs,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Source text
            _TextCard(
              controller: _sourceController,
              hint: '输入要翻译的文本',
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 16),

            // Translate button
            FilledButton.icon(
              onPressed: _isTranslating ? null : _translate,
              icon: _isTranslating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                    )
                  : const Icon(Icons.translate_rounded),
              label: Text(_isTranslating ? '翻译中...' : '翻译'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Target text
            _TextCard(
              controller: _targetController,
              hint: '翻译结果',
              cs: cs,
              tt: tt,
              readOnly: true,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: _targetController.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final String value;
  final Map<String, String> languages;
  final ValueChanged<String?> onChanged;
  final ColorScheme cs;

  const _LanguageSelector({
    required this.value,
    required this.languages,
    required this.onChanged,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: languages.entries.map((e) {
          return DropdownMenuItem(value: e.key, child: Text(e.value));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ColorScheme cs;
  final TextTheme tt;
  final bool readOnly;
  final VoidCallback? onCopy;

  const _TextCard({
    required this.controller,
    required this.hint,
    required this.cs,
    required this.tt,
    this.readOnly = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onCopy != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: onCopy,
                    icon: Icon(Icons.copy_rounded, size: 18, color: cs.primary),
                    tooltip: '复制',
                  ),
                ],
              ),
            TextField(
              controller: controller,
              maxLines: 8,
              readOnly: readOnly,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
