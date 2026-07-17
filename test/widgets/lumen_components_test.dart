import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/theme/lumen_theme.dart';
import 'package:nexai/theme/lumen_tokens.dart';
import 'package:nexai/widgets/lumen/lumen.dart';

void main() {
  testWidgets('Lumen design kit renders core soft-surface contracts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LumenTheme.build(colorScheme: LumenTheme.lightColorScheme()),
        home: Scaffold(
          body: LumenPage(
            scrollable: false,
            children: [
              const LumenSectionHeader(
                icon: Icons.settings_rounded,
                title: '设置分区',
                subtitle: '软表面标题',
              ),
              const LumenActionCard(child: Text('action-card')),
              const LumenStatusLine(
                icon: Icons.check_circle_rounded,
                title: '状态正常',
                detail: 'detail',
              ),
              const LumenEmptyState(
                icon: Icons.inbox_rounded,
                title: '空状态',
                message: '没有内容',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('设置分区'), findsOneWidget);
    expect(find.text('action-card'), findsOneWidget);
    expect(find.text('状态正常'), findsOneWidget);
    expect(find.text('空状态'), findsOneWidget);
    expect(LumenTokens.cardRadius, 20);
    expect(lumenScaffoldBackground(LumenTheme.lightColorScheme()), LumenTokens.background);
  });

  test('LumenActionCard accepts optional border contract', () {
    final card = LumenActionCard(
      borderSide: const BorderSide(color: Colors.red, width: 1),
      child: const Text('bordered'),
    );
    expect(card.borderSide?.color, Colors.red);
    expect(card.borderSide?.width, 1);
  });

  test('chat-like page padding follows Lumen shell helper', () {
    expect(LumenTokens.horizontalPaddingForWidth(390), 12);
    expect(LumenTokens.horizontalPaddingForWidth(640), 16);
    expect(LumenTokens.horizontalPaddingForWidth(900), 24);
  });
}
