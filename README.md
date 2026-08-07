[English](#english) | [繁體中文](#繁體中文)

---

## 繁體中文

# Engineering Hub

**跨專案共用可攜知識庫 ＋ SDLC 自動開發流程引擎**：

- **知識傳承** — 需求 spec、服務原始碼索引、架構決策記錄（ADR）、QA 記錄長期累積在 `knowledge/`，脈絡不隨人員流動帶走。
- **自動開發流程引擎** — PM → SA → BACKEND → REVIEWER → QA 的 Spec-Driven pipeline 全程同步 KB 紀錄，issue tracker 與瀏覽器自動以 MCP 接入。
- **可攜** — 知識庫、skills、subagent 定義、工作規則與 memory 全部隨 repo 攜帶，clone 後一鍵接線即可在任何主機重建同一套工作坊。

## 目錄結構

```
engineering-hub/
├── CLAUDE.md                # 規則索引：只做路由，全文在 governance/，依觸發條件按需讀取
├── .claude/agents/          # worker 子代理（mechanical / readback / security-review）
├── ai-workshop/             # 本地 AI 開發環境（Ollama / Open WebUI / n8n / Continue.dev）
├── governance/              # 規則全文：模型調度、交辦模板、判斷準則、維護協定、診斷、
│                            # 工作歷史踩雷紀錄、冒煙測試檢查表（backup/ 不入版控）
├── memory/                  # 跨專案通用 memory（由 setup-host 接線至 ~/.claude）
├── setting/
│   ├── paths.yml            # @kb/ 相對路徑常數（刻意不含任何主機絕對路徑）
│   ├── setup-host.ps1|.sh   # 新主機一鍵接線（junction/symlink + 註冊 SessionStart hook）
│   ├── setup-mcp.ps1|.sh    # 共用 MCP server 一鍵註冊（密鑰另存 gitignored 本機檔）
│   └── check-*.ps1|.sh      # 自檢腳本：memory / 專案 KB / skill 一致性 / KB 格式
├── knowledge/
│   ├── common_KBs/          # 通用知識庫：guideline / ADRs / tech-research
│   ├── {project}_KBs/       # 專案知識庫（_KBs 後綴，內部結構見下）
│   └── demo_KBs/            # 示範 KB，建立新專案 KB 的模板
├── roles/                   # 角色定義（PM / SA / CONSULTANT / BACKEND / REVIEWER / QA / SRE）
├── role-flows/              # 角色工作流程，另含跨角色的深度追問協定
└── skills/{name}/           # Claude Code skills（SKILL.md + references/ + CHANGELOG.md）
```

工作坊根路徑寫在`memory/reference_knowledge_base.local.md`（將由 setup-host 自動產生），其餘文件用 `@kb/` 前綴，由 skill 在執行期解析。

## 快速開始（新主機）

```
git clone {repo} && cd engineering-hub
powershell -ExecutionPolicy Bypass -File setting\setup-host.ps1   # Windows
bash setting/setup-host.sh                                        # macOS / Linux
```

腳本會做三件事：

1. 把 `memory/` 與 `skills/` 接回 `~/.claude` 對應位置（junction / symlink）。
2. 寫入非專案綁定的 KB 根路徑，讓自檢腳本無論從任何目錄啟動 claude，都能找到本 repo。
3. **修改 `~/.claude/settings.json`**：註冊三個 user-level SessionStart hook（見下節），已註冊者跳過、其餘設定原樣保留。採 user-level 而非專案層，是為了在任何目錄啟動 `claude` 都會觸發。

`.claude/agents/` 由 Claude Code 直接從 repo 讀取。

(可選) 常用 MCP server（jira-mcp / playwright / postman）安裝：

```
powershell -ExecutionPolicy Bypass -File setting\setup-mcp.ps1   # Windows
bash setting/setup-mcp.sh                                        # macOS / Linux
```

以 user scope 註冊，憑證只存在同目錄的 `mcp-secrets.local.json`（請自行修改）；首次在已設定過的主機執行會自動把現有設定值抽出成該檔，內容更動就再跑一次——腳本採「移除後重加」，重複執行安全。

## 治理與自檢

規則本體不放在 README，也不一次全載進 context：`CLAUDE.md` 只留硬規則與一張路由表，遇到對應情境才去讀 `governance/` 的全文；`skills/` 同理，`SKILL.md` 留流程骨幹，細節下沉到 `references/`。

三個 SessionStart hook 在每次 session 開場自動跑，全部唯讀僅做安全操作：

| 腳本                  | 檢查什麼                                                      | 行為                                                      |
| ------------------- | --------------------------------------------------------- | ------------------------------------------------------- |
| `check-memory-link` | 本專案的 `~/.claude/projects/{project}/memory` 是否已接回共用 memory | 空資料夾直接接線；已有內容則不動手，改在對話中問使用者是否遷移；使用者說過「略過」就靜默            |
| `check-project-kb`  | 以各 KB 的 `source-codex/cross/service-map.md` 路徑欄比對當前工作目錄   | 依據當下工作目錄比對知識庫，啟動工作流即建議專案 KB（不因 claude 啟動目錄影響知識累積與工作坊使用） |
| `check-skills`      | skill 更新後的自審機制                                            | `SKILL.md` 內容規格檢查；警告未被引用的孤兒檔與超過 250 行的檔案                |

另有 `check-kb-formats`：比對各 KB 的 `spec-format.md` / `impls-format.md` / `qa-format.md` 副本與 `skills/update-kb/templates/formats/` 正本的標題結構，缺檔或結構不符時報 WARN；若專案 KB 有客製需求，可在 frontmatter 標 `customized: true`。

## 專案知識庫

- 專案 KB 以 **`_KBs`** 後綴命名，`/sdlc-agent` 與 `/update-kb` 啟動時自動掃描供選擇；`common_KBs/` 為共用知識、自動載入不需選擇。
- 建新 KB：複製 `demo_KBs/` 改名後替換內容，或直接執行 `/update-kb` 選新 KB 由 skill 自動初始化結構。

## Skills 一覽

| Skill              | 用途                                                                         |
| ------------------ | -------------------------------------------------------------------------- |
| `/sdlc-agent`      | 自動開發流程工具：單一角色、部分流程或完整 Spec-Driven 生命週期（詳見下節）                               |
| `/update-kb`       | 知識庫更新：手動輸入或排程掃描 `pending/`，並行派子代理寫入（詳見下節）                                  |
| `/code-architect`  | Java 程式分層規則審查，回報違規與修正建議                                                    |
| `/contract-test`   | 依 Controller 生成 Spring Cloud Contract 契約與 ContractBase，涵蓋 HTTP 與 websocket |
| `/mapper-test`     | 依 Mapper 介面生成 MapperTest，以 Instancio + 全欄位比對驗證映射完整性                        |
| `/db-object-rules` | Oracle SQL 與 MongoDB 腳本的內容規則審查                                             |
| `/diagram`         | Mermaid 圖表生成與依 git diff 同步更新（套用通用配色與專案自定義的 participant alias）              |
| `/quiz`            | 從 `tech-research` 對過往研究抽題複習，另有主題性探討與情境長題模式                                 |

Skill 更新審查（由 `check-skills` 把關）：

- 修改任何 `SKILL.md`，同一次工作中必須同步更新該 skill 的 `CHANGELOG.md`（版本號、日期、Added / Changed / Removed），且版本號要對得上 frontmatter。
- `SKILL.md` 只留流程骨幹，細節下沉 `references/`，單檔控制在 250 行內。
- `SKILL.md` 與 `CHANGELOG.md` 均需去識別化。

跨 skill 煙霧測試（全文見 `governance/smoke-test-checklist.md`）：若改到跨 skill 呼叫鏈（`sdlc-agent` / `update-kb` / `code-architect` / `diagram`）的**介面相關內容**（觸發方式、輸入參數、輸出路徑、路由規則、對其他 skill 的行為描述）、或改到 `update-kb` 的模板與 `roles/` `role-flows/` 時，要在 `demo_KBs` 實跑一次對應路由；驗收不只看正常路徑會過，還要故意注入一次漂移、確認測試真的失敗，否則測試本身可能是假陽性。

## 開發工作流程自動化 — `/sdlc-agent`

支援完整 Spec-Driven 開發生命週期：

```
需求企劃 → Spec 轉化 → Spec-Driven 實作 → Code Review → QA
              ↕ ADR 溝通（貫穿 Spec 轉化至實作階段）
```

| 階段             | 角色         | 執行內容                                                             |
| -------------- | ---------- | ---------------------------------------------------------------- |
| 需求企劃           | PM         | 審查 AC 完整性與跨服務依賴，補 Gherkin 範本，產出 `specs/{TICKET}.md` 第一版          |
| Spec 轉化        | SA         | 轉化需求到技術文件，產出完整規格（功能目標、AC、資料流、介面、非功能需求）                           |
| ADR 溝通         | CONSULTANT | 逐決策點對照現有 ADR 與技術棧，記錄新決策；實作時複驗選型一致性                               |
| Spec-Driven 實作 | BACKEND    | 依 spec 實作；`/code-architect` 驗證架構、`/diagram` 產出實作流程圖；測試只跑受異動影響範圍  |
| Code Review    | REVIEWER   | 審查本次異動（QA 回圈輪只審修正 diff）；若有修正，修正後 `/diagram sync` 更新流程圖           |
| QA             | QA         | 對齊 AC 生成測試案例；執行 unit / integration / 本機啟動驗測；功能有誤則回圈至實作修正（至多 3 輪） |

**執行模式**：單一角色（固定 confirm）／部分流程（指定 stage 起跑到 QA）／完整流程／PREVIEW（BACKEND + QA 子代理並行分析同一 story）。

- Pipeline 中每個 stage 可獨立設 **auto** 或 **confirm**（預設 `C A A A A`：spec 把關、其後全自動）。
- 支援參數直通：`/sdlc-agent 1 full CAAAA` -- {KB序號}{執行模式}{各階段自動設定}。
- Pipeline 模式下各 stage 產出先暫存 `pending/` 草稿，終點才一次性 `/update-kb` 正式入庫；若中斷草稿可隨時由排程模式入庫、或提供 AI 下次接續參考。
- SA 階段遇到牽動多個 service、難以回頭（schema／外部合約／資料遷移）或方案超過兩個的決策點，改走 `role-flows/clarification-protocol.md`：先自行從 KB 與程式碼查清事實，再把剩下需要取捨的部分拆成決策樹，一次只問一題，收斂後才記錄 ADR。

## 共用知識 — `knowledge/common_KBs/`

- **guideline/**：跨專案開發預設規範。
- **ADRs/**：通用實務決策紀錄（依領域 01–08），記錄決策脈絡、方案與取捨，而非只記結論。
- **tech-research/**：技術評估與研究筆記，主題索引見 [`tech-research/index.md`](knowledge/common_KBs/tech-research/index.md)。

## 專案 KB 內部結構

| 目錄                  | 對應角色     | 內容                                               |
| ------------------- | -------- | ------------------------------------------------ |
| `specs/`            | PM / SA  | 需求 spec 與實作紀錄                                    |
| `source-codex/`     | RD       | 服務 wiki（`index.md` / `facts.md`）與 `cross/` 跨服務索引 |
| `site-reliability/` | SRE      | 部署架構、CI/CD、維運 SOP                                |
| `ADRs/`             | —        | 架構技術決策紀錄                                         |
| `review-history/`   | REVIEWER | Code Review 記錄（依票號/主題）                           |
| `qa-records/`       | QA       | 測試案例表與執行紀錄（`{TICKET}-qa.md`）                     |
| `pending/`          | —        | 待建 spec 票清單（`jira.txt`）、pipeline 產出草稿、KB 更新 log  |

## 更新知識庫 — `/update-kb`

支援手動輸入（票號 / diff / 描述）與排程掃描 `pending/` 批次更新，涵蓋 spec、ADR、review 記錄、QA 記錄與 tech-research 筆記。

寫入共用路徑（`common_KBs/ADRs/`、`tech-research/`）前，將依去識別化檢查清單（regex + 語意雙軌）掃描並替換為一致佔位符；「識別項目 → 佔位符」對照表僅顯示於當次對話，不寫入任何檔案。

## AI 工作坊 — `ai-workshop/`

本地 AI 開發環境：Ollama 推理 + Open WebUI（模型調教 / RAG 測試）、n8n 自動化引擎（Telegram Bot 意圖路由、排程 SOP、MCP Server 接口）、Continue.dev IntelliJ 整合。建置步驟見 [`ai-workshop/README.md`](ai-workshop/README.md)。

---

## English

# Engineering Hub

**A portable, cross-project knowledge base ＋ process engine**:

- **Knowledge transfer** — requirement specs, service source indexes, architecture decision records (ADRs), and QA records build up under `knowledge/` over time, so the context does not leave when people do.
- **Process engine** — the Spec-Driven pipeline (PM → SA → BACKEND → REVIEWER → QA) takes the KB as both its input and its output at every stage, with the issue tracker and browser automation wired in over MCP.
- **Portable** — knowledge base, skills, subagent definitions, working rules, and memory all travel with the repo; clone and run one setup script to rebuild the same workshop on any machine.

## Directory Structure

```
engineering-hub/
├── CLAUDE.md                # Rules index: routing only; full text in governance/, read on trigger
├── .claude/agents/          # Worker subagents (mechanical / readback / security-review)
├── ai-workshop/             # Local AI dev environment (Ollama / Open WebUI / n8n / Continue.dev)
├── governance/              # Full rules: model dispatch, prompt templates, judgment rubrics,
│                            # maintenance protocol, diagnosis, lessons learned from past work,
│                            # smoke-test checklist (backup/ untracked)
├── memory/                  # Cross-project shared memory (linked to ~/.claude by setup-host)
├── setting/
│   ├── paths.yml            # @kb/-relative path constants (deliberately no host absolute paths)
│   ├── setup-host.ps1|.sh   # One-shot host setup (junction/symlink + SessionStart hook registration)
│   ├── setup-mcp.ps1|.sh    # One-shot shared MCP server registration (secrets in a gitignored file)
│   └── check-*.ps1|.sh      # Self-checks: memory / project KB / skill consistency / KB formats
├── knowledge/
│   ├── common_KBs/          # Shared KB: guideline / ADRs / tech-research
│   ├── {project}_KBs/       # Project KBs (suffix `_KBs`, structure below)
│   └── demo_KBs/            # Sample KB, template for new project KBs
├── roles/                   # Role definitions (PM / SA / CONSULTANT / BACKEND / REVIEWER / QA / SRE)
├── role-flows/              # Per-role workflows, plus the cross-role clarification protocol
└── skills/{name}/           # Claude Code skills (SKILL.md + references/ + CHANGELOG.md)
```

The workshop root path lives in `memory/reference_knowledge_base.local.md` (generated automatically by setup-host); every other document uses the `@kb/` prefix, resolved by the skills at runtime.

## Quick Start (new machine)

```
git clone {repo} && cd engineering-hub
powershell -ExecutionPolicy Bypass -File setting\setup-host.ps1   # Windows
bash setting/setup-host.sh                                        # macOS / Linux
```

The script does three things:

1. Links `memory/` and `skills/` back into `~/.claude` (junction / symlink).
2. Writes a non-project-scoped anchor to the KB root, so the check scripts can find this repo no matter which directory `claude` is launched from.
3. **Modifies `~/.claude/settings.json`** to register three user-level SessionStart hooks (below). Already-registered hooks are skipped and all other settings are preserved. They are user-level rather than project-level so they fire wherever `claude` is launched.

`.claude/agents/` is read directly from the repo by Claude Code.

(Optional) Install the commonly-used MCP servers (jira-mcp / playwright / postman):

```
powershell -ExecutionPolicy Bypass -File setting\setup-mcp.ps1   # Windows
bash setting/setup-mcp.sh                                        # macOS / Linux
```

Registration is at user scope; credentials live only in `mcp-secrets.local.json` next to the script (fill it in yourself). On a host that already has these servers configured, the existing values are extracted into that file automatically. To rotate a token, edit the file and re-run — the script removes and re-adds each server, so re-running is always safe.

## Governance and Self-Checks

Rules do not live in this README, and they are not all loaded into context up front: `CLAUDE.md` keeps only the hard rules plus a routing table, and the full text in `governance/` is read only when its trigger applies. Skills follow the same shape — `SKILL.md` holds the workflow skeleton, details sink into `references/`.

Three SessionStart hooks run at the start of every session; all are read-only and do nothing but safe operations:

| Script | Checks | Behavior |
|--------|--------|----------|
| `check-memory-link` | Whether this project's `~/.claude/projects/{project}/memory` is linked to the shared memory store | Links an empty folder silently; never touches one with real content — instead asks in-conversation whether to migrate; stays silent if the user opted out |
| `check-project-kb` | Matches the current directory against each KB's `source-codex/cross/service-map.md` path column | Suggests the matching project KB as soon as a workflow starts, based on the working directory (so the directory `claude` happens to be launched from never affects what gets accumulated or which workshop is used) |
| `check-skills` | Self-review after a skill is updated | Checks `SKILL.md` against the content spec; warns on orphan reference files and files over 250 lines |

`check-kb-formats` compares each KB's `spec-format.md` / `impls-format.md` / `qa-format.md` copies against the canonical versions in `skills/update-kb/templates/formats/`, and WARNs on missing copies or structural drift. A project KB that needs to diverge can mark `customized: true` in the file's frontmatter.

## Project Knowledge Bases

- Project KBs use the **`_KBs`** suffix; `/sdlc-agent` and `/update-kb` scan and offer them on startup. `common_KBs/` is shared knowledge, auto-loaded without selection.
- New KB: copy `demo_KBs/`, rename, and replace the content — or run `/update-kb` on the new KB and let it scaffold the structure automatically.

## Skills

| Skill | Purpose |
|-------|---------|
| `/sdlc-agent` | Development workflow automation: single role, partial pipeline, or the full Spec-Driven lifecycle (below) |
| `/update-kb` | KB updates from manual input or a scheduled `pending/` scan, written by parallel subagents (below) |
| `/code-architect` | Reviews Java code against the layering rules and reports violations with fixes |
| `/contract-test` | Generates Spring Cloud Contract contracts and a ContractBase from a Controller, HTTP and websocket |
| `/mapper-test` | Generates MapperTests from a Mapper interface, verifying full field mapping via Instancio |
| `/db-object-rules` | Content-rule review for Oracle SQL and MongoDB scripts |
| `/diagram` | Mermaid generation and `git diff`-driven sync (shared color scheme, per-project participant aliases) |
| `/quiz` | Draws questions on past research from `tech-research`; also topic-focused and long-form scenario modes |

Skill update review (enforced by `check-skills`):

- Editing any `SKILL.md` requires updating that skill's `CHANGELOG.md` in the same session (version, date, Added / Changed / Removed), with the version matching the frontmatter.
- `SKILL.md` keeps the workflow skeleton only; details sink into `references/`, each file under 250 lines.
- Both `SKILL.md` and `CHANGELOG.md` must be de-identified.

Cross-skill smoke test (full text in `governance/smoke-test-checklist.md`): when a change touches the **interface surface** of the cross-skill call chain (`sdlc-agent` / `update-kb` / `code-architect` / `diagram`) — trigger conditions, input parameters, output paths, routing rules, or how a skill describes another's behavior — or touches `update-kb`'s templates, `roles/`, or `role-flows/`, run the affected route for real against `demo_KBs`. Acceptance is not just "the happy path passes" — inject one deliberate drift and confirm the test actually fails, or the test itself may be a false positive.

## Development Workflow Automation — `/sdlc-agent`

Drives a full Spec-Driven development lifecycle:

```
Requirements → Spec Conversion → Spec-Driven Development → Code Review → QA
                    ↕ ADR Communication (spans Spec through Development)
```

| Stage | Role | What it does |
|-------|------|-------------|
| Requirements | PM | Reviews AC completeness and cross-service dependencies, adds Gherkin templates, produces the first version of `specs/{TICKET}.md` |
| Spec Conversion | SA | Converts the requirement into a technical document — a complete spec (goals, ACs, data flow, interfaces, NFRs) |
| ADR Communication | CONSULTANT | Checks each decision point against existing ADRs and the tech stack, records new decisions; re-verifies during implementation |
| Spec-Driven Development | BACKEND | Implements per spec; `/code-architect` validates architecture, `/diagram` renders the implementation flow; tests run only on the affected scope |
| Code Review | REVIEWER | Reviews the change set (loop rounds review only the fix diff); if anything is fixed, `/diagram sync` updates the flow afterwards |
| QA | QA | Generates test cases against the ACs; runs unit / integration / local-startup verification; loops back to Development on functional defects (max 3 rounds) |

**Modes**: Single Role (always confirm) / Partial Pipeline (any stage through QA) / Full Pipeline / PREVIEW (parallel BACKEND + QA analysis of one story).

- Each pipeline stage can be set to **auto** or **confirm** (default `C A A A A`: gate the spec, then hands-off).
- Argument pass-through: `/sdlc-agent 1 full CAAAA` -- {KB index}{mode}{per-stage auto/confirm}.
- In pipeline mode, stage outputs are drafted to `pending/` first and committed to the KB by a single `/update-kb` only at the end; if a run is interrupted, the drafts can be committed later by the scheduled mode, or serve as context for the AI to pick up next time.
- When an SA-stage decision spans multiple services, is hard to reverse (schema, external contract, data migration), or has more than two viable options, it switches to `role-flows/clarification-protocol.md`: establish the facts from the KB and the code first, then break what genuinely needs a human trade-off into a decision tree and ask one question at a time, recording the ADR only once it converges.

## Shared Knowledge — `knowledge/common_KBs/`

- **guideline/** — default cross-project development guidelines.
- **ADRs/** — general practice decision records (domains 01–08), capturing context, options, and trade-offs — not just the outcome.
- **tech-research/** — technology evaluation and research notes, indexed in [`tech-research/index.md`](knowledge/common_KBs/tech-research/index.md).

## Project KB Layout

| Directory | Role | Contents |
|-----------|------|----------|
| `specs/` | PM / SA | Requirement specs and implementation records |
| `source-codex/` | RD | Service wikis (`index.md` / `facts.md`) and `cross/` cross-service indexes |
| `site-reliability/` | SRE | Deployment, CI/CD, operations SOPs |
| `ADRs/` | — | Architecture and technical decision records |
| `review-history/` | REVIEWER | Code review records (per ticket / topic) |
| `qa-records/` | QA | Test-case tables and execution records (`{TICKET}-qa.md`) |
| `pending/` | — | Tickets awaiting specs (`jira.txt`), pipeline output drafts, KB update logs |

## Updating the KB — `/update-kb`

Supports manual input (ticket / diff / description) and scheduled `pending/` scans, covering specs, ADRs, review records, QA records, and tech-research notes.

Before writing to shared paths (`common_KBs/ADRs/`, `tech-research/`), content is scanned against a de-identification checklist (regex + semantic passes) and replaced with consistent placeholders; the identifier-to-placeholder mapping is shown only in the conversation and never persisted to any file.

## AI Workshop — `ai-workshop/`

Local AI environment: Ollama inference + Open WebUI (model tuning / RAG testing), n8n automation engine (Telegram Bot intent routing, scheduled SOPs, MCP Server endpoint), and Continue.dev IntelliJ integration. See [`ai-workshop/README.md`](ai-workshop/README.md).
