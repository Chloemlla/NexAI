# research: NexAI Android AI chat baseline

## Scope
Android/Flutter AI conversation surface as of 2026-07-18, focused on tool-enabled chat experience rather than standalone utility pages.

## Primary modules
- `lib/providers/chat_provider.dart`
- `lib/models/message.dart`
- `lib/pages/chat_page.dart`
- `lib/widgets/message_bubble.dart`
- `lib/widgets/rich_content_view.dart`
- `lib/providers/settings_provider.dart`
- `lib/pages/tools_page.dart`
- `lib/providers/image_generation_provider.dart`
- `lib/models/artifact.dart`

## What NexAI Android already has

### Conversation core
- Multi-conversation list with create/select/delete
- Local persistence in `nexai_chats.json`
- Cloud sync restore/merge for conversations
- Streaming text responses for OpenAI-compatible and Vertex SSE
- Global message text search across conversations
- Conversation draft restore when switching chats
- Smart auto-scroll / jump-to-latest

### Message actions
- Copy assistant reply
- Edit + resend user message
- Resend after failure
- Export conversation as Markdown
- Export bubble/conversation image (PNG / gallery)
- Save message content into Notes (new note or append)

### Rendering
- Markdown rendering
- LaTeX / chemical formula rendering
- Mermaid flowchart rendering

### Settings / providers
- OpenAI-compatible mode: base URL, API key, model list, selected model
- Vertex mode: API key / project / location / model list
- Temperature, max tokens, system prompt
- Secure storage for keys

### Adjacent product tools (not tool-calling in chat)
- Standalone AI translation page
- Standalone AI image generation page (`chat` / `images/generations` / `images/edits`)
- Artifacts share (code/markdown/mermaid/html share links)
- Notes + graph page
- Utility tools: video compress/extract, Base64, datetime, password, short URL

## Explicit missing capability in chat path
- No `tools` / `tool_calls` protocol support
- Message model is plain `role + content` text only
- No multimodal user content (image/file/audio attachments in composer)
- No reasoning/thinking part stream rendering
- No citations / web search results attached to assistant messages
- No assistant/persona catalog
- No per-conversation model override or multi-model compare
- No stop/cancel generation control
- No message branching / regenerate alternative siblings
- No token usage / cost metrics on messages
- No MCP / agent loop / skill runtime inside chat

## Architectural implication
NexAI currently treats chat as a thin SSE client over text completion. Tool-enabled conversation will require a message-part model, a tool registry, an execution/approval layer, and richer composer + bubble UI.
