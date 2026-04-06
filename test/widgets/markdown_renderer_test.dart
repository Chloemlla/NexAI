import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown_chloemlla/css/css.dart';
import 'package:nexai/providers/settings_provider.dart';
import 'package:nexai/widgets/markdown/markdown_renderer.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('body markdown style does not inherit underline from links', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final cssTheme = CssTheme.fromString('''
.markdown-body {
  color: #111111;
  font-size: 16px;
}

.markdown-body a {
  color: #0969da;
  text-decoration: underline;
}
''');

    late MarkdownRendererStyles styles;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              styles = MarkdownRendererStyles.resolve(
                context,
                settings,
                cssTheme,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(styles.bodyStyle.decoration, TextDecoration.none);
    expect(styles.linkTextStyle.decoration, TextDecoration.underline);
  });
}
