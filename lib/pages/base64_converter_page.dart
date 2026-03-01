import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Base64ConverterPage extends StatefulWidget {
  const Base64ConverterPage({super.key});

  @override
  State<Base64ConverterPage> createState() => _Base64ConverterPageState();
}

class _Base64ConverterPageState extends State<Base64ConverterPage> {
  final _stringController = TextEditingController();
  final _base64Controller = TextEditingController();
  bool _encodeUrlSafe = false;
  bool _decodeUrlSafe = false;
  String? _encodeError;
  String? _decodeError;

  @override
  void dispose() {
    _stringController.dispose();
    _base64Controller.dispose();
    super.dispose();
  }

  void _encodeToBase64() {
    setState(() {
      _encodeError = null;
      try {
        final input = _stringController.text;
        if (input.isEmpty) {
          _base64Controller.clear();
          return;
        }

        final bytes = utf8.encode(input);
        String encoded = base64.encode(bytes);

        if (_encodeUrlSafe) {
          encoded = encoded
              .replaceAll('+', '-')
              .replaceAll('/', '_')
              .replaceAll('=', '');
        }

        _base64Controller.text = encoded;
      } catch (e) {
        _encodeError = '编码失败: $e';
        _base64Controller.clear();
      }
    });
  }

  void _decodeFromBase64() {
    setState(() {
      _decodeError = null;
      try {
        String input = _base64Controller.text;
        if (input.isEmpty) {
          _stringController.clear();
          return;
        }

        if (_decodeUrlSafe) {
          input = input.replaceAll('-', '+').replaceAll('_', '/');
          // Add padding if needed
          while (input.length % 4 != 0) {
            input += '=';
          }
        }

        final bytes = base64.decode(input);
        final decoded = utf8.decode(bytes);
        _stringController.text = decoded;
      } catch (e) {
        _decodeError = '解码失败: $e';
        _stringController.clear();
      }
    });
  }

  void _copyToClipboard(String value, String label) {
    if (value.isEmpty) return;

    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('已复制 $label'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Base64 编码/解码'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Encode section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_downward,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '字符串转 Base64',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // String input
                TextField(
                  controller: _stringController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: '输入字符串',
                    hintText: '输入要编码的字符串...',
                    errorText: _encodeError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _stringController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _stringController.clear();
                              _base64Controller.clear();
                              setState(() => _encodeError = null);
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => _encodeToBase64(),
                ),
                const SizedBox(height: 12),

                // URL safe option
                CheckboxListTile(
                  title: const Text('URL Safe 编码'),
                  subtitle: const Text('使用 - 和 _ 替代 + 和 /, 移除 ='),
                  value: _encodeUrlSafe,
                  onChanged: (value) {
                    setState(() {
                      _encodeUrlSafe = value ?? false;
                      _encodeToBase64();
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 12),

                // Base64 output
                TextField(
                  controller: _base64Controller,
                  maxLines: 5,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Base64 编码结果',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withAlpha(100),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _base64Controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyToClipboard(
                              _base64Controller.text,
                              'Base64',
                            ),
                            tooltip: '复制',
                          )
                        : null,
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Decode section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: cs.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Base64 转字符串',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Base64 input
                TextField(
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: '输入 Base64 字符串',
                    hintText: '输入要解码的 Base64 字符串...',
                    errorText: _decodeError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                  onChanged: (value) {
                    _base64Controller.text = value;
                    _decodeFromBase64();
                  },
                ),
                const SizedBox(height: 12),

                // URL safe decode option
                CheckboxListTile(
                  title: const Text('URL Safe 解码'),
                  subtitle: const Text('将 - 和 _ 转换为 + 和 /, 自动添加 ='),
                  value: _decodeUrlSafe,
                  onChanged: (value) {
                    setState(() {
                      _decodeUrlSafe = value ?? false;
                      _decodeFromBase64();
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 12),

                // Decoded string output
                TextField(
                  controller: _stringController,
                  maxLines: 5,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: '解码结果',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withAlpha(100),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _stringController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyToClipboard(
                              _stringController.text,
                              '解码结果',
                            ),
                            tooltip: '复制',
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withAlpha(100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.tertiary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: cs.tertiary),
                    const SizedBox(width: 8),
                    Text(
                      '使用说明',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Base64 是一种基于 64 个可打印字符来表示二进制数据的编码方法\n'
                  '• URL Safe 模式适用于在 URL 中传输 Base64 数据\n'
                  '• 标准 Base64 使用 +, /, = 字符\n'
                  '• URL Safe Base64 使用 -, _ 字符，并移除 = 填充',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onTertiaryContainer,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
