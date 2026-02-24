import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material show Material, SelectableText, Colors;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import 'flowchart/flowchart_widget.dart';

// Pre-compiled regex — avoids recompilation per build
final _mathPattern = RegExp(r'(\$\$[\s\S]*?\$\$|\$[^\$\n]+?\$|\\ce\{[^}]+\})');
final _cePattern = RegExp(r'\\ce\{([^}]+)\}');
final _subscriptPattern = RegExp(r'([A-Za-z)])(\d+)');
final _chargePattern = RegExp(r'(\d*[+-])(?!\})');
final _mermaidBlockPattern = RegExp(r'```mermaid\s*\n([\s\S]*?)```', multiLine: true);

/// Renders message content with Markdown, LaTeX/chemical formulas, and Mermaid flowcharts.
class RichContentView extends StatefulWidget {
  final String content;

  const RichContentView({super.key, required this.content});

  @override
  State<RichContentView> createState() => _RichContentViewState();
}

class _RichContentViewState extends State<RichContentView> {
  late List<_Segment> _segments;

  @override
  void initState() {
    super.initState();
    _segments = _parseContent(widget.content);
  }

  @override
  void didUpdateWidget(RichContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _segments = _parseContent(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _segments.map((seg) {
        switch (seg.type) {
          case _SegmentType.mermaid:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RepaintBoundary(
                child: FlowchartWidget(mermaidSource: seg.content),
              ),
            );
          case _SegmentType.math:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _MathWidget(tex: seg.content, display: seg.isDisplay),
            );
          case _SegmentType.markdown:
            return _MarkdownWidget(data: seg.content);
        }
      }).toList(),
    );
  }
}

class _MathWidget extends StatelessWidget {
  final String tex;
  final bool display;

  const _MathWidget({required this.tex, this.display = false});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    var processed = tex.trim();
    processed = processed.replaceAllMapped(
      _cePattern,
      (m) => _convertChemical(m.group(1)!),
    );

    return Container(
      width: display ? double.infinity : null,
      padding: display ? const EdgeInsets.symmetric(vertical: 8) : null,
      alignment: display ? Alignment.center : null,
      child: Math.tex(
        processed,
        textStyle: TextStyle(
          fontSize: display ? 18 : 14,
          color: theme.typography.body?.color,
        ),
        onErrorFallback: (err) {
          return material.SelectableText(
            tex,
            style: TextStyle(fontSize: 13, fontFamily: 'Consolas', color: theme.accentColor),
          );
        },
      ),
    );
  }

  static String _convertChemical(String formula) {
    var result = formula;
    result = result.replaceAllMapped(_subscriptPattern, (m) => '${m.group(1)}_{${m.group(2)}}');
    result = result.replaceAllMapped(_chargePattern, (m) => '^{${m.group(1)}}');
    result = result.replaceAll('->', '\\rightarrow ');
    result = result.replaceAll('<->', '\\rightleftharpoons ');
    result = result.replaceAll('^', '\\uparrow ');
    return '\\text{} $result';
  }
}

class _MarkdownWidget extends StatelessWidget {
  final String data;

  const _MarkdownWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return material.Material(
      color: material.Colors.transparent,
      child: MarkdownBody(
        data: data,
        selectable: true,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(fontSize: 14, color: theme.typography.body?.color, height: 1.6),
          code: TextStyle(
            fontSize: 13,
            fontFamily: 'Consolas',
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
            color: theme.accentColor,
          ),
          codeblockDecoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE0E0E0)),
          ),
          codeblockPadding: const EdgeInsets.all(12),
          blockquoteDecoration: BoxDecoration(
            border: Border(left: BorderSide(color: theme.accentColor, width: 3)),
            color: theme.accentColor.withOpacity(0.05),
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          h1: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.typography.body?.color),
          h2: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: theme.typography.body?.color),
          h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.typography.body?.color),
          listBullet: TextStyle(fontSize: 14, color: theme.typography.body?.color),
          tableHead: TextStyle(fontWeight: FontWeight.w600, color: theme.typography.body?.color),
          tableBorder: TableBorder.all(color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE0E0E0)),
        ),
      ),
    );
  }
}

/// Parses content into segments: mermaid blocks first, then math, then markdown.
List<_Segment> _parseContent(String text) {
  final segments = <_Segment>[];

  // Phase 1: Extract mermaid blocks
  final parts = <_RawPart>[];
  int lastEnd = 0;
  for (final match in _mermaidBlockPattern.allMatches(text)) {
    if (match.start > lastEnd) {
      parts.add(_RawPart(text.substring(lastEnd, match.start), false));
    }
    parts.add(_RawPart(match.group(1)!.trim(), true));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    parts.add(_RawPart(text.substring(lastEnd), false));
  }
  if (parts.isEmpty) {
    parts.add(_RawPart(text, false));
  }

  // Phase 2: For non-mermaid parts, extract math segments
  for (final part in parts) {
    if (part.isMermaid) {
      segments.add(_Segment(_SegmentType.mermaid, part.text));
      continue;
    }

    final subText = part.text;
    int subLastEnd = 0;

    for (final match in _mathPattern.allMatches(subText)) {
      if (match.start > subLastEnd) {
        final mdText = subText.substring(subLastEnd, match.start).trim();
        if (mdText.isNotEmpty) segments.add(_Segment(_SegmentType.markdown, mdText));
      }

      final matched = match.group(0)!;
      if (matched.startsWith('\$\$')) {
        segments.add(_Segment(_SegmentType.math, matched.substring(2, matched.length - 2), isDisplay: true));
      } else if (matched.startsWith('\$')) {
        segments.add(_Segment(_SegmentType.math, matched.substring(1, matched.length - 1)));
      } else if (matched.startsWith('\\ce{')) {
        segments.add(_Segment(_SegmentType.math, matched));
      }

      subLastEnd = match.end;
    }

    if (subLastEnd < subText.length) {
      final remaining = subText.substring(subLastEnd).trim();
      if (remaining.isNotEmpty) segments.add(_Segment(_SegmentType.markdown, remaining));
    }
  }

  if (segments.isEmpty) segments.add(_Segment(_SegmentType.markdown, text));

  return segments;
}

class _RawPart {
  final String text;
  final bool isMermaid;
  _RawPart(this.text, this.isMermaid);
}

enum _SegmentType { markdown, math, mermaid }

class _Segment {
  final _SegmentType type;
  final String content;
  final bool isDisplay;
  _Segment(this.type, this.content, {this.isDisplay = false});
}
