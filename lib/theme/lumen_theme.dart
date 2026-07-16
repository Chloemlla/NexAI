import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lumen_tokens.dart';

class LumenTheme {
  LumenTheme._();

  static ColorScheme lightColorScheme({Color? accentOverride}) {
    final base = ColorScheme(
      brightness: Brightness.light,
      primary: accentOverride ?? LumenTokens.teal,
      onPrimary: LumenTokens.onPrimary,
      primaryContainer: LumenTokens.tealContainer,
      onPrimaryContainer: LumenTokens.onTealContainer,
      secondary: LumenTokens.coral,
      onSecondary: LumenTokens.onCoral,
      secondaryContainer: LumenTokens.coralContainer,
      onSecondaryContainer: LumenTokens.onCoralContainer,
      tertiary: LumenTokens.indigo,
      onTertiary: LumenTokens.onIndigo,
      tertiaryContainer: LumenTokens.indigoContainer,
      onTertiaryContainer: LumenTokens.onIndigoContainer,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: LumenTokens.surface,
      onSurface: LumenTokens.text,
      surfaceContainerLowest: LumenTokens.surface,
      surfaceContainerLow: LumenTokens.surfaceContainerLow,
      surfaceContainer: LumenTokens.surfaceContainer,
      surfaceContainerHigh: LumenTokens.surfaceContainerHigh,
      surfaceContainerHighest: LumenTokens.surfaceContainerHighest,
      surfaceDim: LumenTokens.surfaceVariant,
      surfaceBright: LumenTokens.surface,
      onSurfaceVariant: LumenTokens.outline,
      outline: LumenTokens.outline,
      outlineVariant: LumenTokens.outlineVariant,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFF2F3431),
      onInverseSurface: const Color(0xFFF0F4F1),
      inversePrimary: LumenTokens.tealDark,
      surfaceTint: accentOverride ?? LumenTokens.teal,
    );
    return base;
  }

  static ColorScheme darkColorScheme({Color? accentOverride}) {
    final primary = accentOverride ?? LumenTokens.tealDark;
    return ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: LumenTokens.onPrimaryDark,
      primaryContainer: LumenTokens.tealContainerDark,
      onPrimaryContainer: LumenTokens.onTealContainerDark,
      secondary: LumenTokens.coralDark,
      onSecondary: LumenTokens.onCoralDark,
      secondaryContainer: LumenTokens.coralContainerDark,
      onSecondaryContainer: LumenTokens.onCoralContainerDark,
      tertiary: LumenTokens.indigoDark,
      onTertiary: LumenTokens.onIndigoDark,
      tertiaryContainer: LumenTokens.indigoContainerDark,
      onTertiaryContainer: LumenTokens.onIndigoContainerDark,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: LumenTokens.surfaceDark,
      onSurface: LumenTokens.textDark,
      surfaceContainerLowest: LumenTokens.backgroundDark,
      surfaceContainerLow: LumenTokens.surfaceContainerLowDark,
      surfaceContainer: LumenTokens.surfaceContainerDark,
      surfaceContainerHigh: LumenTokens.surfaceContainerHighDark,
      surfaceContainerHighest: LumenTokens.surfaceContainerHighestDark,
      surfaceDim: LumenTokens.backgroundDark,
      surfaceBright: LumenTokens.surfaceContainerHighDark,
      onSurfaceVariant: LumenTokens.outlineDark,
      outline: LumenTokens.outlineDark,
      outlineVariant: LumenTokens.outlineVariantDark,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFE3EAE6),
      onInverseSurface: const Color(0xFF1A211E),
      inversePrimary: LumenTokens.teal,
      surfaceTint: primary,
    );
  }

  static ThemeData build({
    required ColorScheme colorScheme,
    String? fontFamily,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ).copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: LumenTokens.topBarTitleSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 28 / 22,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 24 / 18,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 20 / 15,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        letterSpacing: 0,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 18 / 13,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 16 / 12,
      ),
    );

    final roundedCard = RoundedRectangleBorder(
      borderRadius: LumenTokens.cardBorderRadius,
    );
    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
    );

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.brightness == Brightness.light
          ? LumenTokens.background
          : LumenTokens.backgroundDark,
      canvasColor: colorScheme.surface,
      textTheme: textTheme,
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: LumenTokens.navigationBarHeight,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
            letterSpacing: 0,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: LumenTokens.topBarHeight,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colorScheme.surface,
          statusBarIconBrightness: colorScheme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarIconBrightness:
              colorScheme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: roundedCard,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(180),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(70),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: roundedMd,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: roundedMd,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 40),
          shape: roundedMd,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
        ),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
          ),
        ),
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHighest.withAlpha(170),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LumenTokens.radiusLg),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
        ),
        iconColor: colorScheme.primary,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlpha(90),
        space: 1,
        thickness: 1,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(milliseconds: 1800),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
    );
  }
}
