import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/widgets/markdown/markdown_render_utils.dart';

void main() {
  group('parseRichContentSegments', () {
    test('handles CRLF mermaid blocks without trimming markdown segments', () {
      final segments = parseRichContentSegments(
        'Hello\r\n\r\n```mermaid\r\ngraph TD;\r\nA-->B\r\n```\r\n\r\nWorld',
      );

      expect(segments, hasLength(3));
      expect(segments[0].type, RichContentSegmentType.markdown);
      expect(segments[0].content, 'Hello\n\n');
      expect(segments[1].type, RichContentSegmentType.mermaid);
      expect(segments[1].content, 'graph TD;\nA-->B');
      expect(segments[2].type, RichContentSegmentType.markdown);
      expect(segments[2].content, '\n\nWorld');
    });
  });

  group('preprocessChemicalMarkdown', () {
    test('skips fenced and inline code spans', () {
      final processed = preprocessChemicalMarkdown(
        'Water: \\ce{H2O}\n\n`\\ce{Na+}`\n\n```text\n\\ce{CO2}\n```',
      );

      expect(processed, contains(r'Water: $ H_{2}O $'));
      expect(processed, contains(r'`\ce{Na+}`'));
      expect(processed, contains('\\ce{CO2}'));
      expect(processed, isNot(contains(r'$ Na^{+} $')));
      expect(processed, isNot(contains(r'$ CO_{2} $')));
    });
  });

  group('convertChemicalToLatex', () {
    test('converts implicit charges without breaking reaction operators', () {
      expect(convertChemicalToLatex('Na+'), r'Na^{+}');
      expect(convertChemicalToLatex('SO4^2-'), r'SO_{4}^{2-}');
      expect(
        convertChemicalToLatex('2H2 + O2 -> 2H2O'),
        r'2H_{2} + O_{2} \rightarrow 2H_{2}O',
      );
    });
  });
}
