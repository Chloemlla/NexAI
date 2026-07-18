# NexAI Android AI 工具对话缺口对照（vs cherry-studio）

> 日期：2026-07-18  
> 范围：NexAI Android / Flutter 客户端已有 AI 对话体验，对标 `F:\Repositories\GitHub\cherry-studio`  
> 目标：只列 **NexAI 缺少、且 Android 可实现** 的能力，形成后续实现任务拆分依据

## 1. 一句话结论

NexAI Android 目前是“**高质量文本流式聊天 + 独立工具页**”，不是 cherry-studio 那种“**对话内 tool-calling / 检索增强 / 多模态 composer / assistant 运行时**”。  
Android 最值得补的不是桌面 Agent 全家桶，而是：

1. 消息协议与工具循环基础
2. 检索类工具（联网搜索、笔记知识）
3. 多模态输入与结果引用展示
4. 助手体系与对话控制（停止、重生成、分支、人设）

## 2. 现状基线

### 2.1 NexAI Android 已有

| 能力 | 现状 | 主要落点 |
|---|---|---|
| 多会话管理 | 有 | `ChatProvider` / `Conversation` |
| 流式文本回复 | 有（OpenAI / Vertex SSE） | `chat_provider.dart` |
| 编辑重发 / 失败重试 | 有 | `message_bubble.dart` |
| Markdown / LaTeX / Mermaid | 有 | `rich_content_view.dart` |
| 导出 Markdown / 图片 | 有 | `message_bubble.dart` |
| 存到笔记 | 有 | message → `NotesProvider` |
| 全局聊天搜索 | 有 | `searchMessages` |
| 模型/温度/系统提示词 | 有 | `SettingsProvider` |
| 云同步会话 | 有 | chat restore/merge |
| AI 翻译 / AI 绘图 | 有，但是**独立页面** | `tools_page.dart` 等 |
| Artifacts 分享 | 有，但是**独立能力** | `Artifact` / artifacts page |

### 2.2 cherry-studio 的工具对话核心

| 能力域 | cherry 现状 |
|---|---|
| Assistant | 预设/自定义助手，绑定模型、prompt、MCP、知识库、工具开关 |
| Topic / 消息树 | 分支、重生成 sibling、active branch |
| Builtin tools | `web_search`/`web_fetch`、`kb_*`、`generate_image`、`read_file`、`report_artifacts` 等 |
| MCP | server 目录、tool/prompt/resource、approval |
| Composer | 附件、mention model、知识库范围、follow-up queue、权限确认 |
| Message parts | text / reasoning / tool / file / citation / stats |
| Agent/Skills | Claude Code agent、skills 市场、二进制工具管理 |

### 2.3 关键架构差

- NexAI `Message` = `role + content + timestamp + isError`
- cherry `Message` = AI SDK `parts[]` + tool/reasoning/file/data + stats + branch metadata
- NexAI 聊天请求不带 `tools`，也不消费 `tool_calls`
- NexAI 工具页与聊天页解耦；cherry 工具是对话运行时一等公民

## 3. Android 可实现缺口总表

> 状态说明  
> - **P0**：对话工具化的地基，优先做  
> - **P1**：明显提升“AI 工具对话”体感  
> - **P2**：增强项，可后置  
> - **排除**：桌面特化 / Android 不适合作为产品路径

| ID | 缺口 | cherry 参照 | Android 可行性 | 优先级 | NexAI 改造面 | 依赖 |
|---|---|---|---|---|---|---|
| G01 | 消息 parts 模型（text/tool/reasoning/file/citation） | UIMessage parts | 高 | P0 | `models/message.dart` 持久化升级 | 无 |
| G02 | tool-calling 协议与工具循环 | builtin tools + tool registry | 高/中 | P0 | `ChatProvider` 请求/解析/回灌 tool result | 模型/网关支持 tools |
| G03 | 工具审批 UI（auto/prompt） | tool approval / permission composer | 高 | P0 | bottom sheet + tool policy | G01/G02 |
| G04 | 停止 / 取消生成 | stream cancel | 高 | P0 | Dio CancelToken + 发送按钮态 | 无 |
| G05 | 重生成备选 / 基础消息分支 | regenerate + message tree | 高 | P0 | conversation graph / sibling group | G01 |
| G06 | 引用/来源卡片 | citation utils | 高 | P0 | bubble 卡片 UI | 搜索/知识工具结果 |
| G07 | 联网搜索工具 `web_search` | web search providers | 中高 | P0 | tool executor + 设置页 provider key | 后端或第三方搜索 API |
| G08 | 网页抓取工具 `web_fetch` | fetch/jina 等 | 中高 | P1 | tool executor | 同源搜索网关 |
| G09 | 笔记知识检索工具 | `kb_search/read` | 高 | P0 | Notes FTS / 本地索引 → tool | Notes 已有 |
| G10 | 文档导入知识库（文件/URL/笔记） | knowledge service | 中 | P1 | 导入器 + 分块 + 检索 | 存储/解析库或后端 |
| G11 | 图片附件 + Vision 对话 | chat attachments | 高/中 | P1 | composer 附件 + multipart/base64 content | 多模态模型 |
| G12 | PDF/文本附件理解 | file processor | 中 | P1 | SAF 选文件 + 本地/远端解析 | 解析器或后端 |
| G13 | 助手 / 人设目录 | assistants catalog | 高 | P1 | 本地 presets + 自定义 assistant | 无 |
| G14 | 会话级模型 / 提示词覆盖 | assistant/topic settings | 高 | P1 | conversation settings | G13 |
| G15 | 多模型同问对比 | multi-model conversation | 中 | P2 | 并行流式请求 + 分栏/标签结果 | 成本与流量 |
| G16 | Reasoning / thinking 折叠区 | reasoning parts | 中高 | P1 | 流解析 + collapsible UI | 模型返回 reasoning |
| G17 | Token / 耗时 / 费用统计 | message stats | 中高 | P2 | 解析 usage + 本地估算 | API usage 字段 |
| G18 | 对话内 `generate_image` 工具 | generate_image tool | 高 | P1 | 复用 `ImageGenerationProvider` 作为 tool | G02 |
| G19 | 对话内 `report_artifacts` / 分享工具 | report_artifacts | 高 | P1 | 复用 Artifacts 服务 | 已有 artifacts |
| G20 | Prompt 模板与变量 | prompt variables | 高 | P1 | composer 模板展开 | 无 |
| G21 | Follow-up 队列（生成中继续排队） | follow-up queue | 高 | P1 | composer queue state | G04 |
| G22 | 消息翻译动作 | translate message | 高 | P1 | bubble action + Translation 服务 | 已有翻译页 |
| G23 | 语音输入 STT | composer voice | 高 | P2 | SpeechRecognizer / package | 权限与 OEM 差异 |
| G24 | 语音朗读 TTS | read aloud | 高 | P2 | platform TTS | 无 |
| G25 | 远程 MCP 客户端（HTTP/SSE） | MCP mode | 中 | P2 | MCP session client + tool bridge | 远程 MCP server / 后端代理 |
| G26 | 工具策略：最大调用次数、白名单 | maxToolCalls / origin policy | 高 | P0 | tool runtime policy | G02 |
| G27 | 更强导出：JSON 备份 / 分享会话包 | export/import | 高 | P2 | share sheet + schema version | G01 |
| G28 | 搜索命中跳转到消息并高亮 | global search UX | 高 | P2 | search result navigation polish | 已有 search |

## 4. 明确排除（Android 不作为产品路径）

| 排除项 | 原因 |
|---|---|
| Claude Code 本地 shell/file agent（Bash/Edit/Write/Glob 等） | 需要桌面工作区与高危本地执行权限 |
| 二进制工具管理器安装 uv/bun/rg/gh 作为通用 agent runtime | 移动端沙箱、体积、分发、签名与安全边界不合适 |
| 桌面划词助手 / 多窗口 Quick Assistant | 桌面交互模型 |
| 企业共享知识库后台管理 | 非 Android 客户端本轮范围 |
| 本地 stdio MCP | 移动端进程/可执行文件模型不匹配；仅考虑远程 MCP |

## 5. 推荐落地分期

### Phase 0 — 对话运行时地基（先做）
目标：让 Android 聊天从“纯文本 SSE”升级为“可扩展工具对话内核”。

- G01 消息 parts 与持久化兼容
- G02 tool call / tool result 循环
- G03 工具审批
- G04 停止生成
- G05 重生成与基础分支
- G06 来源卡片容器
- G26 工具调用护栏

**验收粗标**
- 能对支持 tools 的模型发起带 `tools` 的请求
- 能展示 tool call 卡片，用户确认后回灌结果
- 生成中可停止
- 旧会话文本消息仍可读取

### Phase 1 — 真正的“工具对话体验”
- G07 联网搜索
- G09 Notes 知识检索
- G11 图片 Vision 对话
- G13/G14 助手与会话级配置
- G16 reasoning UI
- G18/G19 对话内绘图与 artifact 分享
- G20/G21/G22 模板、排队、消息翻译

**验收粗标**
- 用户可在对话中开关“联网 / 知识库 / 绘图”
- 助手回答可带来源引用
- 可发图片提问
- 可选择不同助手人设

### Phase 2 — 增强与生态
- G08 web_fetch
- G10 文档知识库
- G15 多模型对比
- G17 usage 统计
- G23/G24 语音
- G25 远程 MCP
- G27/G28 导出与搜索体验打磨

## 6. 建议的 Android 工具最小集合

不要一次搬空 cherry。Android 第一批工具建议只做：

1. `web_search` — 联网检索  
2. `notes_search` / `notes_read` — 基于现有 Notes  
3. `generate_image` — 复用已有绘图能力  
4. `save_artifact` / `report_artifacts` — 复用分享能力  
5. `fetch_url`（可后置）— 打开/摘要网页  

可选但很有价值：
- `get_current_time`
- `device_clipboard_read`（需审批）
- `create_note` / `append_note`（把现有“存笔记”升级成模型可调用工具）

## 7. 关键实现约束（给后续开发）

1. **先改消息模型，再加工具**  
   继续用纯字符串 `content` 硬塞 tool JSON 会迅速失控。
2. **工具执行默认需审批**  
   搜索可默认 auto；写笔记、分享、读剪贴板、抓取任意 URL 应 prompt。
3. **优先走 NexAI 后端/代理**  
   Android 端尽量不做高权限本地 agent；搜索、MCP、复杂文件解析可服务端化。
4. **独立工具页先保留**  
   翻译/绘图等页可继续存在；对话内工具是增强，不是立刻删除工具页。
5. **本地构建限制**  
   本仓库约定本地不跑安装/完整构建测试；实现任务应把验证放进 GitHub workflow。

## 8. 后续可直接拆的任务

1. `feat(android): chat message parts foundation`
2. `feat(android): tool-calling runtime + approval`
3. `feat(android): stop/regenerate/branch controls`
4. `feat(android): web search tool + citations`
5. `feat(android): notes knowledge tools`
6. `feat(android): chat attachments + vision`
7. `feat(android): assistants presets and per-chat overrides`
8. `feat(android): remote MCP client`（Phase 2）

## 9. 参考路径

### NexAI
- `lib/providers/chat_provider.dart`
- `lib/models/message.dart`
- `lib/pages/chat_page.dart`
- `lib/widgets/message_bubble.dart`
- `lib/widgets/rich_content_view.dart`
- `lib/providers/settings_provider.dart`
- `lib/pages/tools_page.dart`
- `lib/providers/image_generation_provider.dart`

### cherry-studio
- `src/shared/ai/builtinTools.ts`
- `src/shared/ai/tool.ts`
- `src/shared/data/types/assistant.ts`
- `src/shared/data/types/message.ts`
- `src/shared/data/presets/webSearchProviders.ts`
- `src/shared/types/mcp.ts`
- `src/renderer/components/composer/**`
- `docs/references/chat/*`
- `docs/references/ai/*`
- `docs/references/knowledge/*`

### Trellis research
- `.trellis/tasks/07-18-android-ai-tools-gap-vs-cherry/research/nexai-android-chat-baseline.md`
- `.trellis/tasks/07-18-android-ai-tools-gap-vs-cherry/research/cherry-studio-ai-tools-inventory.md`
- `.trellis/tasks/07-18-android-ai-tools-gap-vs-cherry/research/android-feasibility.md`

## 10. Implementation snapshot (2026-07-18)

已落地第一批对话内工具（OpenAI 兼容模式）：

- `web_search`
- `notes_search` / `notes_read`
- `generate_image`
- `report_artifacts`
- `fetch_url`
- `create_note`

配套能力：

- tool-calling 循环与最大轮次护栏
- 工具审批 bottom sheet（prompt 策略工具）
- 停止生成
- 消息内 tool run 卡片与 citation chips
- 设置页工具开关

说明：Vertex 模式仍为纯文本流式，不走 tools。

## 11. Phase 1 implementation snapshot (2026-07-18)

在既有 tool-calling 基础上补齐真正工具对话体验：

- 图片附件 + Vision 请求（OpenAI content parts）
- 助手人设目录 + 会话级 assistant/model/prompt 覆盖
- Reasoning 折叠面板
- Prompt 模板插入
- 生成中 Follow-up 排队
- 消息翻译动作（复用 Lumen DeepLX 公共翻译）
- 对话内 generate_image / report_artifacts / notes / web_search 已在前序提交

仍属 Phase 2：多模型同问、远程 MCP、文档知识库导入、语音 STT/TTS。

## 12. Phase 2 implementation snapshot (2026-07-18)

已落地增强与生态能力：

- `fetch_url` 延续可用；新增 `knowledge_search` / `knowledge_read`
- 本地文档知识库导入（txt/md/json/csv/log）
- 多模型对比（会话级 compareModels，顺序生成 sibling 回答）
- usage / latency 统计（tokens + ttft + completionMs）
- STT 语音输入 + TTS 朗读
- 远程 MCP（HTTP/SSE JSON-RPC）服务器配置与工具刷新
- 会话 JSON 导出/导入
- 全局搜索命中跳转并高亮目标消息
- 助手消息重新生成

依赖新增（pubspec）：`speech_to_text`、`flutter_tts`、`share_plus`、`uuid`

## 13. Product rollout defaults (2026-07-18)

为可灰度上线，产品默认改为保守策略：

- 对话工具总开关默认 **关闭**
- 推荐工具：`notes_search` / `notes_read` / `create_note`（一键启用）
- 高级工具默认关闭：`web_search`、`fetch_url`、`generate_image`、`report_artifacts`、`knowledge_*`、远程 MCP
- 最大工具轮次默认 4，上限 8
- 多模型对比最多 3 个模型
- 移除未使用依赖 `uuid`

首发建议：内部包验证后，用“一键启用推荐工具”引导，不默认打开联网/MCP/多模型。

