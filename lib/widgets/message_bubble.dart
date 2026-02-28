import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart' show isAndroid, isDesktop;
import '../models/message.dart';
import '../models/note.dart';
import '../providers/chat_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import 'rich_content_view.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final int messageIndex;

  const MessageBubble({super.key, required this.message, required this.messageIndex});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final GlobalKey _repaintKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildM3Bubble(context);
    return _buildFluentBubble(context);
  }

  // ─── Android: Material 3 bubble ───
  Widget _buildM3Bubble(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final isUser = widget.message.role == 'user';
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RepaintBoundary(
        key: _repaintKey,
        child: Container(
          color: settings.borderlessMode ? cs.surface : Colors.transparent, // Background for PNG
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
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
                  child: Center(child: Icon(Icons.smart_toy_rounded, size: 14, color: cs.onPrimary)),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: screenWidth * 0.82),
                  decoration: settings.borderlessMode
                      ? null
                      : BoxDecoration(
                          color: isUser ? cs.primaryContainer : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(22),
                            topRight: const Radius.circular(22),
                            bottomLeft: Radius.circular(isUser ? 22 : 6),
                            bottomRight: Radius.circular(isUser ? 6 : 22),
                          ),
                          border: widget.message.isError
                              ? Border.all(color: cs.error.withAlpha(120))
                              : null,
                        ),
                  padding: settings.borderlessMode 
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              fontFamily: settings.fontFamily == 'System' ? null : settings.fontFamily,
                              color: settings.borderlessMode ? cs.onSurface : cs.onPrimaryContainer,
                              height: 1.45,
                            ),
                          ),
                        )
                      else
                        RepaintBoundary(child: RichContentView(content: widget.message.content)),
                      const SizedBox(height: 6),
                      _M3Footer(
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
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Icon(Icons.person_rounded, size: 14, color: cs.onSecondaryContainer)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Desktop: Fluent UI bubble ───
  Widget _buildFluentBubble(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final settings = context.watch<SettingsProvider>();
    final isUser = widget.message.role == 'user';
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RepaintBoundary(
        key: _repaintKey,
        child: Container(
          color: settings.borderlessMode ? (isDark ? const Color(0xFF202020) : fluent.Colors.white) : Colors.transparent,
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.accentColor, theme.accentColor.lighter]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(child: Icon(fluent.FluentIcons.robot, size: 16, color: fluent.Colors.white)),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 720),
                  decoration: settings.borderlessMode
                      ? null
                      : BoxDecoration(
                          color: isUser
                              ? Color.fromRGBO(theme.accentColor.value >> 16 & 0xFF, theme.accentColor.value >> 8 & 0xFF, theme.accentColor.value & 0xFF, isDark ? 0.3 : 0.12)
                              : (isDark ? const Color(0xFF2D2D2D) : fluent.Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(isUser ? 12 : 2),
                            bottomRight: Radius.circular(isUser ? 2 : 12),
                          ),
                          border: widget.message.isError
                              ? Border.all(color: fluent.Colors.red.withAlpha((0.5 * 255).round()))
                              : (isDark ? null : Border.all(color: const Color(0xFFE8E8E8))),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? (0.2 * 255).round() : (0.05 * 255).round()), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                  padding: settings.borderlessMode ? const EdgeInsets.all(4) : const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUser)
                        RepaintBoundary(
                          child: SelectableText(
                            widget.message.content,
                            style: TextStyle(
                              fontSize: settings.fontSize,
                              fontFamily: settings.fontFamily == 'System' ? null : settings.fontFamily,
                              color: theme.typography.body?.color,
                            ),
                          ),
                        )
                      else
                        RepaintBoundary(child: RichContentView(content: widget.message.content)),
                      const SizedBox(height: 6),
                      _FluentFooter(
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
                const SizedBox(width: 10),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(child: Icon(fluent.FluentIcons.contact, size: 16, color: theme.typography.body?.color)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _M3Footer extends StatelessWidget {
  final Message message;
  final bool isUser;
  final int messageIndex;
  final GlobalKey repaintKey;
  
  const _M3Footer({
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
          }, cs),
        ],
        _footerIcon(Icons.ios_share_rounded, () => _showShareMenu(context, cs), cs),
        if (!isUser)
          _footerIcon(Icons.note_add_outlined, () => _showNotesDialog(context), cs),
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
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLow,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _shareTile(Icons.description_outlined, '导出为 Markdown', () => _exportMarkdown(context)),
          _shareTile(Icons.image_outlined, '导出为图片 (PNG)', () => _exportImage(context)),
          const Divider(height: 1),
          _shareTile(Icons.share_outlined, '分享到 ShareGPT', () => _shareToShareGPT(context)),
          _shareTile(Icons.artifact_outlined, '生成独立分享页面 (Artifacts)', () => _generateArtifact(context)),
          const SizedBox(height: 12),
        ],
      ),
    );
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
    Navigator.pop(context);
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('对话已作为 Markdown 复制')));
  }

  Future<void> _exportImage(BuildContext context) async {
    Navigator.pop(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('正在保存图片...')));

    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('无法获取图片')));
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
          final file = File('${tempDir.path}/nexai_chat_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(pngBytes);
          await Gal.putImage(file.path, album: 'NexAI');
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('✅ 图片已保存到系统相册')));
        } else {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('⚠️ 缺少存储权限')));
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
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('✅ 图片已保存到: $path')));
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('❌ 保存失败: $e')));
    }
  }

  void _shareToShareGPT(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在连接 ShareGPT...')));
  }

  void _generateArtifact(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artifacts 页面已生成 (演示)')));
  }
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Copied to clipboard'),
                      ],
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 14, color: cs.outline.withAlpha(180)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showSaveToNoteSheet(context),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.note_add_outlined, size: 14, color: cs.outline.withAlpha(180)),
              ),
            ),
          ),
        ],
      ],
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
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.selectedModel,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      systemPrompt: settings.systemPrompt,
    );
  }

  void _editAndResend(BuildContext context, String newContent) async {
    final chatProvider = context.read<ChatProvider>();
    final settings = context.read<SettingsProvider>();

    await chatProvider.editAndResendMessage(
      messageIndex: messageIndex,
      newContent: newContent,
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.selectedModel,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      systemPrompt: settings.systemPrompt,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.note_add_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Text('Save to Note', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                  child: Center(child: Icon(Icons.add_rounded, size: 18, color: cs.onPrimaryContainer)),
                ),
                title: const Text('Create new note', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('Save as a new note', style: TextStyle(fontSize: 12, color: cs.outline)),
                onTap: () {
                  final title = message.content.length > 40
                      ? '${message.content.substring(0, 40)}...'
                      : message.content;
                  notesProvider.createNote(title: title, content: message.content);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Saved to new note'),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
              if (notes.isNotEmpty) ...[
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withAlpha(80)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Existing notes', style: TextStyle(fontSize: 12, color: cs.outline, fontWeight: FontWeight.w500)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Icon(Icons.description_outlined, size: 16, color: cs.onSurfaceVariant)),
                        ),
                        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        onTap: () {
                          notesProvider.appendToNote(note.id, message.content);
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Appended to "${note.title}"')),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _FluentFooter extends StatelessWidget {
  final Message message;
  final bool isUser;
  final int messageIndex;
  final GlobalKey repaintKey;
  const _FluentFooter({required this.message, required this.isUser, required this.messageIndex, required this.repaintKey});

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 10, color: theme.inactiveColor),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showEditDialog(context),
            child: Icon(fluent.FluentIcons.edit, size: 12, color: theme.inactiveColor),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _resendMessage(context),
            child: Icon(fluent.FluentIcons.refresh, size: 12, color: theme.inactiveColor),
          ),
        ],
        if (!isUser) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              fluent.displayInfoBar(context, builder: (ctx, close) {
                return fluent.InfoBar(
                  title: const Text('Copied to clipboard'),
                  severity: fluent.InfoBarSeverity.info,
                  action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close),
                );
              });
            },
            child: Icon(fluent.FluentIcons.copy, size: 12, color: theme.inactiveColor),
          ),
        ],
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _exportImage(context),
          child: Icon(fluent.FluentIcons.save, size: 12, color: theme.inactiveColor),
        ),
      ],
    );
  }

  Future<void> _exportImage(BuildContext context) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        fluent.displayInfoBar(context, builder: (ctx, close) {
          return fluent.InfoBar(title: const Text('Cannot capture image'), severity: fluent.InfoBarSeverity.error, action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close));
        });
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Image data is null');

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Chat Image',
        fileName: 'nexai_chat_${DateTime.now().millisecondsSinceEpoch}.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      if (path != null) {
        final file = File(path);
        await file.writeAsBytes(pngBytes);
        if (context.mounted) {
          fluent.displayInfoBar(context, builder: (ctx, close) {
            return fluent.InfoBar(title: Text('Saved to: $path'), severity: fluent.InfoBarSeverity.success, action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close));
          });
        }
      }
    } catch (e) {
      if (context.mounted) {
        fluent.displayInfoBar(context, builder: (ctx, close) {
          return fluent.InfoBar(title: Text('Error: $e'), severity: fluent.InfoBarSeverity.error, action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close));
        });
      }
    }
  }

  void _showEditDialog(BuildContext context) {
    final controller = fluent.TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (ctx) => fluent.ContentDialog(
        title: const Text('Edit Message'),
        content: fluent.TextBox(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          placeholder: 'Edit your message...',
        ),
        actions: [
          fluent.Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          fluent.FilledButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isEmpty) return;
              Navigator.of(ctx).pop();
              _editAndResend(context, newContent);
            },
            child: const Text('Send'),
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
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.selectedModel,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      systemPrompt: settings.systemPrompt,
    );
  }

  void _editAndResend(BuildContext context, String newContent) async {
    final chatProvider = context.read<ChatProvider>();
    final settings = context.read<SettingsProvider>();

    await chatProvider.editAndResendMessage(
      messageIndex: messageIndex,
      newContent: newContent,
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.selectedModel,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      systemPrompt: settings.systemPrompt,
    );
  }
}
