import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/knowledge_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/password_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/short_url_provider.dart';
import '../providers/translation_provider.dart';
import '../services/local_backup_service.dart';
import '../utils/file_access_helper.dart';
import '../theme/lumen_tokens.dart';

class LocalBackupCard extends StatefulWidget {
  const LocalBackupCard({super.key});

  @override
  State<LocalBackupCard> createState() => _LocalBackupCardState();
}

class _LocalBackupCardState extends State<LocalBackupCard> {
  static const _service = LocalBackupService();
  bool _isBusy = false;

  Future<String?> _promptPassphrase({required bool confirm}) async {
    final passphraseController = TextEditingController();
    final confirmController = TextEditingController();
    var obscure = true;
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(confirm ? '创建卸载前备份' : '重装后恢复'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passphraseController,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '备份口令',
                    helperText: '至少 12 个字符，请妥善保存',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (confirm) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscure,
                    decoration: const InputDecoration(labelText: '再次输入口令'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final passphrase = passphraseController.text.trim();
                  if (passphrase.length < LocalBackupService.minPassphraseLength) {
                    _showMessage('备份口令至少需要 12 个字符');
                    return;
                  }
                  if (confirm && passphrase != confirmController.text.trim()) {
                    _showMessage('两次输入的口令不一致');
                    return;
                  }
                  Navigator.pop(dialogContext, passphrase);
                },
                child: Text(confirm ? '创建备份' : '开始恢复'),
              ),
            ],
          ),
        ),
      );
    } finally {
      passphraseController.dispose();
      confirmController.dispose();
    }
  }

  Future<bool> _confirmRestore() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('覆盖本地数据？'),
        content: const Text(
          '恢复会覆盖当前设置、对话、笔记、知识库、历史记录和密码库。\n\n'
          '如果当前设备还有重要数据，请先创建一份卸载前备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('覆盖并恢复'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _exportBackup() async {
    if (_isBusy) return;
    final passphrase = await _promptPassphrase(confirm: true);
    if (passphrase == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final raw = await _service.createBackup(
        settingsProvider: context.read<SettingsProvider>(),
        chatProvider: context.read<ChatProvider>(),
        notesProvider: context.read<NotesProvider>(),
        knowledgeProvider: context.read<KnowledgeProvider>(),
        passwordProvider: context.read<PasswordProvider>(),
        translationProvider: context.read<TranslationProvider>(),
        shortUrlProvider: context.read<ShortUrlProvider>(),
        passphrase: passphrase,
      );
      final fileName =
          'nexai_backup_${DateTime.now().toIso8601String().substring(0, 10)}.json';
      final path = await FileAccessHelper.saveFile(
        fileName: fileName,
        dialogTitle: '保存 NexAI 卸载前备份',
        allowedExtensions: const ['json'],
      );
      if (path == null) return;
      await File(path).writeAsString(raw, flush: true);
      if (mounted) _showMessage('卸载前备份已保存');
    } catch (error) {
      if (mounted) _showMessage('备份失败：$error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_isBusy || !await _confirmRestore() || !mounted) return;
    final path = await FileAccessHelper.pickFile(
      allowedExtensions: const ['json'],
    );
    if (path == null || !mounted) return;
    final passphrase = await _promptPassphrase(confirm: false);
    if (passphrase == null || !mounted) return;
    final settingsProvider = context.read<SettingsProvider>();
    final chatProvider = context.read<ChatProvider>();
    final notesProvider = context.read<NotesProvider>();
    final knowledgeProvider = context.read<KnowledgeProvider>();
    final passwordProvider = context.read<PasswordProvider>();
    final translationProvider = context.read<TranslationProvider>();
    final shortUrlProvider = context.read<ShortUrlProvider>();

    setState(() => _isBusy = true);
    try {
      final raw = await File(path).readAsString();
      await _service.restoreBackup(
        raw: raw,
        passphrase: passphrase,
        settingsProvider: settingsProvider,
        chatProvider: chatProvider,
        notesProvider: notesProvider,
        knowledgeProvider: knowledgeProvider,
        passwordProvider: passwordProvider,
        translationProvider: translationProvider,
        shortUrlProvider: shortUrlProvider,
      );
      if (mounted) _showMessage('重装后恢复完成，API 密钥和登录状态需要重新设置');
    } catch (error) {
      if (mounted) _showMessage('恢复失败：$error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '加密迁移包包含设置、对话、笔记、知识库、历史记录和密码库。',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'API 密钥、登录令牌、同步恢复密钥以及搜索/MCP 令牌不会导出，恢复后需要重新设置。',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isBusy ? null : _exportBackup,
                icon: _isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.archive_outlined, size: 18),
                label: const Text('卸载前备份'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _isBusy ? null : _restoreBackup,
                icon: const Icon(Icons.unarchive_outlined, size: 18),
                label: const Text('重装后恢复'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
