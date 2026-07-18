# Gap Matrix (machine-friendly)

| id | title | priority | android_feasible | phase | depends_on | notes |
|---|---|---|---|---|---|---|
| G01 | message parts model | P0 | yes | 0 | | foundation |
| G02 | tool calling loop | P0 | yes | 0 | G01 | needs tools-capable model/gateway |
| G03 | tool approval UI | P0 | yes | 0 | G02 | auto/prompt policy |
| G04 | stop generation | P0 | yes | 0 | | CancelToken |
| G05 | regenerate/branch | P0 | yes | 0 | G01 | basic tree first |
| G06 | citation cards | P0 | yes | 0 | G01 | needs tool results |
| G07 | web_search tool | P0 | yes | 1 | G02,G06 | remote provider/backend |
| G08 | web_fetch tool | P1 | yes | 2 | G07 | URL fetch/summary |
| G09 | notes knowledge tools | P0 | yes | 1 | G02 | reuse Notes |
| G10 | imported document KB | P1 | partial | 2 | G09 | parser or backend |
| G11 | image vision chat | P1 | yes | 1 | G01 | multimodal model |
| G12 | pdf/text attachments | P1 | partial | 1 | G11 | local/remote parse |
| G13 | assistants catalog | P1 | yes | 1 | | presets + custom |
| G14 | per-chat model/prompt | P1 | yes | 1 | G13 | conversation settings |
| G15 | multi-model compare | P2 | yes | 2 | G14 | cost/bandwidth |
| G16 | reasoning UI | P1 | yes | 1 | G01 | provider dependent |
| G17 | token/cost stats | P2 | yes | 2 | G01 | usage fields |
| G18 | in-chat image tool | P1 | yes | 1 | G02 | reuse image gen |
| G19 | in-chat artifacts tool | P1 | yes | 1 | G02 | reuse artifacts |
| G20 | prompt templates | P1 | yes | 1 | | local expand |
| G21 | follow-up queue | P1 | yes | 1 | G04 | composer queue |
| G22 | translate message action | P1 | yes | 1 | | reuse translation |
| G23 | speech to text | P2 | yes | 2 | | OEM variance |
| G24 | text to speech | P2 | yes | 2 | | platform TTS |
| G25 | remote MCP client | P2 | partial | 2 | G02 | no local stdio |
| G26 | tool call guardrails | P0 | yes | 0 | G02 | max calls/allowlist |
| G27 | richer export/import | P2 | yes | 2 | G01 | session package |
| G28 | search jump+highlight | P2 | yes | 2 | | polish existing search |
