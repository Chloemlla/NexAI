# NexAI Android / Vivo Adaptation Notes

Sources:
- [vivo Android 11](https://dev.vivo.com.cn/documentCenter/doc/428)
- [vivo Android 12](https://dev.vivo.com.cn/documentCenter/doc/509)
- [vivo Android 13](https://dev.vivo.com.cn/documentCenter/doc/586)
- [vivo Android 14](https://dev.vivo.com.cn/documentCenter/doc/699)
- [vivo Android 15](https://dev.vivo.com.cn/documentCenter/doc/797)
- [vivo Android 16](https://dev.vivo.com.cn/documentCenter/doc/832)
- [vivo Android 17](https://dev.vivo.com.cn/documentCenter/doc/1010)

Fetched material package for Android 11:
- `docs/vivo-adaptation/428-android-11/`

NexAI ships `compileSdk/targetSdk = 37`, `minSdk = 26` (Flutter host + Kotlin boundary channels).

## High priority adaptations

### Android 11 package visibility (doc 428)
- Explicit `<queries>` allowlist for:
  - share/browser/installer/document intents
  - Google/OEM passkey credential packages
  - root / Xposed / VPN packages used by honeypot signals
- No `QUERY_ALL_PACKAGES`.
- `DeviceFingerprint` installed-app hashing remains best-effort under visibility limits.

### Android 11 scoped storage / one-time grants
- No legacy external storage access / `requestLegacyExternalStorage`.
- Media/document access uses Photo Picker / SAF (`OPEN_DOCUMENT` / `CREATE_DOCUMENT`) + optional persistable grants.
- No background location / camera continuous capture path requiring one-time special handling beyond standard runtime permission best practices.

### Android 11 foreground-service camera/mic types
- N/A: no camera/microphone FGS in NexAI.

### Android 11 custom toast from background
- N/A: no native custom-view Toast path; Flutter UI surfaces handle messaging.

### Notifications (Android 13+)
- Declares `POST_NOTIFICATIONS`.
- Runtime request via `PermissionChannel.ensureNotificationPermission`.
- Notification posts check permission and return recoverable `permission_denied`.

### Media / partial photo access (Android 13/14)
- No `READ_MEDIA_*` / `READ_EXTERNAL_STORAGE` gallery permissions.
- Image/video pick uses system Photo Picker (`MediaStore.ACTION_PICK_IMAGES` on API 33+) or SAF `OPEN_DOCUMENT`.
- Persistable URI grants available via `takePersistableUriPermission`.

### Exact alarms
- N/A: NexAI does not schedule exact alarms / reminder timers.

### Foreground services
- N/A typed long-running FGS: media tasks run on bounded thread pools, not mediaPlayback FGS.
- No continuous background audio session.

### Edge-to-edge (Android 15+)
- `MainActivity` / `CrashGateActivity` call `enableEdgeToEdge()`.
- Themes use transparent status/navigation bars + cutout shortEdges.
- Flutter continues to receive IME insets via `WindowCompat.setDecorFitsSystemWindows(window, false)`.

### Predictive back (Android 16+)
- Application enables `android:enableOnBackInvokedCallback="true"`.
- Flutter handles navigation back stack; no raw `onBackPressed` override.

### Large-screen adaptive layout (Android 16/17)
- Activities set `resizeableActivity="true"`.
- Broad `configChanges` keeps Flutter engine across orientation/size changes.
- No forced portrait orientation.

### Intent redirect / implicit URI grants
- `intentMatchingFlags="enforceIntentFilter"`.
- Share/install use FileProvider + `ClipData` + `FLAG_GRANT_READ_URI_PERMISSION`.
- Install path also fails closed on package/signature/hash mismatch.
- Notification PendingIntents are explicit `MainActivity` + `FLAG_IMMUTABLE`.

### Network / cleartext (Android 17 prep)
- Main manifest has no `usesCleartextTraffic`.
- `network_security_config.xml` forces cleartext off (base + production domains).
- Debug/profile may enable cleartext only for local tooling.

### Dynamic native load
- Host depends on packaged libraries (Flutter/lumen-crash); no runtime-downloaded SO/DEX path in app code.

### Local network / body sensors / NPU / loopback / background location
- Not used by NexAI product surface.

## Verification checklist

- Cold start on Android 15+: no opaque system-bar plate issues under edge-to-edge.
- Share file / install APK: receivers can open FileProvider URIs.
- Pick image/video: Photo Picker / SAF without media-library permission prompts.
- Notification permission denied: progress/show notifications return recoverable errors.
- Large phone / foldable: no fixed-orientation crashes; configChanges preserved.
- Passkey diagnostics still detect GMS / known OEM credential packages under package visibility.
- Security honeypot still detects known root/Xposed/VPN packages from the allowlist.

## Refresh log

- 2026-07-16: Applied Vivo Android 13-17 high-priority host adaptations to NexAI Android layer.
- 2026-07-16: Adapted Vivo Android 11 (doc 428) package-visibility allowlist for passkey/security package checks and document/share intents.
