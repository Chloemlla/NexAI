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
- Tools: Base64, Date/Time, Password, AI Translation, plus stubs for media/network tools
- Sync: AES-256-GCM record crypto + NexAI `/sync/v2` upload/download
- Advanced rendering: LaTeX / Mermaid source cards (native equation/graph engines deferred)
- Flutter local data migration (best-effort chats/notes/settings import)
- Independent WinUI CI job (`build-winui`) packaging zip artifacts

Local data roots:

`%LocalAppData%\NexAI\WinUI3\`

## Build (CI)

```powershell
dotnet restore winui/NexAI.WinUI3.sln
dotnet build winui/NexAI.WinUI3/NexAI.WinUI3.csproj -c Release -p:Platform=x64
```

Local machine builds remain prohibited by repo policy; GitHub Actions owns verification.
