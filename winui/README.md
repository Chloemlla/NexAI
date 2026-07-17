# NexAI WinUI3

Native Windows client scaffold for the Fluent / WinUI3 rewrite.

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

PR1 (this scaffold):

- solution + three projects
- Mica main window
- custom title bar
- NavigationView shell with Chat / Settings destinations
- clean local settings store foundation

Still pending in later PRs:

- editable settings UI + theme switcher
- multi-conversation chat storage
- streaming OpenAI-compatible client
- basic Markdown rendering

## Build notes

Local builds are owned by CI for this repo. When CI is wired, expected command shape:

```powershell
msbuild winui\NexAI.WinUI3\NexAI.WinUI3.csproj /p:Platform=x64 /p:Configuration=Release /v:m -restore
```

Flutter `windows/` remains for the existing multi-platform client during transition.
