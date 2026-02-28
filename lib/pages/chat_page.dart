import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' show isAndroid;
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/image_generation_provider.dart';
import '../utils/navigation_helper.dart';
import '../widgets/message_bubble.dart';
import '../widgets/welcome_view.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _isAtBottom = true;
  bool _forceScroll = false;

  // Image generation controllers
  final _imagePromptController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _imageModelController = TextEditingController(text: 'doubao-seedream-4-0-250828');

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final isAtBottom = pos.pixels >= pos.maxScrollExtent - 100;
    if (isAtBottom != _isAtBottom) {
      setState(() => _isAtBottom = isAtBottom);
    }
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _imagePromptController.dispose();
    _imageUrlController.dispose();
    _imageModelController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    final settings = context.read<SettingsProvider>();
    if (!settings.smartAutoScroll && !_forceScroll) return;
    
    // If not at bottom and not forced, don't scroll
    if (!_isAtBottom && !_forceScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        try {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
          _forceScroll = false;
        } catch (_) {}
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final settings = context.read<SettingsProvider>();
    if (!settings.isConfigured) {
      if (!mounted) return;
      if (isAndroid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('请在设置中配置您的 API 密钥。')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      } else {
        fluent.displayInfoBar(context, builder: (ctx, close) {
          return fluent.InfoBar(
            title: const Text('请在设置中配置您的 API 密钥。'),
            severity: fluent.InfoBarSeverity.warning,
            action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close),
          );
        });
      }
      return;
    }

    _controller.clear();
    final chat = context.read<ChatProvider>();
    
    _forceScroll = true;

    try {
      await chat.sendMessage(
        content: text,
        baseUrl: settings.baseUrl,
        apiKey: settings.apiKey,
        model: settings.selectedModel,
        temperature: settings.temperature,
        maxTokens: settings.maxTokens,
        systemPrompt: settings.systemPrompt,
      );
    } catch (e) {
      // Error is already handled inside ChatProvider
    }

    if (!mounted) return;
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _showImageGenerationDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLow,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _buildImageGenerationSheet(ctx, scrollController),
      ),
    );
  }

  Widget _buildImageGenerationSheet(BuildContext context, ScrollController scrollController) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<ImageGenerationProvider>();
    final settings = context.watch<SettingsProvider>();

    ImageGenerationMode mode = ImageGenerationMode.chat;
    String size = '1k';
    int imageCount = 1;
    String imageType = 'normal';
    bool watermark = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        final model = _imageModelController.text.trim();
        final isDoubao = model.contains('doubao') || model.contains('seedream');

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.image_rounded, size: 20, color: cs.onPrimary),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '图片生成',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
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
                      selected: {mode},
                      onSelectionChanged: (Set<ImageGenerationMode> newSelection) {
                        setModalState(() => mode = newSelection.first);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Model input (for non-chat modes)
                    if (mode != ImageGenerationMode.chat) ...[
                      TextField(
                        controller: _imageModelController,
                        decoration: InputDecoration(
                          labelText: '模型',
                          hintText: 'doubao-seedream-4-0-250828',
                          prefixIcon: const Icon(Icons.memory, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          helperText: '豆包模型: doubao-seedream-4-0-250828 或 doubao-seedream-3-0-t2i-250415',
                          helperMaxLines: 2,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Image URL input (for edit and image-to-image)
                    if (mode == ImageGenerationMode.edit || mode == ImageGenerationMode.chat) ...[
                      TextField(
                        controller: _imageUrlController,
                        decoration: InputDecoration(
                          labelText: mode == ImageGenerationMode.edit ? '图片 URL *' : '图片 URL (可选)',
                          hintText: 'https://...',
                          prefixIcon: const Icon(Icons.link, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Size selector (for generation and edit)
                    if (mode != ImageGenerationMode.chat) ...[
                      DropdownButtonFormField<String>(
                        value: size,
                        decoration: InputDecoration(
                          labelText: '尺寸',
                          prefixIcon: const Icon(Icons.aspect_ratio, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          helperText: isDoubao ? '支持: 1k/2k/4k, 1024x1024, 16:9等' : null,
                        ),
                        items: (isDoubao
                                ? ['1k', '2k', '4k', '1024x1024', '1280x720', '2560x1440', '16:9', '4:3', '3:2']
                                : ['1024x1024', '1024x1792', '1792x1024', '512x512'])
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (value) => setModalState(() => size = value!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Doubao-specific parameters
                    if (isDoubao) ...[
                      // Image count
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '生成数量: $imageCount',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            imageType == 'normal' ? '(最多4张)' : '(最多10张)',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Slider(
                        value: imageCount.toDouble(),
                        min: 1,
                        max: (imageType == 'normal' ? 4 : 10).toDouble(),
                        divisions: (imageType == 'normal' ? 3 : 9),
                        label: imageCount.toString(),
                        onChanged: (value) => setModalState(() => imageCount = value.toInt()),
                      ),
                      const SizedBox(height: 8),

                      // Image type
                      DropdownButtonFormField<String>(
                        value: imageType,
                        decoration: InputDecoration(
                          labelText: '生成类型',
                          prefixIcon: const Icon(Icons.category, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          helperText: 'normal: 单次最多4张, group: 单次最多10张',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'normal', child: Text('Normal (标准)')),
                          DropdownMenuItem(value: 'group', child: Text('Group (批量)')),
                        ],
                        onChanged: (value) {
                          setModalState(() {
                            imageType = value!;
                            // Adjust imageCount if it exceeds the new limit
                            if (imageType == 'normal' && imageCount > 4) {
                              imageCount = 4;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Type explanation card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withAlpha(100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.primary.withAlpha(60)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, size: 16, color: cs.primary),
                                const SizedBox(width: 6),
                                Text(
                                  imageType == 'normal' ? 'Normal 模式说明' : 'Group 模式说明',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              imageType == 'normal'
                                  ? '相关性不强，主要根据提示词生成独立图片。\n示例：画一只猫在树上玩耍'
                                  : '相关性较强，适合生成连贯的系列图片。\n示例：生成 6 张 3:4 比例的分镜图，整体画风为 Q 版治愈风，内容讲述王子与公主的故事，每张图作为一个分镜，画风统一，人物形象保持一致，连贯成小故事。',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onPrimaryContainer,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Watermark
                      SwitchListTile(
                        title: const Text('添加水印'),
                        subtitle: const Text('在图片右下角显示 AI 生成标识'),
                        value: watermark,
                        onChanged: (value) => setModalState(() => watermark = value),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Prompt input
                    TextField(
                      controller: _imagePromptController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: '提示词',
                        hintText: isDoubao
                            ? (imageType == 'normal'
                                ? '画一只猫在树上玩耍'
                                : '生成 6 张 3:4 比例的分镜图，Q 版治愈风...')
                            : (mode == ImageGenerationMode.chat
                                ? '帮我画一只宇航猫在月球漫步[1024:1024]'
                                : 'a cat on the moon'),
                        prefixIcon: const Icon(Icons.edit_note, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: isDoubao
                            ? (imageType == 'normal'
                                ? '提示词决定生成内容，每张图独立'
                                : '详细描述整体风格和连贯故事，生成系列图片')
                            : null,
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Generate button
                    FilledButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () async {
                              final prompt = _imagePromptController.text.trim();
                              if (prompt.isEmpty) return;

                              if (!settings.isConfigured) {
                                Navigator.pop(context);
                                _showError('请先在设置中配置 API 密钥');
                                return;
                              }

                              final model = _imageModelController.text.trim();
                              final imageUrl = _imageUrlController.text.trim();

                              switch (mode) {
                                case ImageGenerationMode.chat:
                                  await provider.generateImageViaChat(
                                    baseUrl: settings.baseUrl,
                                    apiKey: settings.apiKey,
                                    model: model.isEmpty ? settings.selectedModel : model,
                                    prompt: prompt,
                                    imageUrl: imageUrl.isEmpty ? null : imageUrl,
                                    imageCount: isDoubao ? imageCount : 1,
                                    imageType: isDoubao ? imageType : null,
                                    watermark: isDoubao ? watermark : false,
                                  );
                                  break;
                                case ImageGenerationMode.generation:
                                  await provider.generateImage(
                                    baseUrl: settings.baseUrl,
                                    apiKey: settings.apiKey,
                                    model: model,
                                    prompt: prompt,
                                    size: size,
                                    imageCount: isDoubao ? imageCount : 1,
                                    imageType: isDoubao ? imageType : null,
                                    watermark: isDoubao ? watermark : false,
                                  );
                                  break;
                                case ImageGenerationMode.edit:
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
                                    size: size,
                                  );
                                  break;
                              }

                              if (provider.error == null) {
                                _imagePromptController.clear();
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _showImageGallery(context);
                              }
                            },
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
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),

                    // Error display
                    if (provider.error != null) ...[
                      const SizedBox(height: 12),
                      Container(
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
                    ],

                    // Recent images preview
                    if (provider.images.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '最近生成',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showImageGallery(context);
                            },
                            icon: const Icon(Icons.grid_view, size: 16),
                            label: const Text('查看全部'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: provider.images.take(5).length,
                          itemBuilder: (context, index) {
                            final image = provider.images[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  image.url,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 120,
                                    height: 120,
                                    color: cs.surfaceContainerHighest,
                                    child: Icon(Icons.broken_image, color: cs.outline),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImageGallery(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.read<ImageGenerationProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLow,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.photo_library, size: 20, color: cs.onPrimary),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '图片画廊',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${provider.images.length}',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
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
                        controller: scrollController,
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
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Image.network(
                                    image.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
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
                                              provider.deleteImage(index);
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
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildAndroid(context);
    return _buildDesktop(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildAndroid(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final messages = chat.messages;
    final mq = MediaQuery.of(context);
    final keyboardVisible = mq.viewInsets.bottom > 0;
    // Responsive horizontal padding: wider on tablets
    final screenWidth = mq.size.width;
    final isWide = screenWidth > 600;
    final horizontalPad = isWide ? screenWidth * 0.1 : 14.0;

    if (messages.isNotEmpty) _scrollToBottom();

    return Column(
      children: [
        // Quick settings bar (only show when not configured or when there are messages)
        if (!settings.isConfigured || messages.isNotEmpty)
          _buildQuickSettingsBar(cs, settings),
        
        // ── Message list ──
        Expanded(
          child: messages.isEmpty
              ? const WelcomeView()
              : GestureDetector(
                  onTap: () => _focusNode.unfocus(),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: false,
                    child: ListView.builder(
                      controller: _scrollController,
                      // Keyboard pushes content up via resizeToAvoidBottomInset
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad, 10, horizontalPad, 10,
                      ),
                      itemCount: messages.length + (chat.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && chat.isLoading) {
                          return _buildThinkingIndicator(cs);
                        }
                        return RepaintBoundary(
                          key: ValueKey(
                            'msg_${messages[index].timestamp.millisecondsSinceEpoch}_$index',
                          ),
                          child: MessageBubble(message: messages[index], messageIndex: index),
                        );
                      },
                    ),
                  ),
                ),
        ),

        // ── Preview bubble ──
        if (_hasText)
          _buildPreviewBubble(cs),

        // ── Input bar ──
        // AnimatedPadding so the bar slides up smoothly with the keyboard
        Material(
          color: cs.surfaceContainerLow,
          surfaceTintColor: cs.surfaceTint,
          elevation: keyboardVisible ? 2 : 0,
          child: SafeArea(
            top: false,
            // When keyboard is visible, SafeArea bottom is not needed
            // because the system already insets for us
            bottom: !keyboardVisible,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? horizontalPad : 10,
                8,
                isWide ? horizontalPad : 6,
                8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Image generation button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 8),
                    child: IconButton(
                      icon: Icon(Icons.image_outlined, color: cs.primary, size: 24),
                      onPressed: () => _showImageGenerationDialog(context),
                      tooltip: '生成图片',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                    ),
                  ),
                  // Text field
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        // Cap max height so it doesn't eat the whole screen
                        maxHeight: mq.size.height * 0.25,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null, // grows freely up to constraint
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: '问我任何问题...',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withAlpha(140),
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withAlpha(200),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide(
                              color: cs.primary.withAlpha(100),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button with animated state
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _buildSendButton(cs, chat.isLoading),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBubble(ColorScheme cs) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 12, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '预览',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.2,
            ),
            child: SingleChildScrollView(
              child: RichContentView(content: _controller.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSettingsBar(ColorScheme cs, SettingsProvider settings) {
    if (!settings.isConfigured) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.errorContainer.withAlpha(200), cs.errorContainer.withAlpha(100)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border(
            bottom: BorderSide(color: cs.error.withAlpha(60), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: cs.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'API 密钥未配置',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to settings page
                NavigationHelper.goToSettings();
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('配置'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(120),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withAlpha(60), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              settings.selectedModel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.primary.withAlpha(60), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.thermostat_rounded, size: 12, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  settings.temperature.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.secondary.withAlpha(60), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.token_rounded, size: 12, color: cs.secondary),
                const SizedBox(width: 4),
                Text(
                  settings.maxTokens >= 1000
                      ? '${(settings.maxTokens / 1000).toStringAsFixed(1)}k'
                      : '${settings.maxTokens}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(ColorScheme cs, bool isLoading) {
    final canSend = _hasText && !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: canSend
            ? LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: canSend ? null : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: canSend ? _send : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onSurfaceVariant,
                        strokeCap: StrokeCap.round,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      key: const ValueKey('send'),
                      size: 22,
                      color: canSend ? cs.onPrimary : cs.onSurfaceVariant.withAlpha(100),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(Icons.smart_toy_rounded, size: 14, color: cs.onPrimary),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThinkingDots(color: cs.primary),
                  const SizedBox(width: 12),
                  Text(
                    '思考中...',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Desktop: Fluent UI ───
  Widget _buildDesktop(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final theme = fluent.FluentTheme.of(context);
    final messages = chat.messages;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (messages.isNotEmpty) _scrollToBottom();

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const WelcomeView()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  addAutomaticKeepAlives: true,
                  itemCount: messages.length + (chat.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && chat.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(width: 48),
                            fluent.ProgressRing(strokeWidth: 2),
                            SizedBox(width: 12),
                            Text('思考中...'),
                          ],
                        ),
                      );
                    }
                    return RepaintBoundary(
                      key: ValueKey('msg_${messages[index].timestamp.millisecondsSinceEpoch}_$index'),
                      child: MessageBubble(message: messages[index], messageIndex: index),
                    );
                  },
                ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.micaBackgroundColor.withAlpha((0.8 * 255).round()),
            border: Border(top: BorderSide(color: theme.resources.dividerStrokeColorDefault)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: fluent.TextBox(
                  controller: _controller,
                  focusNode: _focusNode,
                  placeholder: '输入您的消息...',
                  maxLines: 6,
                  minLines: 1,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 14),
                  decoration: WidgetStatePropertyAll(BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.resources.dividerStrokeColorDefault),
                  )),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: fluent.FilledButton(
                  onPressed: chat.isLoading ? null : _send,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(fluent.FluentIcons.send, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


// ─── Animated thinking dots ───
class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 0.2
            final delay = i * 0.2;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            // Bounce: 0→1→0 over the cycle
            final scale = t < 0.5 ? (t * 2) : (2 - t * 2);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, -3 * scale),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha((120 + 135 * scale).round()),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
