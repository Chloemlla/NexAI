import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/crash_reporter.dart';
import '../utils/build_config.dart';
import 'crash_report_page.dart';
import '../theme/lumen_tokens.dart';
import '../widgets/lumen/lumen.dart';

class DeveloperDebugPage extends StatelessWidget {
  const DeveloperDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final diagnostics = _buildDiagnostics(settings);

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(cs),
      appBar: AppBar(title: const Text('开发者高级调试模式')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          LumenTokens.pagePaddingStart,
          LumenTokens.pagePaddingTop,
          LumenTokens.pagePaddingEnd,
          LumenTokens.pagePaddingBottom,
        ),
        children: [
          LumenActionCard(
            child: Row(
              children: [
                const LumenIconChip(
                  icon: Icons.terminal_rounded,
                  size: 42,
                  iconSize: 22,
                  shape: LumenIconChipShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NexAI Debug Console',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Runtime diagnostics and log stream',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontFamily: SettingsProvider.monospaceFontFamily,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DebugMetricCard(
                cs: cs,
                label: 'API',
                value: settings.apiMode.toUpperCase(),
                icon: Icons.hub_rounded,
              ),
              _DebugMetricCard(
                cs: cs,
                label: 'MODEL',
                value: settings.selectedModel,
                icon: Icons.smart_toy_rounded,
              ),
              _DebugMetricCard(
                cs: cs,
                label: 'TEMP',
                value: settings.temperature.toStringAsFixed(2),
                icon: Icons.thermostat_rounded,
              ),
              _DebugMetricCard(
                cs: cs,
                label: 'TOKENS',
                value: '${settings.maxTokens}',
                icon: Icons.token_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: CrashReporter.store.load(),
            builder: (context, snapshot) {
              final report = snapshot.data;
              return Card(
                color: cs.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bug_report_outlined,
                            size: 20,
                            color: report == null ? cs.outline : cs.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CRASH REPORT',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontFamily:
                                    SettingsProvider.monospaceFontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (report != null)
                            Text(
                              report.reportId,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontFamily:
                                    SettingsProvider.monospaceFontFamily,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        report == null
                            ? 'No stored crash report.'
                            : '${report.exceptionType}\n${report.crashedAtText}',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontFamily: SettingsProvider.monospaceFontFamily,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      if (report != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CrashReportPage(report: report),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                ),
                                label: const Text('查看'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: report.toClipboardText(),
                                    ),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('崩溃报告已复制'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('复制'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            color: cs.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.article_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'LOG STREAM',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontFamily: SettingsProvider.monospaceFontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '复制',
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          await Clipboard.setData(
                            ClipboardData(text: diagnostics),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制调试日志')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    diagnostics,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontFamily: SettingsProvider.monospaceFontFamily,
                      fontSize: 12,
                      height: 1.45,
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

  String _buildDiagnostics(SettingsProvider settings) {
    final modelCount = settings.models.length;
    final buildCode = BuildConfig.buildTime > 0
        ? '${BuildConfig.versionCode}'
        : 'LOCAL';

    return [
      '[NEXAI] DEV_MODE=UNLOCKED',
      '[FONT] MONO=JetBrainsMonoNexAI ASCII_SUBSET=ON',
      '[THEME] MATERIAL3=ON DYNAMIC_COLOR=ON',
      '[API] MODE=${settings.apiMode} MODEL=${settings.selectedModel}',
      '[API] MODEL_COUNT=$modelCount CONFIGURED=${settings.isConfigured}',
      '[GEN] TEMP=${settings.temperature.toStringAsFixed(2)} MAX_TOKENS=${settings.maxTokens}',
      '[BUILD] VERSION_CODE=$buildCode',
      '[SYNC] ENABLED=${settings.syncEnabled} METHOD=${settings.syncMethod}',
    ].join('\n');
  }
}

class _DebugMetricCard extends StatelessWidget {
  final ColorScheme cs;
  final String label;
  final String value;
  final IconData icon;

  const _DebugMetricCard({
    required this.cs,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width >= 720 ? (width - 62) / 4 : (width - 42) / 2;

    return SizedBox(
      width: cardWidth.clamp(140, 220).toDouble(),
      child: Card(
        color: cs.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontFamily: SettingsProvider.monospaceFontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontFamily: SettingsProvider.monospaceFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
