# NexAI

OpenAI-compatible AI chat client built with Flutter. Material Design 3 across Windows, Android, and Web, with notes, tools, encrypted cloud sync, and Android-oriented security hardening.

![Flutter](https://img.shields.io/badge/Flutter-3.44-blue?logo=flutter)
![Version](https://img.shields.io/badge/Version-1.0.7-orange)
![License](https://img.shields.io/badge/License-GPL--3.0-green)
![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20Web-blueviolet)

**Repository:** [github.com/Chloemlla/NexAI](https://github.com/Chloemlla/NexAI)

## Highlights

| Area | What you get |
| --- | --- |
| Chat | OpenAI-compatible + Google Vertex AI, streaming, multi-session, search, edit & resend |
| Rendering | GFM Markdown, syntax highlighting, LaTeX, chemistry (`\ce{...}`), Mermaid flowcharts |
| Notes | Markdown notes, tags, wiki-links, knowledge graph, save from chat |
| Tools | Media, converters, password generator, short URL, artifacts share, AI translate & image gen |
| Account | Login/register, Google Sign-In (Android/Web), Passkeys (Android) |
| Sync | NexAI `/sync/v2` end-to-end encrypted sync (+ WebDAV / Upstash options in settings) |
| Security | Secure storage, request signing, certificate pinning (TOFU), device checks (Android) |

## Features

### Chat

- **OpenAI-compatible API** — OpenAI, Claude proxies, DeepSeek, local models, and other `/v1` endpoints
- **Google Vertex AI** — Project / location / API key configuration in Settings
- **Streaming responses** — Token-by-token output with smart auto-scroll
- **Multiple conversations** — Unlimited sessions with per-session history
- **Message search** — Full-text search across conversations with highlighted hits
- **Edit & resend** — Edit a user message and regenerate from that point
- **Image generation** — Text-to-image / image-to-image via compatible APIs
- **Export bubble to PNG** — Capture any message bubble as an image

### Rendering

- **GitHub-flavored Markdown** with syntax-highlighted code blocks
- **LaTeX** — Inline `$...$` and display `$$...$$`
- **Chemistry** — `\ce{...}` notation
- **Mermaid flowcharts** — Parsed and painted from model output

### Notes

- **Markdown editor** with live preview
- **Tags** — `#tag` in body and YAML frontmatter
- **Wiki-links** — `[[note]]`, `[[note|alias]]`, `[[note#heading]]`
- **Knowledge graph** — Visual map of note connections
- **Star & organize** — Starred, recent, and tag-filtered views
- **Save from chat** — Persist an AI reply into a new or existing note

### Tools

| Category | Tools |
| --- | --- |
| Media | Video compressor, video → audio (MP3/AAC) |
| Convert | Date/time converter, Base64 encode/decode |
| Security | Configurable password generator with history |
| Network | Short URL, artifacts / content share |
| AI | AI translation, AI image generation |

### Appearance & UX

- **Material Design 3** on Windows, Android, and Web
- **Dynamic color** — Follows system accent on Android 12+
- **Custom accent color**, font family, and reading size
- **Dark / Light / System** theme
- **Borderless mode** — Clean, bubble-free chat layout
- **Full-screen mode** — Immersive chat on Android

### Account, Sync & Settings

- **Account** — Email/username login & register
- **Google Sign-In** — Android and Web (when backend enables it)
- **Passkeys** — Android Credential Manager / WebAuthn-aligned flow
- **Cloud sync** — NexAI `/sync/v2` encrypted containers for settings, chats, notes, translation history, and short-URL history
- **Sync recovery key** — Export / import local sync key from Settings → Sync
- **WebDAV / Upstash** — Alternate sync backends available in Settings
- **Auto-update checker** — GitHub Releases on startup
- **Persistent settings** — Non-sensitive prefs in `SharedPreferences`; API keys, tokens, sync keys, and saved passwords in secure storage

### Security & Integrity (especially Android)

- **APK integrity checks** against release metadata when available
- **Certificate pinning** — TOFU with expiry / cache management
- **Device fingerprinting** — Multi-signal permanent device identity
- **Threat detection** — Root, VPN, debugger, emulator, Frida, Xposed (native Android path)
- **Security event reporting** — Backend reporting with risk scoring
- **Request signing** — HMAC-SHA256 signed backend requests
- **Honeypot mode** — Server-controlled handling for compromised devices
- **Secure login screen** — Screenshot / recording protection on the auth page

> Security claims describe client capabilities and intended protections. Treat production hardening as an ongoing process; see `docs/` and recent audit notes before relying on any single control.

## Quick Start

### Build via GitHub Actions (recommended)

CI uses Flutter **3.44.5** and is the supported path for release artifacts.

1. Fork the repository
2. Open **Actions → Build NexAI → Run workflow**
3. Choose target: `windows`, `android`, `web`, or `all`
4. Download the workflow artifact when the job finishes

For signed Android release builds, configure repository secrets:

| Secret | Purpose |
| --- | --- |
| `KEYSTORE_BASE64` | Base64-encoded `.jks` keystore |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |
| `KEYSTORE_PASSWORD` | Keystore password |

Tag pushes matching `v*` run the **Release NexAI** workflow (analyze, test, build, publish).

### Local Development

```bash
flutter pub get
flutter config --enable-windows-desktop   # once, if needed
flutter create --platforms windows .      # if the windows/ project is incomplete
flutter run -d windows
flutter run -d android
flutter run -d chrome
```

**Requirements:** Flutter `>=3.44.0`, Dart SDK `>=3.11.0 <4.0.0`

```bash
flutter analyze
flutter test
dart format lib test
```

> Agents and contributors following this repo’s AGENTS instructions should rely on GitHub Actions for authoritative build/test validation rather than heavy local builds.

## Configuration

Open **Settings** in the app:

| Setting | Description | Default / notes |
| --- | --- | --- |
| Provider | OpenAI-compatible or Google Vertex AI | OpenAI-compatible |
| Base URL | API endpoint | `https://api.openai.com/v1` |
| API Key | Provider key | Stored in secure storage |
| Vertex Project / Location | Vertex AI routing | When provider = Vertex |
| Models | Comma-separated model list | User-defined |
| Temperature | Creativity (0–2) | `0.7` |
| Max Tokens | Response length limit | `4096` |
| System Prompt | Default assistant instruction | LaTeX-aware default |
| Font / Size | Chat typography | System / 14px |
| Borderless Mode | Remove chat bubbles | Off |
| Smart Auto-scroll | Follow streaming output | On |
| Cloud Sync | NexAI encrypted sync v2 | Off |
| Sync Recovery Key | Export / import local key | Settings → Sync |
| Certificate Cache | Clear pinning cache | Settings → Security |

## Rendering Examples

````markdown
Inline math:   $E = mc^2$
Display math:  $$\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}$$
Chemistry:     $\ce{H2O}$   $\ce{2H2 + O2 -> 2H2O}$
Flowchart:

```mermaid
graph TD
  A --> B
  B --> C
```
````

## Project Structure

```
lib/
├── main.dart                 # Entry, platform setup, providers
├── app.dart                  # MaterialApp + dynamic theming
├── models/                   # Message, note, artifact, password, crash report, …
├── providers/                # Chat, settings, notes, auth, sync, tools state
├── pages/                    # Chat, notes, tools, settings, login, about, …
├── widgets/                  # Bubbles, markdown, mermaid, dialogs
│   ├── flowchart/            # Mermaid parser + custom painter
│   └── markdown/             # Markdown render helpers
├── services/                 # Backend client, auth, sync, security, crash, artifacts
│   └── android_native/       # Method-channel facades (fingerprint, passkey, media, …)
└── utils/                    # Security, crypto, update check, signing, helpers

android/                      # Android app + Kotlin native capability layer
windows/                      # Windows desktop runner
web/                          # Web entry
assets/                       # Icons, markdown CSS, fonts
docs/                         # Security, integration, and feature specs
test/                         # Unit & widget tests
.github/workflows/            # build.yml, release.yml, generate-icons.yml
scripts/                      # Build metadata, font subsetting, icons helpers
```

## Documentation

| Document | Topic |
| --- | --- |
| [`docs/SERVER_API_SECURITY.md`](docs/SERVER_API_SECURITY.md) | Backend security API |
| [`docs/NEXAI_CLIENT_INTEGRATION.md`](docs/NEXAI_CLIENT_INTEGRATION.md) | Client integration |
| [`docs/BACKEND_INTEGRATION_CONTRACT.md`](docs/BACKEND_INTEGRATION_CONTRACT.md) | Backend contract |
| [`docs/CERTIFICATE_ERROR_FIX.md`](docs/CERTIFICATE_ERROR_FIX.md) | Certificate verification troubleshooting |
| [`docs/security_hardening_checklist.md`](docs/security_hardening_checklist.md) | Hardening checklist |
| [`docs/flutter-artifacts-integration.md`](docs/flutter-artifacts-integration.md) | Artifacts share client |
| [`docs/artifacts-share-backend-spec.md`](docs/artifacts-share-backend-spec.md) | Artifacts share backend |
| [`docs/katex-chemical-rendering-spec.md`](docs/katex-chemical-rendering-spec.md) | Chemistry rendering |
| [`docs/GPTMARKDOWN_CSS_INTEGRATION.md`](docs/GPTMARKDOWN_CSS_INTEGRATION.md) | Markdown CSS integration |
| [`docs/android-kotlin-native-capability-migration.md`](docs/android-kotlin-native-capability-migration.md) | Android native migration |

## Security Notes

- Never commit API keys, keystores, signing passwords, or local certificate material.
- Android release signing is expected via GitHub Actions secrets, not hardcoded credentials.
- Review `docs/SERVER_API_SECURITY.md` and related contracts before changing request signing, pinning, sync, or device security code.

## 更新日志

### 2026 年 7 月

本月提交按时间从旧到新整理，涵盖 Android 安全/适配、Passkey、Lumen UI 重写、开源声明、崩溃上报与客户端签名等。

#### 07-04

- `1fb6d8b` 调整 Android 构建，排除媒体库并清理插件注册
- `a880b35` Android 原生存储改用 MMKV
- `336dc7b` 新增完整代码审计报告
- `af69238` 加固同步发布与后端安全
- `de28495` 恢复媒体与对话框编译兼容
- `3bc2b81` 移除无用 media kit 启动逻辑
- `e53080a` 处理 analyzer 问题
- `c07af6f` 加固视频压缩元数据加载
- `14228f4` 强化 Android release 混淆
- `394360f` 强化 release shrinking

#### 07-07

- `eb5ed47` 对齐 Passkey Credential Manager 集成
- `7e4cae5` 接入 credential manager signal API
- `8b1da0c` 更新 `auth_provider.dart`

#### 07-12

- `c1429c6` Android 栈升级到 AGP 9.2.1 / compileSdk 37
- `a5132a7` NexAI Passkey 流程对齐 Happy-TTS WebAuthn 契约
- `fbc2e19` 支持无用户名的 discoverable Passkey 登录

#### 07-13

- `c9f0ddf` Passkey 用户取消按软取消处理

#### 07-15

- `a43ab16` 按当前功能与技术栈完善 README
- `a2da906` 防止 Google 头像网络失败导致崩溃
- `e802003` 加固密码备份、离线鉴权与完整性校验
- `3b37c24` 集成 Lumen Crash SDK 用于 Android 宿主崩溃

#### 07-16

**构建 / 崩溃**

- `364fd9b` 满足 auth 初始化 prefer_conditional_assignment
- `94009a4` CrashGate 报告状态改为可空类型
- `3a84d44` 修复 lumen-crash 空 POM 版本的 Compose 依赖声明
- `d548ff9` 防止 lumen-crash release 冷启动白屏
- `3f02e71` 桥接 Flutter 崩溃到 lumen-crash
- `2697c5a` 回退 Android 上的 Flutter lumen-crash bridge
- `85ded7b` 为 Android 构建离线预置 lumen-crash-core

**Passkey / 安全**

- `0d68857` Passkey 优先使用 Google Password Manager
- `b00429f` 新增 Google-only Passkey provider 开关
- `ebbf401` 增加 Passkey provider 诊断
- `0c36958` 启动时建立安全快照
- `8f3d15d` 稳定后台任务与通知
- `3367247` 强化更新包校验
- `99ebdd8` 扩展 anti-debug 与指纹信号
- `8dc6b13` 诊断 Android apk-key-hash base64 origin 不匹配

**Android 适配 / UI**

- `a12b2bc` 保持聊天布局在键盘上方
- `d7c1e05` 规划 Android Kotlin 边界加固
- `7971a74` 固化 Android Kotlin 边界加固计划
- `e8f02fa` 按 Vivo Android 13–17 指引适配 NexAI
- `8b41061` 补充 Android 11 Vivo 适配文档与更新说明
- `8052059` 修复 release Kotlin 构建，并处理 Android 11 包可见性
- `651bcf1` 以 Project Lumen 主题重绘 soft surfaces

#### 07-17

**Passkey / 鉴权 / 安全**

- `7a1a910` auth 诊断使用 null-aware map entry
- `47baa14` 修正 Passkey apk-key-hash 编码不匹配检测
- `5de8036` 对齐 NexAI 客户端安全/API 与后端契约
- `c4198d5` 实现 NexAI sig-v2 客户端签名与分阶段错误弹窗
- `dcfc8c8` 同步/分享失败分阶段弹窗，refresh 使用 refreshToken 签名

**首次安装开源声明**

- `a9e932f` 新增首次安装开源声明页
- `a27fbc6` 加固首次安装开源声明生命周期
- `ee73adc` 加固多平台开源声明安装检测
- `87229ba` 收口首次安装开源声明剩余边界问题
- `26a4980` 清理 lumen 与 oss notice 的 analyzer 警告

**Android Lumen UI 重写与收口**

- `8c30698` 全量 Project-Lumen soft-surface UI/UX 重写
- `6430e5c` 重写后恢复 Lumen soft-surface 契约
- `af775a9` 清理残留 marketing gradient
- `18a52c5` 继续硬化剩余 soft-surface 残留
- `8375135` 迁移漏掉的 soft-surface 页面壳
- `d932dad` 视频工具 raw Card helper 重写为 Lumen 表面
- `c998e59` 执行 Android Lumen UI 绝对 0 残留清理
- `d82cdd4` 完成 100% Lumen kit 收口

**崩溃上报 / UX 修复**

- `afbf354` 从 lumen-crash 适配 NexAI 崩溃上报
- `eefcdcd` 修复视频预览播放器 UX
- `7e97f8d` 修复跨页面交互 UX：图谱可点、笔记 FAB 遮挡、空剪贴板反馈、绘图失败提示
- `ec03166` 修复 login/sync 与 `const Theme.of` 相关 analyzer 错误

## License

[GPL-3.0](LICENSE)
