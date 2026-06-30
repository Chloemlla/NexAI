# Android Kotlin 原生能力迁移技术要求

## 1. 目标

本文档定义 NexAI 在继续以 Flutter 作为主客户端框架的前提下，将 Android 独有能力逐步 Kotlin 原生化的技术要求、接口边界、模块优先级和验收标准。

本迁移不是将 NexAI 重写为纯 Android Kotlin/Compose 应用，而是建立稳定的 Android 原生能力层，让 Flutter 负责 UI、状态编排和跨平台业务，Kotlin 负责 Android 平台 API、系统安全能力、长耗时任务和系统集成。

## 2. 适用范围

### 2.1 纳入 Kotlin 原生化的能力

| 模块 | 迁移目标 |
|---|---|
| 安全检测 | APK 签名/哈希、Root、调试器、模拟器、VPN、Frida、Xposed、屏幕安全策略 |
| 设备指纹 | 硬件、系统、传感器、网络、存储、DEX 哈希等 Android 侧特征采集 |
| 媒体处理 | 视频压缩、音频提取、媒体元数据读取、处理进度、取消任务 |
| 文件与权限 | Android 13+ Photo Picker、SAF、运行时权限、持久 URI 授权 |
| 后台任务 | WorkManager、前台服务、重试、约束条件、长期任务恢复 |
| 系统分享 | Android Sharesheet、FileProvider、安全 URI 暴露 |
| 通知 | 通知渠道、进度通知、失败通知、点击回到任务页 |
| 更新检测 | Android 侧版本信息、下载/跳转安装、更新通知、安装来源限制提示 |

### 2.2 不纳入本阶段重写的能力

| 模块 | 保持现状 |
|---|---|
| 主 UI | 继续使用 Flutter 页面和组件 |
| 聊天流式输出 | 继续由 Dart provider 管理 |
| Markdown/LaTeX/Mermaid 渲染 | 继续由 Flutter 渲染链路处理 |
| 设置、笔记、图谱、工具页 UI | 继续由 Flutter 负责 |
| OpenAI 兼容 API 调用编排 | 继续由 Dart provider/service 负责，必要时只下沉安全请求头或设备状态读取 |

## 3. 总体架构

### 3.1 分层原则

```
Flutter UI / Providers / Services
        |
        | MethodChannel / EventChannel
        v
Android Native Facade (Kotlin)
        |
        +-- SecurityModule
        +-- DeviceFingerprintModule
        +-- MediaModule
        +-- PermissionModule
        +-- BackgroundTaskModule
        +-- ShareModule
        +-- NotificationModule
        +-- UpdateModule
```

要求：

- Flutter 只调用稳定的 channel facade，不直接感知 Android API 版本差异。
- Kotlin 模块负责 Android 版本分支、权限状态、异常归一化和线程切换。
- 长耗时任务必须使用后台线程、WorkManager 或前台服务，不允许阻塞主线程。
- Flutter 与 Kotlin 的数据交换必须使用可序列化结构：`Map<String, Any?>`、`List`、`String`、`Boolean`、`Int`、`Double`。
- 所有 channel 方法必须有明确的错误码，不允许只返回原始异常字符串。

### 3.2 代码位置

当前 Android 原生代码位于：

- `android/app/src/main/kotlin/com/chloemlla/nexai/MainActivity.kt`
- `android/app/src/main/kotlin/com/chloemlla/nexai/DeviceFingerprint.kt`

迁移后建议逐步拆分为：

```
android/app/src/main/kotlin/com/chloemlla/nexai/
  MainActivity.kt
  channels/
    NativeChannelRegistry.kt
    SecurityChannel.kt
    DeviceFingerprintChannel.kt
    MediaChannel.kt
    PermissionChannel.kt
    BackgroundTaskChannel.kt
    ShareChannel.kt
    NotificationChannel.kt
    UpdateChannel.kt
  security/
  fingerprint/
  media/
  permissions/
  background/
  sharing/
  notifications/
  update/
```

`MainActivity.kt` 只负责注册 channel 和生命周期入口，不继续堆叠具体业务实现。

## 4. Channel 规范

### 4.1 命名

现有安全 channel：

```text
com.chloemlla.nexai/security
```

新增 channel 建议：

| Channel | 用途 |
|---|---|
| `com.chloemlla.nexai/security` | 安全检测和屏幕安全 |
| `com.chloemlla.nexai/fingerprint` | 设备指纹特征 |
| `com.chloemlla.nexai/media` | 媒体压缩、提取、元数据 |
| `com.chloemlla.nexai/permissions` | 权限请求和授权状态 |
| `com.chloemlla.nexai/background` | WorkManager/前台服务任务 |
| `com.chloemlla.nexai/share` | 系统分享 |
| `com.chloemlla.nexai/notifications` | 通知渠道和通知展示 |
| `com.chloemlla.nexai/update` | Android 更新检测辅助 |

### 4.2 返回格式

所有新接口统一返回：

```json
{
  "ok": true,
  "data": {},
  "error": null
}
```

失败时：

```json
{
  "ok": false,
  "data": null,
  "error": {
    "code": "permission_denied",
    "message": "Notification permission denied",
    "recoverable": true
  }
}
```

错误码要求：

| 错误码 | 含义 |
|---|---|
| `unsupported_android_version` | 当前系统版本不支持 |
| `permission_denied` | 权限被拒绝 |
| `permission_permanently_denied` | 权限被永久拒绝，需要跳转设置 |
| `user_cancelled` | 用户取消选择或任务 |
| `invalid_argument` | Flutter 传入参数不合法 |
| `task_not_found` | 任务不存在或已结束 |
| `native_failure` | 原生执行失败 |
| `security_restricted` | 安全策略限制执行 |

### 4.3 事件流

进度、状态变化和后台任务结果使用 `EventChannel`：

```json
{
  "taskId": "media-compress-20260630-001",
  "type": "progress",
  "progress": 0.42,
  "message": "compressing",
  "payload": {}
}
```

事件类型：

| 类型 | 含义 |
|---|---|
| `started` | 任务已开始 |
| `progress` | 进度更新 |
| `paused` | 任务暂停 |
| `completed` | 任务完成 |
| `failed` | 任务失败 |
| `cancelled` | 任务取消 |

## 5. 模块技术要求

### 5.1 安全检测模块

### 现状

项目已通过 `MethodChannel('com.chloemlla.nexai/security')` 接入 Android 原生检测，当前 Kotlin 侧已包含 APK 签名、APK 文件哈希、Root、调试器、模拟器、VPN、DEX 哈希、屏幕安全和设备信息读取等能力。

### 迁移要求

保留现有方法兼容性：

| 方法 | 保留要求 |
|---|---|
| `getApkSignatureFingerprint` | 返回 APK 签名证书 SHA-256 |
| `getApkFileSha256` | 返回当前 APK 文件 SHA-256 |
| `isRooted` | 返回 Root/高风险环境检测结果 |
| `isDebuggerAttached` | 返回调试器附加状态 |
| `isEmulator` | 返回模拟器检测结果 |
| `isVpnActive` | 返回 VPN 状态 |
| `getDexHash` | 返回 DEX 哈希 |
| `setSecureScreen` | 控制 `Window.FLAG_SECURE` |

新增或增强：

- Frida 检测拆成独立检测项，返回 `fridaDetected`。
- Xposed/LSPosed 检测拆成独立检测项，返回 `xposedDetected`。
- 增加 overlay/悬浮窗风险检测能力，只作为风险信号，不直接阻断。
- 增加 `getSecuritySnapshot`，一次性返回完整安全状态，减少 Flutter 多次 channel 调用。
- 所有检测结果必须包含 `checkedAt`、`source` 和 `confidence`。

建议返回：

```json
{
  "rooted": false,
  "debuggerAttached": false,
  "emulator": false,
  "vpnActive": false,
  "fridaDetected": false,
  "xposedDetected": false,
  "signatureSha256": "...",
  "apkSha256": "...",
  "dexSha256": "...",
  "checkedAt": 1782816000000
}
```

验收标准：

- Flutter 现有安全调用不破坏。
- 安全快照接口单次调用即可覆盖启动期安全状态。
- 任一检测失败时返回可解析错误，不影响其他检测项返回。
- 敏感页面进入时可开启 `FLAG_SECURE`，离开时可按页面策略恢复。

### 5.2 设备指纹模块

### 迁移要求

将 Android 专属信息采集集中到 Kotlin：

| 方法 | 内容 |
|---|---|
| `getHardwareInfo` | 品牌、型号、设备、板卡、CPU ABI、硬件名 |
| `getSoftwareInfo` | Android 版本、SDK、Build fingerprint、安全补丁版本 |
| `getStorageInfo` | 内部存储容量、可用空间、挂载状态 |
| `getSensorFingerprint` | 传感器名称、厂商、版本、数量摘要 |
| `getNetworkInfo` | 网络类型、VPN、代理、接口摘要 |
| `getSystemProperties` | 白名单内系统属性 |
| `getFingerprintSnapshot` | 一次性聚合以上信息 |

隐私要求：

- 不在日志中打印原始设备指纹字段。
- 不采集联系人、短信、通话记录、精确位置等敏感个人数据。
- 原始字段只用于本地派生设备指纹，不直接上传，除非后端契约明确要求。
- 设备指纹派生时应使用 SHA-256 或 HMAC-SHA256，避免明文长期保存。

验收标准：

- Android 侧采集失败时返回空字段和错误原因，不导致应用启动失败。
- Flutter 侧只依赖 `getFingerprintSnapshot` 聚合结果，旧方法保留兼容。
- 指纹结果在同一安装周期内稳定，系统小版本更新后允许有限变化。

### 5.3 媒体处理模块

### 迁移目标

优先将 Android 媒体处理从 Flutter 插件调用收敛到 Kotlin facade。实现方式可以继续复用已引入的原生能力或 Android 系统 API，但 Flutter 侧只依赖统一 channel。

### 功能要求

| 功能 | 技术要求 |
|---|---|
| 视频元数据 | 使用 `MediaMetadataRetriever` 读取时长、分辨率、码率、旋转角度、MIME |
| 视频压缩 | 支持质量档位、目标分辨率、目标码率、保留/移除音轨 |
| 音频提取 | 支持 AAC/M4A；如继续要求 MP3，需明确使用 FFmpeg 类能力，Android 系统 API 不直接提供 MP3 编码器 |
| 进度回调 | 使用 `EventChannel` 或 WorkManager progress |
| 取消任务 | 支持按 `taskId` 取消 |
| 输出文件 | 输出到 app cache 或用户选择的 SAF URI |

长耗时任务要求：

- 超过 10 秒的媒体任务必须支持前台服务通知或 WorkManager 任务状态恢复。
- 任务执行期间不得阻塞 Flutter UI 线程和 Android 主线程。
- 处理失败时必须清理半成品临时文件。
- 输出文件写入公共媒体库时必须遵守 Android 10+ scoped storage。

验收标准：

- Flutter 工具页可以通过同一接口启动、查看进度、取消、打开输出文件。
- Android 13+ 不依赖过时的外部存储全局读写权限。
- 失败、取消、权限不足、空间不足都返回明确错误码。

### 5.4 文件与权限模块

### 迁移要求

统一 Android 运行时权限和系统选择器：

| 场景 | Android 原生方案 |
|---|---|
| 选择图片/视频 | Android 13+ Photo Picker，旧版本回退到 SAF 或内容选择器 |
| 选择任意文件 | `ACTION_OPEN_DOCUMENT` |
| 保存文件 | `ACTION_CREATE_DOCUMENT` 或 MediaStore |
| 通知权限 | Android 13+ `POST_NOTIFICATIONS` |
| 相册写入 | Android 10+ MediaStore；旧版本按需请求存储权限 |
| 持久授权 | `takePersistableUriPermission` |

要求：

- Flutter 侧只请求业务动作，例如 `pickVideo`、`createDocument`、`ensureNotificationPermission`。
- Kotlin 侧负责 Android 版本判断和权限请求。
- 权限被永久拒绝时返回 `permission_permanently_denied`，Flutter 展示跳转设置入口。
- URI 不转成本地绝对路径作为默认行为，优先使用 `content://` 流式读写。

验收标准：

- Android 11、12、13、14、15 权限路径均有明确分支。
- 用户取消选择时返回 `user_cancelled`，不作为异常崩溃处理。
- 共享给其他应用的文件必须通过 `FileProvider` 或 SAF URI，不暴露 `file://`。

### 5.5 后台任务模块

### 迁移目标

将需要系统调度或任务恢复的 Android 独有任务迁入 Kotlin：

- 媒体压缩/音频提取。
- 云同步重试。
- 安全状态周期检查。
- 更新检测通知。
- 大文件上传/下载。

技术要求：

- 使用 WorkManager 处理可延迟、可恢复任务。
- 使用前台服务处理用户可见的长时间媒体任务。
- 为每个任务生成稳定 `taskId`。
- 任务状态必须可查询：`queued`、`running`、`succeeded`、`failed`、`cancelled`。
- 支持网络、电量、充电、存储空间等约束配置。
- 任务结果持久化到本地，应用重启后 Flutter 可恢复展示。

验收标准：

- 应用进程被系统回收后，已提交任务不会丢失状态。
- 任务失败有 retry/backoff 策略，且不会无限重试。
- 用户主动取消任务后不得自动重启。

### 5.6 系统分享模块

### 迁移要求

Flutter 发起分享意图，Kotlin 负责构造 Android Sharesheet：

| 方法 | 参数 |
|---|---|
| `shareText` | `text`、`subject` |
| `shareFile` | `uri`、`mimeType`、`title` |
| `shareFiles` | `uris`、`mimeType`、`title` |

要求：

- 文件分享必须使用 `content://` URI。
- 临时授权必须设置 `Intent.FLAG_GRANT_READ_URI_PERMISSION`。
- MIME 类型必须由 Kotlin 侧兜底推断。
- 分享失败或没有可用应用时返回 `native_failure`，Flutter 提示用户。

验收标准：

- 聊天消息导出 PNG、图片生成结果、笔记导出文件均可通过统一分享接口发送。
- 分享完成不要求强依赖回调成功，因为 Android Sharesheet 不保证目标应用结果可信。

### 5.7 通知模块

### 迁移要求

建立 Android 通知 facade：

| 通知类型 | 要求 |
|---|---|
| 媒体任务进度 | 可更新进度、可取消 |
| 更新可用 | 点击打开更新页或浏览器 |
| 同步失败 | 点击进入设置或同步页 |
| 安全风险 | 点击进入安全状态页 |

通知渠道：

| Channel ID | 用途 |
|---|---|
| `nexai_media_tasks` | 媒体处理任务 |
| `nexai_updates` | 应用更新 |
| `nexai_sync` | 同步状态 |
| `nexai_security` | 安全风险 |

要求：

- Android 13+ 必须先确认通知权限。
- 通知文案不得包含 API Key、完整设备指纹、访问令牌等敏感信息。
- 进度通知必须支持取消动作，取消动作应通知后台任务模块。
- 点击通知应通过 deep link 或 main activity extra 回到对应 Flutter 页面。

验收标准：

- 通知渠道只初始化一次，可重复调用。
- 用户关闭某类通知后，不影响任务本身执行。
- 所有通知 ID 可预测，便于更新和取消。

### 5.8 更新检测模块

### 迁移目标

保留现有 Dart 更新检查逻辑的业务判断，同时将 Android 平台相关能力下沉到 Kotlin：

- 获取当前安装包版本、versionCode、签名信息。
- 打开 GitHub Releases、浏览器下载页或系统安装器。
- 检查是否允许安装未知来源应用。
- 对下载后的 APK 执行签名/哈希校验。
- 通过通知提示新版本。

要求：

- 不在客户端硬编码签名私钥、GitHub token 或发布凭据。
- APK 安装必须走系统安装流程，不尝试静默安装。
- 下载 APK 后必须校验签名或 release metadata 中的哈希。
- Android 8+ 未授权未知来源安装时，引导用户到系统设置。

验收标准：

- 更新可用时 Flutter 能展示版本、发布日期、变更摘要和下载入口。
- Android 侧能返回安装环境状态：`canRequestPackageInstalls`、`installerPackageName`。
- 校验失败的 APK 不允许继续安装。

## 6. 安全要求

- 所有 Kotlin 原生能力必须接受 R8/ProGuard 混淆。
- 不得在 Kotlin 或 Dart 代码中硬编码 API Key、签名密码、keystore 密码、服务端私钥。
- 原生层日志默认关闭敏感字段。
- 安全检测结果是风控信号，不应只依赖客户端决定最终封禁，服务端仍需基于请求头和事件上报做最终判断。
- 对攻击者可能 patch 的检测项，不直接暴露过多判定细节给 UI。
- 原生层异常必须归一化，不把完整堆栈回传给 Flutter 或后端。

## 7. Dart 侧适配要求

新增 Dart facade，集中封装 channel 调用：

```
lib/services/android_native/
  android_native_result.dart
  android_security_service.dart
  android_fingerprint_service.dart
  android_media_service.dart
  android_permission_service.dart
  android_background_task_service.dart
  android_share_service.dart
  android_notification_service.dart
  android_update_service.dart
```

要求：

- 每个 facade 先判断 `kIsWeb` 和 `Platform.isAndroid`，非 Android 直接返回 unsupported。
- Provider 和 Page 不直接调用 `MethodChannel`。
- 旧工具页逐步改为调用 Dart facade，避免 UI 与 Android channel 耦合。
- 返回类型使用明确的 Dart model，不在业务代码里散落 `Map` 字段读取。

## 8. 分阶段实施计划

### Phase 1：整理现有安全和指纹能力

- 拆分 `MainActivity.kt` 中的安全 channel 注册和实现。
- 保留现有方法名，新增 `getSecuritySnapshot`。
- 将 `DeviceFingerprint.kt` 接入独立 fingerprint channel。
- Dart 侧新增 Android native facade。

验收：

- 现有安全状态、设备指纹、请求签名相关流程不变。
- Flutter 侧不再新增散落的 `MethodChannel` 调用。

### Phase 2：权限、文件和分享 Kotlin 化

- 新增 permission channel。
- 统一 Photo Picker、SAF、通知权限。
- 新增 share channel，使用 FileProvider/SAF URI。
- 将图片保存、消息导出 PNG、文件分享接入统一接口。

验收：

- Android 13+ 权限路径清晰。
- 不再新增 `file://` 分享。

### Phase 3：通知和后台任务

- 新增 notification channel 和通知渠道初始化。
- 新增 background task channel。
- 媒体任务和更新提醒支持通知。
- 可查询任务状态并从应用重启后恢复。

验收：

- 长任务进度可见、可取消。
- 任务失败有明确错误码和用户可理解提示。

### Phase 4：媒体处理 Kotlin facade

- 新增 media channel。
- 视频元数据读取迁入 Kotlin。
- 视频压缩、音频提取接入统一任务接口。
- 明确 MP3 输出是否继续依赖 FFmpeg 类能力；如不依赖，则默认输出 AAC/M4A。

验收：

- 视频压缩和音频提取 UI 不直接依赖具体 Flutter 插件。
- 任务进度、取消、输出文件 URI 行为稳定。

### Phase 5：Android 更新辅助

- 新增 update channel。
- Android 安装环境检测和 APK 校验下沉。
- 更新通知接入 notification channel。
- Flutter 保留版本展示和用户确认流程。

验收：

- 校验失败的 APK 不进入安装流程。
- 未授权未知来源安装时可引导用户到系统设置。

## 9. 验收清单

| 项目 | 要求 |
|---|---|
| 兼容性 | Android 11 至 Android 15 路径明确 |
| 稳定性 | 原生异常不会导致 Flutter 崩溃 |
| 性能 | 启动期安全快照不明显阻塞首屏 |
| 隐私 | 不上传不必要的原始设备信息 |
| 安全 | 不泄露密钥、令牌、完整指纹、堆栈 |
| 可维护性 | `MainActivity.kt` 不再承载大段业务逻辑 |
| 可测试性 | Kotlin 模块具备可单测的纯逻辑类，channel 层保持薄封装 |
| 可回滚 | 每个 phase 可独立合入，不要求一次性迁移 |

## 10. GitHub Actions 验证要求

根据仓库约定，实际构建和测试命令必须在 GitHub workflow 中执行，不在本地设备执行。

每个迁移 phase 合入后应由 GitHub Actions 至少执行：

- Android debug/release 构建。
- Flutter analyzer。
- Flutter unit/widget tests。
- Android 原生单元测试或 instrumentation test（新增后）。
- Release APK 签名、哈希、版本 metadata 校验。

PR 或提交说明中应记录：

- 影响的 Android API 范围。
- 新增/变更的 channel 方法。
- 权限或 manifest 变化。
- 用户可见行为变化。
- GitHub Actions 验证结果。

## 11. 风险与约束

| 风险 | 处理 |
|---|---|
| Channel 接口频繁变化 | 先定义 facade 和返回格式，再迁移调用方 |
| 媒体处理能力退化 | 先保留现有插件路径，Kotlin facade 稳定后再替换 |
| Android 权限差异复杂 | 权限模块集中处理版本分支 |
| 安全检测误报 | 作为风险信号上报，不直接在客户端强封 |
| 后台任务被系统限制 | 使用 WorkManager/前台服务，并向用户展示任务状态 |
| 迁移范围失控 | 按 phase 合入，每阶段只替换一个能力域 |

## 12. 最终状态

完成迁移后，NexAI Android 端应达到以下状态：

- Flutter 继续承担主 UI 和跨平台业务。
- Android 独有能力全部通过 Kotlin facade 暴露。
- 安全、权限、媒体、通知、后台任务、分享、更新逻辑具备统一接口和错误模型。
- 后续新增 Android 原生能力时，只扩展 Kotlin 模块和 Dart facade，不再把平台细节散落到页面或 provider 中。
