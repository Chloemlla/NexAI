import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'main.dart' show isDesktop;
import 'providers/settings_provider.dart';
import 'pages/home_page.dart';

class NexAIApp extends StatelessWidget {
  const NexAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return _buildMaterialApp(settings, lightDynamic, darkDynamic);
      },
    );
  }

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
        cardTheme: CardThemeData(
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
        cardTheme: CardThemeData(
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
}
