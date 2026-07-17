import '../models/oss_dependency_credit.dart';

/// Curated credits for direct runtime dependencies and shipped assets.
///
/// Keep this list in sync when changing direct dependencies in `pubspec.yaml`.
/// Dev-only packages are intentionally excluded from the end-user notice page.
const List<OssDependencyCredit> kOssDependencyCredits = [
  OssDependencyCredit(
    name: 'Flutter',
    author: 'Flutter Authors / Google LLC',
    description: '跨平台 UI 框架与运行时。',
    license: 'BSD-3-Clause',
    url: 'https://github.com/flutter/flutter',
  ),
  OssDependencyCredit(
    name: 'dio',
    author: 'flutterchina / cfug',
    description: 'HTTP 客户端，负责网络请求与拦截器链路。',
    license: 'MIT',
    url: 'https://pub.dev/packages/dio',
  ),
  OssDependencyCredit(
    name: 'cookie_jar',
    author: 'flutterchina / cfug',
    description: 'Cookie 持久化与管理。',
    license: 'MIT',
    url: 'https://pub.dev/packages/cookie_jar',
  ),
  OssDependencyCredit(
    name: 'connectivity_plus',
    author: 'Flutter Community',
    description: '网络连接状态检测。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/connectivity_plus',
  ),
  OssDependencyCredit(
    name: 'dio_http2_adapter',
    author: 'flutterchina / cfug',
    description: '为 Dio 提供 HTTP/2 适配支持。',
    license: 'MIT',
    url: 'https://pub.dev/packages/dio_http2_adapter',
  ),
  OssDependencyCredit(
    name: 'flutter_smart_dialog',
    author: 'fluttercandies',
    description: 'Toast、对话框与全局浮层提示。',
    license: 'MIT',
    url: 'https://pub.dev/packages/flutter_smart_dialog',
  ),
  OssDependencyCredit(
    name: 'crypto',
    author: 'Dart Team',
    description: '哈希与摘要算法工具。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/crypto',
  ),
  OssDependencyCredit(
    name: 'encrypt',
    author: 'leocavalcante',
    description: '对称加密等安全相关工具。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/encrypt',
  ),
  OssDependencyCredit(
    name: 'ffmpeg_kit_flutter_new',
    author: 'sk3llo / FFmpeg community packaging',
    description: '媒体转码与音视频处理能力。',
    license: 'LGPL-3.0 / GPL depending on build',
    url: 'https://pub.dev/packages/ffmpeg_kit_flutter_new',
  ),
  OssDependencyCredit(
    name: 'flutter_displaymode',
    author: 'ajinasokan',
    description: 'Android 高刷新率显示模式设置。',
    license: 'MIT',
    url: 'https://pub.dev/packages/flutter_displaymode',
  ),
  OssDependencyCredit(
    name: 'http',
    author: 'Dart Team',
    description: '轻量 HTTP 客户端。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/http',
  ),
  OssDependencyCredit(
    name: 'shared_preferences',
    author: 'Flutter Team',
    description: '本地非敏感键值偏好存储。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/shared_preferences',
  ),
  OssDependencyCredit(
    name: 'intl',
    author: 'Dart Team',
    description: '国际化、日期与数字格式化。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/intl',
  ),
  OssDependencyCredit(
    name: 'flutter_math_fork',
    author: 'simpleclub / flutter-tex contributors',
    description: 'LaTeX 数学公式渲染。',
    license: 'Apache-2.0',
    url: 'https://pub.dev/packages/flutter_math_fork',
  ),
  OssDependencyCredit(
    name: 'gpt_markdown_chloemlla',
    author: 'Chloemlla / GPT Markdown contributors',
    description: '聊天场景 Markdown 渲染增强。',
    license: 'MIT',
    url: 'https://pub.dev/packages/gpt_markdown',
  ),
  OssDependencyCredit(
    name: 'provider',
    author: 'Remi Rousselet / Flutter Community',
    description: '应用状态管理与依赖注入。',
    license: 'MIT',
    url: 'https://pub.dev/packages/provider',
  ),
  OssDependencyCredit(
    name: 'url_launcher',
    author: 'Flutter Team',
    description: '打开外部链接与系统应用。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/url_launcher',
  ),
  OssDependencyCredit(
    name: 'window_manager',
    author: 'LeanFlutter / LiJianying',
    description: '桌面窗口尺寸、标题栏与焦点管理。',
    license: 'MIT',
    url: 'https://pub.dev/packages/window_manager',
  ),
  OssDependencyCredit(
    name: 'dynamic_color',
    author: 'Material Foundation / Google',
    description: 'Material You 动态取色。',
    license: 'Apache-2.0',
    url: 'https://pub.dev/packages/dynamic_color',
  ),
  OssDependencyCredit(
    name: 'package_info_plus',
    author: 'Flutter Community',
    description: '读取应用版本与包信息。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/package_info_plus',
  ),
  OssDependencyCredit(
    name: 'device_info_plus',
    author: 'Flutter Community',
    description: '读取设备与平台信息。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/device_info_plus',
  ),
  OssDependencyCredit(
    name: 'v_video_compressor',
    author: 'v_video_compressor authors',
    description: '视频压缩工具支持。',
    license: 'MIT',
    url: 'https://pub.dev/packages/v_video_compressor',
  ),
  OssDependencyCredit(
    name: 'file_picker',
    author: 'Miguel Ruivo',
    description: '跨平台文件选择。',
    license: 'MIT',
    url: 'https://pub.dev/packages/file_picker',
  ),
  OssDependencyCredit(
    name: 'path_provider',
    author: 'Flutter Team',
    description: '获取应用文档、缓存等系统路径。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/path_provider',
  ),
  OssDependencyCredit(
    name: 'path',
    author: 'Dart Team',
    description: '跨平台路径拼接与解析。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/path',
  ),
  OssDependencyCredit(
    name: 'gal',
    author: 'natsuk4ze',
    description: '保存图片/视频到系统相册。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/gal',
  ),
  OssDependencyCredit(
    name: 'permission_handler',
    author: 'Baseflow',
    description: '运行时权限申请与状态查询。',
    license: 'MIT',
    url: 'https://pub.dev/packages/permission_handler',
  ),
  OssDependencyCredit(
    name: 'flutter_secure_storage',
    author: 'Moorren / Julian Steenbakker et al.',
    description: '敏感信息安全存储。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/flutter_secure_storage',
  ),
  OssDependencyCredit(
    name: 'google_sign_in',
    author: 'Flutter Team / Google',
    description: 'Google 账号快速登录。',
    license: 'BSD-3-Clause',
    url: 'https://pub.dev/packages/google_sign_in',
  ),
  OssDependencyCredit(
    name: 'JetBrains Mono (NexAI subset)',
    author: 'JetBrains',
    description: '等宽字体子集，用于开发者日志、计时器等界面。',
    license: 'OFL-1.1',
    url: 'https://www.jetbrains.com/lp/mono/',
  ),
];

const String kNexAIRepositoryUrl = 'https://github.com/Chloemlla/NexAI';
const String kNexAILicenseUrl =
    'https://github.com/Chloemlla/NexAI/blob/main/LICENSE';
const String kNexAIReleasesUrl =
    'https://github.com/Chloemlla/NexAI/releases/latest';
const String kNexAIProjectLicense = 'GPL-3.0';
