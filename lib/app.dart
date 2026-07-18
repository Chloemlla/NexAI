import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'models/crash_report.dart';
import 'providers/settings_provider.dart';
import 'services/crash_reporter.dart';
import 'pages/crash_report_page.dart';
import 'pages/home_page.dart';
import 'pages/oss_notice_page.dart';
import 'theme/lumen_theme.dart';
import 'theme/lumen_tokens.dart';
import 'widgets/lumen/lumen.dart';
import 'utils/navigation_helper.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
        : (_isAndroid ? LumenTokens.teal : const Color(0xFF6750A4));

    final accentOverride = settings.accentColorValue != null
        ? Color(settings.accentColorValue!)
        : null;

    final ColorScheme effectiveLight;
    final ColorScheme effectiveDark;

    if (_isAndroid) {
      // Android uses the fixed Project-Lumen soft-surface palette.
      // A custom accent only overrides primary family seed values.
      effectiveLight = LumenTheme.lightColorScheme(accentOverride: accentOverride);
      effectiveDark = LumenTheme.darkColorScheme(accentOverride: accentOverride);
    } else {
      final lightScheme =
          lightDynamic ??
          ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
          );
      final darkScheme =
          darkDynamic ??
          ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          );

      effectiveLight = settings.accentColorValue != null
          ? ColorScheme.fromSeed(
              seedColor: Color(settings.accentColorValue!),
              brightness: Brightness.light,
            )
          : lightScheme;
      effectiveDark = settings.accentColorValue != null
          ? ColorScheme.fromSeed(
              seedColor: Color(settings.accentColorValue!),
              brightness: Brightness.dark,
            )
          : darkScheme;
    }

    return MaterialApp(
      title: 'NexAI',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationHelper.navigatorKey,
      themeMode: settings.themeMode,
      theme: _isAndroid
          ? LumenTheme.build(
              colorScheme: effectiveLight,
              fontFamily: settings.effectiveFontFamily,
            )
          : _buildTheme(settings, effectiveLight),
      darkTheme: _isAndroid
          ? LumenTheme.build(
              colorScheme: effectiveDark,
              fontFamily: settings.effectiveFontFamily,
            )
          : _buildTheme(settings, effectiveDark),
      home: const _CrashReportGate(),
      builder: FlutterSmartDialog.init(),
      navigatorObservers: [FlutterSmartDialog.observer],
    );
  }

  ThemeData _buildTheme(SettingsProvider settings, ColorScheme colorScheme) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      fontFamily: settings.effectiveFontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.compact,
    );
    final textTheme = base.textTheme.apply(
      fontFamily: settings.effectiveFontFamily,
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: settings.effectiveFontFamily,
            letterSpacing: 0,
          ),
        ),
        height: 72,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
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
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        shadowColor: colorScheme.shadow.withAlpha(55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(110)),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(180),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(70),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: rounded16,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: rounded16,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 40),
          shape: rounded16,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHighest.withAlpha(170),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(milliseconds: 1800),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
    );
  }
}

class _CrashReportGate extends StatefulWidget {
  const _CrashReportGate();

  @override
  State<_CrashReportGate> createState() => _CrashReportGateState();
}

class _CrashReportGateState extends State<_CrashReportGate> {
  late CrashReport? _report = CrashReporter.startupCrashReport;

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) return const _OssNoticeGate();
    return CrashReportPage(
      report: report,
      onContinue: () {
        setState(() => _report = null);
      },
    );
  }
}

class _OssNoticeGate extends StatelessWidget {
  const _OssNoticeGate();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // Settings load in background after first frame. Keep a calm waiting state
    // so we never flash Home before the first-install decision is known.
    if (!settings.loaded) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: lumenScaffoldBackground(cs),
        body: Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
      );
    }

    if (!settings.ossNoticeAcknowledged) {
      return const OssNoticePage();
    }

    return const HomePage();
  }
}
