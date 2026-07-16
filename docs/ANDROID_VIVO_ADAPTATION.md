# NexAI Android / Vivo Adaptation Notes

Sources:
- [vivo Android 13](https://dev.vivo.com.cn/documentCenter/doc/586)
- [vivo Android 14](https://dev.vivo.com.cn/documentCenter/doc/699)
- [vivo Android 15](https://dev.vivo.com.cn/documentCenter/doc/797)
- [vivo Android 16](https://dev.vivo.com.cn/documentCenter/doc/832)
- [vivo Android 17](https://dev.vivo.com.cn/documentCenter/doc/1010)

NexAI ships `compileSdk/targetSdk = 37`, `minSdk = 26` (Flutter host + Kotlin boundary channels).

## High priority adaptations

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

### Network / cleartext (Android 17 prep)
- Main manifest has no `usesCleartextTraffic`.
- `network_security_config.xml` forces cleartext off (base + production domains).
- Debug/profile may enable cleartext only for local tooling.

### Dynamic native load
- Host depends on packaged libraries (Flutter/lumen-crash); no runtime-downloaded SO/DEX path in app code.

### Local network / body sensors / NPU / loopback
- Not used by NexAI product surface.

## Verification checklist

- Cold start on Android 15+: no opaque system-bar plate issues under edge-to-edge.
- Share file / install APK: receivers can open FileProvider URIs.
- Pick image/video: Photo Picker / SAF without media-library permission prompts.
- Notification permission denied: progress/show notifications return recoverable errors.
- Large phone / foldable: no fixed-orientation crashes; configChanges preserved.

## Refresh log

- 2026-07-16: Applied Vivo Android 13-17 high-priority host adaptations to NexAI Android layer.
