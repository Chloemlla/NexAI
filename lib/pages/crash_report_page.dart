import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/crash_report.dart';
import '../providers/settings_provider.dart';
import '../services/crash_author_attribution.dart';
import '../services/crash_report_paste_uploader.dart';
import '../services/crash_reporter.dart';
import '../theme/lumen_tokens.dart';
import '../widgets/lumen/lumen.dart';

class CrashReportPage extends StatefulWidget {
  const CrashReportPage({
    super.key,
    required this.report,
    this.onContinue,
    this.clearStoredReportOnContinue = true,
  });

  final CrashReport report;
  final VoidCallback? onContinue;
  final bool clearStoredReportOnContinue;

  @override
  State<CrashReportPage> createState() => _CrashReportPageState();
}

class _CrashReportPageState extends State<CrashReportPage> {
  static const int _collapsedStackLines = 18;
  static const int _visibleEventCount = 12;
  bool _stackExpanded = false;
  bool _exporting = false;
  bool _uploadingLink = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final report = widget.report;
    final systemInfo = report.systemInfo
        .split('\n')
        .map((line) => line.split(':'))
        .where((parts) => parts.length >= 2)
        .map(
          (parts) => MapEntry(parts.first.trim(), parts.skip(1).join(':').trim()),
        )
        .toList();
    final stackLines = report.stackTrace.split('\n');
    final stackPreview = _stackExpanded
        ? report.stackTrace
        : stackLines.take(_collapsedStackLines).join('\n');

    return LumenSecondaryScaffold(
      title: '崩溃报告',
      children: [
        LumenPageIntro(
          icon: Icons.bug_report_rounded,
          title: 'NexAI 崩溃报告',
          description: '汇总崩溃摘要、堆栈与系统信息，便于复制、导出或继续使用应用。',
          chips: const ['Crash', 'Stack', 'Export'],
        ),
                _CrashCard(
                  cs: cs,
                  children: [
                    _SectionTitle(
                      cs: cs,
                      icon: Icons.info_outline_rounded,
                      label: '崩溃摘要',
                    ),
                    _InfoTile(label: 'Report ID', value: report.reportId, cs: cs),
                    _InfoTile(
                      label: 'Crash time',
                      value: report.crashedAtText,
                      cs: cs,
                    ),
                    _InfoTile(
                      label: 'Root cause',
                      value: report.rootCause,
                      cs: cs,
                      emphasis: true,
                    ),
                    _InfoTile(
                      label: 'Exception type',
                      value: report.exceptionType,
                      cs: cs,
                    ),
                    _InfoTile(label: 'Thread', value: report.threadName, cs: cs),
                    _InfoTile(
                      label: 'Process',
                      value: report.processName,
                      cs: cs,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CrashCard(
                  cs: cs,
                  children: [
                    _SectionTitle(
                      cs: cs,
                      icon: Icons.devices_rounded,
                      label: '系统信息',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: systemInfo
                          .map(
                            (entry) => _MetadataPill(
                              label: entry.key,
                              value: entry.value,
                              cs: cs,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                if (report.recentEvents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _CrashCard(
                    cs: cs,
                    children: [
                      _SectionTitle(
                        cs: cs,
                        icon: Icons.history_rounded,
                        label: '最近事件',
                      ),
                      ...report.recentEvents
                          .take(_visibleEventCount)
                          .map((event) => _EventRow(event: event, cs: cs)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _CrashCard(
                  cs: cs,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SectionTitle(
                            cs: cs,
                            icon: Icons.bug_report_outlined,
                            label: '堆栈跟踪',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _stackExpanded = !_stackExpanded);
                          },
                          icon: Icon(
                            _stackExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                          ),
                          label: Text(_stackExpanded ? '收起' : '完整堆栈'),
                        ),
                      ],
                    ),
                    Text(
                      '共 ${stackLines.length} 行',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      constraints: BoxConstraints(
                        maxHeight: _stackExpanded ? 420 : 220,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(
                          LumenTokens.radiusXs,
                        ),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          stackPreview,
                          style: TextStyle(
                            fontFamily: SettingsProvider.monospaceFontFamily,
                            fontSize: 12,
                            height: 1.45,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '报告会尽量脱敏本地路径、URI 与常见密钥痕迹，但复制或导出前仍建议快速检查。',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AuthorCard(report: report, cs: cs),
                const SizedBox(height: 12),
                _ActionPanel(
                  cs: cs,
                  exporting: _exporting,
                  uploadingLink: _uploadingLink,
                  onCopyId: _copyId,
                  onCopyReport: _copyReport,
                  onExport: _exportReport,
                  onUploadLink: _uploadShareableLink,
                  onClear: _clearAndContinue,
                ),
      ],
    );
  }

  Future<void> _copyId() async {
    await Clipboard.setData(ClipboardData(text: widget.report.reportId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report ID 已复制')),
    );
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(
      ClipboardData(text: widget.report.toClipboardText()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('崩溃报告已复制')),
    );
  }

  Future<void> _exportReport() async {
    setState(() => _exporting = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/nexai_crash_report_${widget.report.crashedAtMillis}.txt',
      );
      await file.writeAsString(widget.report.toClipboardText(), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到 ${file.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _uploadShareableLink() async {
    if (_uploadingLink) return;
    setState(() => _uploadingLink = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成分享链接…')),
    );
    try {
      final url = await const CrashReportPasteUploader().uploadText(
        widget.report.toClipboardText(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('分享链接已就绪'),
            content: SelectableText(url),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('复制'),
              ),
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse(url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: const Text('打开'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享链接生成失败: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploadingLink = false);
    }
  }

  Future<void> _clearAndContinue() async {
    if (widget.clearStoredReportOnContinue) {
      await CrashReporter.clearPendingReport();
    }
    if (widget.onContinue != null) {
      widget.onContinue!.call();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.report, required this.cs});

  final CrashReport report;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return _CrashCard(
      cs: cs,
      children: [
        _SectionTitle(
          cs: cs,
          icon: Icons.person_outline_rounded,
          label: '作者署名',
        ),
        _InfoTile(label: 'Author', value: report.authorName, cs: cs),
        _InfoTile(label: 'Author URL', value: report.authorUrl, cs: cs),
        _InfoTile(
          label: 'Fingerprint',
          value: report.authorFingerprint ??
              CrashAuthorAttribution.fingerprintHex,
          cs: cs,
        ),
        Text(
          CrashAuthorAttribution.footerLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _CrashCard extends StatelessWidget {
  const _CrashCard({required this.cs, required this.children});

  final ColorScheme cs;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LumenActionCard(
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children) ...[
            child,
            if (child != children.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.cs,
    required this.icon,
    required this.label,
  });

  final ColorScheme cs;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.cs,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
                  color: cs.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({
    required this.label,
    required this.value,
    required this.cs,
  });

  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.cs});

  final String event;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SelectableText(
        event,
        style: TextStyle(
          fontFamily: SettingsProvider.monospaceFontFamily,
          fontSize: 12,
          height: 1.35,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.cs,
    required this.exporting,
    required this.uploadingLink,
    required this.onCopyId,
    required this.onCopyReport,
    required this.onExport,
    required this.onUploadLink,
    required this.onClear,
  });

  final ColorScheme cs;
  final bool exporting;
  final bool uploadingLink;
  final VoidCallback onCopyId;
  final VoidCallback onCopyReport;
  final VoidCallback onExport;
  final VoidCallback onUploadLink;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return LumenActionCard(
      color: cs.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '报告会尽量脱敏本地路径和 URI，但复制、导出或上传前仍建议快速检查。',
                  style: TextStyle(color: cs.onPrimaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCopyId,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('复制 Report ID'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onCopyReport,
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('复制完整报告'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: exporting ? null : onExport,
            icon: exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt_rounded),
            label: const Text('导出文本文件'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: uploadingLink ? null : onUploadLink,
            icon: uploadingLink
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: const Text('生成分享链接'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('清除并继续'),
          ),
        ],
      ),
    );
  }
}
