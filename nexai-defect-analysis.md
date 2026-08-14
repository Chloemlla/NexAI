# NexAI 缺陷分析报告

> 分析日期: 2026-08-14
> 分析方法: 静态代码审查，7 个并行 subagent 覆盖不相交模块
> 项目: Chloemlla/NexAI (Flutter/Dart + Android + WinUI3)

---

## 严重程度分布

| 严重度 | 数量 | 已验证 |
|--------|------|--------|
| 🔴 高 (High) | 2 | ✅ 全部确认 |
| 🟡 中 (Medium) | 6 | ✅ 全部确认 |
| 🟢 低 (Low) | 11 | ✅ 全部确认 |
| ❌ 误报排除 | 7 | — |

---

## 🔴 高严重度

### H1. MCP Bearer Token 重启后丢失

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/settings_provider.dart` |
| 行号 | 347 (调用) vs 348-360 (数据加载) |

**缺陷描述**: `loadSettings()` 中，`await _restoreToolSecrets()` 在第 347 行调用，此时 `_mcpServers` 尚未从 SharedPreferences 反序列化（第 348-360 行）。`_restoreToolSecrets`（第 597-610 行）遍历 `_mcpServers` 时它仍是空数组 `[]`，因此存储在 secure storage 中的 `mcp:<id>` bearer token 永远不会被恢复。WebSearchProvider 的 secret 正常工作，因为 `_webSearchProviders` 已提前加载。

**影响**: 配置了 bearer token 的 MCP 服务器每次重启后静默丢失认证，token 仅在配置的会话中有效。

**修复**: 将 `await _restoreToolSecrets();` 移到 mcpServers 加载块之后。

---

### H2. 多模型对比污染上下文

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/chat_provider.dart` |
| 行号 | 843-860 (循环), 977-980 (payload 构建) |

**缺陷描述**: `_performMultiModelCompare` 循环遍历模型，每次都调用 `_performOpenAiToolLoop` 并传入**同一个 `conversation` 对象**。`_performOpenAiCall` 从 `conversation.messages` 构建 payload，因此模型 i>0 的上下文已包含模型 0 的 assistant 回复和 tool 消息。各模型的结果并非独立，完全违背了对比功能的初衷。

**影响**: 多模型对比结果不可靠，后续模型的结果包含前置模型的输出。

**修复**: 每个模型应使用独立的 `conversation` 副本，或每次循环后回滚临时消息。

---

## 🟡 中严重度

### M1. 工具执行失败消息被跳过导致 API 协议违规

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/chat_provider.dart` |
| 行号 | 978 (跳过), 1241-1248 (添加错误消息) |

**缺陷描述**: 当工具执行失败时，`_executeToolCalls` 添加 `role:'tool'` 消息并设置 `isError: true`（第 1241-1248 行）。但在下一轮 API 调用中，第 978 行的 `if (msg.isError) continue;` 跳过了这条错误消息。然而包含 `tool_calls` 的 assistant 消息未被跳过。OpenAI API 因此收到不完整的 tool 响应序列，API 协议违规导致后续请求失败，模型也永远不知道工具执行失败。

**影响**: 工具执行失败后，后续工具调用必然失败，且无错误提示。

**修复**: 错误工具消息不应跳过，或应移除对应的 `tool_calls` 条目。

---

### M2. renameTag 误替换共享前缀标签

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/notes_provider.dart` |
| 行号 | 316 |

**缺陷描述**: `note.content.replaceAll('#$oldTag', '#$newTag')` 是无边界检查的字符串替换。重命名标签 `ai` 会错误地将 `#air` 替换为 `#xxr`。对比之下，`deleteTag`（第 334 行）正确使用了 `RegExp('#$tag(?![\\w/])')` 边界检查。

**影响**: 标签重命名/合并操作会破坏正常文本内容。

**修复**: 使用与 `deleteTag` 一致的 `RegExp` 边界匹配。

---

### M3. loadSettings 异常导致半初始化状态

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/settings_provider.dart` |
| 行号 | 263-416 (try/finally 无 catch) |

**缺陷描述**: `loadSettings` 使用 `try/finally` 但没有 `catch` 块。`_secure.read(...)` 调用（第 276-279 行）在 secure storage 不可用的平台上可能抛出异常。异常逃逸后，`finally` 块已设置 `_loaded = true` 并调用 `notifyListeners()`，调用者收到半初始化的状态且未处理的异步错误。

**影响**: 应用启动时可能出现不一致的设置状态，部分字段为空但 `_loaded` 为 true。

**修复**: 添加 `catch` 块处理 secure storage 异常，或单独保护每个 `_secure.read` 调用。

---

### M4. 同步成功但因服务器时间格式错误报告失败

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/sync_provider.dart` |
| 行号 | 97-100 (调用), 271 (_saveLastSyncedAt) |

**缺陷描述**: `uploadAll` 中，`response['serverTime']` 作为字符串读取后传入 `_saveLastSyncedAt`，后者调用 `DateTime.parse(isoTime)`（第 271 行）。如果 `serverTime` 不是 ISO-8601 格式，`DateTime.parse` 抛出异常，`catch` 块捕获后返回 `false`（"上传失败"），但数据实际已成功存储在服务器上。`downloadAll` 中存在相同风险（第 172 行）。

**影响**: 误报上传失败，用户可能重复上传相同数据。

**修复**: 使用 `DateTime.tryParse` 并提供 fallback 值。

---

### M5. 工具执行取消路径无停止提示

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/chat_provider.dart` |
| 行号 | 1157-1159 (返回 false), 948-949 (静默返回) |

**缺陷描述**: 当用户取消工具执行时，`_executeToolCalls` 返回 `false`，`_performOpenAiToolLoop` 在第 948-949 行静默返回，未添加"已停止生成"消息。对比正常取消路径（第 728-730 行）会添加 `Message(role: 'assistant', content: '已停止生成。')`。

**影响**: 用户在工具执行过程中取消时无任何反馈，且后续队列继续执行。

**修复**: 在取消返回前添加停止消息。

---

### M6. logout 中 token 清除异常导致 UI 卡死

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/auth_provider.dart` |
| 行号 | 496-500 |

**缺陷描述**: `finally` 块顺序执行 `await _clearTokens(); _isLoading = false; notifyListeners();`。如果 `_clearTokens()` 内部的 secure storage delete 操作抛出异常，`_isLoading = false` 和 `notifyListeners()` 都被跳过，provider 永久卡在 loading 状态。

**影响**: 退出登录后 UI 可能永久卡在加载状态，用户无法重新登录。

**修复**: 将 `_isLoading = false; notifyListeners();` 放在独立的 `try/finally` 或使用 `await _clearTokens().catchError(...)`。

---

## 🟢 低严重度

### L1. Artifact.fromJson 缺少 createdAt 时崩溃

| 字段 | 值 |
|------|-----|
| 文件 | `lib/models/artifact.dart` |
| 行号 | 45 |

**缺陷描述**: `DateTime.parse(createdAtRaw.toString())` — 当 `createdAt` 和 `created_at` 都缺失时，`createdAtRaw` 为 `null`，`toString()` 返回 `"null"`，`DateTime.parse("null")` 抛出异常。`ArtifactSummary.fromJson`（第 111 行）正确使用了 `tryParse` + fallback，但 `Artifact.fromJson` 没有。

**影响**: 服务端返回缺少 `createdAt` 的 artifact 数据时崩溃。

---

### L2. ArtifactCreateResponse.fromJson 无字段 fallback

| 字段 | 值 |
|------|-----|
| 文件 | `lib/models/artifact.dart` |
| 行号 | 68-79 |

**缺陷描述**: `id`、`shortId`、`shareUrl`、`embedUrl`、`createdAt` 等字段直接访问 `json['id']` 等，未做 null 检查和类型校验。任一字段缺失即抛出 `TypeError` 或 `FormatException`。

**影响**: 服务端响应结构变化时解析失败。

---

### L3. CSV 密码导出未转义字段

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/password_provider.dart` |
| 行号 | 96-103 |

**缺陷描述**: 导出 CSV 时将值包裹在双引号中，但未转义值内部的双引号和换行符。密码或备注中包含 `"` 或换行符时生成无效 CSV，不可可靠导入。

**影响**: 密码导出->导入流程可能丢失数据。

---

### L4. 知识库搜索片段索引错误

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/knowledge_provider.dart` |
| 行号 | 348-356 |

**缺陷描述**: `idx` 是 `hay = title\nfolder\ncontent` 中的匹配位置，但 snippet 从 `doc.content` 中切割。标题或文件夹中的匹配导致 `idx` 偏移错误，snippet 来自错误位置（clamp 防止崩溃，但预览错误）。

**影响**: 搜索结果摘要显示错误内容片段。

---

### L5. loadHistory 类型转换静默丢弃全部历史

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/short_url_provider.dart:56` + `lib/providers/translation_provider.dart:56` |

**缺陷描述**: `jsonDecode(data) as List<dynamic>` 在存储值为 JSON map 或格式错误时抛出异常，被外层 catch 捕获，整个历史记录被静默丢弃，仅输出 debug log。

**影响**: 存储格式异常时用户数据丢失，无任何用户提示。

---

### L6. 同步文件 I/O 阻塞 UI 线程

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/chat_provider.dart` |
| 行号 | 1291-1313 |

**缺陷描述**: `file.lengthSync()` 和 `file.readAsBytesSync()` 在 UI isolate 上执行同步文件 I/O 操作。虽然受 `maxImageBytes` 限制，但在慢速存储上会导致 UI 卡顿。

**影响**: 大附件消息发送时 UI 短暂无响应。

---

### L7. 图片生成 content 为列表时未处理

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/image_generation_provider.dart` |
| 行号 | 195-209 |

**缺陷描述**: 当模型返回 `choices[0].message.content` 为列表时（结构化输出），`content is String` 为 false，URL 提取完全跳过，提示"响应中未找到图片地址"。

**影响**: 模型返回结构化内容时无法正常显示生成图片。

---

### L8. createNote 不重建反向链接索引

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/notes_provider.dart` |
| 行号 | 243-256 |

**缺陷描述**: 新建笔记不调用 `_rebuildBacklinks()`。新笔记标题匹配现有 `[[...]]` 链接时，`getBacklinks` 不会返回该笔记，直到下一次编辑或加载触发重建。

**影响**: 新建笔记后反向链接搜索不完整。

---

### L9. _saveHistory 异步写入重叠

| 字段 | 值 |
|------|-----|
| 文件 | `lib/providers/image_generation_provider.dart` |
| 行号 | 112-118 |

**缺陷描述**: `_addImage` 调用 `_saveHistory()` 时未使用 `await`。快速连续添加图片时，多个异步写操作重叠，最后完成的写入覆盖之前的结果（不一定是最后启动的），导致历史记录丢失条目。

**影响**: 快速生成图片时历史记录可能丢失。

---

### L10. CrashReport.fromJson crashedAtMillis 类型转换

| 字段 | 值 |
|------|-----|
| 文件 | `lib/models/crash_report.dart` |
| 行号 | 115 |

**缺陷描述**: `(json['crashedAtMillis'] as num).toInt()` — 如果 `crashedAtMillis` 缺失或序列化为字符串，`as num` 抛出异常。

**影响**: 崩溃报告数据格式异常时解析失败。

---

### L11. Provider dispose 后调用 notifyListeners

| 字段 | 值 |
|------|-----|
| 文件 | 所有 provider 文件 |
| 行号 | 多处 |

**缺陷描述**: 多个 provider 在异步 continuations（stream、await 回调、`.ignore()` future）中调用 `notifyListeners()`。如果 widget tree 在请求进行中 dispose 了 provider，下一次 `notifyListeners()` 抛出 `FlutterError`。`chat_provider` 的 streaming 循环（第 1064/1072 行）风险最高。

**影响**: 快速页面切换时偶发崩溃。

---

## 其他模块分析结果

### Android 原生代码 (`android/`)

**🔴 高严重度**

| # | 缺陷 | 文件 | 行号 | 状态 |
|---|------|------|------|------|
| A-H1 | NativeTaskStore 嵌套 JSON 对象序列化为 JSONObject/JSONArray → Flutter MethodChannel 无法序列化 | `NativeTaskStore.kt` | 86-95 | ✅ 确认 |
| A-H2 | 启动时主线程执行完整安全快照（APK SHA-256、子进程、/proc 扫描）→ ANR 风险 | `NexAIApplication.kt:41-43`, `StartupSecurityBootstrap.kt:21`, `SecuritySignals.kt:111-178` | 多处 | ✅ 确认 |
| A-H3 | MediaChannel 音频提取每帧写 MMKV + post 主线程 → 数千次消息淹没主线程 | `MediaChannel.kt` | 195-216 | ✅ 确认 |
| A-H4 | APK 解析失败时包名/签名校验静默通过 → 篡改 APK 被当作已验证 | `UpdateChannel.kt` | 212-231 | ✅ 确认 |

**🟡 中严重度**

| # | 缺陷 | 文件 | 行号 |
|---|------|------|------|
| A-M1 | 更新验证哈希在主线程计算 | `UpdateChannel.kt` | 76-176, 351-362 |
| A-M2 | openUrl 接受任意 URI scheme → intent 注入 | `UpdateChannel.kt` | 60-74 |
| A-M3 | taskId 未消毒用于文件路径 → 路径遍历 | `MediaChannel.kt` | 121, 132 |
| A-M4 | PasskeyChannel 协程作用域永不取消 → 泄漏 | `PasskeyChannel.kt` | 33 |
| A-M5 | PermissionChannel 单槽 pending 结果存活于重建 → 卡死 | `PermissionChannel.kt` | 19-20, 47-94 |
| A-M6 | StartupSecurityBootstrap 可并发重复计算完整快照 | `StartupSecurityBootstrap.kt` | 16-57 |
| A-M7 | 预预热引擎竞争 → 创建第二个引擎，预热的被缓存永久 | `NexAIApplication.kt` | 100-121 |
| A-M8 | ClashCompatChannel 主线程执行 PM 查询 + ContentResolver 阻塞调用 | `ClashCompatChannel.kt` | 90-125, 189-221 |
| A-M9 | SecurityChannel.setSecureScreen 返回 null 而非 NativeResult 信封 | `SecurityChannel.kt` | 27 |
| A-M10 | MediaChannel.getVideoMetadata 主线程同步运行 MediaMetadataRetriever | `MediaChannel.kt` | 36, 86-105 |

**🟢 低严重度**

A-L1~A-L11: 过度指纹采集、FileProvider 根目录过宽、Activity taskAffinity、CrashGateActivity 导出、通知 channelId 未校验、视频选择器兼容性、PendingIntent 请求码冲突、R8 混淆、Gradle 配置、进度边界情况、checkFridaPorts 主线程读取 netstat。详见文件。

---

### 服务代码 (`lib/services/`)

**🔴 高严重度**

| # | 缺陷 | 文件 | 行号 | 状态 |
|---|------|------|------|------|
| S-H1 | `jsonDecode` 未保护 + `data['data']` 可能为 null → 非 JSON 响应体或空 data 导致崩溃 | `nexai_artifacts_service.dart` | 62-63 (及多处) | ✅ 确认 |
| S-H2 | 仅 201 被当作成功 → 200 响应被当作失败 | `nexai_artifacts_service.dart` | 61 | ✅ 确认 |
| S-H3 | `as Map<String, dynamic>?` 对非 map 类型抛出 TypeError | `nexai_sync_service.dart` | 48, 71, 109, 132 | ✅ 确认 |

**🟡 中严重度**

| # | 缺陷 | 文件 | 行号 |
|---|------|------|------|
| S-M1 | 所有 Android native 服务未捕获 PlatformException / MissingPluginException | 多个 android_*_service.dart 文件 | 多处 |
| S-M2 | 图片生成返回空时误报旧图片为新图片 | `chat_tool_executor.dart` | 648 |
| S-M3 | backend_client 固定 pin 到单个主机 → setBaseUrl 对其他主机 TLS 失败 | `nexai_backend_client.dart:40` + `pinned_http_client.dart:194-198` | 多处 |
| S-M4 | 客户端构建竞态（双重检查锁未同步） | `nexai_backend_client.dart:40` | 多处 |
| S-M5 | 翻译客户端 jsonDecode 未捕获 FormatException | `lumen_translation_client.dart` | 263-272 |
| S-M6 | auth 服务 token 类型转换抛出 TypeError | `nexai_auth_service.dart` | 706-707 |
| S-M7 | clash_compat 中间赋值抛出 TypeError 导致状态不一致 | `clash_compat.dart` | 101-111 |
| S-M8 | fetchUrl/MCP SSRF 防护仅字符串检查，可被 DNS 重绑定绕过 | `chat_tool_executor.dart:740-800` + `remote_mcp_client.dart:129` | 多处 |

**🟢 低严重度**

S-L1~S-L13: 日志泄漏内容、用户模型类型转换、passkey 解码异常、崩溃报告器安装顺序、临时文件写入竞争、超时未取消连接、死代码、证书 pin 回退、artifact 创建失败误报、语音合成异常未捕获、崩溃报告误删、同步无法区分空成功与失败、StreamController 未关闭。

---

### WinUI3 原生代码 (`winui/`)

**🔴 高严重度**

| # | 缺陷 | 文件 | 行号 | 状态 |
|---|------|------|------|------|
| W-H1 | 设置变更事件从后台线程触发 → 直接操作 UI 抛出 RPC_E_WRONG_THREAD | `App.xaml.cs` | 279-288 | ✅ 确认 |
| W-H2 | 共享 HttpClient 设置无限超时 → 翻译/短链接/图片生成无超时 | `OpenAiCompatibleChatClient.cs:21` + `ServiceCollectionExtensions.cs:33-34` | 多处 | ✅ 确认 |

**🟡 中严重度**

| # | 缺陷 | 文件 | 行号 |
|---|------|------|------|
| W-M1 | 证书固定应用到所有主机而非仅目标主机 | `NexaiHttp.cs` | 175-270 |
| W-M2 | 密码存储静默数据丢失（损坏/密钥丢失时生成新密钥覆盖旧数据） | `ProtectedPasswordVaultStore.cs` | 40-54, 146-177 |
| W-M3 | 同步墓碑检查因 JSON 反序列化类型不匹配永不触发 | `NexaiSyncService.cs` | 266 |
| W-M4 | 首次登录前无签名密钥 → 无法登录 | `NexaiHttp.cs` | 110-119, 307-324 |
| W-M5 | 页面通过未取消的 LanguageChanged 处理器泄漏 | 多个 `*Page.xaml.cs` | 多处 |
| W-M6 | 行内 LaTeX 双重渲染（原始文本未剥离） | `AdvancedMarkdown.cs` | 71-77 |

**🟢 低严重度**

W-L1~W-L12: 异常标记为已处理、线程不安全静态状态、同步状态读取无同步、fire-and-forget 保存、流控制令牌竞态、ffmpeg 输出截断、RuntimeIdentifier 硬编码、临时媒体文件未清理、旧 vault 升级条件、超时影响兄弟客户端、同步偏好静默丢弃、聊天列表完全重新实现。

---

### 页面代码 (`lib/pages/`)

**🔴 高严重度**

| # | 缺陷 | 文件 | 行号 | 状态 |
|---|------|------|------|------|
| P-H1 | 7 个页面文件直接 `import 'dart:io'`，且均被 `main.dart` → `app.dart` → `home_page.dart` 传递导入 → `flutter build web` 编译失败 | `chat_page.dart:1`, `crash_report_page.dart:2`, `image_generation_page.dart:2`, `note_detail_page.dart:2`, `password_generator_page.dart:6`, `video_compressor_page.dart:2`, `video_to_audio_page.dart:1` | 多处 | ✅ 确认 |
| P-H2 | `showDatePicker` 的 `initialDate` 可能来自用户输入（时间戳解析），若超出 [1970, 2100] 范围则抛出断言 | `date_time_converter_page.dart` | 150-157 | ✅ 确认 |

**🟡 中严重度**

| # | 缺陷 | 文件 | 行号 |
|---|------|------|------|
| P-M1 | `build()` 中修改 `_contentController.text` 触发监听器 → `setState` during build 异常 | `note_detail_page.dart` | 530-533 |
| P-M2 | 异步生成完成时 widget 已 dispose 后调用 `_promptController.clear()` 无 `mounted` 检查 | `image_generation_page.dart` | 226 |
| P-M3 | `FutureBuilder` 的 future 在每次 build 重新创建（`CrashReporter.store.load()`、`UpdateChecker.getAutoUpdate()`） | `developer_debug_page.dart:66-67`, `settings_page.dart:1596-1618` | 多处 |
| P-M4 | 遍历 `_tasks` 时可能发生并发修改（`ConcurrentModificationError`） | `video_to_audio_page.dart` | 192-197 |
| P-M5 | 密码生成器不保证每个字符类至少一个字符 | `password_generator_page.dart` | 110-121 |
| P-M6 | `build()` 中赋值 `_transformController.value` 导致 build 期间修改 | `graph_page.dart` | 186 |
| P-M7 | `await` 后无 `mounted` 检查即调用 `setState`/controller 方法（dispose 后访问） | `base64_converter_page.dart:90-100`, `date_time_converter_page.dart:259-268`, `short_url_page.dart:103-111` | 多处 |
| P-M8 | 模型列表为空时 `DropdownButtonFormField` 断言崩溃 | `settings_page.dart` | 413-437 |

**🟢 低严重度**

P-L1~P-L14: `TextEditingController` 泄漏（多处对话框）、未处理异步错误、`try/finally` 无 catch、`launchUrl` 未捕获异常、`firstWhere` 抛出 `StateError`、桌面加载指示器不一致、图布局性能、Gemini 密钥追踪、翻译下拉框状态不同步、async 间隙、ffmpeg 路径引用、`SecurityStatusChecker` context 捕获、build 中 `base64Decode`、日期选择器与输入文本不一致。详见文件。

---

### 工具/主题/组件 (`lib/utils/` + `lib/theme/` + `lib/widgets/`)

**🔴 高严重度**

| # | 缺陷 | 文件 | 行号 | 状态 |
|---|------|------|------|------|
| U-H1 | DEX 哈希 TOFU 在每次正式更新后永久标记设备为 compromised | `app_security.dart` | 598-619 | ✅ 确认 |

**🟡 中严重度**

| # | 缺陷 | 文件 | 行号 |
|---|------|------|------|
| U-M1 | 更新检查无超时 → 网络挂起阻塞启动 | `app_security.dart` | 311-334, 388-425 |
| U-M2 | SSRF 防护仅检测点分十进制 IPv4，可被进制/DNS 重绑定绕过 | `network_safety.dart` | 31-66 |
| U-M3 | X-Device-Root 和 X-Device-Compromised 均使用同一标志 → 非 root 也发送 root:1 | `security_headers_interceptor.dart` | 53-54 |
| U-M4 | 安全事件报告将非 root 原因报告为 root_detected | `security_event_reporter.dart` | 141-143 |
| U-M5 | 阻止状态对话框"退出"按钮仅关闭对话框 → 应用继续运行 | `security_status_checker.dart` | 138-145 |
| U-M6 | 定期安全检查 Timer 未随 widget 生命周期取消 → 泄漏 | `security_status_checker.dart` | 17-28 |
| U-M7 | 同步解密无 try/catch → 单个损坏记录导致崩溃 | `sync_crypto.dart` | 69-99 |
| U-M8 | 更新下载失败后 APK 文件未清理 | `update_checker.dart` | 292-325 |
| U-M9 | 桌面分享路径 RenderBox 强制转换可能崩溃 | `message_bubble.dart` | 417-421 |
| U-M10 | Mermaid 解析器圆圈节点正则优先级错误（`(...)` 在 `((...))` 前）→ 所有 `((text))` 渲染为 stadium | `mermaid_parser.dart` | 67-69 |
| U-M11 | 流程图 500px 高度裁剪 → 大图下方节点丢失 | `flowchart_widget.dart` | 186 |

**🟢 低严重度**

U-L1~U-L32: 原子写入器竞态、指纹获取竞态、Web 平台指纹抛出、代理日志泄露凭证、指纹截断、对话框强制退出无效果、非ce 长度未验证、GitHub asset 路径遍历、Web upload 静默失败、`withAlpha` 弃用、编辑控制器未释放、emoji 截断异常、Markdown 图片加载任意 URL、wiki 链接创建异常未处理、流程图自环不可见、头像 emoji 渲染、LaTeX 边界截断、passkey 调试对话框数据暴露、死 try/catch 等。详见文件。

---

### 测试文件 (`test/`)

**🟡 中严重度**

| # | 缺陷 | 文件 | 行号 | 状态 |
|---|------|------|------|------|
| T-M1 | 布局异常测试断言为空：`FlutterError.onError` 被覆盖绕过 `tester.takeException()`，`captured` 列表仅 debugPrint 从未 assert → 测试在布局异常时仍通过 | `note_detail_page_test.dart` | 61-91 | ✅ 确认 |

**🟢 低严重度**

| # | 缺陷 | 文件 | 行号 |
|---|------|------|------|
| T-L1 | `AppSecurity.instance` 单例变异后仅在 happy path 重置，`expect` 失败时跳过重置 → 污染后续测试 | `app_security_test.dart` | 33-52 |
| T-L2~T-L5 | 覆盖缺口：更新下载失败清理路径未测试、DEX 哈希 TOFU 路径未测试、`crashedAtMillis` 列表/字符串类型未测试、CSV 导出转义未测试 | 多个测试文件 | 多处 |

**已确认无缺陷的测试文件（13 个）**

`app_security_test.dart`（已有断言）、`update_checker_test.dart`、`models/chat_phase1_test.dart`、`models/chat_phase2_test.dart`、`models/chat_tool_message_test.dart`、`models/crash_report_sanitize_test.dart`、`providers/passkey_cancellation_test.dart`、`providers/passkey_origin_mismatch_test.dart`、`providers/password_backup_test.dart`、`providers/sync_provider_test.dart`、`services/crash_reporter_image_error_test.dart`、`theme/lumen_theme_test.dart`、`utils/atomic_file_writer_test.dart`、`widgets/lumen_components_test.dart`、`widgets/markdown_render_utils_test.dart`、`widgets/markdown_renderer_test.dart`、`widgets/user_avatar_test.dart`。

---

## 综合统计

| 模块 | 🔴 高 | 🟡 中 | 🟢 低 | 总计 |
|------|-------|-------|-------|------|
| providers/models | 2 | 6 | 11 | 19 |
| services | 3 | 8 | 13 | 24 |
| android | 4 | 10 | 11 | 25 |
| winui | 2 | 6 | 12 | 20 |
| pages | 2 | 8 | 14 | 24 |
| utils/theme/widgets | 1 | 11 | 20+ | 32+ |
| test | 0 | 1 | 5 | 6 |
| **总计** | **14** | **50** | **86+** | **150+** |

## 全局优先修复建议

1. **P-H1** — Web 构建完全失败（`dart:io` 导入）
2. **A-H1** — 后台任务完全不可用（JSONObject 序列化）
3. **S-H1/S-H2** — Artifact 创建/读取核心功能崩溃
4. **A-H2** — 启动 ANR 风险
5. **S-H3** — 同步服务类型转换崩溃
6. **U-H1** — 每次更新后设备被标记为 compromised
7. **A-H4** — 安全验证旁路（篡改 APK 可通过校验）
8. **W-H1** — 设置变更时跨线程 UI 崩溃
9. **W-H2** — 翻译/短链接/图片生成无超时，请求永久挂起
10. **P-H2** — 日期选择器特定输入崩溃

---

## 核查方法说明

- 每个缺陷均通过直接读取源代码进行核实
- 不使用本地构建、安装依赖或运行测试
- 仅使用静态代码分析（文件读取 + 代码追踪）
- 分析范围覆盖 `lib/`、`android/`、`test/`、`winui/` 四个目录