import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'main.dart' show isDesktop, isAndroid;
import 'providers/settings_provider.dart';
import 'pages/home_page.dart';

class NexAIApp extends StatelessWidget {
  const NexAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        if (isAndroid) {
          return _buildMaterialApp(settings, lightDynamic, darkDynamic);
        }
        return _buildFluentApp(settings, lightDynamic, darkDynamic);
      },
    );
  }

  // ─── Android: Material 3 ───
  Widget _buildMaterialApp(
    SettingsProvider settings,
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
  ) {
    final seedColor = settings.accentColorValue != null
        ? Color(settings.accentColorValue!)
        : const Color(0xFF6750A4);

    final lightScheme = lightDynamic ?? ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final darkScheme = darkDynamic ?? ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    // If user picked a custom accent, override dynamic with seed-based
    final effectiveLight = settings.accentColorValue != null
        ? ColorScheme.fromSeed(seedColor: Color(settings.accentColorValue!), brightness: Brightness.light)
        : lightScheme;
    final effectiveDark = settings.accentColorValue != null
        ? ColorScheme.fromSeed(seedColor: Color(settings.accentColorValue!), brightness: Brightness.dark)
        : darkScheme;

    return MaterialApp(
      title: 'NexAI',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: effectiveLight,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          indicatorColor: effectiveLight.secondaryContainer,
          labelTextStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          height: 72,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 2,
          backgroundColor: effectiveLight.surface,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: effectiveLight.surfaceContainerHighest.withAlpha(180),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: effectiveLight.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: effectiveDark,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          indicatorColor: effectiveDark.secondaryContainer,
          labelTextStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          height: 72,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 2,
          backgroundColor: effectiveDark.surface,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: effectiveDark.surfaceContainerHighest.withAlpha(180),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: effectiveDark.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const HomePage(),
    );
  }

  // ─── Desktop: Fluent UI ───
  Widget _buildFluentApp(
    SettingsProvider settings,
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
  ) {
    final accentColor = _resolveDesktopAccent(settings, lightDynamic, darkDynamic);
    final swatch = _buildSwatch(accentColor);

    return fluent.FluentApp(
      title: 'NexAI',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: fluent.FluentThemeData(
        brightness: Brightness.light,
        accentColor: swatch,
        visualDensity: VisualDensity.standard,
        navigationPaneTheme: fluent.NavigationPaneThemeData(
          backgroundColor: Colors.white.withAlpha((0.85 * 255).round()),
        ),
      ),
      darkTheme: fluent.FluentThemeData(
        brightness: Brightness.dark,
        accentColor: swatch,
        visualDensity: VisualDensity.standard,
        navigationPaneTheme: fluent.NavigationPaneThemeData(
          backgroundColor: const Color(0xFF202020).withAlpha((0.85 * 255).round()),
        ),
      ),
      home: const HomePage(),
    );
  }

  Color _resolveDesktopAccent(
    SettingsProvider settings,
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
  ) {
    if (settings.accentColorValue != null) {
      return Color(settings.accentColorValue!);
    }
    if (!kIsWeb) {
      return SystemTheme.accentColor.accent;
    }
    return const Color(0xFF60A5FA);
  }

  fluent.AccentColor _buildSwatch(Color c) {
    final hsl = HSLColor.fromColor(c);
    return fluent.AccentColor.swatch({
      'normal': c,
      'dark': hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor(),
      'darker': hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor(),
      'darkest': hsl.withLightness((hsl.lightness - 0.3).clamp(0.0, 1.0)).toColor(),
      'light': hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor(),
      'lighter': hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor(),
      'lightest': hsl.withLightness((hsl.lightness + 0.3).clamp(0.0, 1.0)).toColor(),
    });
  }
}
