# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NexAI is a cross-platform AI chat client built with Flutter, supporting OpenAI-compatible APIs. It runs on Windows (Fluent UI), Android (Material 3), and Web.

**Tech Stack**: Flutter 3.41+, Dart 3.11+, Material 3, Fluent UI, Provider pattern

## Development Commands

### Setup
```bash
flutter pub get                    # Install dependencies
```

### Run
```bash
flutter run -d windows             # Run on Windows
flutter run -d android             # Run on Android device/emulator
flutter run -d chrome              # Run on Web (Chrome)
```

### Build
```bash
flutter build windows --release    # Build Windows executable
flutter build apk --release        # Build Android APK
flutter build web --release        # Build Web app
```

### Code Quality
```bash
flutter analyze                    # Run static analysis
flutter test                       # Run tests (if any exist)
```

### GitHub Actions
The project uses GitHub Actions for automated builds. Trigger via:
- Push to any branch (auto-builds all platforms)
- Manual workflow dispatch: Actions → Build NexAI → Run workflow (select platform)

Required secrets for release builds:
- `USER_PAT`: GitHub Personal Access Token
- `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD` (Android signing)

## Architecture

### State Management
Uses **Provider pattern** with `ChangeNotifier`. All providers are initialized in `main.dart` before `runApp()`:

- **ChatProvider** (`lib/providers/chat_provider.dart`): Manages conversations, streaming API calls, message search. Persists to `nexai_chats.json` in app documents directory.
- **SettingsProvider** (`lib/providers/settings_provider.dart`): All app settings (API config, theme, appearance, sync). Persists via `SharedPreferences`.
- **NotesProvider** (`lib/providers/notes_provider.dart`): Notes CRUD, wiki-links, tags, cloud sync (WebDAV/Upstash).
- **ImageGenerationProvider** (`lib/providers/image_generation_provider.dart`): Image generation state (text-to-image, image-to-image).
- **PasswordProvider** (`lib/providers/password_provider.dart`): Password generator history.

### Platform Detection
Platform-specific logic uses helpers defined in `lib/main.dart`:
- `isDesktop`: Windows, Linux, or macOS (non-web)
- `isAndroid`: Android platform

### Dual UI System
- **Desktop (Windows/Linux/macOS)**: Uses Fluent UI (`fluent_ui` package) with sidebar navigation
- **Android**: Uses Material 3 with bottom navigation bar
- **Shared**: Both UIs share the same providers and business logic

Key files:
- `lib/app.dart`: MaterialApp setup, dynamic theming, color schemes
- `lib/pages/home_page.dart`: Navigation shell (switches between Fluent/Material based on platform)
- `lib/widgets/message_bubble.dart`: Platform-specific chat bubble variants

### Content Rendering
`lib/widgets/rich_content_view.dart` handles complex content rendering:
- **Markdown**: GitHub-flavored via `gpt_markdown`
- **LaTeX**: Inline `$...$` and display `$$...$$` via `flutter_math_fork`
- **Chemistry**: `\ce{...}` notation for chemical formulas
- **Mermaid**: Flowchart diagrams via custom parser in `lib/widgets/flowchart/`
- **Wiki-links**: `[[note]]`, `[[note|alias]]`, `[[note#heading]]` for note cross-linking

Performance optimizations:
- Pre-compiled regex patterns (module-level constants)
- Content caching to avoid re-parsing on rebuilds
- `RepaintBoundary` for complex widgets
- Lazy loading for large content

### Networking
- Uses **Dio** with connection pooling (single instance in ChatProvider)
- Timeouts: 30s connect, 120s receive, 30s send
- Supports streaming responses for chat completions

### Persistence
- **Conversations**: JSON file at `{appDocuments}/nexai_chats.json`
- **Notes**: JSON file at `{appDocuments}/nexai_notes.json`
- **Settings**: `SharedPreferences` (platform-specific storage)
- **Passwords**: JSON file at `{appDocuments}/nexai_passwords.json`

### Custom Utilities
- **UUID generation**: Custom UUID v4 implementation in `chat_provider.dart` (`_newId()`) to avoid external dependencies
- **Update checker**: `lib/utils/update_checker.dart` checks GitHub Releases on startup
- **Navigation helper**: `lib/utils/navigation_helper.dart` for cross-page navigation callbacks

## Key Patterns and Conventions

### File Organization
```
lib/
├── main.dart                      # Entry point, platform setup, provider initialization
├── app.dart                       # MaterialApp, theming, dynamic color
├── models/                        # Data models (Message, Conversation, Note, etc.)
├── providers/                     # State management (Provider pattern)
├── pages/                         # Full-screen pages
├── widgets/                       # Reusable widgets
└── utils/                         # Utilities (update checker, navigation, build config)
```

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Private members: `_leadingUnderscore`
- Constants: `camelCase` or `_leadingUnderscoreForPrivate`

### Code Style
- Uses `flutter_lints` with custom overrides in `analysis_options.yaml`:
  - `prefer_const_constructors: false`
  - `prefer_const_literals_to_create_immutables: false`
  - `avoid_print: false`
- Prefer `debugPrint()` for logging (already used throughout codebase)

### Platform-Specific Code
When adding platform-specific features:
1. Check platform using `isDesktop` or `isAndroid` from `main.dart`
2. For UI: Create separate widgets or conditional rendering in `home_page.dart`
3. For functionality: Use platform channels or conditional imports if needed

### Adding New Features
1. **New page**: Add to `lib/pages/`, register in `home_page.dart` navigation
2. **New provider**: Create in `lib/providers/`, add to `MultiProvider` in `main.dart`
3. **New model**: Add to `lib/models/` with JSON serialization if needed
4. **New widget**: Add to `lib/widgets/` for reusable components

## Workflow Rules

### Git Commit Workflow
- **IMPORTANT**: After completing code changes, immediately create a git commit and push automatically (use `git push --force` if necessary)
- Commit message format: `type: brief description` (e.g., `fix:`, `feat:`, `refactor:`, `chore:`)
- If fixing GitHub issues/alerts, reference them in commit message (e.g., `fix: resolve memory leak #460 #461`)

### Code Quality
- Run `flutter analyze` before committing to catch issues
- Ensure no breaking changes to existing API contracts
- Test on both Windows and Android when possible (or at least verify no platform-specific regressions)

## Common Tasks

### Adding a New Chat Feature
1. Modify `ChatProvider` for business logic
2. Update `Message` or `Conversation` model if data structure changes
3. Update UI in `chat_page.dart` or `message_bubble.dart`
4. Ensure persistence works (test save/load cycle)

### Adding a New Tool
1. Create page in `lib/pages/` (e.g., `new_tool_page.dart`)
2. Add navigation entry in `tools_page.dart`
3. Add icon from `font_awesome_flutter` or `material_design_icons_flutter`

### Modifying Theme/Appearance
1. Update `app.dart` for global theme changes
2. Update `SettingsProvider` if adding new appearance settings
3. Ensure both light and dark themes are handled

### Adding Cloud Sync Support
- Existing sync methods: WebDAV, Upstash Redis
- Sync logic in `NotesProvider` (see `syncToCloud()`, `syncFromCloud()`)
- Settings stored in `SettingsProvider` (webdav/upstash credentials)

## Dependencies

### Core
- `provider`: State management
- `shared_preferences`: Settings persistence
- `dio`: HTTP client with streaming support
- `path_provider`: File system paths

### UI
- `fluent_ui`: Windows/Desktop UI
- `dynamic_color`: Material You dynamic theming
- `google_fonts`: Custom fonts
- `flutter_smart_dialog`: Toast/dialog system

### Content Rendering
- `gpt_markdown`: Markdown rendering
- `flutter_math_fork`: LaTeX rendering
- Custom Mermaid parser in `lib/widgets/flowchart/`

### Media
- `media_kit`: Video playback
- `ffmpeg_kit_flutter_new`: Video processing
- `v_video_compressor`: Video compression

### Platform
- `window_manager`: Desktop window management
- `package_info_plus`: App version info
- `device_info_plus`: Device information

## Notes for AI Assistants

- This is a **production app** with real users. Prioritize stability and backward compatibility.
- **Persistence is critical**: Always test save/load cycles when modifying data models.
- **Platform differences matter**: Windows uses Fluent UI, Android uses Material 3. Test or verify both when making UI changes.
- **Performance**: The app handles large conversations and notes. Keep performance in mind (see RichContentView optimizations as example).
- **No breaking changes**: Existing JSON formats must remain compatible or include migration logic.
