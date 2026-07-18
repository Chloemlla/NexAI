# NexAI WinUI3

Native Windows product client for NexAI. This is the only Windows desktop path.

## Layout

```text
winui/
  NexAI.WinUI3.sln
  Directory.Build.props
  Directory.Packages.props
  NexAI.Core/
  NexAI.Infrastructure/
  NexAI.WinUI3/
```

## Feature status

Implemented:

- Fluent shell (Mica, custom title bar, NavigationView)
- Settings: API, theme, language (System/English/简体中文), backend, sync config, recovery key
- Chat: multi-conversation + OpenAI-compatible streaming + basic Markdown
- Notes: local store, search, create/edit/delete/star, tags/wiki-link extraction
- Tools:
  - Base64, Date/Time, Password, AI Translation
  - Short URL via `api.mmp.cc`
  - Artifacts create via NexAI backend (`/artifacts`, requires sign-in)
  - Image generation via OpenAI-compatible `/images/generations` with chat fallback
  - Video compress / video-to-audio via local `ffmpeg` (`PATH` or `NEXAI_FFMPEG`)
- Sync: AES-256-GCM record crypto + NexAI `/sync/v2` upload/download
- Advanced rendering: LaTeX Unicode math preview + Mermaid edge/node preview cards
- Sync restore uses atomic conversation `ReplaceAll` (id-preserving)
- i18n foundation: `Strings/en-US` + `Strings/zh-CN`, runtime language apply, localized nav/tools/settings shell text
  - Full-page bilingual coverage for Chat / Notes / Tools / Settings (static + dynamic UI strings)
- CI/release Windows packaging builds this WinUI3 client only

Local data roots:

`%LocalAppData%\NexAI\WinUI3\`

## Build (CI)

```powershell
msbuild winui\NexAI.WinUI3.sln /t:Restore /p:Configuration=Release /p:Platform=x64
msbuild winui\NexAI.WinUI3\NexAI.WinUI3.csproj /p:Configuration=Release /p:Platform=x64 /p:WindowsPackageType=None /p:WindowsAppSDKSelfContained=true
```

Local machine builds remain prohibited by repo policy; GitHub Actions owns verification.

## Platform note

- Windows desktop product path: `winui/` (native WinUI3)
- Android/Web continue on Flutter
- Legacy Flutter `windows/` host is removed from the repository
