import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Detailed debug dialog for Passkey errors with full context and copy support
class PasskeyDebugDialog extends StatelessWidget {
  final Map<String, dynamic> debugContext;

  const PasskeyDebugDialog({
    super.key,
    required this.debugContext,
  });

  String _formatContext() {
    final buffer = StringBuffer();
    buffer.writeln('=== Passkey Debug Context ===\n');

    // Basic info
    buffer.writeln('Timestamp: ${debugContext['timestamp']}');
    buffer.writeln('Operation: ${debugContext['operation']}');
    buffer.writeln('User ID: ${debugContext['userId']}');
    buffer.writeln('Username: ${debugContext['username']}');
    buffer.writeln();

    // Error info
    if (debugContext['error'] != null) {
      buffer.writeln('=== Error ===');
      buffer.writeln('Type: ${debugContext['errorType']}');
      buffer.writeln('Message: ${debugContext['error']}');
      buffer.writeln();
    }

    // Raw options
    if (debugContext['rawOptions'] != null) {
      buffer.writeln('=== Raw Options from Backend ===');
      try {
        final formatted = JsonEncoder.withIndent('  ')
            .convert(debugContext['rawOptions']);
        buffer.writeln(formatted);
      } catch (e) {
        buffer.writeln(debugContext['rawOptions'].toString());
      }
      buffer.writeln();
    }

    // Sanitized options
    if (debugContext['sanitizedOptions'] != null) {
      buffer.writeln('=== Sanitized Options ===');
      try {
        final formatted = JsonEncoder.withIndent('  ')
            .convert(debugContext['sanitizedOptions']);
        buffer.writeln(formatted);
      } catch (e) {
        buffer.writeln(debugContext['sanitizedOptions'].toString());
      }
      buffer.writeln();
    }

    // Credential info
    if (debugContext['credentialId'] != null) {
      buffer.writeln('=== Credential ===');
      buffer.writeln('ID: ${debugContext['credentialId']}');
      buffer.writeln('Type: ${debugContext['credentialType']}');
      buffer.writeln();
    }

    // Stack trace
    if (debugContext['stackTrace'] != null) {
      buffer.writeln('=== Stack Trace ===');
      buffer.writeln(debugContext['stackTrace']);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final formattedContext = _formatContext();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          const Text('Passkey 调试信息'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error summary
              if (debugContext['error'] != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '错误类型',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        debugContext['errorType'] ?? 'Unknown',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '错误信息',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        debugContext['error'] ?? '',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Full context
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: SelectableText(
                  formattedContext,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: formattedContext));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('复制全部'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
