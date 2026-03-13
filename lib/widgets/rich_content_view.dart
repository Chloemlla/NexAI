import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../pages/note_detail_page.dart';
import 'flowchart/flowchart_widget.dart';

// Pre-compiled regex — avoids recompilation per build
final _cePattern = RegExp(r'\$?\s*\\ce\{([^}]+)\}\s*\$?');
final _subscriptPattern = RegExp(r'([A-Za-z)])(\d+)');
final _chargePattern = RegExp(r'(?<=[A-Za-z\d\)\}])\^?(\d*[+-])(?!\})');
final _bareCaretPattern = RegExp(r'\^(?!\{)');
final _mermaidBlockPattern = RegExp(
  r'```mermaid\s*\n([\s\S]*?)```',
  multiLine: true,
  caseSensitive: false,
);

/// Renders message content with Markdown, LaTeX/chemical formulas, and Mermaid flowcharts.
class RichContentView extends StatefulWidget {
  final String content;
  final bool enableWikiLinks;

  const RichContentView({
    super.key,
    required this.content,
    this.enableWikiLinks = false,
  });

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
      setState(() {
        _segments = _parseContent(widget.content);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_segments.isEmpty) return const SizedBox.shrink();

    return SelectionArea(
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: _segments.map(_buildSegment).toList(),
        ),
      ),
    );
  }

  Widget _buildSegment(_Segment seg) {
    switch (seg.type) {
      case _SegmentType.mermaid:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: RepaintBoundary(
            child: FlowchartWidget(mermaidSource: seg.content),
          ),
        );
      case _SegmentType.markdown:
        if (widget.enableWikiLinks && wikiLinkPattern.hasMatch(seg.content)) {
          return _WikiLinkMarkdown(data: seg.content);
        }
        return _MarkdownWidget(data: seg.content);
    }
  }
}

class _MarkdownWidget extends StatelessWidget {
  final String data;
  const _MarkdownWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();

    final processed = _preprocessChemical(data);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: GptMarkdown(
          processed,
          useDollarSignsForLatex: true,
          style: TextStyle(
            fontSize: settings.fontSize,
            fontFamily: settings.fontFamily == 'System'
                ? null
                : settings.fontFamily,
            color: cs.onSurface,
            height: 1.6,
            letterSpacing: 0.1,
          ),
          onLinkTap: (url, title) async {
            if (url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
      ),
    );
  }

  static String _preprocessChemical(String text) {
    return text.replaceAllMapped(_cePattern, (m) {
      final converted = _convertChemical(m.group(1)!);
      return '\$ $converted \$';
    });
  }

  static String _convertChemical(String formula) {
    var result = formula;
    result = result.replaceAllMapped(
      _subscriptPattern,
      (m) => '${m.group(1)}_{${m.group(2)}}',
    );
    result = result.replaceAllMapped(_chargePattern, (m) => '^{${m.group(1)}}');
    result = result.replaceAll('<->', '\\rightleftharpoons ');
    result = result.replaceAll('->', '\\rightarrow ');
    result = result.replaceAllMapped(_bareCaretPattern, (m) => '\\uparrow ');
    return result;
  }
}

class _WikiLinkMarkdown extends StatelessWidget {
  final String data;
  const _WikiLinkMarkdown({required this.data});

  @override
  Widget build(BuildContext context) {
    final matches = wikiLinkPattern.allMatches(data).toList();
    if (matches.isEmpty) return _MarkdownWidget(data: data);

    final parts = <_WikiSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        parts.add(_WikiSpan(text: data.substring(lastEnd, match.start)));
      }
      parts.add(_WikiSpan(wikiLink: WikiLink.parse(match.group(1)!)));
      lastEnd = match.end;
    }
    if (lastEnd < data.length) {
      parts.add(_WikiSpan(text: data.substring(lastEnd)));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((p) {
        if (p.wikiLink != null) return _WikiLinkChip(link: p.wikiLink!);
        return _MarkdownWidget(data: p.text!);
      }).toList(),
    );
  }
}

class _WikiSpan {
  final String? text;
  final WikiLink? wikiLink;
  _WikiSpan({this.text, this.wikiLink});
}

class _WikiLinkChip extends StatelessWidget {
  final WikiLink link;
  const _WikiLinkChip({required this.link});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Reactive check for target note existence
    final targetNote = context.select<NotesProvider, Note?>(
      (p) => p.findNoteByTitle(link.target),
    );
    final exists = targetNote != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Tooltip(
        message: exists
            ? 'Open note: ${link.target}'
            : 'Create new note: ${link.target}',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            final provider = context.read<NotesProvider>();
            if (exists) {
              provider.markViewed(targetNote.id);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NoteDetailPage(noteId: targetNote.id),
                ),
              );
            } else {
              final newNote = provider.createNote(title: link.target);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NoteDetailPage(noteId: newNote.id),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: exists
                  ? cs.primaryContainer.withAlpha(120)
                  : cs.errorContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: exists
                    ? cs.primary.withAlpha(60)
                    : cs.error.withAlpha(60),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  exists ? Icons.link_rounded : Icons.add_link_rounded,
                  size: 14,
                  color: exists ? cs.primary : cs.error,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    link.displayText,
                    style: TextStyle(
                      fontSize: 13,
                      color: exists ? cs.primary : cs.error,
                      fontWeight: FontWeight.w600,
                      decoration: exists ? null : TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dashed,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (link.heading != null) ...[
                  Text(
                    ' › ${link.heading}',
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<_Segment> _parseContent(String text) {
  final segments = <_Segment>[];
  int lastEnd = 0;

  for (final match in _mermaidBlockPattern.allMatches(text)) {
    if (match.start > lastEnd) {
      final before = text.substring(lastEnd, match.start).trim();
      if (before.isNotEmpty) {
        segments.add(_Segment(_SegmentType.markdown, before));
      }
    }
    segments.add(_Segment(_SegmentType.mermaid, match.group(1)!.trim()));
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    final remaining = text.substring(lastEnd).trim();
    if (remaining.isNotEmpty) {
      segments.add(_Segment(_SegmentType.markdown, remaining));
    }
  }

  final trimmedText = text.trim();
  if (segments.isEmpty && trimmedText.isNotEmpty) {
    segments.add(_Segment(_SegmentType.markdown, trimmedText));
  }
  return segments;
}

enum _SegmentType { markdown, mermaid }

class _Segment {
  final _SegmentType type;
  final String content;
  _Segment(this.type, this.content);
}
