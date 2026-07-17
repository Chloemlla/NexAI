import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/chat_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/image_generation_provider.dart';
import 'providers/password_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/translation_provider.dart';
import 'providers/short_url_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/artifacts_provider.dart';
import 'app.dart';
import 'utils/app_security.dart';
import 'utils/security_headers_interceptor.dart';
import 'utils/security_event_reporter.dart';
import 'services/crash_breadcrumbs.dart';
import 'services/crash_reporter.dart';
import 'services/nexai_security_service.dart';
import 'package:dio/dio.dart';

bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

void main() {
  runZonedGuarded(
    () async {
      await _runMain();
    },
    (error, stackTrace) {
      CrashReporter.recordError(
        error,
        stackTrace,
        event: 'Zone error captured',
      );
    },
  );
}

Future<void> _runMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReporter.installSafely();
  CrashBreadcrumbs.record('Widgets binding initialized');
  await CrashReporter.loadStartupCrashReport();

  if (isAndroid) {
    CrashBreadcrumbs.record('Android system UI configured');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        systemNavigationBarColor: Color(0x00000000),
        systemNavigationBarDividerColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  if (isDesktop) {
    CrashBreadcrumbs.record('Desktop window initialization started');
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(800, 600),
      center: true,
      title: 'NexAI',
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final settingsProvider = SettingsProvider();
  final notesProvider = NotesProvider();
  final chatProvider = ChatProvider();
  final passwordProvider = PasswordProvider();
  final translationProvider = TranslationProvider();
  final shortUrlProvider = ShortUrlProvider();
  final authProvider = AuthProvider();
  authProvider.attachSettingsProvider(settingsProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider.value(value: notesProvider),
        ChangeNotifierProvider(create: (_) => ImageGenerationProvider()),
        ChangeNotifierProvider.value(value: passwordProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: translationProvider),
        ChangeNotifierProvider.value(value: shortUrlProvider),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => ArtifactsProvider()),
      ],
      child: const NexAIApp(),
    ),
  );
  CrashBreadcrumbs.record('runApp completed');

  unawaited(
    _bootstrapAppInBackground(
      settingsProvider: settingsProvider,
      notesProvider: notesProvider,
      chatProvider: chatProvider,
      passwordProvider: passwordProvider,
      translationProvider: translationProvider,
      shortUrlProvider: shortUrlProvider,
      authProvider: authProvider,
    ),
  );
}

Future<void> _bootstrapAppInBackground({
  required SettingsProvider settingsProvider,
  required NotesProvider notesProvider,
  required ChatProvider chatProvider,
  required PasswordProvider passwordProvider,
  required TranslationProvider translationProvider,
  required ShortUrlProvider shortUrlProvider,
  required AuthProvider authProvider,
}) async {
  try {
    CrashBreadcrumbs.record('Background bootstrap started');
    await Future.wait([
      _runSecurityChecksInBackground(),
      settingsProvider.loadSettings(),
      notesProvider.loadNotes(),
      chatProvider.loadConversations(),
      passwordProvider.loadPasswords(),
      translationProvider.loadHistory(),
      shortUrlProvider.loadHistory(),
      authProvider.init(),
    ]);
    CrashBreadcrumbs.record('Background bootstrap completed');
  } catch (e, stackTrace) {
    CrashReporter.recordError(e, stackTrace, event: 'Startup bootstrap failed');
    debugPrint('NexAI startup bootstrap failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _runSecurityChecksInBackground() async {
  await AppSecurity.instance.init();

  final securityDio = createSecureDio(
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  final securityService = NexAISecurityService(securityDio);
  final securityReporter = SecurityEventReporter(securityService);

  if (AppSecurity.instance.isCompromised ||
      !AppSecurity.instance.isSignatureValid ||
      !AppSecurity.instance.isApkHashValid) {
    await securityReporter.reportAllIssues();
  }
}
