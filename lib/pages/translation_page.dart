import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/translation_provider.dart';
import '../services/lumen_translation_client.dart';
import '../theme/lumen_tokens.dart';
import '../widgets/lumen/lumen.dart';
import '../widgets/tool_page_style.dart';

class TranslationPage extends StatefulWidget {
  const TranslationPage({super.key});

  @override
  State<TranslationPage> createState() => _TranslationPageState();
}

class _TranslationPageState extends State<TranslationPage> {
  final _sourceController = TextEditingController();
  final _targetController = TextEditingController();
  final _client = LumenTranslationClient();

  String _sourceLanguage = 'auto';
  String _targetLanguage = 'ZH';
  bool _isTranslating = false;
  bool _loadingConfig = true;
  bool _serviceEnabled = true;
  String? _serviceMessage;
  List<String> _alternatives = const [];

  @override
  void initState() {
    super.initState();
    _refreshConfig();
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _refreshConfig() async {
    setState(() {
      _loadingConfig = true;
      _serviceMessage = null;
    });
    try {
      final config = await _client.fetchConfig();
      if (!mounted) return;
      setState(() {
        _serviceEnabled = config.enabled;
        _serviceMessage = config.enabled ? '服务可用' : '翻译服务未开启';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serviceEnabled = false;
        _serviceMessage = '服务检查失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingConfig = false);
      }
    }
  }

  Future<void> _translate() async {
    final text = _sourceController.text.trim();
    if (text.isEmpty) {
      _showMessage('请输入要翻译的文本');
      return;
    }
    if (text.runes.length > LumenTranslationClient.maxInputChars) {
      _showMessage('文本过长，请控制在 ${LumenTranslationClient.maxInputChars} 个字符以内');
      return;
    }
    if (!_serviceEnabled) {
      _showMessage(_serviceMessage ?? '翻译服务不可用');
      return;
    }

    setState(() {
      _isTranslating = true;
      _alternatives = const [];
    });

    try {
      final result = await _client.translate(
        text: text,
        sourceLang: _sourceLanguage,
        targetLang: _targetLanguage,
      );
      if (!mounted) return;
      setState(() {
        _targetController.text = result.translatedText;
        _alternatives = result.alternatives;
      });
      await context.read<TranslationProvider>().addRecord(
            TranslationRecord(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sourceLanguage: result.sourceLang,
              targetLanguage: result.targetLang,
              sourceText: text,
              translatedText: result.translatedText,
              createdAt: DateTime.now(),
            ),
          );
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _pasteSource() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _showMessage('剪贴板为空');
      return;
    }
    setState(() => _sourceController.text = text.take(LumenTranslationClient.maxInputChars));
  }

  void _copyTarget() {
    if (_targetController.text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _targetController.text));
    _showMessage('已复制翻译结果');
  }

  void _swapLanguages() {
    setState(() {
      final nextSource = _targetLanguage;
      final nextTarget = _sourceLanguage == 'auto' ? 'EN' : _sourceLanguage;
      _sourceLanguage = nextSource == 'auto' ? 'EN' : nextSource;
      _targetLanguage = nextTarget;

      final tempText = _sourceController.text;
      _sourceController.text = _targetController.text;
      _targetController.text = tempText;
      _alternatives = const [];
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 600;
    final sourceLabel =
        LumenTranslationLanguages.source[_sourceLanguage] ?? _sourceLanguage;
    final targetLabel =
        LumenTranslationLanguages.target[_targetLanguage] ?? _targetLanguage;

    return LumenSecondaryScaffold(
      title: 'AI 翻译',
      children: [
        LumenPageIntro(
          icon: Icons.translate_rounded,
          title: 'AI 翻译',
          description: '按 Project-Lumen 方式调用 DeepLX 公共翻译接口，支持自动检测与备选结果。',
          chips: [
            '$sourceLabel → $targetLabel',
            _loadingConfig
                ? '检查服务中'
                : (_serviceEnabled ? '服务可用' : '服务不可用'),
            '自动记录',
          ],
        ),
        ToolQuickActionsBar(
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
            ToolQuickActionData(
              icon: Icons.sync_rounded,
              label: '刷新服务',
              backgroundColor: cs.surfaceContainerHighest,
              iconColor: cs.onSurfaceVariant,
              onTap: _loadingConfig ? null : _refreshConfig,
            ),
          ],
        ),
        if (!_serviceEnabled || _loadingConfig)
          ToolPanel(
            color: cs.errorContainer.withAlpha(90),
            borderSide: BorderSide(color: cs.error.withAlpha(40)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _loadingConfig ? Icons.sync_rounded : Icons.cloud_off_rounded,
                  color: cs.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _loadingConfig
                        ? '正在检查翻译服务…'
                        : (_serviceMessage ?? '翻译服务不可用'),
                    style: TextStyle(color: cs.onErrorContainer, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        LumenSettingsSection(
          icon: Icons.language_rounded,
          title: '语言配置',
          children: [
            ToolPanel(
              child: isNarrow
                  ? Column(
                      children: [
                        _LanguageField(
                          label: '源语言',
                          value: _sourceLanguage,
                          languages: LumenTranslationLanguages.source,
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
                          languages: LumenTranslationLanguages.target,
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
                            languages: LumenTranslationLanguages.source,
                            onChanged: (value) =>
                                setState(() => _sourceLanguage = value!),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            languages: LumenTranslationLanguages.target,
                            onChanged: (value) =>
                                setState(() => _targetLanguage = value!),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        LumenSettingsSection(
          icon: Icons.edit_note_rounded,
          title: '原文输入',
          children: [
            ToolPanel(
              child: Column(
                children: [
                  TextField(
                    controller: _sourceController,
                    minLines: 6,
                    maxLines: 10,
                    maxLength: LumenTranslationClient.maxInputChars,
                    onChanged: (value) {
                      if (value.runes.length > LumenTranslationClient.maxInputChars) {
                        final clipped = value.take(LumenTranslationClient.maxInputChars);
                        _sourceController.value = TextEditingValue(
                          text: clipped,
                          selection: TextSelection.collapsed(offset: clipped.length),
                        );
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '输入或粘贴需要翻译的文本',
                      counterText:
                          '${_sourceController.text.runes.length}/${LumenTranslationClient.maxInputChars}',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 88),
                        child: Icon(Icons.notes_rounded),
                      ),
                      suffixIcon: _sourceController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setState(() {
                                _sourceController.clear();
                              }),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isTranslating || !_serviceEnabled
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
                          : const Icon(Icons.translate_rounded),
                      label: Text(_isTranslating ? '翻译中...' : '开始翻译'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        LumenSettingsSection(
          icon: Icons.fact_check_rounded,
          title: '翻译结果',
          children: [
            ToolPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
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
                        borderRadius:
                            BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                    ),
                  ),
                  if (_alternatives.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '备选结果',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._alternatives.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          item,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        _buildTranslationHistorySection(cs),
      ],
    );
  }

  Widget _buildTranslationHistorySection(ColorScheme cs) {
    final history = context.watch<TranslationProvider>().history;
    return LumenSettingsSection(
      icon: Icons.history_rounded,
      title: '翻译历史',
      children: [
        if (history.isEmpty)
          const ToolEmptyStateCard(
            icon: Icons.history_toggle_off_rounded,
            title: '暂无记录',
            description: '翻译成功后会自动记录在这里，可一键恢复原文与译文。',
          )
        else
          ToolPanel(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await context.read<TranslationProvider>().clearHistory();
                      if (!mounted) return;
                      _showMessage('已清空翻译历史');
                    },
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('清空历史'),
                  ),
                ),
                ...history.take(20).map((record) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      record.translatedText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${record.sourceLanguage} → ${record.targetLanguage} · ${record.sourceText}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: '删除',
                      icon: Icon(Icons.close_rounded, color: cs.error),
                      onPressed: () => context
                          .read<TranslationProvider>()
                          .deleteRecord(record.id),
                    ),
                    onTap: () {
                      setState(() {
                        _sourceController.text = record.sourceText;
                        _targetController.text = record.translatedText;
                        _sourceLanguage = record.sourceLanguage;
                        _targetLanguage = record.targetLanguage;
                        _alternatives = const [];
                      });
                      _showMessage('已恢复到输入区');
                    },
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}

extension on String {
  String take(int maxChars) {
    if (runes.length <= maxChars) return this;
    return String.fromCharCodes(runes.take(maxChars));
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
        ),
      ),
      items: languages.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
