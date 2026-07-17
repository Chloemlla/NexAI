# NexAI WinUI3

Native Windows client for the Fluent / WinUI3 rewrite.

## Layout

```text
winui/
  NexAI.WinUI3.sln
  Directory.Build.props
  Directory.Packages.props
  NexAI.Core/                 # pure models and contracts
  NexAI.Infrastructure/       # storage and OS/network adapters
  NexAI.WinUI3/               # WinUI3 app head, shell, pages
```

## MVP-1 status

MVP-1 is implemented in code:

- solution + three projects
- Mica main window, custom title bar, NavigationView
- editable Settings (Base URL / API Key / Model / Temperature / Max tokens / Theme)
- clean local JSON settings/conversation stores
- multi-conversation chat (create / select / delete / search)
- OpenAI-compatible streaming chat with Send/Stop
- basic Markdown rendering (headings, lists, quotes, fenced code, bold/italic/inline code/links)
- Fluent-style chat density polish

Still deferred beyond MVP-1:

- Notes / Tools
- full Sync
- advanced rendering (LaTeX / chemistry / Mermaid)
- media tools
- Google / Passkey
- Flutter local data migration
- dedicated WinUI3 CI job (Flutter Windows CI remains)

## Local data

Settings:

`%LocalAppData%\NexAI\WinUI3\settings.json`

Conversations:

`%LocalAppData%\NexAI\WinUI3\conversations.json`

No Flutter data migration in MVP-1.

## Build notes

Local builds are owned by CI for this repo. When a WinUI job is wired, expected command shape:

```powershell
msbuild winui\NexAI.WinUI3\NexAI.WinUI3.csproj /p:Platform=x64 /p:Configuration=Release /v:m -restore
```

Flutter `windows/` remains for the existing multi-platform client during transition.
