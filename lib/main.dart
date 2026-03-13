import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';

import 'providers/chat_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/image_generation_provider.dart';
import 'providers/password_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/translation_provider.dart';
import 'providers/short_url_provider.dart';
import 'providers/sync_provider.dart';
import 'app.dart';
import 'utils/app_security.dart';

bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit for video playback
  MediaKit.ensureInitialized();

  // Security: APK integrity + root detection (honeypot mode)
  await AppSecurity.instance.init();

  if (isAndroid) {
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
  await settingsProvider.loadSettings();

  final notesProvider = NotesProvider();
  await notesProvider.loadNotes();

  final chatProvider = ChatProvider();
  await chatProvider.loadConversations();

  final passwordProvider = PasswordProvider();
  await passwordProvider.loadPasswords();

  final translationProvider = TranslationProvider();
  await translationProvider.loadHistory();

  final shortUrlProvider = ShortUrlProvider();
  await shortUrlProvider.loadHistory();

  final authProvider = AuthProvider();
  // Auth init is async but non-blocking - will restore session in background
  authProvider.init();

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
      ],
      child: const NexAIApp(),
    ),
  );
}
