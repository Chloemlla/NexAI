import 'package:flutter/material.dart';
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
      theme: LumenTheme.build(
        colorScheme: effectiveLight,
        fontFamily: settings.effectiveFontFamily,
      ),
      darkTheme: LumenTheme.build(
        colorScheme: effectiveDark,
        fontFamily: settings.effectiveFontFamily,
      ),
      home: const _CrashReportGate(),
      builder: FlutterSmartDialog.init(),
      navigatorObservers: [FlutterSmartDialog.observer],
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
