# NexAI

An AI chat client built with Flutter, supporting OpenAI-compatible APIs. Runs on Windows (Fluent UI) and Android (Material 3).

![Flutter](https://img.shields.io/badge/Flutter-3.41-blue?logo=flutter)
![Version](https://img.shields.io/badge/Version-1.1.6-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20Web-blueviolet)

## Features

### Chat
- **OpenAI-compatible API** — Works with any endpoint: OpenAI, Claude, DeepSeek, local models, etc.
- **Streaming responses** — Real-time token-by-token output
- **Multiple conversations** — Unlimited sessions with per-session history
- **Message search** — Full-text search across all conversations with highlighted results
- **Edit & resend** — Edit any user message and regenerate from that point
- **Smart auto-scroll** — Follows new tokens, pauses when you scroll up
- **Markdown rendering** — GitHub-flavored Markdown with syntax-highlighted code blocks
- **LaTeX & chemistry** — Inline `$...$`, display `$$...$$`, and `\ce{...}` chemical notation
- **Mermaid flowcharts** — Renders flowchart diagrams from AI responses
- **Image generation** — Text-to-image and image-to-image via compatible APIs (e.g. Flux, DALL·E)

### Notes
- **Markdown editor** — Full Markdown with live preview
- **Tags** — `#tag` extraction from note body and YAML frontmatter
- **Wiki-links** — `[[note]]`, `[[note|alias]]`, `[[note#heading]]` cross-linking
- **Knowledge graph** — Visual graph of note connections
- **Star & organize** — Starred, recent, and tag-filtered views
- **Save from chat** — Save any AI message directly to a new or existing note

### Tools
- **Video compressor** — Compress video files with configurable quality
- **Video to audio** — Extract audio from video (MP3/AAC)
- **Date/time converter** — Unix timestamp ↔ human-readable conversion
- **Base64 converter** — Encode/decode Base64
- **Password generator** — Configurable secure password generator with history
- **Short URL** — URL shortening via compatible APIs

### Appearance & UX
- **Dual UI** — Fluent UI (Windows/Desktop), Material 3 (Android)
- **Dynamic color** — Follows system accent color on Android 12+
- **Custom accent color** — Override with any color
- **Dark / Light / System** theme
- **Custom font & size** — Choose font family and reading size
- **Borderless mode** — Clean, bubble-free chat layout
- **Full-screen mode** — Immersive chat on Android with FAB overlays
- **Export to PNG** — Save any message bubble as an image

### Sync & Settings
- **Cloud sync** — WebDAV or Upstash Redis for conversation backup
- **Auto-update checker** — Checks GitHub Releases on startup
- **Persistent settings** — All preferences saved via `SharedPreferences`

## Quick Start

### Build via GitHub Actions

1. Fork the repository
2. Add a `USER_PAT` secret (Settings → Secrets → Actions)
3. Go to **Actions → Build NexAI → Run workflow**
4. Select target platform: `windows`, `android`, `web`, or `all`
5. Download the artifact when the build completes

For Android release signing, also add:
- `KEYSTORE_BASE64` — Base64-encoded `.jks` keystore
- `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`

### Local Development

```bash
flutter pub get
flutter run -d windows   # Desktop
flutter run -d android   # Android
flutter run -d chrome    # Web
```

Requirements: Flutter 3.41+, Dart SDK 3.11+

## Configuration

Open **Settings** in the app:

| Setting | Description | Default |
|---------|-------------|---------|
| Base URL | API endpoint | `https://api.openai.com/v1` |
| API Key | Your API key | — |
| Models | Comma-separated model list | `gpt-4o, gpt-4o-mini, ...` |
| Temperature | Creativity (0–2) | `0.7` |
| Max Tokens | Response length limit | `4096` |
| System Prompt | Default assistant instruction | LaTeX-aware prompt |
| Font / Size | Chat message typography | System / 14px |
| Borderless Mode | Remove chat bubbles | Off |
| Smart Auto-scroll | Follow streaming output | On |
| Cloud Sync | WebDAV or Upstash | Off |

## Rendering Examples

```
Inline math:   $E = mc^2$
Display math:  $$\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}$$
Chemistry:     $\ce{H2O}$   $\ce{2H2 + O2 -> 2H2O}$
Flowchart:     ```mermaid\ngraph TD; A-->B; B-->C;\n```
```

## Project Structure

```
lib/
├── main.dart                      # Entry point, platform detection, window setup
├── app.dart                       # MaterialApp + dynamic theming
├── models/
│   ├── message.dart               # Message, Conversation
│   ├── note.dart                  # Note, WikiLink (tags, frontmatter, wiki-links)
│   └── saved_password.dart        # Password entry model
├── providers/
│   ├── chat_provider.dart         # Conversations, streaming API, search
│   ├── settings_provider.dart     # All settings + persistence
│   ├── notes_provider.dart        # Notes CRUD + cloud sync
│   ├── image_generation_provider.dart  # Image gen state
│   └── password_provider.dart     # Password history
├── pages/
│   ├── home_page.dart             # Navigation shell (Fluent sidebar / M3 bottom nav)
│   ├── chat_page.dart             # Chat UI + image generation tab
│   ├── settings_page.dart         # Settings UI
│   ├── notes_page.dart            # Notes list (tabs: all/starred/recent/tags)
│   ├── note_detail_page.dart      # Markdown editor + preview
│   ├── graph_page.dart            # Wiki-link knowledge graph
│   ├── tools_page.dart            # Tools hub
│   ├── image_generation_page.dart # Standalone image generation
│   ├── video_compressor_page.dart # Video compression
│   ├── video_to_audio_page.dart   # Audio extraction
│   ├── date_time_converter_page.dart
│   ├── base64_converter_page.dart
│   ├── password_generator_page.dart
│   ├── short_url_page.dart
│   └── about_page.dart
├── widgets/
│   ├── message_bubble.dart        # Chat bubbles (M3 + Fluent variants)
│   ├── rich_content_view.dart     # Markdown + LaTeX + Mermaid renderer
│   ├── welcome_view.dart          # Empty state
│   └── flowchart/                 # Mermaid parser + custom painter
└── utils/
    ├── update_checker.dart        # GitHub Releases update check
    ├── navigation_helper.dart     # Cross-page navigation callbacks
    └── build_config.dart          # Build metadata
```

## License

MIT
