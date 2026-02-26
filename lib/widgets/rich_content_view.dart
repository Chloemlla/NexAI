import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show isAndroid;
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../pages/note_detail_page.dart';
import 'flowchart/flowchart_widget.dart';

// Pre-compiled regex — avoids recompilation per build
final _mathPattern = RegExp(r'(\$\$[\s\S]*?\$\$|\$[^\$\n]+?\$|\\ce\{[^}]+\})');
final _cePattern = RegExp(r'\\ce\{([^}]+)\}');
final _subscriptPattern = RegExp(r'([A-Za-z)])(\d+)');
final _chargePattern = RegExp(r'(\d*[+-])(?!\})');
final _mermaidBlockPattern = RegExp(r'```mermaid\s*\n([\s\S]*?)```', multiLine: true);

/// Renders message content with Markdown, LaTeX/chemical formulas, and Mermaid flowcharts.
/// Links are clickable and open in the system browser.
/// Wiki-links [[note]] are rendered as clickable internal links.
/// 
/// Performance optimizations:
/// - Uses ListView.builder for large content to enable lazy loading
/// - Wraps complex widgets in RepaintBoundary to reduce repaints
/// - Caches parsed segments to avoid re-parsing on rebuilds
class RichContentView extends StatefulWidget {
  final String content;
  final bool enableWikiLinks;

  const RichContentView({super.key, required this.content, this.enableWikiLinks = false});

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
    if (oldWidget.content != widget.content && _cachedContent != widget.content) {
      _cachedContent = widget.content;
      _segments = _parseContent(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_segments.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // For large content (>10 segments), use ListView.builder for better performance
    if (_segments.length > 10) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _segments.length,
        itemBuilder: (context, index) => _buildSegment(_segments[index]),
      );
    }
    
    // For smaller content, use Column for simplicity
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _segments.map(_buildSegment).toList(),
    );
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
      case _SegmentType.math:
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _MathWidget(tex: seg.content, display: seg.isDisplay),
          ),
        );
      case _SegmentType.markdown:
        if (widget.enableWikiLinks && wikiLinkPattern.hasMatch(seg.content)) {
          return RepaintBoundary(
            child: _WikiLinkMarkdown(data: seg.content),
          );
        }
        return RepaintBoundary(
          child: _MarkdownWidget(data: seg.content),
        );
    }
  }
}

class _MathWidget extends StatelessWidget {
  final String tex;
  final bool display;

  const _MathWidget({required this.tex, this.display = false});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color accentColor;

    if (isAndroid) {
      final cs = Theme.of(context).colorScheme;
      textColor = cs.onSurface;
      accentColor = cs.primary;
    } else {
      final theme = fluent.FluentTheme.of(context);
      textColor = theme.typography.body?.color ?? Colors.white;
      accentColor = theme.accentColor;
    }

    var processed = tex.trim();
    processed = processed.replaceAllMapped(
      _cePattern,
      (m) => _convertChemical(m.group(1)!),
    );

    return Container(
      width: display ? double.infinity : null,
      padding: display ? const EdgeInsets.symmetric(vertical: 8) : null,
      alignment: display ? Alignment.center : null,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          processed,
          textStyle: TextStyle(
            fontSize: display ? 18 : 14,
            color: textColor,
          ),
          onErrorFallback: (err) {
            return SelectableText(
              tex,
              style: TextStyle(fontSize: 13, fontFamily: 'Consolas', color: accentColor),
            );
          },
        ),
      ),
    );
  }

  static String _convertChemical(String formula) {
    var result = formula;
    result = result.replaceAllMapped(_subscriptPattern, (m) => '${m.group(1)}_{${m.group(2)}}');
    result = result.replaceAllMapped(_chargePattern, (m) => '^{${m.group(1)}}');
    // Replace <-> before -> to avoid partial match
    result = result.replaceAll('<->', '\\rightleftharpoons ');
    result = result.replaceAll('->', '\\rightarrow ');
    // Only replace standalone ^ (gas evolution symbol), not ^{ from charge notation
    result = result.replaceAllMapped(RegExp(r'\^(?!\{)'), (m) => '\\uparrow ');
    return '\\text{} $result';
  }
}

class _MarkdownWidget extends StatelessWidget {
  final String data;

  const _MarkdownWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildM3Markdown(context);
    return _buildFluentMarkdown(context);
  }

  Widget _buildM3Markdown(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: MarkdownBody(
          data: data,
          selectable: true,
          shrinkWrap: true,
          // Disable image loading for better performance
          imageBuilder: (uri, title, alt) {
            return RepaintBoundary(
              child: Image.network(
                uri.toString(),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, color: cs.error, size: 16),
                        const SizedBox(width: 8),
                        Text(alt ?? '图片加载失败', style: TextStyle(color: cs.error, fontSize: 12)),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              ),
            );
          },
          extensionSet: md.ExtensionSet.gitHubFlavored,
          onTapLink: (text, href, title) {
            if (href != null && href.isNotEmpty) {
              final uri = Uri.tryParse(href);
              if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.6),
            a: TextStyle(fontSize: 14, color: cs.primary, decoration: TextDecoration.underline, decorationColor: cs.primary),
            code: TextStyle(
              fontSize: 13, fontFamily: 'Consolas',
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
              color: cs.primary,
            ),
            codeblockDecoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE0E0E0)),
            ),
            codeblockPadding: const EdgeInsets.all(12),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: cs.primary, width: 3)),
              color: cs.primary.withAlpha((0.05 * 255).round()),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            h1: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface),
            h2: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: cs.onSurface),
            h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
            listBullet: TextStyle(fontSize: 14, color: cs.onSurface),
            tableHead: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
            tableBorder: TableBorder.all(color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE0E0E0)),
          ),
        ),
      ),
    );
  }

  Widget _buildFluentMarkdown(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: MarkdownBody(
          data: data,
          selectable: true,
          shrinkWrap: true,
          extensionSet: md.ExtensionSet.gitHubFlavored,
          onTapLink: (text, href, title) {
            if (href != null && href.isNotEmpty) {
              final uri = Uri.tryParse(href);
              if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 14, color: theme.typography.body?.color, height: 1.6),
            a: TextStyle(fontSize: 14, color: theme.accentColor, decoration: TextDecoration.underline, decorationColor: theme.accentColor),
            code: TextStyle(
              fontSize: 13, fontFamily: 'Consolas',
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
              color: Color.fromRGBO(theme.accentColor.value >> 16 & 0xFF, theme.accentColor.value >> 8 & 0xFF, theme.accentColor.value & 0xFF, 0.05),
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
      ),
    );
  }
}

/// Renders markdown with wiki-links [[note]] as clickable inline chips.
class _WikiLinkMarkdown extends StatelessWidget {
  final String data;
  const _WikiLinkMarkdown({required this.data});

  @override
  Widget build(BuildContext context) {
    // Split text by wiki-link pattern and build mixed inline content
    final parts = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in wikiLinkPattern.allMatches(data)) {
      if (match.start > lastEnd) {
        parts.add(InlineSpan(text: data.substring(lastEnd, match.start)));
      }
      final link = WikiLink.parse(match.group(1)!);
      parts.add(InlineSpan(wikiLink: link));
      lastEnd = match.end;
    }
    if (lastEnd < data.length) {
      parts.add(InlineSpan(text: data.substring(lastEnd)));
    }

    // If no wiki-links found, fall back to regular markdown
    if (parts.every((p) => p.wikiLink == null)) {
      return _MarkdownWidget(data: data);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((p) {
        if (p.wikiLink != null) {
          return _WikiLinkChip(link: p.wikiLink!);
        }
        // Render text parts as markdown
        return _MarkdownWidget(data: p.text!);
      }).toList(),
    );
  }
}

class InlineSpan {
  final String? text;
  final WikiLink? wikiLink;
  InlineSpan({this.text, this.wikiLink});
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
              MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: targetNote.id)),
            );
          } else {
            // Create the note and navigate
            final newNote = provider.createNote(title: link.target);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: newNote.id)),
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
                Text(' › ${link.heading}',
                    style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
              if (link.blockId != null) ...[
                Text(' › ^${link.blockId}',
                    style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ],
          ),
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
