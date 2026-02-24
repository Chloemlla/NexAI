import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ColorScheme;
import 'package:provider/provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'providers/settings_provider.dart';
import 'pages/home_page.dart';

class NexAIApp extends StatelessWidget {
  const NexAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final accentColor = _resolveAccentColor(settings, lightDynamic, darkDynamic);

        final swatch = _buildSwatch(accentColor);

        return FluentApp(
          title: 'NexAI',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: FluentThemeData(
            brightness: Brightness.light,
            accentColor: swatch,
            visualDensity: VisualDensity.standard,
            navigationPaneTheme: NavigationPaneThemeData(
              backgroundColor: Colors.white.withOpacity(0.85),
            ),
          ),
          darkTheme: FluentThemeData(
            brightness: Brightness.dark,
            accentColor: swatch,
            visualDensity: VisualDensity.standard,
            navigationPaneTheme: NavigationPaneThemeData(
              backgroundColor: const Color(0xFF202020).withOpacity(0.85),
            ),
          ),
          home: const HomePage(),
        );
      },
    );
  }

  Color _resolveAccentColor(
    SettingsProvider settings,
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
  ) {
    // User override takes priority
    if (settings.accentColorValue != null) {
      return Color(settings.accentColorValue!);
    }

    // Android Material You dynamic color
    if (lightDynamic != null &&
        (defaultTargetPlatform == TargetPlatform.android || kIsWeb)) {
      final brightness = settings.themeMode == ThemeMode.dark ||
          (settings.themeMode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
      if (brightness && darkDynamic != null) return darkDynamic.primary;
      return lightDynamic.primary;
    }

    // Desktop system accent
    if (!kIsWeb) {
      return SystemTheme.accentColor.accent;
    }

    return const Color(0xFF60A5FA);
  }

  AccentColor _buildSwatch(Color c) {
    final hsl = HSLColor.fromColor(c);
    return AccentColor.swatch({
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
