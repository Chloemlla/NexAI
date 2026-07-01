import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Detailed debug dialog for authentication errors with full context and copy support
class AuthDebugDialog extends StatelessWidget {
  final Map<String, dynamic> debugContext;
  final String title;

  const AuthDebugDialog({
    super.key,
    required this.debugContext,
    this.title = '调试信息',
  });

  void _writeJsonSection(StringBuffer buffer, String title, dynamic value) {
    if (value == null) return;
    buffer.writeln('=== $title ===');
    try {
      final formatted = const JsonEncoder.withIndent('  ').convert(value);
      buffer.writeln(formatted);
    } catch (_) {
      buffer.writeln(value.toString());
    }
    buffer.writeln();
  }

  String _formatContext() {
    final buffer = StringBuffer();
    final operation = debugContext['operation'] ?? 'Unknown';
    buffer.writeln('=== $operation Debug Context ===\n');

    // Basic info
    buffer.writeln('Timestamp: ${debugContext['timestamp']}');
    buffer.writeln('Operation: ${debugContext['operation']}');

    // User/identifier info
    if (debugContext['userId'] != null) {
      buffer.writeln('User ID: ${debugContext['userId']}');
    }
    if (debugContext['username'] != null) {
      buffer.writeln('Username: ${debugContext['username']}');
    }
    if (debugContext['identifier'] != null) {
      buffer.writeln('Identifier: ${debugContext['identifier']}');
    }
    if (debugContext['accountEmail'] != null) {
      buffer.writeln('Account Email: ${debugContext['accountEmail']}');
    }
    if (debugContext['apiBaseUrl'] != null) {
      buffer.writeln('API Base URL: ${debugContext['apiBaseUrl']}');
    }
    if (debugContext['platform'] != null) {
      buffer.writeln('Platform: ${debugContext['platform']}');
    }
    if (debugContext['buildMode'] != null) {
      buffer.writeln('Build Mode: ${debugContext['buildMode']}');
    }
    if (debugContext['lastStep'] != null) {
      buffer.writeln('Last Step: ${debugContext['lastStep']}');
    }
    buffer.writeln();

    // Error info
    if (debugContext['error'] != null) {
      buffer.writeln('=== Error ===');
      buffer.writeln('Type: ${debugContext['errorType']}');
      buffer.writeln('Message: ${debugContext['error']}');
      if (debugContext['errorDetails'] != null) {
        buffer.writeln('Details: ${debugContext['errorDetails']}');
      }
      buffer.writeln();
    }

    _writeJsonSection(
      buffer,
      'Error Diagnostics',
      debugContext['errorDiagnostics'],
    );
    _writeJsonSection(
      buffer,
      'Likely Causes / Hints',
      debugContext['errorHints'],
    );
    _writeJsonSection(buffer, 'Step Timeline', debugContext['steps']);
    _writeJsonSection(buffer, 'NexAI Build Info', debugContext['nexaiBuild']);
    _writeJsonSection(buffer, 'Package Info', debugContext['packageInfo']);
    _writeJsonSection(
      buffer,
      'Android Device Info',
      debugContext['androidDevice'],
    );
    if (debugContext['packageInfoError'] != null ||
        debugContext['androidDeviceError'] != null) {
      _writeJsonSection(buffer, 'Environment Collection Errors', {
        'packageInfoError': debugContext['packageInfoError'],
        'androidDeviceError': debugContext['androidDeviceError'],
      });
    }

    // Google-specific info
    if (debugContext['googleClientId'] != null) {
      buffer.writeln('=== Google Configuration ===');
      buffer.writeln('Client ID: ${debugContext['googleClientId']}');
      buffer.writeln('Google Enabled: ${debugContext['googleEnabled']}');
      buffer.writeln('Has ID Token: ${debugContext['hasIdToken']}');
      buffer.writeln('Has Access Token: ${debugContext['hasAccessToken']}');
      buffer.writeln();
    }

    // Backend response
    if (debugContext['backendResponse'] != null) {
      buffer.writeln('=== Backend Response ===');
      try {
        final formatted = JsonEncoder.withIndent(
          '  ',
        ).convert(debugContext['backendResponse']);
        buffer.writeln(formatted);
      } catch (e) {
        buffer.writeln(debugContext['backendResponse'].toString());
      }
      buffer.writeln();
    }

    // Raw options (for Passkey)
    if (debugContext['rawOptions'] != null) {
      buffer.writeln('=== Raw Options from Backend ===');
      try {
        final formatted = JsonEncoder.withIndent(
          '  ',
        ).convert(debugContext['rawOptions']);
        buffer.writeln(formatted);
      } catch (e) {
        buffer.writeln(debugContext['rawOptions'].toString());
      }
      buffer.writeln();
    }
    _writeJsonSection(
      buffer,
      'Raw Options Diagnostics',
      debugContext['rawOptionsDiagnostics'],
    );

    // Sanitized options (for Passkey)
    if (debugContext['sanitizedOptions'] != null) {
      buffer.writeln('=== Sanitized Options ===');
      try {
        final formatted = JsonEncoder.withIndent(
          '  ',
        ).convert(debugContext['sanitizedOptions']);
        buffer.writeln(formatted);
      } catch (e) {
        buffer.writeln(debugContext['sanitizedOptions'].toString());
      }
      buffer.writeln();
    }
    _writeJsonSection(
      buffer,
      'Sanitized Options Diagnostics',
      debugContext['sanitizedOptionsDiagnostics'],
    );
    _writeJsonSection(
      buffer,
      'Native Register Result',
      debugContext['nativeRegisterResult'],
    );
    _writeJsonSection(
      buffer,
      'Native Authenticate Result',
      debugContext['nativeAuthenticateResult'],
    );

    // Credential info (for Passkey)
    if (debugContext['credentialId'] != null) {
      buffer.writeln('=== Credential ===');
      buffer.writeln('ID: ${debugContext['credentialId']}');
      buffer.writeln('Type: ${debugContext['credentialType']}');
      buffer.writeln();
    }
    _writeJsonSection(
      buffer,
      'Credential Response Summary',
      debugContext['credentialResponseSummary'],
    );
    _writeJsonSection(
      buffer,
      'Assertion Response Summary',
      debugContext['assertionResponseSummary'],
    );

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
          Text(title),
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
                          fontFamily: 'JetBrainsMonoNexAI',
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
                        debugContext['errorDetails'] ??
                            debugContext['error'] ??
                            '',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      if (debugContext['lastStep'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '失败阶段',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          debugContext['lastStep'].toString(),
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontFamily: 'JetBrainsMonoNexAI',
                          ),
                        ),
                      ],
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
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: SelectableText(
                  formattedContext,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMonoNexAI',
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
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

/// Legacy alias for backward compatibility
class PasskeyDebugDialog extends AuthDebugDialog {
  const PasskeyDebugDialog({super.key, required super.debugContext})
    : super(title: 'Passkey 调试信息');
}
