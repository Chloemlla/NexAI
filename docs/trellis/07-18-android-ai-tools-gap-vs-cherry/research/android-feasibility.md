# research: Android feasibility of cherry-studio chat gaps

## Feasibility classes
- **A — Android native feasible now**: pure client UI + HTTP/SSE + local storage / SAF / MediaStore / WorkManager
- **B — Feasible with NexAI backend/proxy**: client UX exists if server provides tool execution, search, or model-native tool calls
- **C — Partial / constrained**: possible but limited by sandbox, OEM variance, battery, storage
- **D — Not suitable for Android product path**: desktop shell agent, arbitrary binary runtime, multi-window desktop chrome

## Recommended Android-feasible gaps
| Gap | Class | Why feasible on Android |
|---|---|---|
| Message parts model (text/tool/reasoning/citation/file) | A | Local model redesign + streaming parser |
| Stop/cancel generation | A | CancelToken / stream subscription cancel |
| Multimodal attachments (image/pdf/text) | A/B | image_picker, file_picker, SAF; PDF parse can be local or backend |
| Vision chat (image input to model) | B | Needs multimodal model endpoint already usable by NexAI proxy |
| Web search + fetch tools | B | Call remote search providers or NexAI backend tool gateway |
| Tool call loop + approval sheet | A/B | UI and state machine local; tool executors may be remote |
| Citations / source cards in bubble | A | Rendering only once search/tool results exist |
| Assistants/personas catalog | A | Local preset + custom system prompts |
| Per-conversation model override | A | Settings already multi-model |
| Multi-model compare / regenerate alternatives | A/B | Parallel HTTP streams; higher cost/bandwidth |
| Message branch tree | A | Local conversation graph redesign |
| Reasoning/thinking stream UI | A/B | Parser + collapsible UI; provider dependent |
| Token/cost metrics | A/B | Parse usage if API returns it |
| Knowledge base search over Notes/files | A/C | Start with Notes FTS; vector search can be local lite or server |
| In-chat image generation tool | B | Reuse existing image generation provider as tool backend |
| Artifacts tool / share from chat | A | Existing Artifacts service already exists |
| Prompt templates / variables | A | Local template expansion |
| Chat history export/import richer formats | A | JSON/Markdown share sheets |
| Follow-up queue / compose while streaming | A | Local queue state |
| Speech-to-text input | A | Android SpeechRecognizer / system STT |
| TTS read aloud | A | flutter_tts / platform TTS |
| Message translation action | A/B | Reuse translation service from tools page |
| MCP remote HTTP/SSE client | B/C | Remote MCP over network is possible; local stdio MCP is not |
| Tool policy / max tool calls | A | Local guardrails |

## Explicitly out of Android MVP scope
- Claude Code local shell agent (Bash/Edit/Write over device FS)
- Binary tool manager installing uv/bun/rg/gh into app sandbox as general agent runtime
- Desktop selection toolbar / multi-window quick assistant
- Full enterprise shared knowledge admin backend
- Desktop WebDAV file manager parity as chat dependency

## Suggested Android MVP slice
1. Message parts + tool call protocol foundation
2. Stop generation + regenerate + basic branching
3. Attachment + vision (image) chat
4. Web search tool with citation cards
5. Notes-backed knowledge search tool
6. Assistants presets + per-conversation system prompt/model
7. Tool approval UI and max-tool-call guard

## Suggested phase 2
- Remote MCP client
- Multi-model simultaneous answers
- Vector knowledge over imported docs
- In-chat generate_image / report_artifacts tools
- Reasoning UI + usage metrics
- Voice input/output polish
