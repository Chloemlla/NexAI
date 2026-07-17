import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/crash_reporter.dart';
import '../utils/build_config.dart';
import 'crash_report_page.dart';
import '../widgets/lumen/lumen.dart';

class DeveloperDebugPage extends StatelessWidget {
  const DeveloperDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final diagnostics = _buildDiagnostics(settings);

    return LumenSecondaryScaffold(
      title: '开发者高级调试模式',
      children: [
        const LumenPageIntro(
          icon: Icons.terminal_rounded,
          title: 'NexAI Debug Console',
          description: '运行时诊断、崩溃报告入口与日志流。此页采用 Lumen 二级页节奏：简洁顶栏 + soft section。',
          chips: ['Runtime', 'Crash', 'Log stream'],
        ),
        LumenSettingsSection(
          icon: Icons.analytics_outlined,
          title: '运行指标',
          subtitle: '当前模型与生成参数快照',
          children: [
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
          ],
        ),
        FutureBuilder(
            future: CrashReporter.store.load(),
            builder: (context, snapshot) {
              final report = snapshot.data;
              return LumenSettingsSection(
                icon: Icons.bug_report_outlined,
                title: '崩溃报告',
                subtitle: report == null ? '当前没有已存储的崩溃报告' : report.reportId,
                children: [
                      Text(
                        report == null
                            ? '尚未捕获崩溃报告。'
                            : '${report.exceptionType}\n${report.crashedAtText}',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontFamily: SettingsProvider.monospaceFontFamily,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      if (report != null) ...[
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
              );
            },
          ),
        LumenSettingsSection(
          icon: Icons.article_rounded,
          title: '日志流',
          subtitle: '复制运行参数快照用于排障',
          headerAccessory: IconButton(
            tooltip: '复制',
            onPressed: () async {
              HapticFeedback.selectionClick();
              await Clipboard.setData(ClipboardData(text: diagnostics));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制调试日志')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
          children: [
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
      ],
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
      child: LumenActionCard(
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
    );
  }
}
