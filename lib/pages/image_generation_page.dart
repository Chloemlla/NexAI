import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

import '../main.dart' show isAndroid;
import '../providers/image_generation_provider.dart';
import '../providers/settings_provider.dart';

class ImageGenerationPage extends StatefulWidget {
  const ImageGenerationPage({super.key});

  @override
  State<ImageGenerationPage> createState() => _ImageGenerationPageState();
}

class _ImageGenerationPageState extends State<ImageGenerationPage> {
  final _promptController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _modelController = TextEditingController(text: 'flux.1-kontext-dev');

  ImageGenerationMode _mode = ImageGenerationMode.chat;
  String _size = '1024x1024';
  final String _responseFormat = 'url';

  @override
  void dispose() {
    _promptController.dispose();
    _imageUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    final settings = context.read<SettingsProvider>();
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
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    if (isAndroid) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      fluent.displayInfoBar(
        context,
        builder: (ctx, close) {
          return fluent.InfoBar(
            title: Text(message),
            severity: fluent.InfoBarSeverity.error,
            action: fluent.IconButton(
              icon: const Icon(fluent.FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildAndroid(context);
    return _buildDesktop(context);
  }

  Widget _buildAndroid(BuildContext context) {
    final provider = context.watch<ImageGenerationProvider>();
    final cs = Theme.of(context).colorScheme;

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
                        borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Generate button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: provider.isLoading ? null : _generate,
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(provider.isLoading ? '生成中...' : '生成图片'),
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
                      borderRadius: BorderRadius.circular(12),
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

    return Card(
      clipBehavior: Clip.antiAlias,
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
                    const Spacer(),
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
    final theme = fluent.FluentTheme.of(context);

    return Row(
      children: [
        // Left panel - controls
        SizedBox(
          width: 350,
          child: Container(
            decoration: BoxDecoration(
              color: theme.micaBackgroundColor,
              border: Border(
                right: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '图片生成',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Mode selector
                fluent.ComboBox<ImageGenerationMode>(
                  value: _mode,
                  items: const [
                    fluent.ComboBoxItem(
                      value: ImageGenerationMode.chat,
                      child: Text('对话模式'),
                    ),
                    fluent.ComboBoxItem(
                      value: ImageGenerationMode.generation,
                      child: Text('生成模式'),
                    ),
                    fluent.ComboBoxItem(
                      value: ImageGenerationMode.edit,
                      child: Text('编辑模式'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                const SizedBox(height: 16),

                if (_mode != ImageGenerationMode.chat) ...[
                  fluent.InfoLabel(
                    label: '模型',
                    child: fluent.TextBox(
                      controller: _modelController,
                      placeholder: '模型',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_mode == ImageGenerationMode.edit ||
                    _mode == ImageGenerationMode.chat) ...[
                  fluent.InfoLabel(
                    label: _mode == ImageGenerationMode.edit
                        ? '图片 URL *'
                        : '图片 URL (可选)',
                    child: fluent.TextBox(
                      controller: _imageUrlController,
                      placeholder: '图片 URL',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                fluent.InfoLabel(
                  label: '提示词',
                  child: fluent.TextBox(
                    controller: _promptController,
                    placeholder: '提示词',
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 16),

                fluent.FilledButton(
                  onPressed: provider.isLoading ? null : _generate,
                  child: Text(provider.isLoading ? '生成中...' : '生成图片'),
                ),

                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: fluent.InfoBar(
                      title: Text(provider.error!),
                      severity: fluent.InfoBarSeverity.error,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Right panel - gallery
        Expanded(
          child: provider.images.isEmpty
              ? const Center(child: Text('还没有生成图片'))
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
                    return fluent.Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Image.network(image.url, fit: BoxFit.cover),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              image.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
