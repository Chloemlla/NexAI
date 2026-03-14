import 'dart:async';
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
import 'utils/security_headers_interceptor.dart';
import 'utils/security_event_reporter.dart';
import 'services/nexai_security_service.dart';
import 'widgets/startup_loading_dialog.dart';
import 'package:dio/dio.dart';

bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create log stream for startup dialog
  final logController = StreamController<String>();

  // Show loading dialog in a separate zone
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: StartupLoadingDialog(logStream: logController.stream),
    ),
  );

  // Give UI time to render
  await Future.delayed(const Duration(milliseconds: 100));

  try {
    // Initialize media_kit for video playback
    logController.add('初始化媒体播放器...');
    MediaKit.ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 50));

    // Security: APK integrity + root detection (honeypot mode)
    logController.add('执行安全检查...');
    await AppSecurity.instance.init();
    await Future.delayed(const Duration(milliseconds: 50));

    // Initialize security services
    logController.add('初始化安全服务...');
    final securityDio = createSecureDio(
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final securityService = NexAISecurityService(securityDio);
    final securityReporter = SecurityEventReporter(securityService);
    await Future.delayed(const Duration(milliseconds: 50));

    // Report security issues if detected
    if (AppSecurity.instance.isCompromised ||
        !AppSecurity.instance.isSignatureValid ||
        !AppSecurity.instance.isApkHashValid) {
      logController.add('检测到安全问题，正在上报...');
      // Report asynchronously, don't block app startup
      securityReporter.reportAllIssues().ignore();
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (isAndroid) {
      logController.add('配置 Android 系统界面...');
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
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (isDesktop) {
      logController.add('初始化桌面窗口管理器...');
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
      await Future.delayed(const Duration(milliseconds: 50));
    }

    logController.add('加载应用设置...');
    final settingsProvider = SettingsProvider();
    await settingsProvider.loadSettings();
    await Future.delayed(const Duration(milliseconds: 50));

    logController.add('加载笔记数据...');
    final notesProvider = NotesProvider();
    await notesProvider.loadNotes();
    await Future.delayed(const Duration(milliseconds: 50));

    logController.add('加载对话历史...');
    final chatProvider = ChatProvider();
    await chatProvider.loadConversations();
    await Future.delayed(const Duration(milliseconds: 50));

    logController.add('加载密码管理器...');
    final passwordProvider = PasswordProvider();
    await passwordProvider.loadPasswords();
    await Future.delayed(const Duration(milliseconds: 50));

    logController.add('加载翻译历史...');
    final translationProvider = TranslationProvider();
    await translationProvider.loadHistory();
    await Future.delayed(const Duration(milliseconds: 50));

    logController.add('加载短链接历史...');
    final shortUrlProvider = ShortUrlProvider();
    await shortUrlProvider.loadHistory();
    await Future.delayed(const Duration(milliseconds: 50));

    logController.add('初始化身份验证服务...');
    final authProvider = AuthProvider();
    // Auth init is async but non-blocking - will restore session in background
    authProvider.init();
    await Future.delayed(const Duration(milliseconds: 50));

    logController.add('启动完成！正在进入应用...');
    await Future.delayed(const Duration(milliseconds: 300));

    // Close log stream
    await logController.close();

    // Launch main app
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
  } catch (e) {
    logController.add('启动失败: $e');
    await Future.delayed(const Duration(seconds: 3));
    logController.close();
    rethrow;
  }
}
