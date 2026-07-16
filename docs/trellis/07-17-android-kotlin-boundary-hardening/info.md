# Technical Design — Android Kotlin Boundary Hardening

## 1. Architecture

```
Flutter
  AuthProvider / AppSecurity / UpdateChecker / Media services
        | MethodChannel / EventChannel
Kotlin facade
  PasskeyChannel
  SecurityChannel
  BackgroundTaskChannel
  NotificationChannelHandler
  UpdateChannel
  DeviceFingerprintChannel
        |
Domain helpers
  PasskeyProviderDiagnostics
  StartupSecurityBootstrap
  SecuritySignals
  NativeTaskStore
  DeviceFingerprint
```

原则：

* Flutter 只消费稳定 facade
* Kotlin 处理 OEM/API 版本差异
* 启动路径全部 `runCatching`，禁止 fail-open 成进程崩溃
* 错误统一 `NativeResult`

## 2. API Surface

### 2.1 Passkey

Channel: `com.chloemlla.nexai/passkeys`

| Method | Args | Result data |
|---|---|---|
| `diagnoseProviders` | `{ googleOnly?: bool }` | provider diagnostics map |
| `register` | `{ requestJson, googleOnly? }` | existing + diagnostics fields |
| `authenticate` | `{ requestJson, googleOnly? }` | existing + diagnostics fields |

Diagnostics map:

```json
{
  "checkedAt": 0,
  "googlePlayServicesInstalled": true,
  "googlePasswordManagerEnabled": true,
  "googleOnlyPreferred": true,
  "recommendedProviderMode": "google_password_manager_only",
  "oemProviders": [],
  "risk": "low",
  "notes": []
}
```

### 2.2 Security / Startup

Channel: `com.chloemlla.nexai/security`

| Method | Notes |
|---|---|
| `getSecuritySnapshot` | existing, enrich anti-debug fields |
| `getStartupSecuritySnapshot` | new; returns bootstrap aggregate |
| existing detection methods | keep compatibility |

Startup snapshot:

```json
{
  "checkedAt": 0,
  "security": { "...SecuritySignals snapshot..." },
  "passkeyProviders": { "...PasskeyProviderDiagnostics..." },
  "source": "android_kotlin_native"
}
```

### 2.3 Background / Notifications

Keep channels:

* `com.chloemlla.nexai/background`
* `com.chloemlla.nexai/notifications`
* `com.chloemlla.nexai/native_task_events`

Hardening focus is behavioral stability, not new public surface.

Optional additive fields only:

* task: `lastErrorCode`, `notificationId`
* notification state: `channelsInitialized`

### 2.4 Update

Channel: `com.chloemlla.nexai/update`

Enhance:

* `verifyApkSha256` (keep)
* `installApk` preflight checks
* optional new `verifyApkPackage` returning packageName/version/signature

Suggested verify payload:

```json
{
  "sha256": "...",
  "matches": true,
  "packageName": "com.chloemlla.nexai",
  "versionName": "...",
  "versionCode": 0,
  "signatureSha256": "...",
  "signatureMatchesInstalled": true
}
```

### 2.5 Fingerprint / Anti-debug

Channel compatibility:

* `com.chloemlla.nexai/security`
* `com.chloemlla.nexai/fingerprint`

Security snapshot additive fields:

* `adbEnabled`
* `developmentSettingsEnabled`
* `debugBuild`
* `tracerPid`
* `antiDebugScore` (0..1 optional)

## 3. Dart Bridges

| Dart API | Native |
|---|---|
| `AndroidPasskeyService.diagnoseProviders` | passkeys/diagnoseProviders |
| `AndroidSecurityService.getStartupSecuritySnapshot` | security/getStartupSecuritySnapshot |
| `AppSecurity.init` reuse startup snapshot | security/* |
| `UpdateChecker` pre-install verify | update/verify* + installApk |
| Passkey debug context enrichment | diagnoseProviders |

## 4. Implementation Order

1. Docs/trellis freeze
2. Complete Passkey diagnostics end-to-end (incl. Dart + debug context)
3. Startup security bootstrap Dart bridge + AppSecurity reuse
4. Background/notification stability fixes
5. Update package verification
6. Anti-debug/fingerprint enrichment

## 5. Commit Hygiene

* One slice per commit
* Do not include unrelated IME/`home_page` edge-to-edge changes in boundary commits
* Push after each slice

## 6. Test Matrix (workflow + device)

| Case | Expected |
|---|---|
| Cold start release | no white-screen; startup snapshot available |
| Passkey Google-only on | only Google provider used |
| Passkey Google-only off + Google fail | fallback system path |
| diagnoseProviders on vivo OEM | risk notes + oemProviders |
| install wrong hash APK | install blocked with hash_mismatch |
| cancel media task | status cancelled + output cleaned |
| debugger attached | security snapshot flags debugger/adb/dev settings |

## 7. Rollback Plan

Each slice is independently revertable.

If startup diagnostics regress cold start:

* keep installSafely/runCatching shells
* disable only heavy checks, never remove crash SDK install path