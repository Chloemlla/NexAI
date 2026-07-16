import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/theme/lumen_theme.dart';
import 'package:nexai/theme/lumen_tokens.dart';

void main() {
  group('LumenTheme', () {
    test('light scheme uses Lumen soft-surface palette', () {
      final scheme = LumenTheme.lightColorScheme();

      expect(scheme.primary, LumenTokens.teal);
      expect(scheme.secondary, LumenTokens.coral);
      expect(scheme.tertiary, LumenTokens.indigo);
      expect(scheme.surface, LumenTokens.surface);
      expect(scheme.surfaceContainerLow, LumenTokens.surfaceContainerLow);
      expect(scheme.outlineVariant, LumenTokens.outlineVariant);
    });

    test('dark scheme uses Lumen dark soft-surface palette', () {
      final scheme = LumenTheme.darkColorScheme();

      expect(scheme.primary, LumenTokens.tealDark);
      expect(scheme.surface, LumenTokens.surfaceDark);
      expect(scheme.surfaceContainer, LumenTokens.surfaceContainerDark);
      expect(scheme.outline, LumenTokens.outlineDark);
    });

    test('accent override only replaces primary seed', () {
      const accent = Color(0xFF3366FF);
      final scheme = LumenTheme.lightColorScheme(accentOverride: accent);

      expect(scheme.primary, accent);
      expect(scheme.secondary, LumenTokens.coral);
      expect(scheme.tertiary, LumenTokens.indigo);
    });

    test('theme builder applies Lumen card and navigation geometry', () {
      final theme = LumenTheme.build(
        colorScheme: LumenTheme.lightColorScheme(),
      );

      expect(theme.cardTheme.elevation, 0);
      expect(
        theme.scaffoldBackgroundColor,
        LumenTokens.background,
      );
      expect(theme.navigationBarTheme.height, LumenTokens.navigationBarHeight);
      expect(theme.appBarTheme.toolbarHeight, LumenTokens.topBarHeight);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);

      final shape = theme.cardTheme.shape as RoundedRectangleBorder?;
      expect(shape?.borderRadius, LumenTokens.cardBorderRadius);
    });

    test('page token helpers match Lumen layout json defaults', () {
      expect(LumenTokens.maxContentWidth, 720);
      expect(LumenTokens.pagePaddingStart, 12);
      expect(LumenTokens.sectionGap, 10);
      expect(LumenTokens.horizontalPaddingForWidth(900), 24);
      expect(LumenTokens.horizontalPaddingForWidth(640), 16);
      expect(LumenTokens.horizontalPaddingForWidth(390), 12);
    });
  });
}
