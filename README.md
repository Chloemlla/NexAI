# NexAI

A beautiful AI chat client built with Flutter and Fluent Design, supporting OpenAI-compatible APIs.

![Flutter](https://img.shields.io/badge/Flutter-3.24-blue?logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Fluent Design UI** — Native Windows look and feel with Mica/Acrylic effects
- **Custom API Configuration** — Set your own base URL, API key, and available models
- **Multiple Models** — Configure models with comma-separated values (e.g. `gpt-4o, claude-3, deepseek-chat`)
- **Chemical Formula Rendering** — LaTeX math and `\ce{}` chemical notation support
- **Markdown Rendering** — Full GitHub-flavored Markdown with syntax-highlighted code blocks
- **Conversation Management** — Multiple chat sessions with history
- **Dark/Light Theme** — System-aware theming with manual override
- **Configurable Generation** — Temperature, max tokens, and system prompt settings

## Quick Start

### Using GitHub Actions (Recommended)

1. Add a `USER_PAT` secret to your repository (Settings → Secrets → Actions)
2. Go to Actions → "Setup Dependencies & Build NexAI"
3. Click "Run workflow" and select your target platform
4. Download the build artifact when complete

### Local Development

```bash
flutter pub get
flutter run -d windows
```

## Configuration

Open Settings in the app to configure:

| Setting | Description | Example |
|---------|-------------|---------|
| Base URL | API endpoint | `https://api.openai.com/v1` |
| API Key | Your API key | `sk-...` |
| Models | Comma-separated model list | `gpt-4o, gpt-4o-mini, gpt-3.5-turbo` |
| Temperature | Creativity (0-2) | `0.7` |
| Max Tokens | Response length limit | `4096` |

## Chemical Formula Examples

The app renders LaTeX and chemical formulas from AI responses:

- Inline math: `$E = mc^2$`
- Display math: `$$\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}$$`
- Chemical: `$\ce{H2O}$`, `$\ce{2H2 + O2 -> 2H2O}$`
- Organic: `$\ce{CH3COOH}$`

## Project Structure

```
lib/
├── main.dart              # App entry point
├── app.dart               # FluentApp configuration
├── models/
│   └── message.dart       # Data models
├── providers/
│   ├── chat_provider.dart     # Chat state & API calls
│   └── settings_provider.dart # Settings persistence
├── pages/
│   ├── home_page.dart     # Navigation shell
│   ├── chat_page.dart     # Chat interface
│   └── settings_page.dart # Settings UI
└── widgets/
    ├── message_bubble.dart    # Message display
    ├── rich_content_view.dart # Markdown + LaTeX renderer
    └── welcome_view.dart      # Empty state
```

## License

MIT
