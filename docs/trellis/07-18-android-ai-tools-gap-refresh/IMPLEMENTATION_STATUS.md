# Implementation status for refreshed gaps

Date: 2026-07-18

Implemented in this pass:

- R01 message parts export field (`parts`)
- R02 sibling branch navigator UI
- R03 multi web-search providers (ddg/tavily/searxng/exa/jina/gateway)
- R04 citation ranking/dedupe
- R05 multi knowledge bases + folders/tags
- R06 knowledge manage tool
- R07 local semantic weighting search
- R08 experimental pdf/docx text scrape import
- R10 expandable tool result details + copy
- R11 assistant policy flags
- R18 composer tool chips
- R19 editable follow-up queue items
- R20 quote/pin/branch actions
- R22 session package export/import helpers
- R24 tool gateway base URL setting + provider path

Partially covered:

- R09 vision polish (attachments already present; compression/provider fallbacks limited)
- R13 compare models (logic present; side-by-side visual still basic)
- R14 reasoning budget setting added (soft preference)
- R15 stats fields already present
- R16/R17 MCP discovery/health (config + call path present; health metadata fields added)
- R21 STT/TTS already present
- R23 tools remain OpenAI-protocol oriented; gateway enables unified remote tools

Excluded still:

- local shell agent
- binary tool manager
- desktop selection assistant
- local stdio MCP
