# NexAI WinUI3

Native Windows client for the Fluent / WinUI3 rewrite.

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
- Settings: API, theme, backend, sync config, recovery key, Flutter migration trigger
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
- Flutter local data migration (best-effort chats/notes/settings import)
- Independent WinUI CI job (`build-winui`) packaging zip artifacts

Local data roots:

`%LocalAppData%\NexAI\WinUI3\`

## Build (CI)

```powershell
msbuild winui\NexAI.WinUI3.sln /t:Restore /p:Configuration=Release /p:Platform=x64
msbuild winui\NexAI.WinUI3\NexAI.WinUI3.csproj /p:Configuration=Release /p:Platform=x64 /p:WindowsPackageType=None /p:WindowsAppSDKSelfContained=true
```

Local machine builds remain prohibited by repo policy; GitHub Actions owns verification.
