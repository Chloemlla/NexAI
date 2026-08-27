import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/lumen_tokens.dart';
import 'package:flutter/services.dart';

import '../widgets/tool_page_style.dart';
import '../widgets/lumen/lumen.dart';

class Base64ConverterPage extends StatefulWidget {
  const Base64ConverterPage({super.key});

  @override
  State<Base64ConverterPage> createState() => _Base64ConverterPageState();
}

/// Per-direction view state. A record so `ValueNotifier` skips notifying when
/// a keystroke leaves all three flags unchanged.
typedef _ConverterState = ({String? error, bool hasInput, bool hasOutput});

const _ConverterState _idleConverterState = (
  error: null,
  hasInput: false,
  hasOutput: false,
);

class _Base64ConverterPageState extends State<Base64ConverterPage> {
  final _encodeInputController = TextEditingController();
  final _encodeOutputController = TextEditingController();
  final _decodeInputController = TextEditingController();
  final _decodeOutputController = TextEditingController();

  final _encodeState = ValueNotifier<_ConverterState>(_idleConverterState);
  final _decodeState = ValueNotifier<_ConverterState>(_idleConverterState);

  bool _encodeUrlSafe = false;
  bool _decodeUrlSafe = false;

  // Memo keys: skip re-running the conversion when neither the raw input nor
  // the URL-safe flag actually changed.
  String? _lastEncodeInput;
  bool? _lastEncodeUrlSafe;
  String? _lastDecodeInput;
  bool? _lastDecodeUrlSafe;

  @override
  void dispose() {
    _encodeInputController.dispose();
    _encodeOutputController.dispose();
    _decodeInputController.dispose();
    _decodeOutputController.dispose();
    _encodeState.dispose();
    _decodeState.dispose();
    super.dispose();
  }

  void _encodeToBase64() {
    final input = _encodeInputController.text;
    if (input == _lastEncodeInput && _encodeUrlSafe == _lastEncodeUrlSafe) {
      return;
    }
    _lastEncodeInput = input;
    _lastEncodeUrlSafe = _encodeUrlSafe;

    String? error;
    if (input.isEmpty) {
      _encodeOutputController.clear();
    } else {
      try {
        var encoded = base64.encode(utf8.encode(input));
        if (_encodeUrlSafe) {
          encoded = encoded
              .replaceAll('+', '-')
              .replaceAll('/', '_')
              .replaceAll('=', '');
        }
        _encodeOutputController.text = encoded;
      } catch (err) {
        error = '编码失败: $err';
        _encodeOutputController.clear();
      }
    }

    _encodeState.value = (
      error: error,
      hasInput: input.isNotEmpty,
      hasOutput: _encodeOutputController.text.isNotEmpty,
    );
  }

  void _decodeFromBase64() {
    final raw = _decodeInputController.text;
    if (raw == _lastDecodeInput && _decodeUrlSafe == _lastDecodeUrlSafe) {
      return;
    }
    _lastDecodeInput = raw;
    _lastDecodeUrlSafe = _decodeUrlSafe;

    String? error;
    var input = raw.trim();
    if (input.isEmpty) {
      _decodeOutputController.clear();
    } else {
      try {
        if (_decodeUrlSafe) {
          input = input.replaceAll('-', '+').replaceAll('_', '/');
          final padding = (4 - input.length % 4) % 4;
          if (padding > 0) {
            input = input.padRight(input.length + padding, '=');
          }
        }
        _decodeOutputController.text = utf8.decode(base64.decode(input));
      } catch (err) {
        error = '解码失败: $err';
        _decodeOutputController.clear();
      }
    }

    _decodeState.value = (
      error: error,
      hasInput: raw.isNotEmpty,
      hasOutput: _decodeOutputController.text.isNotEmpty,
    );
  }

  Future<void> _pasteToController(
    TextEditingController controller,
    VoidCallback onChanged,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.isEmpty) return;

    controller.text = text;
    onChanged();
  }

  void _clearAll() {
    _encodeInputController.clear();
    _decodeInputController.clear();
    _lastEncodeInput = null;
    _lastDecodeInput = null;
    _encodeToBase64();
    _decodeFromBase64();
  }

  void _copyToClipboard(String value, String label) {
    if (value.isEmpty) return;

    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '已复制$label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumenTokens.radiusSm)),
        duration: const Duration(milliseconds: 1200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LumenSecondaryScaffold(
      title: 'Base64 编解码',
      children: [
        LumenPageIntro(
          icon: Icons.code_rounded,
          title: 'Base64 编解码',
          description: '将文本编码为 Base64，或将 Base64 解码为文本，支持 URL Safe 模式。',
          chips: [
            '双向转换',
            _encodeUrlSafe || _decodeUrlSafe ? 'URL Safe 已启用' : '支持 URL Safe',
            '即时复制',
          ],
        ),
        ToolQuickActionsBar(
          actions: [
            ToolQuickActionData(
              icon: Icons.content_paste_rounded,
              label: '粘贴待编码文本',
              backgroundColor: cs.primaryContainer,
              iconColor: cs.onPrimaryContainer,
              onTap: () => _pasteToController(
                _encodeInputController,
                _encodeToBase64,
              ),
            ),
            ToolQuickActionData(
              icon: Icons.input_rounded,
              label: '粘贴待解码内容',
              backgroundColor: cs.secondaryContainer,
              iconColor: cs.onSecondaryContainer,
              onTap: () => _pasteToController(
                _decodeInputController,
                _decodeFromBase64,
              ),
            ),
            ToolQuickActionData(
              icon: Icons.cleaning_services_rounded,
              label: '清空全部',
              backgroundColor: cs.tertiaryContainer,
              iconColor: cs.onTertiaryContainer,
              onTap: _clearAll,
            ),
          ],
        ),
        LumenSettingsSection(
          icon: Icons.arrow_downward_rounded,
          title: '字符串转 Base64',
          subtitle: _encodeUrlSafe ? 'URL Safe 模式' : '标准模式',
          children: [
            ToolPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<_ConverterState>(
                    valueListenable: _encodeState,
                    builder: (context, state, _) => TextField(
                      controller: _encodeInputController,
                      minLines: 4,
                      maxLines: 6,
                      onChanged: (_) => _encodeToBase64(),
                      decoration: InputDecoration(
                        labelText: '原始文本',
                        hintText: '输入需要编码的文本、JSON 或 Token',
                        errorText: state.error,
                        prefixIcon: const Icon(Icons.text_snippet_rounded),
                        suffixIcon: state.hasInput
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                tooltip: '清空原始文本',
                                onPressed: () {
                                  _encodeInputController.clear();
                                  _encodeToBase64();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _encodeUrlSafe,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('输出 URL Safe 结果'),
                    subtitle: const Text('适合 URL、JWT 或查询参数传递'),
                    secondary: Icon(Icons.link_rounded, color: cs.primary),
                    onChanged: (value) {
                      setState(() => _encodeUrlSafe = value);
                      _encodeToBase64();
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<_ConverterState>(
                    valueListenable: _encodeState,
                    builder: (context, state, _) => TextField(
                      controller: _encodeOutputController,
                      readOnly: true,
                      minLines: 4,
                      maxLines: 6,
                      style: const TextStyle(fontFamily: 'JetBrainsMonoNexAI'),
                      decoration: InputDecoration(
                        labelText: '编码结果',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withAlpha(90),
                        prefixIcon: const Icon(Icons.output_rounded),
                        suffixIcon: state.hasOutput
                            ? IconButton(
                                icon: const Icon(Icons.copy_rounded),
                                tooltip: '复制编码结果',
                                onPressed: () => _copyToClipboard(
                                  _encodeOutputController.text,
                                  '编码结果',
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
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
          icon: Icons.arrow_upward_rounded,
          title: 'Base64 转字符串',
          subtitle: _decodeUrlSafe ? 'URL Safe 解码' : '自动解析',
          children: [
            ToolPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<_ConverterState>(
                    valueListenable: _decodeState,
                    builder: (context, state, _) => TextField(
                      controller: _decodeInputController,
                      minLines: 4,
                      maxLines: 6,
                      onChanged: (_) => _decodeFromBase64(),
                      style: const TextStyle(fontFamily: 'JetBrainsMonoNexAI'),
                      decoration: InputDecoration(
                        labelText: 'Base64 内容',
                        hintText: '输入待解码的 Base64 或 URL Safe Base64',
                        errorText: state.error,
                        prefixIcon: const Icon(Icons.input_rounded),
                        suffixIcon: state.hasInput
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                tooltip: '清空 Base64 内容',
                                onPressed: () {
                                  _decodeInputController.clear();
                                  _decodeFromBase64();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _decodeUrlSafe,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('按 URL Safe Base64 解码'),
                    subtitle: const Text('自动补齐缺失的 = 并还原 - / _'),
                    secondary: Icon(Icons.shield_rounded, color: cs.secondary),
                    onChanged: (value) {
                      setState(() => _decodeUrlSafe = value);
                      _decodeFromBase64();
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<_ConverterState>(
                    valueListenable: _decodeState,
                    builder: (context, state, _) => TextField(
                      controller: _decodeOutputController,
                      readOnly: true,
                      minLines: 4,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: '解码结果',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withAlpha(90),
                        prefixIcon: const Icon(Icons.text_fields_rounded),
                        suffixIcon: state.hasOutput
                            ? IconButton(
                                icon: const Icon(Icons.copy_rounded),
                                tooltip: '复制解码结果',
                                onPressed: () => _copyToClipboard(
                                  _decodeOutputController.text,
                                  '解码结果',
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
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
          icon: Icons.info_outline_rounded,
          title: '使用提示',
          initiallyExpanded: true,
          children: [
            ToolPanel(
              color: cs.tertiaryContainer.withAlpha(90),
              borderSide: BorderSide(color: cs.tertiary.withAlpha(50)),
              child: Text(
                '标准 Base64 使用 + / =；URL Safe 会改为 - / _，并可省略结尾 =。'
                '\n编码与解码分别在两个工作区完成。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: cs.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

}
