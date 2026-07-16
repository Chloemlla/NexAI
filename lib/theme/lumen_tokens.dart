import 'package:flutter/material.dart';

/// Project-Lumen soft-surface tokens ported for NexAI Android.
class LumenTokens {
  LumenTokens._();

  // Light palette
  static const Color teal = Color(0xFF126B66);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color tealContainer = Color(0xFFCDEDEA);
  static const Color onTealContainer = Color(0xFF083B38);
  static const Color coral = Color(0xFFB85C38);
  static const Color onCoral = Color(0xFFFFFFFF);
  static const Color coralContainer = Color(0xFFFFDBCC);
  static const Color onCoralContainer = Color(0xFF5A1C0A);
  static const Color indigo = Color(0xFF525DAA);
  static const Color onIndigo = Color(0xFFFFFFFF);
  static const Color indigoContainer = Color(0xFFE1E3FF);
  static const Color onIndigoContainer = Color(0xFF181D62);
  static const Color surface = Color(0xFFFFFCFA);
  static const Color surfaceVariant = Color(0xFFE0E7E4);
  static const Color surfaceContainer = Color(0xFFF0F4F1);
  static const Color surfaceContainerLow = Color(0xFFF5F8F5);
  static const Color surfaceContainerHigh = Color(0xFFE8EEEA);
  static const Color surfaceContainerHighest = Color(0xFFE0E7E4);
  static const Color background = Color(0xFFF8FAF7);
  static const Color outline = Color(0xFF6D7A76);
  static const Color outlineVariant = Color(0xFFC4CECA);
  static const Color text = Color(0xFF263331);

  // Dark palette
  static const Color tealDark = Color(0xFF8ED6D1);
  static const Color onPrimaryDark = Color(0xFF003734);
  static const Color tealContainerDark = Color(0xFF0A504C);
  static const Color onTealContainerDark = Color(0xFFCDEDEA);
  static const Color coralDark = Color(0xFFFFB59A);
  static const Color onCoralDark = Color(0xFF612100);
  static const Color coralContainerDark = Color(0xFF8B3F21);
  static const Color onCoralContainerDark = Color(0xFFFFDBCC);
  static const Color indigoDark = Color(0xFFC2C6FF);
  static const Color onIndigoDark = Color(0xFF242B75);
  static const Color indigoContainerDark = Color(0xFF3A438F);
  static const Color onIndigoContainerDark = Color(0xFFE1E3FF);
  static const Color surfaceDark = Color(0xFF111815);
  static const Color surfaceVariantDark = Color(0xFF303A36);
  static const Color surfaceContainerDark = Color(0xFF1A211E);
  static const Color surfaceContainerLowDark = Color(0xFF151C19);
  static const Color surfaceContainerHighDark = Color(0xFF222A26);
  static const Color surfaceContainerHighestDark = Color(0xFF303A36);
  static const Color backgroundDark = Color(0xFF0C1210);
  static const Color outlineDark = Color(0xFF8A9691);
  static const Color outlineVariantDark = Color(0xFF404B47);
  static const Color textDark = Color(0xFFE3EAE6);

  // Shape scale (Lumen)
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double cardRadius = 20;
  static const double iconChipRadius = 12;
  static const double preferenceRadius = 20;

  // Page shell (design/lumen-ui-tokens.json)
  static const double maxContentWidth = 720;
  static const double pagePaddingStart = 12;
  static const double pagePaddingTop = 8;
  static const double pagePaddingEnd = 12;
  static const double pagePaddingBottom = 24;
  static const double sectionGap = 10;
  static const double topBarHeight = 64;
  static const double topBarTitleSize = 22;
  static const double navigationBarHeight = 80;

  static BorderRadius get cardBorderRadius =>
      BorderRadius.circular(cardRadius);

  static BorderRadius get panelBorderRadius =>
      BorderRadius.circular(radiusMd);

  static BorderRadius get chipBorderRadius =>
      BorderRadius.circular(iconChipRadius);

  static EdgeInsets pagePadding({double? horizontalBoost}) {
    final h = horizontalBoost ?? pagePaddingStart;
    return EdgeInsets.fromLTRB(
      h,
      pagePaddingTop,
      h,
      pagePaddingBottom,
    );
  }

  static double horizontalPaddingForWidth(double width) {
    if (width >= 840) return 24;
    if (width >= 600) return 16;
    return pagePaddingStart;
  }
}
