import 'package:flutter/foundation.dart';

final _cePattern = RegExp(r'\$\s*\\ce\{([^{}]+)\}\s*\$|\\ce\{([^{}]+)\}');
final _subscriptPattern = RegExp(r'([A-Za-z)])(\d+)');
final _underscoreSubscriptPattern = RegExp(r'_([^{\s}]+)');
final _chargePattern = RegExp(r'(?<=[A-Za-z\d\)\}])\^?(\d*[+\-])(?!\})');
final _protectedMarkdownPattern = RegExp(r'```[\s\S]*?```|`[^`\n]*`');
final _mermaidBlockPattern = RegExp(
  r'```mermaid[ \t]*\n([\s\S]*?)```',
  multiLine: true,
  caseSensitive: false,
);

enum RichContentSegmentType { markdown, mermaid }

@immutable
class RichContentSegment {
  const RichContentSegment({required this.type, required this.content});

  final RichContentSegmentType type;
  final String content;
}

String normalizeMarkdownLineEndings(String text) {
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

List<RichContentSegment> parseRichContentSegments(String text) {
  final normalized = normalizeMarkdownLineEndings(text);
  final segments = <RichContentSegment>[];
  var lastEnd = 0;

  for (final match in _mermaidBlockPattern.allMatches(normalized)) {
    if (match.start > lastEnd) {
      final before = normalized.substring(lastEnd, match.start);
      if (before.trim().isNotEmpty) {
        segments.add(
          RichContentSegment(
            type: RichContentSegmentType.markdown,
            content: before,
          ),
        );
      }
    }

    final mermaidContent = (match.group(1) ?? '').trim();
    if (mermaidContent.isNotEmpty) {
      segments.add(
        RichContentSegment(
          type: RichContentSegmentType.mermaid,
          content: mermaidContent,
        ),
      );
    }
    lastEnd = match.end;
  }

  if (lastEnd < normalized.length) {
    final remaining = normalized.substring(lastEnd);
    if (remaining.trim().isNotEmpty) {
      segments.add(
        RichContentSegment(
          type: RichContentSegmentType.markdown,
          content: remaining,
        ),
      );
    }
  }

  if (segments.isEmpty && normalized.trim().isNotEmpty) {
    segments.add(
      RichContentSegment(
        type: RichContentSegmentType.markdown,
        content: normalized,
      ),
    );
  }

  return segments;
}

String preprocessChemicalMarkdown(String text) {
  final normalized = normalizeMarkdownLineEndings(text);
  return _transformOutsideMarkdownCode(normalized, _replaceChemicalSegments);
}

String convertChemicalToLatex(String formula) {
  var result = formula;
  result = result.replaceAllMapped(
    RegExp(r'\s*<->\s*'),
    (_) => r' \rightleftharpoons ',
  );
  result = result.replaceAllMapped(
    RegExp(r'\s*->\s*'),
    (_) => r' \rightarrow ',
  );
  result = result.replaceAllMapped(
    _underscoreSubscriptPattern,
    (match) => '_{${match.group(1)}}',
  );
  result = result.replaceAllMapped(
    _subscriptPattern,
    (match) => '${match.group(1)}_{${match.group(2)}}',
  );
  result = result.replaceAllMapped(
    _chargePattern,
    (match) => '^{${match.group(1)}}',
  );
  return result;
}

String _transformOutsideMarkdownCode(
  String text,
  String Function(String value) transform,
) {
  final buffer = StringBuffer();
  var lastEnd = 0;

  for (final match in _protectedMarkdownPattern.allMatches(text)) {
    if (match.start > lastEnd) {
      buffer.write(transform(text.substring(lastEnd, match.start)));
    }
    buffer.write(match.group(0));
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    buffer.write(transform(text.substring(lastEnd)));
  }

  return buffer.toString();
}

String _replaceChemicalSegments(String text) {
  return text.replaceAllMapped(_cePattern, (match) {
    final inner = match.group(1) ?? match.group(2) ?? '';
    final converted = convertChemicalToLatex(inner);
    return '\$ $converted \$';
  });
}
