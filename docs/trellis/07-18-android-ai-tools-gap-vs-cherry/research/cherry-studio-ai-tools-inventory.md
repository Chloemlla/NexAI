# research: cherry-studio AI tool chat inventory

## Product position
Cherry Studio is a desktop Electron client for multi-provider LLM chat with a full tool/agent surface. Source inspected under `F:\Repositories\GitHub\cherry-studio`.

## Capability areas relevant to AI tool conversation

### 1. Provider & model platform
- Multi-provider registry (`packages/provider-registry`)
- Assistant-level model binding (`providerId::modelId`)
- Inference knobs: temperature/topP/maxTokens/stream/reasoning_effort/custom params
- Provider-native reasoning and usage stats

### 2. Assistants / topics / conversation structure
- 300+ preset assistants + custom assistants
- Assistant owns system prompt, tools, MCP servers, knowledge bases
- Topic management with branching (`docs/references/chat/message-tree.md`, `TopicBranchPanel`)
- Multi-model simultaneous conversations
- Temporary topics, topic naming, overlays

### 3. Builtin tool calling (chat tools)
From `src/shared/ai/builtinTools.ts` and related modules:
- `kb_list` / `kb_search` / `kb_read` / `kb_manage`
- `web_search` / `web_fetch`
- `generate_image`
- `report_artifacts`
- `read_file`
- Agent-side job tools: `cron` / `notify` / `config`
- Tool origin model: builtin / mcp / internal
- Tool approval modes: auto / prompt

### 4. MCP ecosystem
- MCP server configuration and catalogs
- MCP tools / prompts / resources
- MCP mode on assistant: disabled / auto / manual
- MCP marketplace roadmap / shared MCP types
- MCP trace package

### 5. Knowledge base as retrieval tools
- Local knowledge service with vector index + FTS
- Knowledge items: files/urls/notes
- Agent can list/search/read/manage knowledge through tools
- Knowledge base scoped from chat composer

### 6. Web search providers
Preset providers: zhipu, tavily, searxng, exa, exa-mcp, bocha, querit, fetch, jina, firecrawl
Capabilities: keyword search and URL fetch

### 7. Composer / multimodal input
- Attachment pipeline (`composerAttachment`, file tokens)
- File processor features: image-to-text, document-to-markdown
- Mention models, knowledge-base scope, prompt variables
- Follow-up queue, input history, draft cache
- Quote / regenerate / edit drafts
- Permission request composer and ask-user-question composer for tool loops

### 8. Message parts & observability
- AI SDK UIMessage parts: text, reasoning, files, dynamic tools, data parts
- Message stats: prompt/completion/thoughts tokens, cache tokens, cost, latency
- Citation utilities
- Stream manager / execution overlay / tool registry docs

### 9. Agent / skill runtime
- Claude Code agent type
- Builtin code-agent tools (Bash/Edit/Read/Grep/WebSearch/...)
- Skills install/search sources
- Agent session export/runtime
- Binary tool manager (uv/bun/rg/gh/...)

### 10. Product surfaces around chat
- Translate page + message translation
- Paintings / image generation parameters
- Mini apps
- Quick assistant floating window
- Selection toolbar / selection assistant
- WebDAV backup and enterprise knowledge features (product docs)

## Android feasibility filter
Many cherry features assume desktop OS privileges (local shell, arbitrary binary install, multi-window, Claude Code filesystem agent). For NexAI Android, only capabilities that can run under mobile sandbox + Flutter/native Android APIs or remote backends are candidates.
