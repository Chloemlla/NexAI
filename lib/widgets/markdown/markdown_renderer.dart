import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown_chloemlla/css/css.dart';
import 'package:gpt_markdown_chloemlla/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown_chloemlla/custom_widgets/selectable_adapter.dart';
import 'package:gpt_markdown_chloemlla/gpt_markdown_chloemlla.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/note.dart';
import '../../pages/note_detail_page.dart';
import '../../providers/notes_provider.dart';
import '../../providers/settings_provider.dart';
import 'markdown_render_utils.dart';

class MarkdownCssThemeCache {
  static final Map<Brightness, Future<CssTheme>> _cache = {};

  static Future<CssTheme> load(Brightness brightness) {
    return _cache.putIfAbsent(brightness, () async {
      final asset = brightness == Brightness.dark
          ? 'assets/github-markdown-dark.css'
          : 'assets/github-markdown.css';

      try {
        return await CssTheme.fromAsset(asset);
      } catch (_) {
        _cache.remove(brightness);
        rethrow;
      }
    });
  }
}

class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    super.key,
    required this.data,
    required this.cssTheme,
    this.enableWikiLinks = false,
  });

  final String data;
  final CssTheme? cssTheme;
  final bool enableWikiLinks;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final styles = MarkdownRendererStyles.resolve(context, settings, cssTheme);
    final processed = preprocessChemicalMarkdown(data);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: GptMarkdownTheme(
        gptThemeData: styles.toGptThemeData(Theme.of(context).brightness),
        child: GptMarkdown(
          processed,
          useDollarSignsForLatex: true,
          followLinkColor: true,
          style: styles.bodyStyle,
          components: buildMarkdownComponents(styles),
          inlineComponents: buildInlineComponents(
            styles,
            enableWikiLinks: enableWikiLinks,
          ),
          highlightBuilder: (context, text, style) {
            return InlineCodeChip(text: text, styles: styles);
          },
          codeBuilder: (context, language, code, closed) {
            return MarkdownCodeBlock(
              language: language,
              code: code,
              closed: closed,
              styles: styles,
            );
          },
          tableBuilder: (context, rows, textStyle, config) {
            return MarkdownTable(
              rows: rows,
              textStyle: textStyle,
              config: config,
              styles: styles,
            );
          },
          imageBuilder: (context, imageUrl) {
            return MarkdownImage(imageUrl: imageUrl, styles: styles);
          },
          latexBuilder: buildLatexWidget,
          onLinkTap: handleExternalLinkTap,
        ),
      ),
    );
  }
}

class MarkdownRendererStyles {
  const MarkdownRendererStyles({
    required this.bodyStyle,
    required this.h1Style,
    required this.h2Style,
    required this.h3Style,
    required this.h4Style,
    required this.h5Style,
    required this.h6Style,
    required this.codeTextStyle,
    required this.blockquoteTextStyle,
    required this.textColor,
    required this.mutedTextColor,
    required this.linkColor,
    required this.borderColor,
    required this.dividerColor,
    required this.codeBackgroundColor,
    required this.codeHeaderBackgroundColor,
    required this.inlineCodeBackgroundColor,
    required this.inlineCodeForegroundColor,
    required this.blockquoteBackgroundColor,
    required this.blockquoteBorderColor,
    required this.tableHeaderBackgroundColor,
    required this.tableStripeColor,
    required this.imageBackgroundColor,
    required this.imageBorderColor,
  });

  final TextStyle bodyStyle;
  final TextStyle h1Style;
  final TextStyle h2Style;
  final TextStyle h3Style;
  final TextStyle h4Style;
  final TextStyle h5Style;
  final TextStyle h6Style;
  final TextStyle codeTextStyle;
  final TextStyle blockquoteTextStyle;
  final Color textColor;
  final Color mutedTextColor;
  final Color linkColor;
  final Color borderColor;
  final Color dividerColor;
  final Color codeBackgroundColor;
  final Color codeHeaderBackgroundColor;
  final Color inlineCodeBackgroundColor;
  final Color inlineCodeForegroundColor;
  final Color blockquoteBackgroundColor;
  final Color blockquoteBorderColor;
  final Color tableHeaderBackgroundColor;
  final Color tableStripeColor;
  final Color imageBackgroundColor;
  final Color imageBorderColor;

  factory MarkdownRendererStyles.resolve(
    BuildContext context,
    SettingsProvider settings,
    CssTheme? cssTheme,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final baseTextColor = resolveCssColor(
      cssTheme,
      '--fgColor-default',
      theme.brightness == Brightness.dark
          ? const Color(0xFFf0f6fc)
          : const Color(0xFF1f2328),
    );

    final baseBodyStyle = TextStyle(
      fontSize: settings.fontSize,
      fontFamily: settings.fontFamily,
      color: baseTextColor,
      height: 1.65,
      letterSpacing: 0.1,
    );

    final themedBodyStyle =
        resolveCssTextStyle(cssTheme, '.markdown-body', baseBodyStyle).copyWith(
          fontSize: settings.fontSize,
          fontFamily: settings.fontFamily,
          color: baseTextColor,
          height: 1.65,
          letterSpacing: 0.1,
        );

    final mutedTextColor = resolveCssColor(
      cssTheme,
      '--fgColor-muted',
      cs.onSurfaceVariant,
    );
    final linkColor = resolveCssColor(cssTheme, '--fgColor-accent', cs.primary);
    final borderColor = resolveCssColor(
      cssTheme,
      '--borderColor-default',
      cs.outlineVariant,
    );
    final dividerColor = resolveCssColor(
      cssTheme,
      '--borderColor-muted',
      cs.outlineVariant.withAlpha(150),
    );
    final codeBackgroundColor = resolveCssColor(
      cssTheme,
      '--bgColor-muted',
      cs.surfaceContainerHighest,
    );
    final inlineCodeBackgroundColor = resolveCssColor(
      cssTheme,
      '--bgColor-neutral-muted',
      codeBackgroundColor.withAlpha(210),
    );

    final codeTextStyle = resolveCssTextStyle(
      cssTheme,
      '.markdown-body code',
      themedBodyStyle.copyWith(
        fontFamily: 'monospace',
        fontSize: (themedBodyStyle.fontSize ?? settings.fontSize) * 0.92,
        height: 1.55,
      ),
    );

    final blockquoteTextStyle = resolveCssTextStyle(
      cssTheme,
      '.markdown-body blockquote',
      themedBodyStyle.copyWith(
        color: mutedTextColor,
        fontStyle: FontStyle.italic,
      ),
    );

    final bodyFontSize = themedBodyStyle.fontSize ?? settings.fontSize;

    return MarkdownRendererStyles(
      bodyStyle: themedBodyStyle,
      h1Style: resolveCssTextStyle(
        cssTheme,
        '.markdown-body h1',
        themedBodyStyle.copyWith(
          fontSize: bodyFontSize * 2.0,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
      h2Style: resolveCssTextStyle(
        cssTheme,
        '.markdown-body h2',
        themedBodyStyle.copyWith(
          fontSize: bodyFontSize * 1.6,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
      h3Style: resolveCssTextStyle(
        cssTheme,
        '.markdown-body h3',
        themedBodyStyle.copyWith(
          fontSize: bodyFontSize * 1.35,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
      h4Style: resolveCssTextStyle(
        cssTheme,
        '.markdown-body h4',
        themedBodyStyle.copyWith(
          fontSize: bodyFontSize * 1.15,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      ),
      h5Style: resolveCssTextStyle(
        cssTheme,
        '.markdown-body h5',
        themedBodyStyle.copyWith(
          fontSize: bodyFontSize,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
      h6Style: resolveCssTextStyle(
        cssTheme,
        '.markdown-body h6',
        themedBodyStyle.copyWith(
          fontSize: bodyFontSize * 0.92,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: mutedTextColor,
        ),
      ),
      codeTextStyle: codeTextStyle,
      blockquoteTextStyle: blockquoteTextStyle,
      textColor: baseTextColor,
      mutedTextColor: mutedTextColor,
      linkColor: linkColor,
      borderColor: borderColor,
      dividerColor: dividerColor,
      codeBackgroundColor: codeBackgroundColor,
      codeHeaderBackgroundColor: theme.brightness == Brightness.dark
          ? codeBackgroundColor.withAlpha(220)
          : cs.surfaceContainerLow,
      inlineCodeBackgroundColor: inlineCodeBackgroundColor,
      inlineCodeForegroundColor: codeTextStyle.color ?? baseTextColor,
      blockquoteBackgroundColor: theme.brightness == Brightness.dark
          ? cs.surfaceContainerLow.withAlpha(140)
          : cs.surfaceContainerLowest.withAlpha(220),
      blockquoteBorderColor: dividerColor,
      tableHeaderBackgroundColor: codeBackgroundColor,
      tableStripeColor: theme.brightness == Brightness.dark
          ? cs.surfaceContainerLowest.withAlpha(70)
          : cs.surfaceContainerLowest.withAlpha(110),
      imageBackgroundColor: theme.brightness == Brightness.dark
          ? cs.surfaceContainerLow
          : cs.surfaceContainerLowest,
      imageBorderColor: borderColor.withAlpha(180),
    );
  }

  GptMarkdownThemeData toGptThemeData(Brightness brightness) {
    return GptMarkdownThemeData(
      brightness: brightness,
      h1: h1Style,
      h2: h2Style,
      h3: h3Style,
      h4: h4Style,
      h5: h5Style,
      h6: h6Style,
      hrLineThickness: 1,
      hrLineColor: dividerColor,
      linkColor: linkColor,
      linkHoverColor: linkColor.withAlpha(220),
      highlightColor: inlineCodeBackgroundColor,
    );
  }
}

TextStyle resolveCssTextStyle(
  CssTheme? cssTheme,
  String selector,
  TextStyle fallback,
) {
  return cssTheme?.getTextStyle(selector, baseStyle: fallback) ?? fallback;
}

Color resolveCssColor(CssTheme? cssTheme, String variable, Color fallback) {
  return cssTheme?.getColor(variable) ?? fallback;
}

List<MarkdownComponent> buildMarkdownComponents(MarkdownRendererStyles styles) {
  return [
    CodeBlockMd(),
    LatexMathMultiLine(),
    NewLines(),
    StyledBlockQuoteMd(styles),
    TableMd(),
    HTag(),
    TaskListMd(styles),
    UnOrderedList(),
    OrderedList(),
    RadioButtonMd(),
    CheckBoxMd(),
    StyledHrMd(styles),
    IndentMd(),
  ];
}

List<MarkdownComponent> buildInlineComponents(
  MarkdownRendererStyles styles, {
  required bool enableWikiLinks,
}) {
  return [
    if (enableWikiLinks) WikiLinkMd(styles),
    ATagMd(),
    ImageMd(),
    TableMd(),
    StrikeMd(),
    BoldMd(),
    ItalicMd(),
    UnderLineMd(),
    LatexMath(),
    LatexMathMultiLine(),
    HighlightedText(),
    SourceTag(),
  ];
}

class StyledBlockQuoteMd extends InlineMd {
  StyledBlockQuoteMd(this.styles);

  final MarkdownRendererStyles styles;

  @override
  RegExp get exp => RegExp(
    r'(?:(?:^)\ *>[^\n]+)(?:(?:\n)\ *>[^\n]+)*',
    dotAll: true,
    multiLine: true,
  );

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    final buffer = StringBuffer();
    final content = match?.group(0) ?? text;

    for (final line in content.split('\n')) {
      var normalized = line.trimLeft();
      if (normalized.startsWith('>')) {
        normalized = normalized.substring(1);
        if (normalized.startsWith(' ')) {
          normalized = normalized.substring(1);
        }
      }
      buffer.writeln(normalized);
    }

    return TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: styles.blockquoteBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: styles.blockquoteBorderColor,
                    width: 4,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: MdWidget(
                context,
                buffer.toString().trim(),
                true,
                config: config.copyWith(style: styles.blockquoteTextStyle),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TaskListMd extends BlockMd {
  TaskListMd(this.styles);

  final MarkdownRendererStyles styles;

  @override
  String get expString => r'(?:\-|\*)\ \[([ xX])\]\ ([^\n]+)$';

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text.trim());
    final checked = ((match?.group(1) ?? '').toLowerCase() == 'x');
    final content = match?.group(2)?.trim() ?? '';

    return Directionality(
      textDirection: config.textDirection,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: checked ? styles.linkColor : styles.mutedTextColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MdWidget(
              context,
              content,
              true,
              config: config.copyWith(style: config.style ?? styles.bodyStyle),
            ),
          ),
        ],
      ),
    );
  }
}

class StyledHrMd extends BlockMd {
  StyledHrMd(this.styles);

  final MarkdownRendererStyles styles;

  @override
  String get expString => r'(?:-{3,}|\*{3,}|_{3,})$';

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, thickness: 1, color: styles.dividerColor),
    );
  }
}

class WikiLinkMd extends InlineMd {
  WikiLinkMd(this.styles);

  final MarkdownRendererStyles styles;

  @override
  RegExp get exp => wikiLinkPattern;

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final raw = exp.firstMatch(text.trim())?.group(1);
    if (raw == null || raw.isEmpty) {
      return TextSpan(text: text, style: config.style);
    }

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: InlineWikiLink(link: WikiLink.parse(raw), styles: styles),
    );
  }
}

class InlineWikiLink extends StatelessWidget {
  const InlineWikiLink({super.key, required this.link, required this.styles});

  final WikiLink link;
  final MarkdownRendererStyles styles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final targetNote = context.select<NotesProvider, Note?>(
      (provider) => provider.findNoteByTitle(link.target),
    );
    final exists = targetNote != null;
    final foreground = exists ? styles.linkColor : cs.error;
    final background = exists
        ? cs.primaryContainer.withAlpha(96)
        : cs.errorContainer.withAlpha(88);
    final border = foreground.withAlpha(96);

    return Tooltip(
      message: exists
          ? 'Open note: ${link.target}'
          : 'Create new note: ${link.target}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => openWikiLink(context, link, targetNote),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    exists ? Icons.link_rounded : Icons.add_link_rounded,
                    size: 12,
                    color: foreground,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      link.displayText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.bodyStyle.copyWith(
                        fontSize: (styles.bodyStyle.fontSize ?? 14) * 0.9,
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (link.heading != null) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '› ${link.heading}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.bodyStyle.copyWith(
                          fontSize: (styles.bodyStyle.fontSize ?? 14) * 0.78,
                          color: styles.mutedTextColor,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InlineCodeChip extends StatelessWidget {
  const InlineCodeChip({super.key, required this.text, required this.styles});

  final String text;
  final MarkdownRendererStyles styles;

  @override
  Widget build(BuildContext context) {
    return SelectableAdapter(
      selectedText: text,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: styles.inlineCodeBackgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: styles.codeTextStyle.copyWith(
            color: styles.inlineCodeForegroundColor,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class MarkdownCodeBlock extends StatefulWidget {
  const MarkdownCodeBlock({
    super.key,
    required this.language,
    required this.code,
    required this.closed,
    required this.styles,
  });

  final String language;
  final String code;
  final bool closed;
  final MarkdownRendererStyles styles;

  @override
  State<MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

class _MarkdownCodeBlockState extends State<MarkdownCodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;

    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.language.trim().isEmpty
        ? 'plain text'
        : widget.language.trim().toLowerCase();
    final content = widget.closed ? widget.code : '${widget.code}\n```';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: widget.styles.codeBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.styles.borderColor.withAlpha(180),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: widget.styles.codeHeaderBackgroundColor,
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: widget.styles.codeTextStyle.copyWith(
                      color: widget.styles.mutedTextColor,
                      fontSize:
                          (widget.styles.codeTextStyle.fontSize ?? 13) * 0.94,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _copy,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 16,
                  ),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.styles.mutedTextColor,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: SelectableText(content, style: widget.styles.codeTextStyle),
          ),
        ],
      ),
    );
  }
}

class MarkdownTable extends StatelessWidget {
  const MarkdownTable({
    super.key,
    required this.rows,
    required this.textStyle,
    required this.config,
    required this.styles,
  });

  final List<CustomTableRow> rows;
  final TextStyle textStyle;
  final GptMarkdownConfig config;
  final MarkdownRendererStyles styles;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final columnCount = rows.fold<int>(
      0,
      (maxColumns, row) =>
          row.fields.length > maxColumns ? row.fields.length : maxColumns,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: styles.borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: {
            for (var index = 0; index < columnCount; index++)
              index: const IntrinsicColumnWidth(),
          },
          border: TableBorder.symmetric(
            inside: BorderSide(
              color: styles.borderColor.withAlpha(120),
              width: 1,
            ),
          ),
          children: List.generate(rows.length, (rowIndex) {
            final row = rows[rowIndex];
            final decoration = row.isHeader
                ? BoxDecoration(color: styles.tableHeaderBackgroundColor)
                : rowIndex.isOdd
                ? BoxDecoration(color: styles.tableStripeColor)
                : const BoxDecoration();

            return TableRow(
              decoration: decoration,
              children: List.generate(columnCount, (columnIndex) {
                final field = columnIndex < row.fields.length
                    ? row.fields[columnIndex]
                    : CustomTableField(data: '');

                final cellStyle = row.isHeader
                    ? textStyle.copyWith(fontWeight: FontWeight.w700)
                    : textStyle;

                final content = field.data.trim().isEmpty
                    ? const SizedBox.shrink()
                    : MdWidget(
                        context,
                        field.data.trim(),
                        true,
                        config: config.copyWith(style: cellStyle),
                      );

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: AlignedCell(
                    alignment: field.alignment,
                    child: content,
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }
}

class AlignedCell extends StatelessWidget {
  const AlignedCell({super.key, required this.alignment, required this.child});

  final TextAlign alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (alignment) {
      TextAlign.center => Center(child: child),
      TextAlign.right => Align(alignment: Alignment.centerRight, child: child),
      _ => Align(alignment: Alignment.centerLeft, child: child),
    };
  }
}

class MarkdownImage extends StatelessWidget {
  const MarkdownImage({
    super.key,
    required this.imageUrl,
    required this.styles,
  });

  final String imageUrl;
  final MarkdownRendererStyles styles;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: BoxDecoration(
        color: styles.imageBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: styles.imageBorderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          final expected = loadingProgress.expectedTotalBytes;
          final progress = expected == null
              ? null
              : loadingProgress.cumulativeBytesLoaded / expected;

          return SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(value: progress)),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            height: 220,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 28,
                    color: styles.mutedTextColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Image unavailable',
                    style: styles.bodyStyle.copyWith(
                      color: styles.mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget buildLatexWidget(
  BuildContext context,
  String tex,
  TextStyle textStyle,
  bool inline,
) {
  final mathStyle = inline ? MathStyle.text : MathStyle.display;
  final fontOptions = FontOptions(
    fontFamily: 'Main',
    fontWeight: textStyle.fontWeight ?? FontWeight.normal,
    fontShape: textStyle.fontStyle ?? FontStyle.normal,
  );

  return SelectableAdapter(
    selectedText: tex,
    child: Math.tex(
      tex,
      textStyle: textStyle,
      mathStyle: mathStyle,
      textScaleFactor: 1,
      settings: const TexParserSettings(strict: Strict.ignore),
      options: MathOptions(
        sizeUnderTextStyle: inline ? MathSize.normalsize : MathSize.large,
        color: textStyle.color ?? Theme.of(context).colorScheme.onSurface,
        fontSize:
            textStyle.fontSize ??
            Theme.of(context).textTheme.bodyMedium?.fontSize,
        mathFontOptions: fontOptions,
        textFontOptions: fontOptions,
        style: mathStyle,
      ),
      onErrorFallback: (error) {
        return Text(
          tex,
          textDirection: Directionality.of(context),
          style: textStyle.copyWith(color: Theme.of(context).colorScheme.error),
        );
      },
    ),
  );
}

Future<void> handleExternalLinkTap(String url, String title) async {
  if (url.isEmpty) return;

  final uri = Uri.tryParse(url);
  if (uri == null) return;

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (error) {
    debugPrint('Failed to launch link "$url": $error');
  }
}

Future<void> openWikiLink(
  BuildContext context,
  WikiLink link,
  Note? targetNote,
) async {
  final provider = context.read<NotesProvider>();
  late final Note destination;

  if (targetNote != null) {
    await provider.markViewed(targetNote.id);
    destination = targetNote;
  } else {
    destination = await provider.createNote(title: link.target);
  }

  if (!context.mounted) return;

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => NoteDetailPage(noteId: destination.id)),
  );
}
