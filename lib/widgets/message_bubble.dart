import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart' show isAndroid, isDesktop;
import '../models/message.dart';
import '../models/chat_tool.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/chat_provider.dart';
import '../services/chat_tool_executor.dart';
import '../services/chat_tool_catalog.dart';
import '../providers/image_generation_provider.dart';
import '../providers/artifacts_provider.dart';
import '../providers/notes_provider.dart';
import '../services/chat_speech_service.dart';
import '../models/chat_knowledge.dart';
import '../providers/knowledge_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/translation_provider.dart';
import '../services/lumen_translation_client.dart';
import '../providers/auth_provider.dart';
import '../utils/file_access_helper.dart';
import 'rich_content_view.dart';
import 'share_artifact_dialog.dart';
import '../theme/lumen_tokens.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final int messageIndex;

  const MessageBubble({
    super.key,
    required this.message,
    required this.messageIndex,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final GlobalKey _repaintKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return _buildBubble(context);
  }

  Widget _buildBubble(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final isUser = widget.message.role == 'user';
    final chat = context.watch<ChatProvider>();
    final focused = chat.focusMessageIndex == widget.messageIndex;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;
    final maxBubbleWidth = isWide ? 720.0 : screenWidth * 0.82;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RepaintBoundary(
        key: _repaintKey,
        child: Container(
          color: settings.borderlessMode ? cs.surface : Colors.transparent,
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Image.asset(
                  'assets/app_icon_runtime.png',
                  width: isWide ? 36 : 30,
                  height: isWide ? 36 : 30,
                ),
                SizedBox(width: isWide ? 10 : 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  decoration: settings.borderlessMode
                      ? null
                      : BoxDecoration(
                          color: isUser
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(LumenTokens.radiusLg),
                            topRight: const Radius.circular(LumenTokens.radiusLg),
                            bottomLeft: Radius.circular(
                              isUser ? LumenTokens.radiusLg : LumenTokens.radiusXs,
                            ),
                            bottomRight: Radius.circular(
                              isUser ? LumenTokens.radiusXs : LumenTokens.radiusLg,
                            ),
                          ),
                          border: widget.message.isError
                              ? Border.all(color: cs.error.withAlpha(120))
                              : (focused
                                  ? Border.all(color: cs.primary, width: 1.4)
                                  : null),
                        ),
                  padding: settings.borderlessMode
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isUser && widget.message.toolRuns.isNotEmpty) ...[
                        ...widget.message.toolRuns.map((run) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ToolRunChip(run: run),
                          );
                        }),
                      ],
                      if (!isUser && widget.message.reasoning.trim().isNotEmpty) ...[
                        _ReasoningPanel(reasoning: widget.message.reasoning),
                        const SizedBox(height: 8),
                      ],
                      if (widget.message.attachments.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.message.attachments.map((attachment) {
                            if (attachment.type == 'image') {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                                child: Image.file(
                                  File(attachment.path),
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 140,
                                    height: 140,
                                    color: cs.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              );
                            }
                            return Chip(
                              avatar: const Icon(Icons.attach_file, size: 16),
                              label: Text(attachment.name),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (isUser)
                        RepaintBoundary(
                          child: SelectableText(
                            widget.message.content,
                            style: TextStyle(
                              fontSize: settings.fontSize + 1,
                              fontFamily: settings.effectiveFontFamily,
                              color: settings.borderlessMode
                                  ? cs.onSurface
                                  : cs.onPrimaryContainer,
                              height: 1.45,
                            ),
                          ),
                        )
                      else
                        RepaintBoundary(
                          child: RichContentView(
                            content: widget.message.content,
                          ),
                        ),
                      if (!isUser && widget.message.citations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.message.citations.map((c) {
                            return _CitationChip(citation: c);
                          }).toList(),
                        ),
                      ],
                      if (!isUser &&
                          (widget.message.modelId != null ||
                              widget.message.stats != null)) ...[
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (widget.message.modelId != null &&
                                widget.message.modelId!.isNotEmpty)
                              widget.message.modelId!,
                            if (widget.message.stats?.totalTokens != null)
                              'tokens ${widget.message.stats!.totalTokens}',
                            if (widget.message.stats?.completionMs != null)
                              '${widget.message.stats!.completionMs}ms',
                            if (widget.message.stats?.timeToFirstTokenMs != null)
                              'ttft ${widget.message.stats!.timeToFirstTokenMs}ms',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.outline,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      _MessageFooter(
                        message: widget.message,
                        isUser: isUser,
                        messageIndex: widget.messageIndex,
                        repaintKey: _repaintKey,
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                SizedBox(width: isWide ? 10 : 8),
                Container(
                  width: isWide ? 36 : 30,
                  height: isWide ? 36 : 30,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(isWide ? 12 : 10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: isWide ? 18 : 14,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageFooter extends StatelessWidget {
  final Message message;
  final bool isUser;
  final int messageIndex;
  final GlobalKey repaintKey;

  const _MessageFooter({
    required this.message,
    required this.isUser,
    required this.messageIndex,
    required this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 10, color: cs.outline.withAlpha(180)),
        ),
        const SizedBox(width: 8),
        if (isUser) ...[
          _footerIcon(
            Icons.edit_outlined,
            '编辑并重新发送',
            () => _showEditDialog(context),
            cs,
          ),
          _footerIcon(
            Icons.refresh_rounded,
            '重新发送',
            () => _resendMessage(context),
            cs,
          ),
        ] else ...[
          _footerIcon(Icons.copy_rounded, '复制回复', () {
            Clipboard.setData(ClipboardData(text: message.content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已复制'),
                duration: Duration(seconds: 1),
              ),
            );
          }, cs),
          _footerIcon(
            Icons.translate_rounded,
            '翻译消息',
            () => _translateMessage(context),
            cs,
          ),
          _footerIcon(
            Icons.volume_up_rounded,
            '朗读',
            () => _speakMessage(context),
            cs,
          ),
          _footerIcon(
            Icons.autorenew_rounded,
            '重新生成',
            () => _regenerate(context),
            cs,
          ),
        ],
        _footerIcon(
          Icons.ios_share_rounded,
          '分享或导出',
          () => _showShareMenu(context, cs),
          cs,
        ),
        if (!isUser)
          _footerIcon(
            Icons.note_add_outlined,
            '保存到笔记',
            () => _showSaveToNoteSheet(context),
            cs,
          ),
      ],
    );
  }

  Widget _footerIcon(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
    ColorScheme cs,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 14, color: cs.outline.withAlpha(190)),
          ),
        ),
      ),
    );
  }

  Future<void> _showShareMenu(BuildContext context, ColorScheme cs) async {
    if (isAndroid) {
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        backgroundColor: cs.surfaceContainerLow,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _shareTile(
              Icons.description_outlined,
              '导出为 Markdown',
              () => _exportMarkdown(context),
            ),
            _shareTile(
              Icons.image_outlined,
              '导出为图片 (PNG)',
              () => _exportImage(context),
            ),
            const Divider(height: 1),
            _shareTile(
              Icons.share_outlined,
              '分享到 ShareGPT',
              () => _shareToShareGPT(context),
            ),
            _shareTile(
              Icons.open_in_new_rounded,
              '生成独立分享页面 (Artifacts)',
              () => _generateArtifact(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    } else {
      // Desktop: use popup menu
      final RenderBox button =
          repaintKey.currentContext?.findRenderObject() as RenderBox;
      final overlay =
          Navigator.of(context).overlay!.context.findRenderObject()
              as RenderBox;
      final position = RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      );
      final selectedValue = await showMenu<String>(
        context: context,
        position: position,
        items: [
          const PopupMenuItem(value: 'markdown', child: Text('导出为 Markdown')),
          const PopupMenuItem(value: 'image', child: Text('导出为图片 (PNG)')),
          const PopupMenuItem(value: 'sharegpt', child: Text('分享到 ShareGPT')),
          const PopupMenuItem(value: 'artifact', child: Text('生成独立分享页面')),
        ],
      );
      if (!context.mounted || selectedValue == null) return;
      switch (selectedValue) {
        case 'markdown':
          _exportMarkdown(context);
          break;
        case 'image':
          _exportImage(context);
          break;
        case 'sharegpt':
          _shareToShareGPT(context);
          break;
        case 'artifact':
          _generateArtifact(context);
          break;
      }
    }
  }

  Widget _shareTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
      dense: true,
    );
  }

  void _exportMarkdown(BuildContext context) {
    if (isAndroid) Navigator.pop(context);
    final chat = context.read<ChatProvider>();
    final buffer = StringBuffer();
    buffer.writeln('# NexAI 聊天导出');
    buffer.writeln('导出时间: ${DateTime.now().toString()}');
    buffer.writeln();
    for (final msg in chat.messages) {
      buffer.writeln('### ${msg.role.toUpperCase()}');
      buffer.writeln(msg.content);
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('对话已作为 Markdown 复制')));
  }

  Future<void> _exportImage(BuildContext context) async {
    if (isAndroid) Navigator.pop(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('正在保存图片...')));

    try {
      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('无法获取图片')));
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) throw Exception('Image data is null');

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      if (isAndroid) {
        // Use Gal library which handles MediaStore API properly
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        final granted = hasAccess || await Gal.requestAccess(toAlbum: true);

        if (granted) {
          final tempDir = await getTemporaryDirectory();
          final file = File(
            '${tempDir.path}/nexai_chat_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await file.writeAsBytes(pngBytes);
          await Gal.putImage(file.path, album: 'NexAI');
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text('图片已保存到系统相册'),
                ],
              ),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text('缺少存储权限'),
                ],
              ),
            ),
          );
        }
      } else if (isDesktop) {
        final String? path = await FileAccessHelper.saveFile(
          fileName: 'nexai_chat_${DateTime.now().millisecondsSinceEpoch}.png',
          dialogTitle: '保存聊天截图',
          allowedExtensions: ['png'],
        );
        if (path != null) {
          final file = File(path);
          await file.writeAsBytes(pngBytes);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text('图片已保存到: $path')),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.cancel_rounded, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('保存失败: $e')),
            ],
          ),
        ),
      );
    }
  }

  void _shareToShareGPT(BuildContext context) {
    if (isAndroid) Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('正在连接 ShareGPT...')));
  }

  void _generateArtifact(BuildContext context) {
    if (isAndroid) Navigator.pop(context);

    final authProvider = context.read<AuthProvider>();

    // Check if user is logged in
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录以使用分享功能')));
      return;
    }

    // Determine content type and extract content
    String contentType = 'markdown';
    String? language;
    String content = message.content;

    // 1. Check for fenced code block  ```lang\n...\n```
    final codeBlockRegex = RegExp(r'```(\w+)?\n([\s\S]*?)```');
    final match = codeBlockRegex.firstMatch(message.content);

    if (match != null) {
      language = match.group(1)?.toLowerCase();
      content = match.group(2) ?? '';

      // Promote certain languages to their own content type
      if (language == 'json') {
        contentType = 'json';
        language = null;
      } else if (language == 'svg') {
        contentType = 'svg';
        language = null;
      } else if (language == 'html') {
        contentType = 'html';
        language = null;
      } else if (language == 'xml') {
        contentType = 'xml';
        language = null;
      } else if (language == 'csv') {
        contentType = 'csv';
        language = null;
      } else if (language == 'latex' || language == 'tex') {
        contentType = 'latex';
        language = null;
      } else if (language == 'mermaid') {
        contentType = 'mermaid';
        language = null;
      } else {
        contentType = 'code';
      }
    } else {
      // 2. No code block — try to auto-detect from raw content
      final trimmed = message.content.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          // Basic JSON heuristic
          contentType = 'json';
          content = trimmed;
        } catch (_) {}
      } else if (trimmed.startsWith('<svg') || trimmed.startsWith('<?xml')) {
        contentType = trimmed.contains('<svg') ? 'svg' : 'xml';
        content = trimmed;
      } else if (trimmed.startsWith('<!DOCTYPE html') ||
          trimmed.startsWith('<html')) {
        contentType = 'html';
        content = trimmed;
      } else if (trimmed.startsWith('\\documentclass') ||
          trimmed.contains('\\begin{')) {
        contentType = 'latex';
        content = trimmed;
      }
      // else stays 'markdown'
    }

    // Show share dialog
    showDialog(
      context: context,
      builder: (ctx) => ShareArtifactDialog(
        content: content,
        contentType: contentType,
        language: language,
        defaultTitle: isUser ? '用户消息' : 'AI 回复',
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: message.content);
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.edit_rounded, color: cs.primary),
        title: const Text('编辑消息'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '编辑您的消息...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(LumenTokens.radiusSm)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isEmpty) return;
              Navigator.of(ctx).pop();
              _editAndResend(context, newContent);
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }


  void _configureTools(BuildContext context, ChatProvider chat, SettingsProvider settings) {
    final toolsEnabled = settings.chatToolsEnabled && settings.apiMode == 'OpenAI';
    var tools = toolsEnabled
        ? ChatToolCatalog.enabledFromFlags(
            webSearchEnabled: settings.toolWebSearchEnabled,
            notesEnabled: settings.toolNotesEnabled,
            imageEnabled: settings.toolImageEnabled,
            artifactsEnabled: settings.toolArtifactsEnabled,
            fetchUrlEnabled: settings.toolFetchUrlEnabled,
            createNoteEnabled: settings.toolCreateNoteEnabled,
            knowledgeEnabled: settings.toolKnowledgeEnabled,
          )
        : <ChatToolDefinition>[];
    final existingMcp = chat.enabledTools.where((t) => ChatToolCatalog.isMcpTool(t.name));
    tools = [...tools, ...existingMcp];
    chat.configureTools(
      tools: tools,
      runtimeContext: tools.isEmpty
          ? null
          : ChatToolRuntimeContext(
              notesProvider: context.read<NotesProvider>(),
              imageGenerationProvider: context.read<ImageGenerationProvider>(),
              artifactsProvider: context.read<ArtifactsProvider>(),
              knowledgeProvider: context.read<KnowledgeProvider>(),
              mcpServers: settings.remoteMcpEnabled
                  ? settings.mcpServers.where((s) => s.enabled).toList()
                  : const <McpServerConfig>[],
              baseUrl: settings.baseUrl,
              apiKey: settings.apiKey,
              selectedModel: settings.selectedModel,
              accessToken: context.read<AuthProvider>().accessToken,
              imageModel: settings.imageToolModel.isEmpty
                  ? settings.selectedModel
                  : settings.imageToolModel,
            ),
      onApprove: chat.approvalHandler,
      maxRounds: settings.maxToolRounds,
    );
  }

  void _resendMessage(BuildContext context) async {
    final chatProvider = context.read<ChatProvider>();
    final settings = context.read<SettingsProvider>();

    _configureTools(context, chatProvider, settings);
    await chatProvider.resendMessage(
      messageIndex: messageIndex,
      apiMode: settings.apiMode,
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.selectedModel,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      systemPrompt: settings.systemPrompt,
      vertexProjectId: settings.vertexProjectId,
      vertexLocation: settings.vertexLocation,
    );
  }

  void _editAndResend(BuildContext context, String newContent) async {
    final chatProvider = context.read<ChatProvider>();
    final settings = context.read<SettingsProvider>();

    _configureTools(context, chatProvider, settings);
    await chatProvider.editAndResendMessage(
      messageIndex: messageIndex,
      newContent: newContent,
      apiMode: settings.apiMode,
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.selectedModel,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      systemPrompt: settings.systemPrompt,
      vertexProjectId: settings.vertexProjectId,
      vertexLocation: settings.vertexLocation,
    );
  }


  Future<void> _translateMessage(BuildContext context) async {
    final content = message.content.trim();
    if (content.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('正在翻译...'), duration: Duration(seconds: 1)),
    );
    try {
      final client = LumenTranslationClient();
      final clipped = content.length > LumenTranslationClient.maxInputChars
          ? content.substring(0, LumenTranslationClient.maxInputChars)
          : content;
      final result = await client.translate(
        text: clipped,
        targetLang: 'ZH',
        sourceLang: 'auto',
      );
      if (!context.mounted) return;
      final translationProvider = context.read<TranslationProvider>();
      await translationProvider.addRecord(
        TranslationRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sourceLanguage: result.sourceLang,
          targetLanguage: result.targetLang,
          sourceText: content,
          translatedText: result.translatedText,
          createdAt: DateTime.now(),
        ),
      );
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('翻译结果', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SelectableText(result.translatedText),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: result.translatedText),
                        );
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('复制译文'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('翻译失败：$e')));
    }
  }

  void _showSaveToNoteSheet(BuildContext context) {
    final notesProvider = context.read<NotesProvider>();
    final cs = Theme.of(context).colorScheme;
    final notes = notesProvider.notes;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLow,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Icon(Icons.note_add_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Save to Note',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: cs.outlineVariant.withAlpha(80)),
              // New note option
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                title: const Text(
                  'Create new note',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Save as a new note',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                onTap: () async {
                  final title = message.content.length > 40
                      ? '${message.content.substring(0, 40)}...'
                      : message.content;
                  await notesProvider.createNote(
                    title: title,
                    content: message.content,
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text('Saved to new note'),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                    ),
                  );
                },
              ),
              if (notes.isNotEmpty) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant.withAlpha(80),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Existing notes',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: notes.length,
                    itemBuilder: (_, idx) {
                      final note = notes[idx];
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        title: Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () async {
                          await notesProvider.appendToNote(
                            note.id,
                            message.content,
                          );
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Appended to "${note.title}"'),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}


class _ToolRunChip extends StatelessWidget {
  final ToolRunRecord run;
  const _ToolRunChip({required this.run});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (run.status) {
      ChatToolRunStatus.success => cs.primary,
      ChatToolRunStatus.error => cs.error,
      ChatToolRunStatus.denied => cs.tertiary,
      ChatToolRunStatus.running => cs.secondary,
      ChatToolRunStatus.pending => cs.outline,
      ChatToolRunStatus.cancelled => cs.outline,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${run.name} · ${run.status.name}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (run.resultPreview.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              run.resultPreview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  final Citation citation;
  const _CitationChip({required this.citation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(Icons.link_rounded, size: 16, color: cs.primary),
      label: Text(
        citation.title.isEmpty ? citation.url : citation.title,
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () async {
        final uri = Uri.tryParse(citation.url);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}


class _ReasoningPanel extends StatefulWidget {
  final String reasoning;
  const _ReasoningPanel({required this.reasoning});

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withAlpha(120),
        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
        border: Border.all(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.psychology_alt_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _expanded ? '收起思考过程' : '查看思考过程',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SelectableText(
                widget.reasoning,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
