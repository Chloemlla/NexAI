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

Done:

- solution + three projects
- Mica main window, custom title bar, NavigationView
- editable Settings (Base URL / API Key / Model / Temperature / Max tokens / Theme)
- clean local JSON settings store with validation
- multi-conversation chat store (create / select / delete / search / local draft messages)

Still pending:

- streaming OpenAI-compatible client
- basic Markdown rendering

## Local data

Settings:

`%LocalAppData%\NexAI\WinUI3\settings.json`

Conversations:

`%LocalAppData%\NexAI\WinUI3\conversations.json`

No Flutter data migration in MVP-1.

## Build notes

Local builds are owned by CI for this repo. When CI is wired, expected command shape:

```powershell
msbuild winui\NexAI.WinUI3\NexAI.WinUI3.csproj /p:Platform=x64 /p:Configuration=Release /v:m -restore
```

Flutter `windows/` remains for the existing multi-platform client during transition.
