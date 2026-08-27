import 'package:flutter/material.dart';
import 'package:gpt_markdown_chloemlla/css/css.dart';

import 'flowchart/flowchart_widget.dart';
import 'markdown/markdown_render_utils.dart';
import 'markdown/markdown_renderer.dart';

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
  late List<RichContentSegment> _segments;
  Future<CssTheme>? _cssThemeFuture;
  Brightness? _themeBrightness;

  /// Last rendered subtree, reused verbatim while the inputs are unchanged.
  Widget? _cachedBody;
  CssTheme? _cachedBodyCssTheme;

  @override
  void initState() {
    super.initState();
    _segments = parseRichContentSegments(widget.content);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCssThemeFuture();
  }

  @override
  void didUpdateWidget(RichContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _segments = parseRichContentSegments(widget.content);
      _cachedBody = null;
    }
    if (oldWidget.enableWikiLinks != widget.enableWikiLinks) {
      _cachedBody = null;
    }
  }

  void _syncCssThemeFuture() {
    final brightness = Theme.of(context).brightness;
    if (_cssThemeFuture != null && _themeBrightness == brightness) {
      return;
    }

    _themeBrightness = brightness;
    _cssThemeFuture = MarkdownCssThemeCache.load(brightness);
  }

  @override
  Widget build(BuildContext context) {
    if (_segments.isEmpty) return const SizedBox.shrink();

    final cssThemeFuture = _cssThemeFuture;
    if (cssThemeFuture == null) return const SizedBox.shrink();

    return FutureBuilder<CssTheme>(
      future: cssThemeFuture,
      builder: (context, snapshot) {
        final cssTheme = snapshot.data;
        // Handing Flutter back the identical widget instance lets it skip the
        // whole markdown/LaTeX subtree, so a streaming rebuild of the message
        // list no longer re-parses and re-lays-out unchanged content.
        final cached = _cachedBody;
        if (cached != null && identical(_cachedBodyCssTheme, cssTheme)) {
          return cached;
        }

        final body = SelectionArea(
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: _segments
                  .map((segment) => _buildSegment(segment, cssTheme))
                  .toList(),
            ),
          ),
        );
        _cachedBody = body;
        _cachedBodyCssTheme = cssTheme;
        return body;
      },
    );
  }

  Widget _buildSegment(RichContentSegment segment, CssTheme? cssTheme) {
    switch (segment.type) {
      case RichContentSegmentType.mermaid:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: RepaintBoundary(
            child: FlowchartWidget(mermaidSource: segment.content),
          ),
        );
      case RichContentSegmentType.markdown:
        return MarkdownRenderer(
          data: segment.content,
          cssTheme: cssTheme,
          enableWikiLinks: widget.enableWikiLinks,
        );
    }
  }
}
