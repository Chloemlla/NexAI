# NexAI Android AI 工具对话缺口对照（刷新版 vs cherry-studio）

> 日期：2026-07-18  
> 范围：NexAI Android/Flutter **当前已落地** 的 AI 工具对话体验  
> 对标：`F:\Repositories\GitHub\cherry-studio`  
> 目标：只列 **仍然缺少、且 Android 可实现** 的能力

## 1. 一句话结论

NexAI Android 已从“纯文本 SSE + 独立工具页”升级为“**对话内 tool-calling 可用**”：

- 已有：tools 循环、审批、停止生成、重生成、图片附件、搜索/笔记/知识库/绘图/artifacts/fetch/create_note、远程 MCP 基础、助手人设、follow-up 队列、reasoning/citations/stats 雏形。

但仍显著落后 cherry-studio 的点，集中在：

1. **工具体验深度**（composer 工具入口、tool result 细节、策略编排）
2. **知识库产品化**（多库/目录/管理/语义检索）
3. **检索质量与 provider 生态**
4. **分支/多模型对比 UX**
5. **MCP 完整度与统一工具网关**

不是“从 0 缺工具”，而是“有运行时、缺产品完成度”。

## 2. 当前 NexAI 已有能力（不再算缺口）

| 能力 | 状态 | 主要落点 |
|---|---|---|
| tool-calling 循环 | 有（OpenAI 模式） | `chat_provider.dart` |
| 工具审批 auto/prompt | 有 | `ChatToolApprovalPolicy` + UI |
| 最大工具轮次 | 有 | `maxToolRounds` |
| 停止生成 | 有 | `cancelGeneration` |
| 重生成 | 有 | `regenerateLastAssistant` |
| web_search | 有 | DDG + 可选 proxy |
| notes_search/read | 有 | NotesProvider |
| knowledge_search/read | 有 | KnowledgeProvider（文本导入） |
| generate_image | 有 | ImageGenerationProvider |
| report_artifacts | 有 | ArtifactsProvider |
| fetch_url | 有 | executor HTML extract |
| create_note | 有 | NotesProvider |
| 远程 MCP tools/list+call | 有（基础） | `remote_mcp_client.dart` |
| 图片附件 | 有 | `ChatAttachment` |
| reasoning 折叠 | 有 | bubble panel |
| citations chips | 有 | bubble |
| 助手 presets | 有 | `ChatAssistantCatalog` |
| 会话级模型/助手覆盖 | 有 | conversation settings |
| compareModels 基础 | 有 | sequential/parallel prep |
| follow-up queue | 有 | chat provider queue |
| prompt templates | 有 | PromptTemplateCatalog |
| 消息翻译 | 有 | Lumen DeepLX |
| STT/TTS 基础 | 有 | `chat_speech_service.dart` |
| 工具设置开关/引导 | 有 | Settings + onboarding banner |

## 3. cherry-studio 仍领先的核心面

| 能力域 | cherry | NexAI Android 现状 |
|---|---|---|
| Assistant 运行时 | 工具/MCP/KB/策略深度绑定 | 主要是 system prompt presets |
| Knowledge | 多库、目录、manage、语义检索 | 扁平导入文档 + 关键词检索 |
| Web search | 多 provider 生态 | 单薄 provider |
| Message/topic tree | 完整分支导航 | 仅 sibling 元数据 |
| MCP | tools/prompts/resources/market | tools 调用骨架 |
| Composer | 工具芯片、权限流、文档处理管线 | 设置驱动 + 基础附件 |
| Agent | Claude Code / skills / binary tools | 不做（Android 排除） |

## 4. 仍缺少且 Android 可实现缺口

### P0（立刻影响“好用”）

| ID | 缺口 | 可行性 | 建议改造面 |
|---|---|---|---|
| R01 | 消息 parts / 导出版本化 schema | A | `message.dart` 持久化与导入导出 |
| R02 | 分支导航 UI（切换 sibling / active path） | A | chat list + bubble + conversation graph |
| R03 | 多搜索 provider 配置（Tavily/SearXNG/Exa/Jina 等） | B | settings + executor provider router |
| R10 | tool result 详情 UX（展开/原始 JSON/重试） | A | `message_bubble` tool cards |
| R18 | Composer 内工具开关芯片（search/kb/image/mcp） | A | `chat_page` composer |
| R24 | 后端工具网关契约（search/fetch/mcp proxy） | B | backend + client gateway |

### P1（体感与生态）

| ID | 缺口 | 可行性 |
|---|---|---|
| R04 | 搜索 grounding / citation 排序去重 | B |
| R05 | 多知识库 + 目录结构 | A/C |
| R06 | 知识库管理工具（增删改） | A |
| R07 | 语义/向量检索 | B/C |
| R08 | PDF/DOCX 附件理解 | C |
| R09 | Vision 多图压缩与 provider 回退 | B |
| R11 | Assistant 绑定 tools/MCP/KB 策略 | A |
| R16 | MCP prompts/resources + 发现缓存 UI | B/C |
| R17 | MCP 健康检查/测试连接/白名单 | A |
| R20 | 引用到输入框、从消息建分支等动作 | A |
| R23 | Vertex/tools 统一适配或强制网关 | B |

### P2（增强）

| ID | 缺口 | 可行性 |
|---|---|---|
| R12 | 临时会话 / 自动标题 / topic 面板 | A |
| R13 | 多模型并排对比完整 UX | A/B |
| R14 | reasoning budget 控制 | B |
| R15 | 会话级 token/cost 看板 | A/B |
| R19 | follow-up 队列可编辑管理 | A |
| R21 | STT/TTS 体验打磨 | C |
| R22 | 会话包导入导出（含工具/附件元数据） | A |

## 5. 明确排除（Android 不走）

- 本地 Claude Code shell/file agent（Bash/Edit/Write 等）
- 二进制工具管理器（uv/bun/rg/gh）
- 桌面划词助手 / 多窗口 Quick Assistant
- 本地 stdio MCP
- 企业共享知识库后台管理

## 6. 推荐下一阶段实现顺序

### Phase A — 可用性打磨（1~2 个任务）
1. Composer 工具芯片（R18）
2. Tool result 详情与重试（R10）
3. 分支导航 UI（R02）

### Phase B — 检索与知识产品化
1. 搜索 provider 体系（R03/R04）
2. 多知识库 + 管理工具（R05/R06）
3. 语义检索（R07）

### Phase C — 生态
1. MCP 发现/健康/资源（R16/R17）
2. 工具网关 + Vertex 对齐（R23/R24）
3. 多模型对比与导出（R13/R22）

## 7. 可直接拆的后续任务

1. `feat(android): composer tool chips + tool result details`
2. `feat(android): conversation branch navigator`
3. `feat(android): multi web-search providers`
4. `feat(android): multi-base knowledge + manage tools`
5. `feat(android): remote mcp discovery health ui`
6. `feat(android): unified tool gateway (openai/vertex)`

## 8. 参考

### NexAI
- `lib/providers/chat_provider.dart`
- `lib/services/chat_tool_catalog.dart`
- `lib/services/chat_tool_executor.dart`
- `lib/services/remote_mcp_client.dart`
- `lib/models/message.dart`
- `lib/models/chat_assistant.dart`
- `lib/models/chat_knowledge.dart`
- `lib/pages/chat_page.dart`
- `lib/widgets/message_bubble.dart`

### cherry-studio
- `src/shared/ai/builtinTools.ts`
- `src/shared/data/types/assistant.ts`
- `src/shared/data/types/message.ts`
- `src/shared/types/mcp.ts`
- `src/main/services/webSearch/*`
- `src/shared/ai/claudecode/*`

### Trellis research
- `.trellis/tasks/07-18-android-ai-tools-gap-refresh/research/nexai-current-baseline.md`
- `.trellis/tasks/07-18-android-ai-tools-gap-refresh/research/cherry-inventory.md`
- `.trellis/tasks/07-18-android-ai-tools-gap-refresh/research/remaining-gaps.md`
