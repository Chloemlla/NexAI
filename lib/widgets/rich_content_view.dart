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
final _cePattern = RegExp(r'\\ce\{([^}]+)\}');
final _subscriptPattern = RegExp(r'([A-Za-z)])(\d+)');
final _chargePattern = RegExp(r'(\d*[+-])(?!\})');
final _mermaidBlockPattern = RegExp(
  r'```mermaid\s*\n([\s\S]*?)```',
  multiLine: true,
);

/// Renders message content with Markdown, LaTeX/chemical formulas, and Mermaid flowcharts.
/// Links are clickable and open in the system browser.
/// Wiki-links [[note]] are rendered as clickable internal links.
///
/// Rendering pipeline:
/// 1. Extract mermaid code blocks → render as FlowchartWidget
/// 2. Pre-process \ce{...} chemical formulas → standard LaTeX
/// 3. Pass all remaining content (incl. math) to GptMarkdown
///
/// GptMarkdown natively handles:
///   - Inline math: $...$
///   - Display math: $$...$$
///   - Code blocks with syntax highlighting
///   - Standard markdown (headings, lists, tables, etc.)
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
  String? _cachedContent;

  @override
  void initState() {
    super.initState();
    _cachedContent = widget.content;
    _segments = _parseContent(widget.content);
  }

  @override
  void didUpdateWidget(RichContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-parse if content actually changed
    if (oldWidget.content != widget.content &&
        _cachedContent != widget.content) {
      _cachedContent = widget.content;
      _segments = _parseContent(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_segments.isEmpty) {
      return const SizedBox.shrink();
    }

    // If there is only one markdown segment (the common case), render directly
    if (_segments.length == 1 && _segments[0].type == _SegmentType.markdown) {
      return SelectionArea(
        child: RepaintBoundary(child: _buildMarkdown(_segments[0].content)),
      );
    }

    Widget content;
    // For large content (>10 segments), use ListView.builder for better performance
    if (_segments.length > 10) {
      content = ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _segments.length,
        itemBuilder: (context, index) => _buildSegment(_segments[index]),
      );
    } else {
      // For smaller content, use Column for simplicity
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _segments.map(_buildSegment).toList(),
      );
    }

    return SelectionArea(child: content);
  }

  Widget _buildSegment(_Segment seg) {
    switch (seg.type) {
      case _SegmentType.mermaid:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: RepaintBoundary(
            child: FlowchartWidget(mermaidSource: seg.content),
          ),
        );
      case _SegmentType.markdown:
        return RepaintBoundary(child: _buildMarkdown(seg.content));
    }
  }

  /// Builds the appropriate markdown widget, with wiki-link support if enabled.
  Widget _buildMarkdown(String data) {
    if (widget.enableWikiLinks && wikiLinkPattern.hasMatch(data)) {
      return _WikiLinkMarkdown(data: data);
    }
    return _MarkdownWidget(data: data);
  }
}

class _MarkdownWidget extends StatelessWidget {
  final String data;

  const _MarkdownWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    // Pre-process \ce{...} chemical formulas into standard LaTeX
    final processed = _preprocessChemical(data);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: GptMarkdown(
          processed,
          style: TextStyle(
            fontSize: settings.fontSize,
            fontFamily: settings.fontFamily == 'System'
                ? null
                : settings.fontFamily,
            color: cs.onSurface,
            height: 1.6,
          ),
          onLinkTap: (url, title) {
            if (url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
      ),
    );
  }

  /// Convert \ce{...} chemical notation into standard LaTeX that GptMarkdown
  /// can render. Wraps the result in $...$ for inline rendering.
  static String _preprocessChemical(String text) {
    return text.replaceAllMapped(_cePattern, (m) {
      final converted = _convertChemical(m.group(1)!);
      return '\$\\text{} $converted\$';
    });
  }

  static String _convertChemical(String formula) {
    var result = formula;
    result = result.replaceAllMapped(
      _subscriptPattern,
      (m) => '${m.group(1)}_{${m.group(2)}}',
    );
    result = result.replaceAllMapped(_chargePattern, (m) => '^{${m.group(1)}}');
    // Replace <-> before -> to avoid partial match
    result = result.replaceAll('<->', '\\rightleftharpoons ');
    result = result.replaceAll('->', '\\rightarrow ');
    // Only replace standalone ^ (gas evolution symbol), not ^{ from charge notation
    result = result.replaceAllMapped(RegExp(r'\^(?!\{)'), (m) => '\\uparrow ');
    return result;
  }
}

/// Renders markdown with wiki-links [[note]] as clickable inline chips.
class _WikiLinkMarkdown extends StatelessWidget {
  final String data;
  const _WikiLinkMarkdown({required this.data});

  @override
  Widget build(BuildContext context) {
    final parts = <_WikiSpan>[];
    int lastEnd = 0;

    for (final match in wikiLinkPattern.allMatches(data)) {
      if (match.start > lastEnd) {
        parts.add(_WikiSpan(text: data.substring(lastEnd, match.start)));
      }
      final link = WikiLink.parse(match.group(1)!);
      parts.add(_WikiSpan(wikiLink: link));
      lastEnd = match.end;
    }
    if (lastEnd < data.length) {
      parts.add(_WikiSpan(text: data.substring(lastEnd)));
    }

    if (parts.every((p) => p.wikiLink == null)) {
      return _MarkdownWidget(data: data);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((p) {
        if (p.wikiLink != null) {
          return _WikiLinkChip(link: p.wikiLink!);
        }
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
    final provider = context.read<NotesProvider>();
    final targetNote = provider.findNoteByTitle(link.target);
    final exists = targetNote != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          if (exists) {
            provider.markViewed(targetNote.id);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoteDetailPage(noteId: targetNote.id),
              ),
            );
          } else {
            // Create the note and navigate
            final newNote = provider.createNote(title: link.target);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoteDetailPage(noteId: newNote.id),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: exists
                ? cs.primaryContainer.withAlpha(160)
                : cs.errorContainer.withAlpha(100),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: exists ? cs.primary.withAlpha(60) : cs.error.withAlpha(60),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                exists ? Icons.link_rounded : Icons.add_link_rounded,
                size: 12,
                color: exists ? cs.primary : cs.error,
              ),
              const SizedBox(width: 3),
              Text(
                link.displayText,
                style: TextStyle(
                  fontSize: 13,
                  color: exists ? cs.primary : cs.error,
                  fontWeight: FontWeight.w500,
                  decoration: exists ? null : TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dashed,
                ),
              ),
              if (link.heading != null) ...[
                Text(
                  ' › ${link.heading}',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ],
              if (link.blockId != null) ...[
                Text(
                  ' › ^${link.blockId}',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Parses content into segments: only mermaid blocks are extracted separately.
/// Everything else (including math) is passed as markdown to GptMarkdown.
List<_Segment> _parseContent(String text) {
  final segments = <_Segment>[];

  // Extract mermaid blocks — GptMarkdown can't render these
  int lastEnd = 0;
  for (final match in _mermaidBlockPattern.allMatches(text)) {
    // Add any text before this mermaid block as markdown
    if (match.start > lastEnd) {
      final before = text.substring(lastEnd, match.start).trim();
      if (before.isNotEmpty) {
        segments.add(_Segment(_SegmentType.markdown, before));
      }
    }
    // Add the mermaid content
    segments.add(_Segment(_SegmentType.mermaid, match.group(1)!.trim()));
    lastEnd = match.end;
  }

  // Add any remaining text after the last mermaid block
  if (lastEnd < text.length) {
    final remaining = text.substring(lastEnd).trim();
    if (remaining.isNotEmpty) {
      segments.add(_Segment(_SegmentType.markdown, remaining));
    }
  }

  // If no segments were created (no mermaid blocks), treat entire text as markdown
  if (segments.isEmpty) {
    segments.add(_Segment(_SegmentType.markdown, text));
  }

  return segments;
}

enum _SegmentType { markdown, mermaid }

class _Segment {
  final _SegmentType type;
  final String content;
  _Segment(this.type, this.content);
}
