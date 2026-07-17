import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../theme/lumen_tokens.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../main.dart' show isAndroid, isDesktop;
import '../providers/image_generation_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/navigation_helper.dart';
import '../utils/file_access_helper.dart';
import '../widgets/lumen/lumen.dart';

class ImageGenerationPage extends StatefulWidget {
  const ImageGenerationPage({super.key});

  @override
  State<ImageGenerationPage> createState() => _ImageGenerationPageState();
}

class _ImageGenerationPageState extends State<ImageGenerationPage> {
  final _promptController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _modelController = TextEditingController(text: 'flux.1-kontext-dev');
  final Dio _downloadDio = Dio();

  ImageGenerationMode _mode = ImageGenerationMode.chat;
  String _size = '1024x1024';
  final String _responseFormat = 'url';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ImageGenerationProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _imageUrlController.dispose();
    _modelController.dispose();
    _downloadDio.close();
    super.dispose();
  }

  bool _supportsImageEndpoint(SettingsProvider settings) {
    if (settings.apiMode != 'OpenAI') return false;

    final uri = Uri.tryParse(settings.baseUrl);
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path.toLowerCase() ?? '';
    final isNexaiApi =
        host == 'tts.chloemlla.com' &&
        (path == '/api/nexai' || path.startsWith('/api/nexai/'));
    final isHappyApi = host == 'happyapi.org' || host.endsWith('.happyapi.org');
    return isNexaiApi || isHappyApi;
  }

  bool _canGenerate(SettingsProvider settings) {
    return _supportsImageEndpoint(settings) && settings.isConfigured;
  }

  String _currentEndpointLabel(SettingsProvider settings) {
    if (settings.apiMode != 'OpenAI') {
      return '当前为 ${settings.apiMode} 模式';
    }
    return settings.baseUrl.trim().isEmpty ? '未配置' : settings.baseUrl;
  }

  String _generateButtonLabel(
    SettingsProvider settings,
    ImageGenerationProvider provider,
  ) {
    if (provider.isLoading) return '生成中...';
    if (!_supportsImageEndpoint(settings)) {
      return '请配置 NexAI API 端点';
    }
    if (!settings.isConfigured) return '请先配置 API 密钥';
    return '生成图片';
  }

  void _openSettings() {
    Navigator.of(context).pop();
    NavigationHelper.goToSettings();
  }

  Future<void> _saveImageLocally(GeneratedImage image) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(const SnackBar(content: Text('正在保存图片...')));

    try {
      Uint8List bytes;
      if (image.b64Json != null && image.b64Json!.isNotEmpty) {
        bytes = base64Decode(image.b64Json!);
      } else {
        final response = await _downloadDio.get<List<int>>(
          image.url,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = response.data;
        if (data == null || data.isEmpty) {
          throw Exception('无法下载图片数据');
        }
        bytes = Uint8List.fromList(data);
      }

      final fileName =
          'nexai_image_${DateTime.now().millisecondsSinceEpoch}.png';

      if (isAndroid) {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        final granted = hasAccess || await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          throw Exception('缺少系统相册权限');
        }

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes, flush: true);
        await Gal.putImage(tempFile.path, album: 'NexAI');
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('图片已保存到系统相册')));
        return;
      }

      if (isDesktop) {
        final path = await FileAccessHelper.saveFile(
          fileName: fileName,
          dialogTitle: '保存生成图片',
          allowedExtensions: ['png'],
        );
        if (path == null) {
          if (!mounted) return;
          messenger.showSnackBar(const SnackBar(content: Text('已取消保存')));
          return;
        }

        await File(path).writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('图片已保存到: $path')));
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('图片已保存到应用目录: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    final settings = context.read<SettingsProvider>();
    if (!_supportsImageEndpoint(settings)) {
      _showError('绘图页仅支持 NexAI API 端点，请先到设置中切换接口');
      return;
    }
    if (!settings.isConfigured) {
      _showError('请先在设置中配置 API 密钥');
      return;
    }

    final provider = context.read<ImageGenerationProvider>();
    final model = _modelController.text.trim();

    switch (_mode) {
      case ImageGenerationMode.chat:
        final imageUrl = _imageUrlController.text.trim();
        await provider.generateImageViaChat(
          baseUrl: settings.baseUrl,
          apiKey: settings.apiKey,
          model: model.isEmpty ? settings.selectedModel : model,
          prompt: prompt,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
        );
        break;
      case ImageGenerationMode.generation:
        await provider.generateImage(
          baseUrl: settings.baseUrl,
          apiKey: settings.apiKey,
          model: model,
          prompt: prompt,
          size: _size,
          responseFormat: _responseFormat,
        );
        break;
      case ImageGenerationMode.edit:
        final imageUrl = _imageUrlController.text.trim();
        if (imageUrl.isEmpty) {
          _showError('编辑模式需要提供图片 URL');
          return;
        }
        await provider.editImage(
          baseUrl: settings.baseUrl,
          apiKey: settings.apiKey,
          model: model,
          image: imageUrl,
          prompt: prompt,
          size: _size,
          responseFormat: _responseFormat,
        );
        break;
    }

    if (provider.error == null) {
      _promptController.clear();
    } else if (mounted) {
      _showError(provider.error!);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumenTokens.radiusSm)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final body = screenWidth > 800
        ? _buildDesktop(context)
        : _buildAndroid(context);

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(Theme.of(context).colorScheme),
      appBar: AppBar(
        title: const Text('AI 绘图'),
        actions: [
          TextButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('接口设置'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
      bottomNavigationBar: !_canGenerate(settings)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.tonalIcon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('前往设置 NexAI API 端点'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEndpointNotice(BuildContext context, SettingsProvider settings) {
    final cs = Theme.of(context).colorScheme;
    final supported = _supportsImageEndpoint(settings);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: supported
            ? cs.primaryContainer.withAlpha(150)
            : cs.errorContainer.withAlpha(220),
        borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
        border: Border.all(
          color: supported ? cs.primary.withAlpha(60) : cs.error.withAlpha(70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                supported
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: supported ? cs.primary : cs.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  supported ? '当前端点可用于绘图' : '请接入 NexAI API 端点',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: supported
                        ? cs.onPrimaryContainer
                        : cs.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            supported
                ? '当前端点：${_currentEndpointLabel(settings)}\n生成记录会自动保存在本地，单张图片可手动保存到相册或文件。'
                : '请在设置中将 API 模式切换为 OpenAI，并把 Base URL 设置为 ${SettingsProvider.defaultOpenaiBaseUrl}。\n当前：${_currentEndpointLabel(settings)}',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: supported ? cs.onPrimaryContainer : cs.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroid(BuildContext context) {
    final provider = context.watch<ImageGenerationProvider>();
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final canGenerate = _canGenerate(settings);

    return Column(
      children: [
        // Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEndpointNotice(context, settings),
              const SizedBox(height: 12),
              // Mode selector
              SegmentedButton<ImageGenerationMode>(
                segments: const [
                  ButtonSegment(
                    value: ImageGenerationMode.chat,
                    label: Text('对话'),
                    icon: Icon(Icons.chat_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ImageGenerationMode.generation,
                    label: Text('生成'),
                    icon: Icon(Icons.image_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ImageGenerationMode.edit,
                    label: Text('编辑'),
                    icon: Icon(Icons.edit_outlined, size: 16),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (Set<ImageGenerationMode> newSelection) {
                  setState(() => _mode = newSelection.first);
                },
              ),
              const SizedBox(height: 12),

              // Model input
              if (_mode != ImageGenerationMode.chat)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: '模型',
                      hintText: 'flux.1-kontext-dev',
                      prefixIcon: const Icon(Icons.memory, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                    ),
                  ),
                ),

              // Image URL input (for edit and image-to-image)
              if (_mode == ImageGenerationMode.edit ||
                  _mode == ImageGenerationMode.chat)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _imageUrlController,
                    decoration: InputDecoration(
                      labelText: _mode == ImageGenerationMode.edit
                          ? '图片 URL *'
                          : '图片 URL (可选)',
                      hintText: 'https://...',
                      prefixIcon: const Icon(Icons.link, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                    ),
                  ),
                ),

              // Size selector (for generation and edit)
              if (_mode != ImageGenerationMode.chat)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _size,
                    decoration: InputDecoration(
                      labelText: '尺寸',
                      prefixIcon: const Icon(Icons.aspect_ratio, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                    ),
                    items: ['1024x1024', '1024x1792', '1792x1024', '512x512']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) => setState(() => _size = value!),
                  ),
                ),

              // Prompt input
              TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '提示词',
                  hintText: _mode == ImageGenerationMode.chat
                      ? '帮我画一只宇航猫在月球漫步[1024:1024]'
                      : 'a cat on the moon',
                  prefixIcon: const Icon(Icons.edit_note, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Generate button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: provider.isLoading || !canGenerate
                      ? null
                      : _generate,
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_generateButtonLabel(settings, provider)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Error display
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: cs.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.error!,
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Image gallery
        Expanded(
          child: provider.images.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, size: 64, color: cs.outline),
                      const SizedBox(height: 16),
                      Text(
                        '还没有生成图片',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: provider.images.length,
                  itemBuilder: (context, index) {
                    final image = provider.images[index];
                    return _buildImageCard(context, image, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildImageCard(
    BuildContext context,
    GeneratedImage image,
    int index,
  ) {
    final cs = Theme.of(context).colorScheme;

    return LumenActionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.network(
              image.url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.broken_image, color: cs.outline),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: cs.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  image.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      image.mode == ImageGenerationMode.chat
                          ? Icons.chat_outlined
                          : image.mode == ImageGenerationMode.generation
                          ? Icons.image_outlined
                          : Icons.edit_outlined,
                      size: 12,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${image.timestamp.month.toString().padLeft(2, '0')}-${image.timestamp.day.toString().padLeft(2, '0')} ${image.timestamp.hour.toString().padLeft(2, '0')}:${image.timestamp.minute.toString().padLeft(2, '0')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 16),
                      tooltip: '保存到本地',
                      onPressed: () => _saveImageLocally(image),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      onPressed: () {
                        context.read<ImageGenerationProvider>().deleteImage(
                          index,
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final provider = context.watch<ImageGenerationProvider>();
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final canGenerate = _canGenerate(settings);

    return Row(
      children: [
        // Left panel - controls
        SizedBox(
          width: 350,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(
                right: BorderSide(color: cs.outlineVariant.withAlpha(80)),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '绘图工作台',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildEndpointNotice(context, settings),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<ImageGenerationMode>(
                          segments: const [
                            ButtonSegment(
                              value: ImageGenerationMode.chat,
                              label: Text('对话'),
                            ),
                            ButtonSegment(
                              value: ImageGenerationMode.generation,
                              label: Text('生成'),
                            ),
                            ButtonSegment(
                              value: ImageGenerationMode.edit,
                              label: Text('编辑'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (newSelection) {
                            setState(() => _mode = newSelection.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_mode != ImageGenerationMode.chat) ...[
                          TextField(
                            controller: _modelController,
                            decoration: InputDecoration(
                              labelText: '模型',
                              hintText: 'flux.1-kontext-dev',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_mode == ImageGenerationMode.edit ||
                            _mode == ImageGenerationMode.chat) ...[
                          TextField(
                            controller: _imageUrlController,
                            decoration: InputDecoration(
                              labelText: _mode == ImageGenerationMode.edit
                                  ? '图片 URL *'
                                  : '图片 URL (可选)',
                              hintText: 'https://...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_mode != ImageGenerationMode.chat) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _size,
                            decoration: InputDecoration(
                              labelText: '尺寸',
                              prefixIcon: const Icon(
                                Icons.aspect_ratio,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                              ),
                            ),
                            items:
                                [
                                      '1024x1024',
                                      '1024x1792',
                                      '1792x1024',
                                      '512x512',
                                    ]
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) =>
                                setState(() => _size = value!),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _promptController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: '提示词',
                            hintText: _mode == ImageGenerationMode.chat
                                ? '帮我画一只宇航猫在月球漫步[1024:1024]'
                                : 'a cat on the moon',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: provider.isLoading || !canGenerate
                                ? null
                                : _generate,
                            icon: provider.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(
                              _generateButtonLabel(settings, provider),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (provider.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.errorContainer,
                                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: cs.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      provider.error!,
                                      style: TextStyle(
                                        color: cs.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right panel - gallery
        Expanded(
          child: provider.images.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, size: 64, color: cs.outline),
                      const SizedBox(height: 16),
                      Text(
                        '还没有生成图片',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: provider.images.length,
                  itemBuilder: (context, index) {
                    final image = provider.images[index];
                    return _buildImageCard(context, image, index);
                  },
                ),
        ),
      ],
    );
  }
}
