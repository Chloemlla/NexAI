# Current Gap Matrix

Date: 2026-07-17
Repo: NexAI
Scope: Android Kotlin boundary (5 slices)

## Matrix

| Slice | Already present | Gap | Target |
|---|---|---|---|
| 1. Passkey provider diagnostics | Google-first/Google-only selection in `PasskeyChannel`; settings toggle `passkeyGoogleOnly` | No structured OEM/GMS diagnostics API; failures lack provider inventory | `PasskeyProviderDiagnostics` + `diagnoseProviders` + Dart debug attachment |
| 2. Startup security/integrity | `SecuritySignals` + Flutter `AppSecurity.init()` after engine start; lumen-crash install early | No unified pre-Flutter startup snapshot; AppSecurity may re-probe everything | `StartupSecurityBootstrap` in `Application.onCreate` + channel readback + AppSecurity reuse |
| 3. Background tasks & notifications | MMKV task store, media executor, notification channels/progress | Weak cross-linking of task lifecycle and notifications; limited recovery semantics | Stable status machine, cancel/prune guarantees, permission-safe notifications |
| 4. Update install & package verify | sha256 verify + install intent + unknown-sources gate | No packageName/signature consistency gate before installer | Preflight identity checks; fail-closed on mismatch |
| 5. Fingerprint / anti-debug | Broad fingerprint + root/frida/xposed/debugger/emulator/vpn | Missing adb/dev-settings/debuggable/tracer enrichment and unified digest | Expand `SecuritySignals` + expose via snapshot/AppSecurity |

## WIP inventory (do not discard)

Present as untracked/modified before this docs freeze:

* `android/.../security/PasskeyProviderDiagnostics.kt` (new)
* `android/.../security/StartupSecurityBootstrap.kt` (new)
* `PasskeyChannel` diagnostics wiring (partial)
* `SecurityChannel.getStartupSecuritySnapshot` (partial)
* `NexAIApplication` bootstrap call (partial)

## Unrelated dirty files (exclude from this task commits)

* `android/.../MainActivity.kt` edge-to-edge IME helper changes
* `lib/pages/home_page.dart` keyboard inset handling
* `AGENTS.md` local instruction churn

## Decision log

1. Keep Flutter shell; Kotlin only for Android boundary.
2. Prefer diagnostics + fail-closed checks over process-killing protections.
3. Google-only remains default for passkey providers.
4. Use docs/trellis task shape because NexAI has no full `.trellis` runtime.