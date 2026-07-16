# Current Gap Matrix

Date: 2026-07-16
Repo: NexAI
Scope: Android Kotlin boundary (5 slices)

## Matrix

| Slice | Already present | Gap | Target |
|---|---|---|---|
| 1. Passkey provider diagnostics | Google-first/Google-only in `PasskeyChannel`; settings toggle; Kotlin `PasskeyProviderDiagnostics` + channel `diagnoseProviders` (WIP) | No Dart `diagnoseProviders`; failures lack provider inventory in auth debug context | Dart bridge + auth debug attachment |
| 2. Startup security/integrity | `SecuritySignals` + Flutter `AppSecurity.init()`; lumen-crash early install; Kotlin `StartupSecurityBootstrap` + channel method (WIP) | Dart still only loads `getSecuritySnapshot`; no startup snapshot reuse | Dart `getStartupSecuritySnapshot` + AppSecurity reuse |
| 3. Background tasks & notifications | MMKV task store, media executor, notification channels/progress | Weak task/notification linkage; permission error lacks `recoverable=true`; cancel/list field stability | Stable status machine, cancel/prune guarantees, permission-safe notifications |
| 4. Update install & package verify | sha256 verify + install intent + unknown-sources gate | No packageName/signature consistency gate before installer | Preflight identity checks; fail-closed on mismatch |
| 5. Fingerprint / anti-debug | Broad fingerprint + root/frida/xposed/debugger/emulator/vpn | Missing adb/dev-settings/debuggable/tracer enrichment and unified digest | Expand `SecuritySignals` + expose via snapshot/AppSecurity |

## WIP inventory (do not discard)

Present as untracked/modified before docs freeze:

* `android/.../security/PasskeyProviderDiagnostics.kt` (new)
* `android/.../security/StartupSecurityBootstrap.kt` (new)
* `PasskeyChannel` diagnostics wiring (partial)
* `SecurityChannel.getStartupSecuritySnapshot` (partial)
* `NexAIApplication` bootstrap call (partial)

## Unrelated dirty files (exclude from this task commits)

* `AGENTS.md` local instruction churn
* `.gitignore` local changes

## Decision log

1. Keep Flutter shell; Kotlin only for Android boundary.
2. Prefer diagnostics + fail-closed checks over process-killing protections.
3. Google-only remains default for passkey providers.
4. Formal local Trellis task: `.trellis/tasks/07-16-android-kotlin-boundary-hardening/`
5. Commit-able docs mirror: `docs/trellis/07-17-android-kotlin-boundary-hardening/`
