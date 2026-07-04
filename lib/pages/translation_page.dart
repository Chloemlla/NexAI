import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/translation_provider.dart';
import '../utils/model_request_budget.dart';
import '../widgets/tool_page_style.dart';

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

  final _languages = const {
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
    final budgetError = ModelRequestBudget.validateTranslationInput(text);
    if (budgetError != null) {
      _showMessage(budgetError);
      return;
    }

    final settings = context.read<SettingsProvider>();
    if (settings.vertexApiKey.isEmpty) {
      _showMessage('请先在设置中配置 Vertex AI API Key');
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final dio = Dio();
      final modelId = 'gemini-2.0-flash-001';
      final endpoint =
          'https://aiplatform.googleapis.com/v1/publishers/google/models/$modelId:generateContent';

      final sourceLang = _languages[_sourceLanguage] ?? _sourceLanguage;
      final targetLang = _languages[_targetLanguage] ?? _targetLanguage;

      final response = await dio.post(
        '$endpoint?key=${settings.vertexApiKey}',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      'Translate the following text from $sourceLang to $targetLang. '
                      'Only return the translated text without any explanation or additional content.\n\n'
                      'Text to translate:\n$text',
                },
              ],
            },
          ],
          'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 2048},
        },
      );

      if (response.statusCode == 200) {
        final candidates = response.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final translatedText = parts.first['text'] as String?;
            if (translatedText != null) {
              if (mounted) {
                setState(() => _targetController.text = translatedText.trim());
              }
              if (mounted) {
                await context.read<TranslationProvider>().addRecord(
                  TranslationRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    sourceLanguage: _sourceLanguage,
                    targetLanguage: _targetLanguage,
                    sourceText: text,
                    translatedText: translatedText.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
              }
              return;
            }
          }
        }

        _showMessage('翻译失败：无法解析响应');
      } else {
        _showMessage('翻译失败：${response.statusMessage}');
      }
    } catch (error) {
      _showMessage('翻译错误：$error');
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _pasteSource() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    setState(() => _sourceController.text = text);
  }

  void _copyTarget() {
    if (_targetController.text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _targetController.text));
    _showMessage('已复制翻译结果');
  }

  void _swapLanguages() {
    setState(() {
      final tempLanguage = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = tempLanguage;

      final tempText = _sourceController.text;
      _sourceController.text = _targetController.text;
      _targetController.text = tempText;
    });
  }

  void _clearAll() {
    setState(() {
      _sourceController.clear();
      _targetController.clear();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 600;
    final hPad = isNarrow ? 16.0 : mq.size.width * 0.06;
    final settings = context.watch<SettingsProvider>();
    final hasApiKey = settings.vertexApiKey.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          ToolPageHeroSliver(
            title: 'AI 翻译',
            subtitle: '把语言切换、输入和结果输出都放进同一条操作链里，减少配置和翻译结果之间的视觉割裂。',
            icon: Icons.translate_rounded,
            chips: [
              ToolHeroChipData(
                icon: Icons.swap_horiz_rounded,
                label:
                    '${_languages[_sourceLanguage]} → ${_languages[_targetLanguage]}',
              ),
              ToolHeroChipData(
                icon: hasApiKey
                    ? Icons.verified_rounded
                    : Icons.key_off_rounded,
                label: hasApiKey ? 'API Key 已配置' : '缺少 API Key',
              ),
              const ToolHeroChipData(
                icon: Icons.history_rounded,
                label: '自动记录',
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
            sliver: SliverToBoxAdapter(
              child: ToolQuickActionsBar(
                actions: [
                  ToolQuickActionData(
                    icon: Icons.content_paste_rounded,
                    label: '粘贴原文',
                    backgroundColor: cs.primaryContainer,
                    iconColor: cs.onPrimaryContainer,
                    onTap: _pasteSource,
                  ),
                  ToolQuickActionData(
                    icon: Icons.swap_horiz_rounded,
                    label: '交换语言与内容',
                    backgroundColor: cs.secondaryContainer,
                    iconColor: cs.onSecondaryContainer,
                    onTap: _swapLanguages,
                  ),
                  ToolQuickActionData(
                    icon: Icons.copy_rounded,
                    label: '复制结果',
                    backgroundColor: cs.tertiaryContainer,
                    iconColor: cs.onTertiaryContainer,
                    onTap: _copyTarget,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!hasApiKey) ...[
                  ToolPanel(
                    color: cs.errorContainer.withAlpha(90),
                    borderSide: BorderSide(color: cs.error.withAlpha(40)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.key_off_rounded, color: cs.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '当前未配置 Vertex AI API Key。可以先在设置页补齐密钥，再返回这里直接翻译。',
                            style: TextStyle(
                              color: cs.onErrorContainer,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const ToolSectionTitle(
                  icon: Icons.language_rounded,
                  title: '语言配置',
                ),
                const SizedBox(height: 12),
                ToolPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isNarrow
                          ? Column(
                              children: [
                                _LanguageField(
                                  label: '源语言',
                                  value: _sourceLanguage,
                                  languages: _languages,
                                  onChanged: (value) =>
                                      setState(() => _sourceLanguage = value!),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  onPressed: _swapLanguages,
                                  icon: const Icon(Icons.swap_vert_rounded),
                                  label: const Text('交换'),
                                ),
                                const SizedBox(height: 12),
                                _LanguageField(
                                  label: '目标语言',
                                  value: _targetLanguage,
                                  languages: _languages,
                                  onChanged: (value) =>
                                      setState(() => _targetLanguage = value!),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _LanguageField(
                                    label: '源语言',
                                    value: _sourceLanguage,
                                    languages: _languages,
                                    onChanged: (value) => setState(
                                      () => _sourceLanguage = value!,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: FilledButton.tonal(
                                    onPressed: _swapLanguages,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.all(16),
                                    ),
                                    child: const Icon(Icons.swap_horiz_rounded),
                                  ),
                                ),
                                Expanded(
                                  child: _LanguageField(
                                    label: '目标语言',
                                    value: _targetLanguage,
                                    languages: _languages,
                                    onChanged: (value) => setState(
                                      () => _targetLanguage = value!,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const ToolSectionTitle(
                  icon: Icons.edit_note_rounded,
                  title: '原文输入',
                ),
                const SizedBox(height: 12),
                ToolPanel(
                  child: Column(
                    children: [
                      TextField(
                        controller: _sourceController,
                        minLines: 6,
                        maxLines: 10,
                        decoration: InputDecoration(
                          hintText: '输入或粘贴需要翻译的文本',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 88),
                            child: Icon(Icons.notes_rounded),
                          ),
                          suffixIcon: _sourceController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () =>
                                      setState(() => _sourceController.clear()),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isTranslating || !hasApiKey
                              ? null
                              : _translate,
                          icon: _isTranslating
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(_isTranslating ? '翻译中...' : '开始翻译'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const ToolSectionTitle(
                  icon: Icons.fact_check_rounded,
                  title: '翻译结果',
                ),
                const SizedBox(height: 12),
                ToolPanel(
                  child: TextField(
                    controller: _targetController,
                    minLines: 6,
                    maxLines: 10,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: '翻译结果会显示在这里',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 88),
                        child: Icon(Icons.translate_rounded),
                      ),
                      suffixIcon: _targetController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.copy_rounded),
                              onPressed: _copyTarget,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const ToolSectionTitle(
                  icon: Icons.tips_and_updates_rounded,
                  title: '体验优化',
                ),
                const SizedBox(height: 12),
                ToolPanel(
                  color: cs.secondaryContainer.withAlpha(70),
                  borderSide: BorderSide(color: cs.secondary.withAlpha(40)),
                  child: Text(
                    '当前页面把语言切换、输入、翻译按钮和结果输出整合为单列流程。'
                    '相比原来的基础表单布局，用户可以更直观地判断现在的源语言、目标语言，以及是否已经具备调用 API 的条件。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.cleaning_services_rounded),
                    label: const Text('清空输入与结果'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageField extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> languages;
  final ValueChanged<String?> onChanged;

  const _LanguageField({
    required this.label,
    required this.value,
    required this.languages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.language_rounded),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withAlpha(90),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: languages.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
