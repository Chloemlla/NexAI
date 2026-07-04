import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/sync_crypto.dart';

const _syncCrypto = SyncCrypto();

Future<void> showSyncRecoveryKeyDialog(BuildContext context) async {
  try {
    final key = await _syncCrypto.exportRecoveryKey();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('同步恢复密钥'),
        content: SelectableText(key),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('复制'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) _showSnackBar(context, '导出同步恢复密钥失败: $e');
  }
}

Future<void> showImportSyncRecoveryKeyDialog(BuildContext context) async {
  final controller = TextEditingController();
  try {
    final imported = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入同步恢复密钥'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '粘贴恢复密钥',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (imported != true) return;
    await _syncCrypto.importRecoveryKey(controller.text);
    if (context.mounted) _showSnackBar(context, '同步恢复密钥已导入');
  } catch (e) {
    if (context.mounted) _showSnackBar(context, '导入同步恢复密钥失败: $e');
  } finally {
    controller.dispose();
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
