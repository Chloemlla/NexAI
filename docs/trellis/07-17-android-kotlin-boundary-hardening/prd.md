# Harden Android Kotlin Boundary Capabilities for NexAI

## Goal

在继续以 Flutter 作为主客户端框架的前提下，用 Kotlin 把 Android 系统边界能力做扎实，覆盖 5 个高价值切片：

1. Passkey 供应商探测与诊断
2. 启动安全/完整性检查
3. 后台任务与通知稳定性
4. 更新安装与包校验
5. 设备指纹/反调试信号

目标不是把业务 UI 重写成 Compose，而是形成可观测、可回退、可验收的 Android 原生边界层。

## What I already know

### Architecture baseline

* Flutter 负责 UI / 状态 / 跨平台业务
* Kotlin 已承担大量 Android 边界能力（channel facade 已拆分）
* 关键现状文档：`docs/android-kotlin-native-capability-migration.md`
* 安全清单：`docs/security_hardening_checklist.md`

### Existing Kotlin surfaces

| 模块 | 现状 |
|---|---|
| Passkey | `PasskeyChannel` 已支持 Google-first / Google-only；缺系统级 provider 诊断 API |
| Security | `SecuritySignals` 已有 root/debugger/emulator/VPN/frida/xposed/签名/APK hash |
| Startup | `NexAIApplication` 只装 lumen-crash + MMKV；缺统一启动安全快照 |
| Background | `BackgroundTaskChannel` + `NativeTaskStore(MMKV)`；主要是入队/查询，缺恢复与通知联动稳定性 |
| Media tasks | `MediaChannel` 有音频提取线程池；视频压缩仍占位 |
| Notifications | `NotificationChannelHandler` 有渠道/进度/权限检查 |
| Update | `UpdateChannel` 可校验 sha256 + 调起安装；缺安装前包身份/签名一致性硬校验 |
| Fingerprint | `DeviceFingerprint` 多维采集已存在；与 security 信号可再聚合 |

### Partial WIP already present in working tree

以下文件已开始落地（需纳入本任务验收，不可丢）：

* `security/PasskeyProviderDiagnostics.kt`（new）
* `security/StartupSecurityBootstrap.kt`（new）
* `PasskeyChannel` 增加 `diagnoseProviders`
* `SecurityChannel` 增加 `getStartupSecuritySnapshot`
* `NexAIApplication` 启动时非致命 bootstrap

注意：工作区还有与本任务无关的 IME/edge-to-edge 改动（`MainActivity.kt` / `home_page.dart`），实现阶段应避免混提交。

### Product constraints

* 本地禁止跑全量 build/test（走 GitHub workflow）
* 不执行安装类命令，只改代码
* 每完成一个功能切片：生成 commit message 并提交 + auto push
* GPG 签名可临时省略

## Locked Scope Decision

* **In scope**: 上述 5 个 Kotlin 边界切片 + 对应 Dart bridge + 诊断字段
* **Out of scope**:
  * Flutter 业务 UI 重写
  * Android 全量 Compose 化
  * 新增崩溃后端
  * 替换 FFmpeg 的完整原生转码器（可保留占位/提示）
  * 改后端 Happy-TTS 协议（本任务只做客户端边界）

## Assumptions

1. “Google-only” 默认仍为 true（已有设置开关）
2. 启动安全检查必须非致命：不能再引入冷启动白屏/秒退
3. 诊断信息优先进入：
   * MethodChannel 返回
   * Passkey debug context
   * lumen-crash breadcrumbs
4. 安全策略继续走“蜜罐标记”而不是本地硬杀进程
5. 更新安装必须 fail-closed 于包校验失败，但允许用户看到明确错误码

## Open Questions

当前无阻塞开放问题。若实现中发现：

* 某些 OEM 无法探测 Google Password Manager component enabled 状态
* 安装包校验需要额外签名证书链比对 API

则先以 best-effort + 明确 `error.code` 返回，不阻塞主路径。

## Requirements

### R1 — Passkey 供应商探测与诊断

1. Kotlin 提供 `PasskeyProviderDiagnostics.diagnose(context, googleOnlyPreferred)`
2. 输出至少包含：
   * GMS 是否安装
   * Google Password Manager component 是否可用
   * 已知 OEM credential 相关包列表
   * `risk`（`low` / `oem_providers_present` / `google_missing` / `google_disabled_or_hidden`）
   * `recommendedProviderMode`
3. Channel：
   * `com.chloemlla.nexai/passkeys` 增加 `diagnoseProviders`
   * 入参可带 `googleOnly`
4. Dart：
   * `AndroidPasskeyService.diagnoseProviders()`
   * bind/login 失败 debug context 自动附带 provider 诊断
5. 注册/登录路径继续：
   * Google-only 不回退
   * 非 Google-only 时 Google 优先后回退系统

### R2 — 启动安全/完整性检查

1. Kotlin 提供 `StartupSecurityBootstrap.ensureInitialized(context)`
2. 在 `Application.onCreate` 非致命执行
3. 快照聚合：
   * security snapshot
   * passkey provider diagnostics
4. 写 lumen-crash breadcrumb（rooted/debugger/frida/xposed/passkeyRisk）
5. Channel：
   * `com.chloemlla.nexai/security` 增加 `getStartupSecuritySnapshot`
6. Dart：
   * `AndroidSecurityService.getStartupSecuritySnapshot()`
   * `AppSecurity.init()` 优先复用启动快照，避免重复重探测

### R3 — 后台任务与通知稳定性

1. 任务状态机统一：`queued/running/succeeded/failed/cancelled`
2. `BackgroundTaskChannel`：
   * enqueue 时校验 type
   * cancel 幂等
   * list/get 返回稳定字段
3. 任务关键状态必须可联动通知（至少 media/update）
4. 通知：
   * 缺权限时返回 `permission_denied` 且 `recoverable=true`
   * progress 通知 `onlyAlertOnce`
   * 点击回主界面 intent 保留 route/taskId
5. Media 任务：
   * 维持线程池上限
   * cancel 后清理输出文件
   * prune terminal tasks 保持

### R4 — 更新安装与包校验

1. `verifyApkSha256` 保持
2. 新增/强化安装前校验：
   * 文件存在/可读
   * sha256 匹配（若提供 expected）
   * 包名匹配 `com.chloemlla.nexai`（可读 PackageInfo 时）
   * 签名指纹与当前安装包签名一致性（可读时）
3. 失败错误码：
   * `invalid_argument`
   * `hash_mismatch`
   * `package_mismatch`
   * `signature_mismatch`
   * `permission_denied`
   * `native_failure`
4. Dart `UpdateChecker` 安装前调用强化后的校验结果，失败时展示可读信息

### R5 — 设备指纹 / 反调试信号

1. `SecuritySignals.getSecuritySnapshot()` 增补：
   * `adbEnabled`
   * `developmentSettingsEnabled`
   * `debugBuild`（ApplicationInfo.FLAG_DEBUGGABLE）
   * `tracerPid` best-effort
   * 既有 frida/xposed/root/debugger/emulator/vpn
2. 指纹：
   * 保持现有多维采集
   * 增加与 security 的联合摘要字段（可选 `securityDigest`）
3. Dart 侧 `AppSecurity` 暴露新增信号，供请求蜜罐标记使用

### R6 — 接口与错误契约

1. 所有新增/修改方法继续 `NativeResult` envelope
2. 不允许只回 raw exception string
3. 所有新增字段向后兼容；旧 Flutter 版本忽略未知字段不崩

### R7 — 提交策略

按切片提交，建议顺序：

1. docs(trellis): Android Kotlin boundary hardening plan
2. feat(android): passkey provider diagnostics
3. feat(android): startup security bootstrap
4. fix(android): stabilize background tasks and notifications
5. feat(android): harden update package verification
6. feat(android): expand anti-debug and fingerprint signals
7. feat(dart): bridge new Android boundary diagnostics

## Acceptance Criteria

### Global

* [ ] 5 个切片都有 Kotlin 实现与 Dart 可调用入口
* [ ] 启动路径无新增致命异常
* [ ] Passkey debug 能看到 provider 诊断
* [ ] 更新安装在 hash/包名/签名不匹配时 fail-closed
* [ ] 每个切片独立 commit + push
* [ ] 不混入无关 IME/edge-to-edge 改动（除非单开 commit）

### R1 Passkey

* [ ] `diagnoseProviders` 可返回 GMS/OEM/risk/recommendedMode
* [ ] Google-only=true 时不回退系统 provider
* [ ] 失败 debug context 包含 provider 诊断

### R2 Startup Security

* [ ] `Application.onCreate` 生成启动快照且不炸进程
* [ ] `getStartupSecuritySnapshot` 可重复读取
* [ ] breadcrumb 写入成功或 best-effort 失败可忽略

### R3 Tasks/Notifications

* [ ] cancel/list/get 行为稳定
* [ ] 通知权限缺失返回明确错误码
* [ ] media cancel 清理输出

### R4 Update Verify

* [ ] 安装前可做 sha256 + package + signature 校验
* [ ] 校验失败不会拉起系统安装器

### R5 Fingerprint/Anti-debug

* [ ] security snapshot 含 adb/dev settings/debugBuild 等字段
* [ ] Dart `AppSecurity` 能读到并用于蜜罐标记

## Non-Goals

* 不重写聊天/设置/笔记 UI
* 不引入新的商业化风控后端协议
* 不在本任务完成完整原生视频转码器

## Delivery Plan (implementation slices)

### Slice A — Docs (this task)
输出 Trellis 文档，冻结需求。

### Slice B — Passkey diagnostics
Kotlin diagnostics + channel + Dart bridge + debug context.

### Slice C — Startup security
Bootstrap + Application hook + security channel + AppSecurity reuse.

### Slice D — Background/notification stability
Task/notify hardening without API 破坏。

### Slice E — Update package verification
Install-time identity checks.

### Slice F — Anti-debug/fingerprint expansion
Signal enrichment + Dart exposure.

## Risks

| Risk | Mitigation |
|---|---|
| OEM 隐藏 GMS component 状态不可靠 | risk 分级 + best-effort notes |
| 启动检查过重拖慢冷启动 | 只做轻量同步探测；重 I/O 保持现有懒加载 |
| 安装包解析 API 版本差异 | version-gated + 失败可恢复错误码 |
| 工作区混杂无关改动 | 提交时严格 path-scope |

## Validation

* 代码级静态检查（通读关键路径）
* 依赖 GitHub workflow 做权威 Android release 构建
* 手动场景清单（设备侧）：
  1. 有 GMS 的机器 bindPasskey（Google-only on/off）
  2. 冷启动后拉 startup snapshot
  3. 媒体任务取消后通知/文件清理
  4. 错误 APK hash 安装被拒
  5. 调试器/开发者选项信号可见