# Fuck My Shit Mountain Audit Report

**Project:** NexAI
**Audit mode:** full
**Date:** 2026-07-04
**Reviewer:** Codex / GPT-5

---

## 1. Executive Summary

NexAI 是一个 Flutter/Dart OpenAI-compatible 客户端，代码已经覆盖聊天、笔记、密码、同步、Artifacts、更新、安全检测和 Android native channel。整体形态接近可发布应用，但当前稳定发布的主要阻塞点不在 UI 观感，而在数据一致性、同步恢复、CI 供应链权限、关键路径测试缺口和几个过大的状态/UI 文件。

最强的正面信号是：敏感设置已迁移到 `FlutterSecureStorage`，聊天错误诊断有脱敏逻辑，崩溃报告存储使用原子写入，Android release 构建会强制签名，`pubspec.lock` 已提交。主要风险是：云同步会跳过不可解密记录后继续覆盖本地数据，HTTP backend 客户端没有统一超时，媒体 native 任务没有并发/保留上限，CI 使用 PAT、宽权限和 floating action ref，测试几乎没有覆盖 auth/sync/provider/Android channel。

本次审计未运行本地构建、测试或安装命令，遵守仓库要求；只做静态审计和证据读取。整体评分为 **6.0 / B**：可以继续迭代，但不建议把当前状态视为稳定公开发布基线。

### Score Dashboard

```
Security        ██████░░░░  6.4  B   Secure storage and redaction exist, but request signing fails open and CI/PAT surface is broad.
Stability       █████░░░░░  5.6  B   Sync restore, no-timeout backend calls, direct JSON writes, and native task concurrency create realistic failure modes.
Performance     ██████░░░░  6.1  B   Main bottlenecks are unbounded media/native work, large retained UI/state surfaces, and linear in-memory searches.
Testing         ███░░░░░░░  3.5  C   Existing tests cover update comparison and Markdown only; critical providers and native flows are untested.
Maintainability █████░░░░░  5.2  B   Multiple files exceed 1000 lines and UI components orchestrate business flows directly.
Design          █████░░░░░  5.5  B   SRP, fail-fast, timeout, and boundary-contract issues are concentrated in sync, providers, and API wrappers.
Release         ██████░░░░  6.0  B   CI builds artifacts and checksums, but permissions, action pinning, manifest/signature, rollback docs, and test gates need work.
─────────────────────────────────────
Overall         ██████░░░░  6.0  B
```

Each dimension scored 0.0–10.0. **Higher = better (10 = clean, 0 = shit mountain).** Scores are judgment-based, not formula-based. See `rubrics/scoring.md` for anchor descriptions.

### Finding Statistics

| Severity | Count | Confirmed | Suspected |
|----------|-------|-----------|-----------|
| Critical | 0 | 0 | 0 |
| High | 3 | 3 | 0 |
| Medium | 10 | 10 | 0 |
| Low | 4 | 4 | 0 |
| Info | 1 | 1 | 0 |
| **Total** | **18** | **18** | **0** |

## 2. Project Map

Runtime starts in `lib/main.dart`, creates shared Provider instances (`ChatProvider`, `NotesProvider`, `PasswordProvider`, `TranslationProvider`, `ShortUrlProvider`, `AuthProvider`) and wires UI through `Provider`. UI screens live in `lib/pages/`, reusable rendering and dialogs in `lib/widgets/`, app state and API-facing orchestration in `lib/providers/`, HTTP/security/backend integrations in `lib/services/` and `lib/utils/`, data models in `lib/models/`, and Android native channel code in `android/app/src/main/kotlin/com/chloemlla/nexai/`.

Data flow is mostly local-first: chats/notes/image history are JSON files under application documents, passwords and secrets use secure storage, translation/short-url history use `SharedPreferences`, sync uploads encrypted records to the NexAI backend, and auth/artifacts/sync use signed+pinned HTTP wrappers. AI/model surfaces include chat completions, Vertex streaming, image generation/editing, title generation, and translation. Release flow is GitHub Actions based for Android/Web/Windows, with Android signing secrets injected in CI.

Most likely risk areas are sync restore, local persistence writes, request signing/pinning wrappers, update/release artifact integrity, native media background work, and large UI/provider files that mix view code with business orchestration.

### Coverage Matrix

| Dimension | Coverage | Evidence inspected | Exclusions / limits |
|-----------|----------|--------------------|---------------------|
| Architecture | Medium | `lib/main.dart`, providers, services, Android channels, line-count inventory | No runtime dependency graph generated |
| Security | Medium | secure storage, request signing, pinning, CI secrets, artifact/update paths, secret regex search | No dependency CVE scan or dynamic attack testing |
| Stability | Medium | error handling, direct file writes, HTTP calls, sync restore, native tasks | No local `flutter test` or stress testing |
| Performance | Medium | media tasks, large files, search loops, model/API calls | No profiling or benchmark execution |
| Testing | High | `test/`, workflow commands, critical code paths mapped to tests | Did not run tests locally |
| Maintainability | High | file-size inventory, providers/pages/services, duplication search | No automated complexity tool run |
| Design | Medium | principle rubrics applied to sync, providers, API wrappers, CI | No architectural diagrams generated |
| Release | High | `.github/workflows/*.yml`, Gradle, scripts, README, release docs | Did not execute workflows |
| Documentation | Medium | README, backend/security docs, migration docs, scripts README | Did not validate screenshots or external docs |
| Observability | Medium | crash reporter, debug logs, security headers, CI logs | No production telemetry backend inspected |
| Configuration | Medium | `pubspec.yaml`, Gradle, settings provider, workflows | No environment matrix execution |
| Data-Integrity | High | local JSON persistence, sync encryption/restore, password backups | No fault-injection run |
| Privacy | Medium | password storage/export, crash reports, logs, sync payloads | No privacy policy/legal review |
| Accessibility | Low | Representative Flutter UI code and dialogs | No screen reader/keyboard runtime inspection |
| Supply-Chain | High | workflows, action refs, Gradle, lockfile, release assets | No SBOM/CVE tooling run |
| Cost | Medium | LLM calls, translation, image generation, media work, history retention | No billing telemetry available |
| AI-Safety | Medium | chat, Vertex, image, translation prompts and budgets | No red-team/eval execution |
| Fallback | High | `catch`, null returns, silent fallbacks, disabled legacy paths | Static only |
| Testing-Authenticity | High | all tests and missing critical paths | No mutation testing |
| Type-Safety | Medium | model `fromJson`, sync maps, native channel maps | No analyzer run |
| Frontend-State | High | large pages/providers, state orchestration in UI | No UI runtime inspection |
| Backend-API | Medium | Flutter API clients/contracts for auth/sync/artifacts | Backend implementation not in repo |
| Dependency-Weight | Medium | `pubspec.yaml`, Gradle deps, media deps | No binary size analysis |
| Code-Consistency | High | API wrapper duplication, persistence/error patterns | No formatter/analyzer run |
| Comment-Coverage | Medium | public comments, docs, TODO-like searches | Did not inspect every inline comment |

## 3. Top Risks

1. **High — Sync restore can overwrite local data with a partial decrypted snapshot.** `_decryptSnapshot` skips bad records and `_restoreLocalData` still clears/restores provider lists.
2. **High — Critical auth/sync/artifact paths have no tests.** Existing tests cover update comparison and Markdown only.
3. **High — CI release surface uses PAT, broad write permissions, and floating action refs.** Workflow compromise has direct release impact.
4. **Medium — Backend HTTP wrappers lack explicit request timeouts.** Auth/sync/artifact calls can hang indefinitely behind the pinned `http.Client`.
5. **Medium — Local JSON persistence uses direct overwrite without atomic write.** Chat, notes, and generated image histories can be truncated or corrupted on crash.
6. **Medium — Native media tasks are unbounded.** Each audio extraction starts a thread and task storage has no retention/pruning.
7. **Medium — Request signing fails open and has a shared fallback device ID.** Signing errors return unsigned headers instead of failing closed.
8. **Medium — Cloud sync key is local-only and unrecoverable after device loss.** Encrypted cloud data is not portable unless the same secure storage key remains.
9. **Medium — Stable-release update integrity is incomplete.** Client download path opens browser URLs and does not bind asset selection to a verified expected hash before install.
10. **Medium — Large UI/provider files violate SRP and slow safe change.** `settings_page.dart`, `auth_provider.dart`, media pages, and password page are oversized.
11. **Low — Documentation overstates or conflicts with implemented behavior.** README still describes WebDAV/Upstash sync and local dev commands while implementation uses NexAI sync v2 and repo rules forbid local build/test for agents.
12. **Low — Password setup script prints secret values during setup.** Local terminal history/screenshots can expose signing credentials.

## 4. Detailed Findings

### Finding: Sync restore can overwrite local data with a partial decrypted snapshot

- Severity: High
- Confidence: High
- Category: Stability
- Status: Confirmed
- Affected area: Cloud sync restore / data integrity
- Evidence:
  - File: `lib/providers/sync_provider.dart:387`
  - Function / Module: `_decryptSnapshot`, `_restoreLocalData`
  - Relevant behavior: Undecryptable records are skipped, restore only fails when zero records decrypt, then provider `restoreFromList` calls overwrite local state.
- Problem: A cloud snapshot with one corrupt/tampered/mismatched-key record can still be treated as usable. The restore path then clears local notes/conversations/history for categories present in the partial result.
- Why it matters: Partial restore is a realistic data-loss path because corruption, interrupted upload, schema mismatch, or key mismatch can affect only part of a snapshot.
- Realistic failure scenario: User downloads cloud data after one record fails AES-GCM decrypt; `_decryptSnapshot` logs and skips it; `_restoreLocalData` calls `notesProvider.restoreFromList` or `chatProvider.restoreFromList`; missing records disappear locally and later upload makes the loss durable.
- Minimal fix: Treat any undecryptable record in a category as restore failure unless the record is explicitly marked deleted; validate expected counts or snapshot manifest before applying.
- Better long-term fix: Restore into a staging model, show a diff, then commit atomically after all categories pass validation.
- Regression test suggestion: Build a snapshot with two note records where one has invalid ciphertext; assert `downloadAll` refuses to clear local notes.
- Estimated effort: 1 day

### Finding: Critical auth, sync, provider, and native flows lack tests

- Severity: High
- Confidence: High
- Category: Testing
- Status: Confirmed
- Affected area: Test suite / release confidence
- Evidence:
  - File: `test/update_checker_test.dart:6`, `test/widgets/markdown_render_utils_test.dart:5`, `test/widgets/markdown_renderer_test.dart:8`
  - Function / Module: `test/`
  - Relevant behavior: Tests cover update version comparison and Markdown rendering utilities, but no tests reference `ChatProvider`, `NotesProvider`, `SyncProvider`, `PasswordProvider`, `AuthProvider`, `NexaiAuthApi`, Android channels, or encrypted sync.
- Problem: The riskiest data and security paths can regress without a failing test.
- Why it matters: Sync restore, secure storage migration, token refresh, passkey auth, password import/restore, and native media task behavior are all release-critical.
- Realistic failure scenario: A future sync refactor changes category names or decrypt behavior; workflows still pass because no sync/provider tests exercise the path.
- Minimal fix: Add focused unit tests for sync decrypt/restore, provider persistence parsing, password backup restore, request signing failure behavior, and update hash extraction.
- Better long-term fix: Add CI gates for `flutter analyze` and `flutter test` plus Android channel contract tests behind fakes.
- Regression test suggestion: Add `test/providers/sync_provider_test.dart`, `test/providers/password_provider_test.dart`, and `test/services/request_signer_test.dart` with fake storage/API boundaries.
- Estimated effort: 2-4 days

### Finding: GitHub Actions release surface has broad write permission and floating action refs

- Severity: High
- Confidence: High
- Category: Security
- Status: Confirmed
- Affected area: CI/CD supply chain
- Evidence:
  - File: `.github/workflows/build.yml:21`
  - Function / Module: Build and release workflows
  - Relevant behavior: Workflows set `contents: write`, checkout uses `secrets.USER_PAT`, `softprops/action-gh-release@master` and `subosito/flutter-action@main` are floating refs; release job uses `permissions: write-all` at `.github/workflows/release.yml:257`.
- Problem: A compromised action tag/branch or over-scoped PAT has enough permission to write repository contents or publish release assets.
- Why it matters: This project distributes binaries; CI compromise becomes a direct artifact integrity risk.
- Realistic failure scenario: Upstream floating ref changes unexpectedly; workflow runs on push/tag; malicious build step publishes altered APKs under a legitimate release.
- Minimal fix: Pin third-party actions to immutable SHAs, replace PAT checkout where `GITHUB_TOKEN` is enough, and scope job permissions per job.
- Better long-term fix: Add provenance/SLSA attestation, environment protection for releases, and separate build from publish permissions.
- Regression test suggestion: Add a workflow policy check that rejects `@main`, `@master`, `write-all`, and unneeded PAT usage.
- Estimated effort: 0.5-1 day

### Finding: Backend API clients have no explicit request timeout

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Affected area: Auth, sync, artifacts backend calls
- Evidence:
  - File: `lib/services/nexai_auth_service.dart:44`
  - Function / Module: `_NexaiHttp.post/get/put`
  - Relevant behavior: Calls `(await _get()).post/get/put(...)` on `http.Client` with no `.timeout(...)`; same pattern exists in `lib/services/nexai_sync_service.dart:41` and `lib/services/nexai_artifacts_service.dart:40`.
- Problem: Network or TLS stalls can leave login, sync, artifact CRUD, and passkey flows waiting indefinitely.
- Why it matters: UI loading states and restore/upload operations can remain stuck, and failures become hard to distinguish from slow networks.
- Realistic failure scenario: Backend accepts a TCP connection but never completes a response; `downloadAll` stays in `SyncStatus.downloading`, user cannot tell whether cloud restore is safe to retry.
- Minimal fix: Apply a shared timeout wrapper to every backend request and convert timeout into typed errors.
- Better long-term fix: Centralize backend HTTP in one client with timeout, retry budget, correlation ID, and redacted diagnostics.
- Regression test suggestion: Use a fake `http.Client` future that never completes and assert provider status becomes error after configured timeout.
- Estimated effort: 4-6 hours

### Finding: Local JSON stores use non-atomic overwrite for user data

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Affected area: Chat, notes, generated image history
- Evidence:
  - File: `lib/providers/chat_provider.dart:176`
  - Function / Module: `_save`
  - Relevant behavior: Chat writes `nexai_chats.json` via `file.writeAsString(...)`; notes use the same pattern in `lib/providers/notes_provider.dart:232`; image history uses it in `lib/providers/image_generation_provider.dart:98`.
- Problem: A crash, disk error, or interruption during overwrite can leave a truncated JSON file and make later loads fail.
- Why it matters: These files hold primary user data. The project already has an atomic writer in `CrashReportStore`, so the risk is known and locally fixable.
- Realistic failure scenario: App is killed during `_save()` after a long conversation update; next startup `Conversation.decodeList` throws, load logs the error and the user sees missing chat history.
- Minimal fix: Reuse an atomic write helper: write to `*.tmp` with flush, rename over the target, keep previous file until the temp write succeeds.
- Better long-term fix: Add backup rotation and corruption recovery per store.
- Regression test suggestion: Simulate a partial write temp file and assert load keeps the last valid file.
- Estimated effort: 1 day

### Finding: Native media work starts unbounded threads and retains tasks indefinitely

- Severity: Medium
- Confidence: High
- Category: Performance
- Status: Confirmed
- Affected area: Android media channel / background tasks
- Evidence:
  - File: `android/app/src/main/kotlin/com/chloemlla/nexai/channels/MediaChannel.kt:114`
  - Function / Module: `startAudioExtraction`, `NativeTaskStore`
  - Relevant behavior: Every extraction starts `thread(name = "nexai-audio-extract-$taskId")`; task records are stored in MMKV by `NativeTaskStore.put` and `list` has no retention or pruning.
- Problem: User or UI retries can create many native threads and persistent task records without a cap.
- Why it matters: Media files are large, native extraction is CPU/I/O heavy, and unbounded threads can degrade or crash the app.
- Realistic failure scenario: User taps extraction repeatedly on several videos; each call starts a thread, cache outputs accumulate, task list grows, and the app becomes unresponsive.
- Minimal fix: Use a bounded executor, reject/queue tasks after a small limit, and add task/output cleanup for terminal states.
- Better long-term fix: Move native media jobs to WorkManager with constraints, cancellation, retention, and progress persistence.
- Regression test suggestion: Native unit/instrumentation test enqueues N+1 tasks and asserts only N run concurrently and old terminal tasks are pruned.
- Estimated effort: 1-2 days

### Finding: Request signing fails open and can fall back to a shared device identifier

- Severity: Medium
- Confidence: High
- Category: Security
- Status: Confirmed
- Affected area: Backend request signing
- Evidence:
  - File: `lib/utils/request_signer.dart:38`
  - Function / Module: `signRequest`, `_getDeviceId`
  - Relevant behavior: Web returns headers unsigned; signing exceptions are caught and original headers returned; device-info failure uses raw value `nexai-fallback-id`.
- Problem: A security control that silently disables itself is hard to enforce server-side, and fallback ID makes signatures predictable for any environment where device info fails.
- Why it matters: README describes HMAC request signing as scraping protection. Fail-open behavior weakens that boundary and makes errors invisible to callers.
- Realistic failure scenario: DeviceInfoPlugin fails after a platform update; requests continue without signature or with a common fallback-derived key; backend cannot reliably distinguish legitimate devices.
- Minimal fix: Return a typed signing failure for endpoints requiring signing, and use a per-install random secure-storage ID instead of a constant fallback.
- Better long-term fix: Negotiate signed capability with backend and make unsigned web calls explicitly scoped to public endpoints.
- Regression test suggestion: Mock DeviceInfoPlugin failure and assert signed backend clients fail closed or generate a unique persisted fallback ID.
- Estimated effort: 1 day

### Finding: Cloud sync encryption key is local-only and has no recovery story

- Severity: Medium
- Confidence: High
- Category: Data-Integrity
- Status: Confirmed
- Affected area: Encrypted sync v2
- Evidence:
  - File: `lib/utils/sync_crypto.dart:82`
  - Function / Module: `_getOrCreateKey`
  - Relevant behavior: AES-256-GCM key is randomly generated and stored only in local secure storage under `nexai.sync.v2.key`.
- Problem: Cloud sync data becomes undecryptable after device loss, secure storage reset, reinstall, or a second device unless the same local key is preserved.
- Why it matters: A user-facing cloud sync feature is normally expected to restore data across device lifecycle events.
- Realistic failure scenario: User uploads encrypted sync, reinstalls the app, logs in, and `downloadAll` returns `无法解密云端同步数据` because the old key is gone.
- Minimal fix: Document this limitation clearly in the sync UI and block destructive restore attempts when the local key is missing.
- Better long-term fix: Add a user passphrase/recovery key flow with KDF, key rotation, and explicit backup warnings.
- Regression test suggestion: Encrypt with one `SyncCrypto` key, clear secure storage, then assert download refuses restore without modifying local data.
- Estimated effort: 1-3 days depending on recovery design

### Finding: Update download path does not bind selected APK to verified release metadata

- Severity: Medium
- Confidence: High
- Category: Release
- Status: Confirmed
- Affected area: Android update flow / artifact integrity
- Evidence:
  - File: `lib/utils/update_checker.dart:253`
  - Function / Module: `_downloadAndInstall`
  - Relevant behavior: The update flow selects an APK asset and opens `browser_download_url` externally; hash extraction exists elsewhere in `AppSecurity`, and `UpdateChannel.verifyApkSha256` exists, but this path does not verify before handing off download/install.
- Problem: The user-facing update action does not enforce the release checksum/manifest before the user obtains the APK.
- Why it matters: Release notes checksums help manual verification, but the app's primary update UX does not use them.
- Realistic failure scenario: A compromised release asset or wrong ABI asset is selected; user installs from browser; only later runtime integrity may flag issues, not prevent the installation path.
- Minimal fix: Fetch a manifest or checksum asset, download in-app to controlled storage, verify SHA256, then call native install only on match.
- Better long-term fix: Sign release manifest and verify signature in the app before presenting install.
- Regression test suggestion: Feed release JSON with APK asset plus mismatched checksum and assert install flow refuses to launch.
- Estimated effort: 1-2 days

### Finding: Oversized UI and provider files violate SRP and increase change risk

- Severity: Medium
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Affected area: Pages/providers
- Evidence:
  - File: `lib/pages/settings_page.dart:1`
  - Function / Module: `SettingsPage`, `AuthProvider`, media/password pages
  - Relevant behavior: `settings_page.dart` has 2360 lines, `auth_provider.dart` 1499, `password_generator_page.dart` 1586, `video_compressor_page.dart` 1509, `note_detail_page.dart` 1957.
- Problem: These files combine rendering, form state, provider orchestration, dialogs, networking calls, and domain decisions.
- Why it matters: Changes such as sync recovery, OAuth diagnostics, or password backup behavior require editing large files with many unrelated responsibilities.
- Realistic failure scenario: A settings UI change accidentally changes sync behavior because the button handlers orchestrate provider reads and cloud operations inline.
- Minimal fix: Extract feature sections and command objects for sync, update, OAuth/passkey diagnostics, and password import/export.
- Better long-term fix: Make pages mostly compose widgets; move workflow orchestration to focused controllers/services.
- Regression test suggestion: Before splitting, add widget tests for settings sync/update controls and provider tests for extracted commands.
- Estimated effort: 3-5 days incrementally

### Finding: Backend API wrappers duplicate signing/pinning/error patterns

- Severity: Medium
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Affected area: Auth, sync, artifacts services
- Evidence:
  - File: `lib/services/nexai_auth_service.dart:14`
  - Function / Module: `_NexaiHttp`, `_Http`
  - Relevant behavior: Auth, sync, and artifacts each define their own static HTTP wrapper with client caching, `_base`, signing, and raw `http.Client` calls.
- Problem: Timeout, redaction, correlation IDs, retries, fail-closed signing, and pinning behavior must be fixed in several places.
- Why it matters: Security/stability fixes are easy to apply inconsistently.
- Realistic failure scenario: Timeout is added to auth but not sync; login behaves well on network stalls while cloud restore still hangs.
- Minimal fix: Introduce one `NexaiBackendClient` with signed/pinned methods and typed errors.
- Better long-term fix: Add request/response interceptors, redacted diagnostics, and testable fake client injection.
- Regression test suggestion: Shared client test verifies all methods apply signing, timeout, and redaction consistently.
- Estimated effort: 1-2 days

### Finding: Model and sync boundaries rely on unchecked dynamic casts

- Severity: Medium
- Confidence: High
- Category: Design
- Status: Confirmed
- Affected area: JSON parsing and cloud restore
- Evidence:
  - File: `lib/models/message.dart:63`
  - Function / Module: `Conversation.fromJson`, `Note.fromJson`, sync restore
  - Relevant behavior: `Conversation.fromJson` casts `messages` as `List` and nested items as `Map<String,dynamic>`; `Note.fromJson` casts required fields directly; sync passes decrypted maps directly into provider restores.
- Problem: External or persisted data shape errors become exceptions instead of typed validation failures.
- Why it matters: Local files and cloud sync are user-data boundaries; a single malformed record can break loading or trigger partial restore behavior.
- Realistic failure scenario: Older app version wrote a conversation without `messages`; current restore throws during `Conversation.fromJson`, and the user gets a generic download failure or partial load.
- Minimal fix: Add `tryParse`/validation results for persisted models and collect per-record validation errors before applying restore.
- Better long-term fix: Version schemas with migrations and typed error reporting per category.
- Regression test suggestion: Feed malformed conversation/note JSON and assert valid records load while invalid records are quarantined without clearing local data.
- Estimated effort: 1-2 days

### Finding: Password setup helper prints signing secrets in plaintext

- Severity: Low
- Confidence: High
- Category: Security
- Status: Confirmed
- Affected area: Android signing helper script
- Evidence:
  - File: `scripts/setup-android-signing.cmd:253`
  - Function / Module: signing setup script
  - Relevant behavior: The script echoes `KEYSTORE_PASSWORD` and `KEY_PASSWORD` values to console before setting GitHub secrets.
- Problem: Secrets can leak into terminal scrollback, screenshots, screen sharing, or CI logs if the script is reused.
- Why it matters: Signing key passwords protect release artifacts.
- Realistic failure scenario: Developer runs the setup during a recorded support session and exposes the keystore password.
- Minimal fix: Print only secret names and masked values; avoid echoing password variables.
- Better long-term fix: Use `gh secret set` prompts or temporary files with cleanup and no plaintext display.
- Regression test suggestion: Static script test/search that fails on `echo %STORE_PASSWORD%` and `echo %KEY_PASSWORD%` outside secret-setting commands.
- Estimated effort: 30 minutes

### Finding: Crash reports sanitize paths but not token-like values

- Severity: Low
- Confidence: High
- Category: Privacy
- Status: Confirmed
- Affected area: Crash report export
- Evidence:
  - File: `lib/models/crash_report.dart:149`
  - Function / Module: `_sanitize`
  - Relevant behavior: Sanitization removes user home paths and file/content URIs, but not bearer tokens, API keys in query strings, or `sk-`/`AIza`-style keys.
- Problem: Exceptions that include request URLs or headers can leave secrets in local crash report text and clipboard export.
- Why it matters: Crash reports are intended for diagnostics and may be shared by users.
- Realistic failure scenario: A Dio exception includes a URL containing `?key=...`; crash report is copied to support with the key intact.
- Minimal fix: Reuse the same secret redaction patterns already present in `ChatProvider`.
- Better long-term fix: Centralize redaction as a utility used by chat diagnostics, crash reports, logs, and artifact errors.
- Regression test suggestion: CrashReport.fromError with `Bearer`, `sk-`, `AIza`, and query token strings should redact them.
- Estimated effort: 2-3 hours

### Finding: Translation and image generation lack abuse/cost budgets beyond basic output caps

- Severity: Low
- Confidence: High
- Category: Performance
- Status: Confirmed
- Affected area: AI/model surfaces
- Evidence:
  - File: `lib/pages/translation_page.dart:66`
  - Function / Module: `_translate`, `ImageGenerationProvider`
  - Relevant behavior: Translation sends full user text directly to Gemini with `maxOutputTokens: 2048`; image generation accepts prompt/image inputs and image count parameters without centralized per-user/request budget enforcement.
- Problem: Large pasted inputs or repeated generation can produce avoidable model/API cost and latency.
- Why it matters: LLM/API spend and rate limits are part of reliability for an AI client.
- Realistic failure scenario: User pastes a very large document into translation; the request fails late or consumes large token budget repeatedly.
- Minimal fix: Add visible input length/token estimate limits and local request throttling per feature.
- Better long-term fix: Add per-provider budget policy with counters for tokens/images/requests and user-configurable caps.
- Regression test suggestion: Widget/provider tests assert over-limit text/image counts are rejected before network call.
- Estimated effort: 0.5-1 day

### Finding: README and implementation disagree on sync and configuration defaults

- Severity: Low
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Affected area: Documentation
- Evidence:
  - File: `README.md:54`
  - Function / Module: README vs sync/settings code
  - Relevant behavior: README says cloud sync uses WebDAV or Upstash Redis and settings persist via `SharedPreferences`; current sync buttons call `SyncProvider.uploadAll/downloadAll` against NexAI sync v2, while sensitive settings use `FlutterSecureStorage`.
- Problem: Docs describe older behavior and can mislead users and maintainers.
- Why it matters: Sync and storage are sensitive areas where wrong expectations lead to bad backups and support load.
- Realistic failure scenario: User expects WebDAV backup to contain chats/passwords based on README, but cloud sync behavior and password non-sync differ.
- Minimal fix: Update README with current NexAI sync v2 behavior, password non-sync policy, secure storage split, and local-key recovery limitation.
- Better long-term fix: Add a short architecture/security doc generated from current providers/services.
- Regression test suggestion: Docs check that README sync keywords match current supported providers or a maintained feature matrix.
- Estimated effort: 1-2 hours

### Finding: View tracking intentionally swallows all failures without a signal

- Severity: Info
- Confidence: High
- Category: Stability
- Status: Confirmed
- Affected area: Artifacts observability
- Evidence:
  - File: `lib/services/nexai_artifacts_service.dart:281`
  - Function / Module: `recordView`
  - Relevant behavior: Any exception from posting `/artifacts/:shortId/view` is caught and ignored.
- Problem: Best-effort analytics is acceptable, but there is no debug/metric signal to distinguish disabled tracking from broken tracking.
- Why it matters: Artifact view counts can silently stop working after backend/API changes.
- Realistic failure scenario: Backend changes `recordView` response contract; client ignores failures for months and users see stale analytics.
- Minimal fix: Keep best-effort behavior but emit a redacted debug log or lightweight counter in debug/developer mode.
- Better long-term fix: Add a non-blocking observability hook for optional backend events.
- Regression test suggestion: Fake failing `recordView` and assert artifact fetch still succeeds while a diagnostic event is emitted.
- Estimated effort: 1 hour

### Finding: Release docs list required backend/release items that workflows do not fully satisfy

- Severity: Medium
- Confidence: High
- Category: Release
- Status: Confirmed
- Affected area: Release readiness / docs-contract gap
- Evidence:
  - File: `docs/BACKEND_INTEGRATION_CONTRACT.md:1024`
  - Function / Module: release integrity contract
  - Relevant behavior: Contract recommends `/releases/:tag/manifest` and checklist asks for auth/sync/artifacts/security/release-manifest integration tests; workflows generate APK SHA256 text but no signed manifest and tests do not cover those integrations.
- Problem: Release contract and implementation are not aligned.
- Why it matters: Operators may assume the release integrity and integration coverage described in docs exists.
- Realistic failure scenario: A release ships with valid checksums in notes but no machine-verifiable manifest; client update path cannot enforce the documented contract.
- Minimal fix: Mark manifest as not implemented or implement it; add CI tests for the checklist's named integration paths.
- Better long-term fix: Treat the backend integration checklist as a release gate in CI.
- Regression test suggestion: CI policy test verifies release manifest artifact exists or docs explicitly state checksum-only mode.
- Estimated effort: 1-3 days

## 5. Architecture Concerns

- Coverage: Medium
- Inspected evidence: Providers, services, Android channels, entry point, line counts, HTTP wrappers
- Exclusions / limits: No runtime dependency graph or architecture decision history generated

Relevant findings: oversized UI/provider files, duplicated backend wrappers, unchecked dynamic restore boundaries, sync partial restore.

## 6. Security Concerns

- Coverage: Medium
- Inspected evidence: secure storage, request signer, certificate pinning, CI secrets, scripts, artifact/update services
- Exclusions / limits: No CVE scan, no penetration test, no dynamic MITM test

Key risks are CI supply-chain permission/action pinning, request signing fail-open behavior, setup script secret echoing, and incomplete update integrity enforcement. No committed production API key or private key was found; docs contain placeholder secrets only.

## 7. Stability Concerns

- Coverage: Medium
- Inspected evidence: sync restore, local persistence, HTTP clients, native tasks, crash reporting
- Exclusions / limits: No fault injection or local test execution

Highest stability risk is partial sync restore. Secondary risks are no backend request timeout and direct JSON overwrites for user data. Crash reporting is comparatively better because it already uses atomic writes.

## 8. Performance Concerns

- Coverage: Medium
- Inspected evidence: media task channel, large UI files, search/history loops, model request surfaces
- Exclusions / limits: No profiling or benchmark runs

The most realistic performance issue is unbounded native media work. Linear in-memory search over conversations/notes is acceptable at small scale but should get caps/indexing before very large histories.

## 9. Testing Gaps

- Coverage: High
- Inspected evidence: `test/`, workflows, high-risk providers/services
- Exclusions / limits: Tests were not run locally by repository rule

Must add: sync restore corruption tests, provider persistence tests, auth/token tests, backend timeout tests, request signing tests, native media task contract tests. Current tests are valuable but narrow.

## 10. Maintainability Concerns

- Coverage: High
- Inspected evidence: line-count inventory, providers, pages, services, docs
- Exclusions / limits: No automated complexity score

SRP risk is concentrated in files over 1000 lines and repeated HTTP wrapper code. Fix this incrementally after adding tests; do not rewrite the app.

## 11. Design / Principles Concerns

- Coverage: Medium
- Inspected evidence: principle rubric applied to sync, persistence, HTTP, UI/provider boundaries
- Exclusions / limits: No formal ADR review

Main principle violations: Single Responsibility (1.1), File Size Limit (1.2), Fail-Fast (4.4), Don't Swallow Errors (6.1), Timeout Every External Call (10.4), Unbounded Resources (10.2), DRY (4.1).

## 12. Type Safety Analysis

- Coverage: Medium
- Inspected evidence: model `fromJson`, sync maps, native channel maps
- Exclusions / limits: No analyzer execution

Dynamic map parsing is common in this codebase. The largest real risk is not the casts themselves; it is applying parsed cloud/local data before validating the whole restore transaction.

## 13. Release Concerns

- Coverage: High
- Inspected evidence: workflows, Gradle, release docs, update checker, lockfile
- Exclusions / limits: Workflows not executed

Release builds exist for Android/Web/Windows and Android signing is enforced, but action pinning, permission scoping, release manifest/signature, rollback docs, and integration-test gates need tightening.

## 14. Documentation Analysis

- Coverage: Medium
- Inspected evidence: README, backend contract, security docs, scripts README
- Exclusions / limits: No external hosted docs inspected

Docs are broad but not fully current. README's sync/storage descriptions and backend contract release checklist should be reconciled with implemented NexAI sync v2 and checksum-only release behavior.

## 15. Observability / Operability Analysis

- Coverage: Medium
- Inspected evidence: crash reporter/store, debug logs, security headers, artifact view tracking
- Exclusions / limits: No production log/metric backend inspected

Crash reporting has useful local persistence. Gaps remain in structured backend call diagnostics, correlation IDs, sync restore decision logs, media task metrics, and optional event failure signals.

## 16. Configuration Safety Analysis

- Coverage: Medium
- Inspected evidence: `SettingsProvider`, Gradle properties, workflows, README config table
- Exclusions / limits: No environment matrix execution

Sensitive config is generally stored correctly. Risk remains from deployment-varying defaults and the absence of startup validation for backend base URL modes, sync key state, and provider-specific limits.

## 17. Data Integrity Analysis

- Coverage: High
- Inspected evidence: sync crypto/provider, local JSON providers, password backup, crash store
- Exclusions / limits: No fault injection

The data-integrity priority is to make sync restore all-or-nothing and make local user-data writes atomic. Password backup checksum is useful but is not authenticated encryption.

## 18. Privacy / Data Governance Analysis

- Coverage: Medium
- Inspected evidence: password provider, secure storage, crash reports, sync payload collection, logs
- Exclusions / limits: No privacy policy review

Password storage is local and secure-storage backed, but export/backup is plaintext by design. Crash reports need broader token redaction before users share them.

## 19. Accessibility / UX Correctness Analysis

- Coverage: Low
- Inspected evidence: representative settings/dialog/button code
- Exclusions / limits: No screen reader, focus traversal, keyboard, or viewport runtime check

No high-confidence accessibility defect was confirmed statically. Given large custom pages, add widget/semantics tests for sync confirmation, update dialogs, password export/restore, and long text/error states.

## 20. Supply Chain / Reproducibility Analysis

- Coverage: High
- Inspected evidence: `.github/workflows`, `pubspec.lock`, Gradle, release packaging
- Exclusions / limits: No SBOM or CVE tooling run

Lockfile exists and release builds are automated. Main gaps are floating action refs, PAT usage, broad permissions, checksum-only provenance, and no SBOM.

## 21. Cost / Resource Economics Analysis

- Coverage: Medium
- Inspected evidence: chat/image/translation API calls, media work, history caps
- Exclusions / limits: No cost telemetry available

Chat has `maxTokens` and single-flight loading. Translation/image generation need explicit input/request budgets; native media needs concurrency and storage budgets.

## 22. AI / LLM Safety Analysis

- Coverage: Medium
- Inspected evidence: chat payloads, Vertex payloads, image generation, translation prompt
- Exclusions / limits: No red-team/eval run

This client does not expose model-controlled tools, so tool authorization risk is low. The relevant risks are prompt injection in translation-style instructions, output validation, cost budgets, and no evals for provider-specific behavior.

## 23. Fallback / Defensive Code Analysis

- Coverage: High
- Inspected evidence: catches, null returns, silent fallbacks, request signing, sync decrypt, artifact tracking
- Exclusions / limits: Static only

Several fallbacks are reasonable UX choices, but sync decrypt skip and request signing fail-open should be changed to fail-fast or at least surfaced as hard errors in security-sensitive paths.

## 24. Testing Authenticity Analysis

- Coverage: High
- Inspected evidence: all tests and critical production paths
- Exclusions / limits: No mutation testing

### Confidence Assessment

| Test Area | Real Confidence | Risk | Action |
|-----------|---------------|------|--------|
| Update version comparison | Medium | Release comparison regressions | Keep and augment |
| Markdown rendering utilities | Medium | Markdown rendering regressions | Keep |
| Providers/auth/sync/native | None | Data loss/security regressions escape | Add tests |

### Valuable Tests

`update_checker_test.dart` protects version comparison edge cases. Markdown tests protect recent rendering utility behavior.

### Suspicious Tests

No over-mocked tests were found; the issue is missing coverage, not fake green coverage.

### Missing Tests

Sync restore, secure storage migration, auth refresh/passkey, provider persistence corruption, native media task lifecycle, artifacts API error handling, and update integrity.

## 25. Frontend State Analysis

- Coverage: High
- Inspected evidence: `settings_page.dart`, `password_generator_page.dart`, `video_compressor_page.dart`, `chat_page.dart`, providers
- Exclusions / limits: No UI runtime inspection

### Summary

| Subtype | Count | Affected Components |
|---------|-------|-------------------|
| ComponentSize | 6 | settings, note detail, password generator, video compressor, chat, markdown renderer |
| StateDuplication | 1 | sync settings vs sync provider status |
| PropDrilling | 0 | Not a dominant pattern |
| EffectChain | 1 | media preview timers |
| UIBusinessCoupling | 3 | settings sync/update/OAuth, password import/export, media pages |
| DOMasState | 0 | Not applicable to Flutter |
| RequestState | 2 | artifacts, sync |
| RenderPerf | 1 | large note/chat lists without virtualization evidence in sampled paths |

## 26. Backend API Analysis

- Coverage: Medium
- Inspected evidence: Flutter auth/sync/artifacts API clients and backend contract docs
- Exclusions / limits: Backend implementation not present

Client-side API design is inconsistent: sync returns `null`/`false` on many failures while auth/artifacts throw exceptions. This makes provider error behavior inconsistent and complicates typed recovery.

## 27. Dependency Weight Analysis

- Coverage: Medium
- Inspected evidence: `pubspec.yaml`, Gradle dependencies, workflow build toolchain
- Exclusions / limits: No transitive size/CVE scan

### Dependency Scoreboard

| Dependency | Status | Weight | Transitives | Used For | Recommended Action |
|------------|--------|--------|-------------|----------|-------------------|
| `ffmpeg_kit_flutter_new` | Healthy but heavy | High | Not measured | audio/video tooling | Keep, document why |
| `v_video_compressor` | Healthy but heavy | High | Not measured | video compression | Keep, avoid duplicate native transcoder until needed |
| `dio` + `http` | Mixed | Medium | Not measured | separate API stacks | Consolidate where practical |
| `flutter_secure_storage` | Healthy | Medium | Not measured | secrets/passwords | Keep |

No dependency was flagged for immediate removal. The main dependency concern is operational weight and duplicated HTTP stacks, not obvious dead packages.

## 28. Code Consistency Analysis

- Coverage: High
- Inspected evidence: providers/services, API wrappers, persistence patterns, errors
- Exclusions / limits: No analyzer/formatter run

Consistent patterns exist in Provider state ownership, but error handling and backend client behavior diverge: some APIs throw, some return null, some swallow optional errors, and persistence alternates between secure storage, JSON files, and SharedPreferences without a shared storage abstraction.

## 29. Comment Coverage Analysis

- Coverage: Medium
- Inspected evidence: public comments in services/providers/models and docs
- Exclusions / limits: Not every inline comment audited

Comments are generally helpful around security and migration intent. Stale-risk areas are comments that claim behavior as implemented security guarantees while the code is TOFU/fail-open or checksum-only. Update docs/comments after fixing the underlying behavior.

---

## 30. Principles Compliance

The codebase follows some pragmatic principles: secrets are not plainly stored in settings, crash reports use atomic writes, provider state is mostly centralized, and release signing fails the Gradle graph when missing. The biggest principle gaps are concentrated and locally fixable.

### Principles Violated

| Principle | Violations | Severity | Affected Areas |
|-----------|------------|----------|----------------|
| Single Responsibility (1.1) | 6 | Medium | large pages/providers |
| File Size Limit (1.2) | 8 | Medium | settings/auth/password/media/note/chat/markdown |
| DRY (4.1) | 1 | Medium | duplicated backend HTTP wrappers |
| Fail-Fast (4.4) | 2 | High | sync partial restore, request signing |
| Don't Swallow Errors (6.1) | 2 | Medium | artifact view tracking, decrypt skip |
| Timeout Every External Call (10.4) | 3 | Medium | auth/sync/artifacts clients |
| Unbounded Resources (10.2) | 1 | Medium | native media tasks |

### Principles Respected

Secure storage is used for API keys, tokens, passwords, and sync encryption key. Crash report persistence uses temp-file writes and rename fallback. Gradle release signing refuses unsigned release tasks unless explicitly configured for debug signing. Chat diagnostics redact common token/key patterns before showing request/response details.

---

## 31. Architecture Analysis

### Architecture Summary

| Subtype | Count | Affected Areas | Recommended Action |
|---------|-------|----------------|-------------------|
| ModuleBoundary | 3 | settings page, auth provider, API wrappers | Split workflow orchestration and HTTP client |
| DependencyDirection | 1 | UI button handlers orchestrate sync/providers | Move commands to controller/provider methods |
| StateOwnership | 2 | sync restore, settings/sync method fields | Define source of truth and supported modes |
| BoundaryContract | 3 | JSON models, native channel maps, release manifest | Add validation schemas/contracts |
| EvolutionRisk | 3 | large pages, duplicated clients, CI release | Extract and gate changes with tests |

The architecture is serviceable for a Flutter app, but too much behavior sits in large UI/provider classes and backend client logic is repeated. Start with shared backend client and sync restore staging; those reduce risk without a rewrite.

## 32. Documentation Analysis

### Documentation Summary

| Subtype | Count | Affected Docs | Recommended Action |
|---------|-------|---------------|-------------------|
| UserDocs | 1 | README sync/settings | Correct current sync and secure storage behavior |
| OperatorDocs | 1 | release docs | Add rollback and manifest/signature flow |
| DeveloperDocs | 1 | README local commands vs repo rules | Clarify GitHub Actions-only validation for agents |
| ApiDocs | 1 | backend contract release manifest | Align implementation or mark not implemented |
| DecisionRecord | 1 | sync encryption key | Document recovery tradeoff |
| StaleDocs | 1 | WebDAV/Upstash sync wording | Update or remove |

## 33. Privacy / Data Governance Analysis

### Privacy Summary

| Subtype | Count | Affected Data | Recommended Action |
|---------|-------|---------------|-------------------|
| DataInventory | 1 | chats, notes, passwords, translation, URLs | Add data inventory table |
| Minimization | 1 | crash reports | Redact token/key patterns |
| AccessBoundary | 0 | Not confirmed | Keep auth boundaries server-side |
| Retention | 2 | crash reports, native tasks | Add retention cleanup |
| Deletion | 1 | cloud sync restore/delete expectations | Document and test delete semantics |
| Export | 1 | password CSV/backup | Warn plaintext export clearly |
| TelemetryPrivacy | 1 | security headers/fingerprint | Document purpose and retention |

## 34. Accessibility / UX Correctness Analysis

### Accessibility Summary

| Subtype | Count | Affected Workflows | Recommended Action |
|---------|-------|-------------------|-------------------|
| SemanticStructure | 0 | Not confirmed | Add semantics tests |
| KeyboardFocus | 0 | Not confirmed | Runtime verify dialogs/forms |
| ResponsiveVisual | 0 | Not confirmed | Screenshot-test dense pages |
| ErrorState | 1 | sync/update/model errors | Make errors actionable and typed |
| LoadingState | 1 | sync/artifacts/media | Ensure cancellation and disabled states |
| UXStateCorrectness | 1 | partial restore | Make restore all-or-nothing |

## 35. Supply Chain / Reproducibility Analysis

### Supply Chain Summary

| Subtype | Count | Affected Surface | Recommended Action |
|---------|-------|------------------|-------------------|
| DependencyProvenance | 1 | GitHub actions | Pin actions to SHAs |
| Reproducibility | 1 | release artifacts | Add manifest/SBOM/provenance |
| CIIntegrity | 2 | PAT and permissions | Scope permissions and remove PAT where possible |
| ArtifactProvenance | 1 | APK/Web/Windows zips | Sign manifests/checksums |
| RegistryHygiene | 0 | Not assessed | Not a published package |

## 36. Cost / Resource Economics Analysis

### Cost Summary

| Subtype | Count | Cost Driver | Recommended Action |
|---------|-------|-------------|-------------------|
| UnboundedWork | 1 | native media CPU/I/O | Add bounded executor |
| ExternalApiCost | 1 | translation/short URL/model APIs | Add request/input budgets |
| LLMCost | 1 | chat/image/translation tokens | Add local quotas and estimates |
| InfrastructureSizing | 0 | Not assessed | Client app only |
| ObservabilityCost | 0 | Not confirmed | No telemetry backend in repo |
| CostVisibility | 1 | per-feature API calls | Add counters/debug budget |

## 37. AI / LLM Safety Analysis

### AI Safety Summary

| Subtype | Count | Boundary Crossed | Recommended Action |
|---------|-------|------------------|-------------------|
| PromptInjection | 1 | translation instruction + user text | Isolate user text and evaluate |
| ToolAuthorization | 0 | No model tools confirmed | Keep deterministic actions outside model output |
| RAGLeakage | 0 | No RAG surface | Not assessed beyond absence |
| ModelFallback | 0 | No silent model fallback confirmed | Keep explicit model selection |
| OutputValidation | 1 | URL extraction from model text | Validate image URLs/content types |
| EvalGap | 1 | provider prompts | Add prompt/provider regression tests |
| AbuseCost | 1 | tokens/images/API requests | Add budgets |

## 38. Observability / Operability Analysis

### Signal Summary

| Subtype | Count | Critical Signals Missing | Recommended Action |
|---------|-------|--------------------------|-------------------|
| Logging | 2 | sync partial restore decisions, optional view failures | Add redacted debug signals |
| Metrics | 2 | media task count, backend timeout/error rate | Add counters where available |
| Tracing | 1 | backend request correlation | Add request IDs |
| HealthCheck | 0 | Client app only | Not applicable |
| Alerting | 0 | Client app only | Not applicable |
| Runbook | 1 | release/update integrity | Document recovery/rollback |
| Debuggability | 1 | sync key/recovery state | Add safe diagnostics |

## 39. Configuration Safety Analysis

### Configuration Summary

| Subtype | Count | Affected Keys / Files | Recommended Action |
|---------|-------|-----------------------|-------------------|
| SchemaValidation | 2 | base URL, sync decrypted settings | Validate before save |
| UnsafeDefault | 1 | request signer fallback ID | Replace with per-install ID |
| EnvironmentSeparation | 1 | workflows/PAT/secrets | Scope per job/environment |
| SecretConfig | 1 | setup script output | Mask secret values |
| FeatureFlag | 1 | sync legacy disabled paths | Remove or document lifecycle |
| ConfigDocs | 1 | README config table | Update defaults/storage split |

## 40. Data Integrity Analysis

### Integrity Summary

| Subtype | Count | Invariants at Risk | Recommended Action |
|---------|-------|-------------------|-------------------|
| TransactionBoundary | 2 | restore all categories, local file save | Stage/atomic commit |
| Idempotency | 1 | sync full upload/download | Add snapshot IDs and conflict behavior |
| ConcurrencyConsistency | 1 | media/native task updates | Bounded executor/state transitions |
| MigrationSafety | 1 | local JSON/schema | Add versioned migrations |
| InvariantValidation | 2 | model `fromJson`, sync categories | Validate before apply |
| BackupRestore | 2 | sync key recovery, password backup | Document and test restore |
| Reconciliation | 1 | partial decrypt categories | Add manifest/count reconciliation |

## 41. Fallback / Defensive Code Analysis

### Fallback Summary

| Subtype | Count | KeepWithAlert | FailFast | Remove |
|---------|-------|---------------|----------|--------|
| SilentFallback | 4 | 1 | 3 | 0 |
| EmptyCatch | 2 | 2 | 0 | 0 |
| CompatibilityBranch | 2 | 1 | 0 | 1 |
| SilentCorrection | 1 | 1 | 0 | 0 |
| DefensiveGuess | 2 | 1 | 1 | 0 |

Sync decrypt skip and request signing fail-open should fail fast. Artifact view tracking can remain best effort with a diagnostic signal.

## 42. Recommended Fix Order

### Fix Immediately

| Priority | Issue | Why |
|----------|-------|-----|
| P0 | Make sync restore all-or-nothing | Prevents realistic local data loss |
| P0 | Add tests for sync restore and provider persistence | Protects the first fix |
| P0 | Scope CI permissions and pin actions | Protects release artifacts |

### Fix Before Stable Release

| Priority | Issue | Why |
|----------|-------|-----|
| P1 | Add backend HTTP timeouts | Prevents hung login/sync/artifact flows |
| P1 | Make user-data JSON writes atomic | Prevents local data corruption |
| P1 | Fix request signing fail-open behavior | Makes security control enforceable |
| P1 | Add release manifest/checksum enforcement | Improves update integrity |
| P1 | Add native media concurrency/retention limits | Prevents resource exhaustion |

### Schedule Later

| Priority | Issue | Why |
|----------|-------|-----|
| P2 | Split large pages/providers | Reduces change risk |
| P2 | Centralize backend HTTP wrapper | Removes duplicated fixes |
| P2 | Add AI cost budgets/evals | Improves predictable model behavior |
| P2 | Update README/docs | Reduces user/operator confusion |

### Ignore for Now

| Priority | Issue | Why |
|----------|-------|-----|
| P3 | Full dependency slimming | No confirmed unused heavy dependency |
| P3 | Broad UI redesign | Not needed to reduce current top risks |

## 43. Quick Wins

| Quick win | Impact | Effort |
|-----------|--------|--------|
| Add `.timeout(...)` to auth/sync/artifact calls through a shared helper | Prevents indefinite hangs | 2-4 hours |
| Mask password echoes in `scripts/setup-android-signing.cmd` | Prevents accidental secret exposure | 30 minutes |
| Add token/key redaction to `CrashReport._sanitize` | Safer support reports | 2 hours |
| Pin `softprops/action-gh-release` and `subosito/flutter-action` to SHAs | Reduces CI supply-chain risk | 1 hour |
| Add sync partial-restore unit test | Locks the highest-risk behavior | 2-4 hours |
| Update README sync/storage section | Reduces backup confusion | 1 hour |

## 44. Long-term Refactor Plan

1. **Staged sync restore**
   Motivation: prevent partial cloud data from overwriting local data.
   Approach: decrypt and validate all records into staging, produce a category diff, then apply atomically.
   Risk: schema compatibility edge cases.
   Testing strategy: corrupt record, missing category, old schema, wrong key, and successful restore tests.

2. **Shared backend client**
   Motivation: remove duplicated signing/pinning/timeout/error behavior.
   Approach: implement `NexaiBackendClient` and migrate auth, sync, artifacts one service at a time.
   Risk: subtle behavior changes in error mapping.
   Testing strategy: fake client tests for signing, timeout, redaction, and status-code mapping.

3. **Feature section extraction from large pages**
   Motivation: reduce SRP violations without rewriting UI.
   Approach: extract settings sync/update/security/passkey sections and password import/export commands.
   Risk: widget state regressions.
   Testing strategy: widget tests around dialogs/buttons plus provider command unit tests.
