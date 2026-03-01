import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart' show isAndroid, isDesktop;
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import 'rich_content_view.dart';

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
                Container(
                  width: isWide ? 36 : 30,
                  height: isWide ? 36 : 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(isWide ? 12 : 10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.smart_toy_rounded,
                      size: isWide ? 18 : 14,
                      color: cs.onPrimary,
                    ),
                  ),
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
                            topLeft: const Radius.circular(22),
                            topRight: const Radius.circular(22),
                            bottomLeft: Radius.circular(isUser ? 22 : 6),
                            bottomRight: Radius.circular(isUser ? 6 : 22),
                          ),
                          border: widget.message.isError
                              ? Border.all(color: cs.error.withAlpha(120))
                              : null,
                          boxShadow: isWide
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
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
                      if (isUser)
                        RepaintBoundary(
                          child: SelectableText(
                            widget.message.content,
                            style: TextStyle(
                              fontSize: settings.fontSize + 1,
                              fontFamily: settings.fontFamily == 'System'
                                  ? null
                                  : settings.fontFamily,
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
          _footerIcon(Icons.edit_outlined, () => _showEditDialog(context), cs),
          _footerIcon(Icons.refresh_rounded, () => _resendMessage(context), cs),
        ] else ...[
          _footerIcon(Icons.copy_rounded, () {
            Clipboard.setData(ClipboardData(text: message.content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已复制'),
                duration: Duration(seconds: 1),
              ),
            );
          }, cs),
        ],
        _footerIcon(
          Icons.ios_share_rounded,
          () => _showShareMenu(context, cs),
          cs,
        ),
        if (!isUser)
          _footerIcon(
            Icons.note_add_outlined,
            () => _showSaveToNoteSheet(context),
            cs,
          ),
      ],
    );
  }

  Widget _footerIcon(IconData icon, VoidCallback onTap, ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: cs.outline.withAlpha(180)),
        ),
      ),
    );
  }

  void _showShareMenu(BuildContext context, ColorScheme cs) {
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
      showMenu<String>(
        context: context,
        position: position,
        items: [
          const PopupMenuItem(value: 'markdown', child: Text('导出为 Markdown')),
          const PopupMenuItem(value: 'image', child: Text('导出为图片 (PNG)')),
          const PopupMenuItem(value: 'sharegpt', child: Text('分享到 ShareGPT')),
          const PopupMenuItem(value: 'artifact', child: Text('生成独立分享页面')),
        ],
      ).then((selectedValue) {
        if (selectedValue == null) return;
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
      });
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
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = deviceInfo.version.sdkInt;

        bool hasAccess = false;
        if (sdkInt >= 29) {
          hasAccess = await Gal.hasAccess(toAlbum: true);
          if (!hasAccess) hasAccess = await Gal.requestAccess(toAlbum: true);
        } else {
          final status = await Permission.storage.request();
          hasAccess = status.isGranted;
        }

        if (hasAccess) {
          final tempDir = await getTemporaryDirectory();
          final file = File(
            '${tempDir.path}/nexai_chat_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await file.writeAsBytes(pngBytes);
          await Gal.putImage(file.path, album: 'NexAI');
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('✅ 图片已保存到系统相册')),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('⚠️ 缺少存储权限')),
          );
        }
      } else if (isDesktop) {
        final String? path = await FilePicker.platform.saveFile(
          dialogTitle: '保存聊天截图',
          fileName: 'nexai_chat_${DateTime.now().millisecondsSinceEpoch}.png',
          type: FileType.custom,
          allowedExtensions: ['png'],
        );
        if (path != null) {
          final file = File(path);
          await file.writeAsBytes(pngBytes);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('✅ 图片已保存到: $path')),
          );
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('❌ 保存失败: $e')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Artifacts 页面已生成 (演示)')));
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

  void _resendMessage(BuildContext context) async {
    final chatProvider = context.read<ChatProvider>();
    final settings = context.read<SettingsProvider>();

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
                    borderRadius: BorderRadius.circular(10),
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
                onTap: () {
                  final title = message.content.length > 40
                      ? '${message.content.substring(0, 40)}...'
                      : message.content;
                  notesProvider.createNote(
                    title: title,
                    content: message.content,
                  );
                  Navigator.of(ctx).pop();
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
                        borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
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
                        onTap: () {
                          notesProvider.appendToNote(note.id, message.content);
                          Navigator.of(ctx).pop();
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
                                borderRadius: BorderRadius.circular(12),
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
