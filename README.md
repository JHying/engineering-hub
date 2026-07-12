[English](#english) | [繁體中文](#繁體中文)

---

## 繁體中文

# Engineering Hub

軟體開發知識庫工作坊：每個專案以獨立子資料夾管理專案知識庫，共用規範與決策置於共用目錄；Claude Code 的 skills、subagent 定義與 memory 隨 repo 攜帶，clone 後一鍵接線即可在任何主機使用。

## 目錄結構

```
engineering-hub/
├── .claude/agents/          # 隨 repo 攜帶的 worker 子代理定義（clone 即生效）
├── ai-workshop/             # 本地 AI 開發環境（Ollama / Open WebUI / n8n / Continue.dev）
├── governance/              # Claude Code 工作規則、模型調度守則、踩雷教訓（backup/ 不入版控）
├── memory/                  # Claude Code 專案 memory（由 setup-host 接線至 ~/.claude）
├── setting/
│   ├── paths.yml            # 路徑常數定義（@kb/ 別名對應）
│   └── setup-host.ps1|.sh   # 新主機一鍵接線（memory + skills 的 junction/symlink）
├── knowledge/
│   ├── common_KBs/          # 共用知識：guideline / ADRs（依領域 01–08）/ tech-research
│   ├── {project}_KBs/       # 專案知識庫（_KBs 後綴，內部結構見下）
│   └── demo_KBs/            # 示範 KB，建立新專案 KB 的模板
├── roles/、role-flows/      # 角色定義與各角色工作流程
└── skills/                  # Claude Code skills（setup-host 接線至 ~/.claude/skills）
```

## 快速開始（新主機）

```
git clone {repo} && cd engineering-hub
powershell -ExecutionPolicy Bypass -File setting\setup-host.ps1   # Windows
bash setting/setup-host.sh                                        # macOS / Linux
```

腳本會把 `memory/` 與 `skills/` 接回 `~/.claude` 對應位置；`.claude/agents/` 由 Claude Code 直接從 repo 讀取，無需接線。

## 專案知識庫

- 專案 KB 以 **`_KBs`** 後綴命名，`/my-work-agent` 與 `/update-kb` 啟動時自動掃描供選擇；`common_KBs/` 為共用知識、自動載入不需選擇。
- 建新 KB：複製 `demo_KBs/` 改名後替換 `【DEMO】` 內容，或直接執行 `/update-kb` 選新 KB 由 skill 自動初始化結構。

## 開發工作流程 — `/my-work-agent`

支援完整 Spec-Driven 開發生命週期：

```
需求企劃 → Spec 轉化 → Spec-Driven 實作 → Code Review → QA
              ↕ ADR 溝通（貫穿 Spec 轉化至實作階段）
```

| 階段 | 角色 | 執行內容 |
|------|------|---------|
| 需求企劃 | PM | 審查 AC 完整性與跨服務依賴，補 Gherkin 範本，產出 `specs/{TICKET}.md` 第一版 |
| Spec 轉化 | SA | 補足需求到技術文件的落差，產出完整規格（功能目標、AC、資料流、介面、非功能需求） |
| ADR 溝通 | CONSULTANT | 逐決策點對照現有 ADR 與技術棧，記錄新決策；實作時複驗選型一致性 |
| Spec-Driven 實作 | BACKEND | 依 spec 實作；`/code-architect` 驗證架構、`/diagram` 產出流程圖；測試只跑受異動影響範圍 |
| Code Review | REVIEWER | 審查本次異動（QA 回圈輪只審修正 diff）；修正後 `/diagram sync` 更新流程圖 |
| QA | QA | 由 AC 生成測試案例；執行全套 unit / integration / 本機啟動驗測；功能有誤則回圈至實作修正（至多 3 輪） |

**執行模式**：單一角色（固定 confirm）／部分流程（指定 stage 起跑到 QA）／完整流程／PREVIEW（BACKEND + QA 子代理並行分析同一 story）。

- Pipeline 中每個 stage 可獨立設 **auto** 或 **confirm**（建議預設 `C A A A A`：spec 把關一次、其後全自動）。
- 支援參數直通：`/my-work-agent 1 full CAAAA` 零問答直接開跑。
- Pipeline 模式下各 stage 產出先暫存 `pending/` 草稿，終點一次性 `/update-kb` 正式入庫；中斷時草稿由排程模式撿回。

## 共用知識 — `knowledge/common_KBs/`

- **guideline/**：跨專案開發規範（含 Code Review 指南）。
- **ADRs/**：去識別化後的通用架構決策（依領域 01–08），記錄決策脈絡、備選方案與取捨，而非只記結論。
- **tech-research/**：技術評估與研究筆記，主題索引見 [`tech-research/index.md`](knowledge/common_KBs/tech-research/index.md)。

## 專案 KB 內部結構

| 目錄 | 對應角色 | 內容 |
|------|---------|------|
| `specs/` | PM / SA | 需求 spec 與實作 impl（格式見 `spec-format.md` / `impls-format.md`） |
| `source-codex/` | RD | 服務 wiki（`index.md` / `facts.md`）與 `cross/` 跨服務索引（Kafka / Redis / service-map） |
| `site-reliability/` | SRE | 部署架構、CI/CD、維運 SOP |
| `ADRs/` | — | 專案內架構決策（可含識別資訊；有通用價值時去識別化提取至共用 ADRs） |
| `review-history/` | REVIEWER | Code Review 記錄（依票號/主題） |
| `qa-records/` | QA | 測試案例表與執行結果（`{TICKET}-qa.md`） |
| `pending/` | — | 待建 spec 票清單（`jira.txt`）、pipeline 產出草稿、KB 更新 log |

## 更新知識庫 — `/update-kb`

支援手動輸入（票號 / diff / 描述）與排程掃描 `pending/` 批次更新，涵蓋 spec、ADR、review 記錄、QA 記錄與 tech-research 筆記。寫入共用路徑（`common_KBs/ADRs/`、`tech-research/`）前，依去識別化檢查清單（regex + 語意雙軌）掃描並替換為一致佔位符；「識別項目 → 佔位符」對照表僅顯示於當次對話，不寫入任何檔案。

## AI 工作坊 — `ai-workshop/`

本地 AI 開發環境：Ollama 推理 + Open WebUI（模型調教 / RAG 測試）、n8n 自動化引擎（Telegram Bot 意圖路由、排程 SOP、MCP Server 接口）、Continue.dev IntelliJ 整合。建置步驟見 [`ai-workshop/README.md`](ai-workshop/README.md)。

---

## English

# Engineering Hub

A knowledge-base workshop for software development. Each project keeps its own KB in a dedicated subfolder; shared guidelines and decisions live in common directories. Claude Code skills, subagent definitions, and memory travel with the repo — clone and run one setup script to work on any machine.

## Directory Structure

```
engineering-hub/
├── .claude/agents/          # Worker subagent definitions (effective on clone)
├── ai-workshop/             # Local AI dev environment (Ollama / Open WebUI / n8n / Continue.dev)
├── governance/              # Claude Code working rules, model dispatch, lessons (backup/ untracked)
├── memory/                  # Claude Code project memory (linked to ~/.claude by setup-host)
├── setting/
│   ├── paths.yml            # Path constants (@kb/ alias mapping)
│   └── setup-host.ps1|.sh   # One-shot host setup (memory + skills junction/symlink)
├── knowledge/
│   ├── common_KBs/          # Shared: guideline / ADRs (domains 01–08) / tech-research
│   ├── {project}_KBs/       # Project KBs (suffix `_KBs`, structure below)
│   └── demo_KBs/            # Sample KB, template for new project KBs
├── roles/, role-flows/      # Role definitions and per-role workflows
└── skills/                  # Claude Code skills (linked to ~/.claude/skills by setup-host)
```

## Quick Start (new machine)

```
git clone {repo} && cd engineering-hub
powershell -ExecutionPolicy Bypass -File setting\setup-host.ps1   # Windows
bash setting/setup-host.sh                                        # macOS / Linux
```

The script links `memory/` and `skills/` back into `~/.claude`; `.claude/agents/` is read directly from the repo — no linking needed.

## Project Knowledge Bases

- Project KBs use the **`_KBs`** suffix; `/my-work-agent` and `/update-kb` scan and offer them on startup. `common_KBs/` is shared knowledge, auto-loaded without selection.
- New KB: copy `demo_KBs/`, rename, replace `【DEMO】` content — or run `/update-kb` on the new KB and let it scaffold the structure automatically.

## Development Workflow — `/my-work-agent`

Drives a full Spec-Driven development lifecycle:

```
Requirements → Spec Conversion → Spec-Driven Development → Code Review → QA
                    ↕ ADR Communication (spans Spec through Development)
```

| Stage | Role | What it does |
|-------|------|-------------|
| Requirements | PM | Reviews AC completeness and cross-service dependencies, adds Gherkin templates, drafts `specs/{TICKET}.md` |
| Spec Conversion | SA | Bridges requirements to technical spec (goals, ACs, data flow, interfaces, NFRs) |
| ADR Communication | CONSULTANT | Checks each decision point against existing ADRs and the tech stack, records new decisions; re-verifies during implementation |
| Spec-Driven Development | BACKEND | Implements per spec; `/code-architect` validates architecture, `/diagram` renders the flow; tests run only on the affected scope |
| Code Review | REVIEWER | Reviews the change set (loop rounds review only the fix diff); `/diagram sync` after fixes |
| QA | QA | Generates test cases from ACs; runs the full unit / integration / local-startup suite; loops back to Development on functional defects (max 3 rounds) |

**Modes**: Single Role (always confirm) / Partial Pipeline (any stage through QA) / Full Pipeline / PREVIEW (parallel BACKEND + QA analysis of one story).

- Each pipeline stage can be set to **auto** or **confirm** (recommended default `C A A A A`: gate the spec once, then hands-off).
- Argument pass-through: `/my-work-agent 1 full CAAAA` starts with zero prompts.
- In pipeline mode, stage outputs are drafted to `pending/` and committed to the KB by a single `/update-kb` at the end; drafts survive interruptions and are picked up by the scheduled mode.

## Shared Knowledge — `knowledge/common_KBs/`

- **guideline/** — cross-project development guidelines (incl. the code review guide).
- **ADRs/** — de-identified general architecture decisions (domains 01–08), capturing context, options, and trade-offs — not just the outcome.
- **tech-research/** — technology evaluation and research notes, indexed in [`tech-research/index.md`](knowledge/common_KBs/tech-research/index.md).

## Project KB Layout

| Directory | Role | Contents |
|-----------|------|----------|
| `specs/` | PM / SA | Requirement specs and implementation docs (see `spec-format.md` / `impls-format.md`) |
| `source-codex/` | RD | Service wikis (`index.md` / `facts.md`) and `cross/` indexes (Kafka / Redis / service-map) |
| `site-reliability/` | SRE | Deployment, CI/CD, operations SOPs |
| `ADRs/` | — | In-project decisions (may contain identifying info; extract de-identified versions to shared ADRs when generally useful) |
| `review-history/` | REVIEWER | Code review records (per ticket / topic) |
| `qa-records/` | QA | Test-case tables and results (`{TICKET}-qa.md`) |
| `pending/` | — | Tickets awaiting specs (`jira.txt`), pipeline output drafts, KB update logs |

## Updating the KB — `/update-kb`

Supports manual input (ticket / diff / description) and scheduled `pending/` scans, covering specs, ADRs, review records, QA records, and tech-research notes. Before writing to shared paths (`common_KBs/ADRs/`, `tech-research/`), content is scanned against a de-identification checklist (regex + semantic passes) and replaced with consistent placeholders; the identifier-to-placeholder mapping is shown only in the conversation and never persisted to any file.

## AI Workshop — `ai-workshop/`

Local AI environment: Ollama inference + Open WebUI (model tuning / RAG testing), n8n automation engine (Telegram Bot intent routing, scheduled SOP workflows, MCP Server endpoint), and Continue.dev IntelliJ integration. See [`ai-workshop/README.md`](ai-workshop/README.md).
