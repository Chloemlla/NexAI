# Android AI tool chat gaps vs cherry-studio

## Goal
对比 NexAI Android 客户端现有 AI 对话体验与 cherry-studio 的 AI 工具对话能力，沉淀一份 **Android 可实现** 的缺口清单与落地优先级文档，作为后续功能规划依据，而非本任务直接实现代码。

## What I already know
- NexAI Android 聊天是薄 SSE 文本客户端：OpenAI-compatible + Vertex 流式文本、会话管理、编辑重发、Markdown/LaTeX/Mermaid、导出、存笔记、云同步。
- NexAI 的“工具页”是独立功能页（翻译、绘图、短链、编解码等），**不是**对话内 tool-calling。
- cherry-studio 是完整工具/Agent 对话产品：assistant/topic、builtin tools、MCP、知识库检索工具、web search、附件管线、message parts、tool approval、agent/skills 等。
- 用户要求：只列 **缺少且能在安卓实现** 的能力，并形成 Trellis 文档。

## Assumptions
- 对标重点是“AI 工具对话体验”，不是完整复制 cherry 桌面生态。
- Android 实现以 Flutter 客户端为主，必要时可依赖 NexAI 后端/代理提供搜索或 tool gateway。
- 本地 shell agent、任意二进制安装、桌面多窗口等不纳入。

## Requirements
1. 产出 gap matrix：cherry 有 / NexAI 无 / Android 可实现 / 优先级 / 依赖。
2. 明确 MVP 与后续阶段，避免把桌面 agent 能力误列入 Android。
3. 把结论写入 Trellis task 与 `docs/trellis/` 可查阅文档。
4. 每项缺口附上 NexAI 现有落点或改造面（provider/model/UI）。

## Acceptance Criteria
- [x] 完成 NexAI Android 聊天能力基线调研
- [x] 完成 cherry-studio AI 工具对话能力盘点
- [x] 产出 Android 可行性过滤
- [x] 形成结构化缺口文档（P0/P1/P2）
- [x] 文档落在 Trellis task 与 docs/trellis

## Definition of Done
- research 文件齐全
- prd/info 与 docs 文档齐全
- 提交 git commit（文档任务）

## Out of Scope
- 本任务不实现 tool-calling 代码
- 不迁移 cherry 桌面 agent / binary manager
- 不改造 Windows WinUI 客户端

## Research References
- [`research/nexai-android-chat-baseline.md`](research/nexai-android-chat-baseline.md)
- [`research/cherry-studio-ai-tools-inventory.md`](research/cherry-studio-ai-tools-inventory.md)
- [`research/android-feasibility.md`](research/android-feasibility.md)
- 外部可读文档：[`docs/trellis/07-18-android-ai-tools-gap-vs-cherry/README.md`](../../../../docs/trellis/07-18-android-ai-tools-gap-vs-cherry/README.md)

## Decision (ADR-lite)
**Context**: cherry-studio 能力面很广，直接全量对标会把 Android 拖进桌面 agent 复杂度。  
**Decision**: 以“对话内工具增强”为中心，按 Android 沙箱可行性裁剪，输出 P0 基础协议与检索工具、P1 多模态与助手体系、P2 远程 MCP/多模型/语音等。  
**Consequences**: 文档可直接拆后续实现任务；桌面专属能力明确排除，减少错误预期。

## Technical Notes
- NexAI 关键改造面：
  - `lib/models/message.dart` → message parts
  - `lib/providers/chat_provider.dart` → tool loop / cancel / multimodal payload
  - `lib/pages/chat_page.dart` + composer widgets → attachments / tool toggles
  - `lib/widgets/message_bubble.dart` → tool/citation/reasoning cards
  - 可选后端：search/tool gateway、vision model、remote MCP proxy
