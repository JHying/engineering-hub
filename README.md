# Engineering Hub

A knowledge-base workshop for software development. Each project manages its own knowledge base in a dedicated subfolder, while shared guidelines and architectural decisions live in common directories.

---

## Directory Structure

```
engineering-hub/
├── ai-workshop/                     # Local AI development environment & architecture
│   ├── README.md                    # Setup guide (Ollama / Open WebUI / n8n / Continue.dev)
│   ├── docker-compose.yml           # Docker service definitions
│   └── localAI_architecture.md      # Architecture diagrams (V1 / V2)
├── setting/
│   ├── paths.yml                    # Path constant definitions (@kb/ alias mapping)
│   └── setup-skills-junction.ps1   # Script to create the ~/.claude/skills/ junction
├── knowledge/
│   ├── common_KBs/                  # Shared knowledge (auto-loaded for all projects)
│   │   ├── MASTER_INDEX.md
│   │   ├── guideline/               # Cross-project development guidelines
│   │   ├── ADRs/                    # Shared architecture decisions (categorized 01–08)
│   │   └── tech-research/           # Technology research & evaluation notes (see index.md)
│   ├── {project_name}_KBs/          # Project knowledge base (named with the _KBs suffix)
│   │   ├── MASTER_INDEX.md          # Project overview & AI document routing rules
│   │   ├── specs/                   # PM KB: requirement specs & implementation docs
│   │   ├── source-codex/            # RD KB: service wikis & cross-service resource index
│   │   ├── site-reliability/        # SRE KB: deployment, CI/CD, operations SOPs
│   │   ├── ADRs/                    # In-project architecture decisions
│   │   ├── review-history/          # Code review records (per ticket / topic)
│   │   └── pending/
│   │       ├── jira.txt             # List of requirement tickets pending spec creation
│   │       └── logs/                # KB update records
│   └── demo_KBs/                    # Sample project KB (reference when creating a new KB)
├── role-flows/                      # AI query flow definitions for each role
├── roles/                           # Role definitions (PM / RD / QA / SRE / Reviewer)
└── skills/                          # Claude Code skill definitions
```

---

## Project Knowledge Base Naming Convention

- All project KB folders are named with the **`_KBs`** suffix (e.g., `myproject_KBs`).
- On startup, the `/my-work-agent` and `/update-kb` skills automatically scan every `*_KBs` folder under `knowledge/` and offer them for selection.
- `knowledge/common_KBs/guideline/` and `knowledge/common_KBs/ADRs/` are shared knowledge — **auto-loaded, no selection required**.

---

## Creating a New Project KB

1. Copy the `knowledge/demo_KBs/` folder and rename it to `{project_name}_KBs`.
2. Replace every `【DEMO】` marker with the actual project content.
3. Update the system positioning, service list, and AI routing rules in `MASTER_INDEX.md`.
4. Launch `/my-work-agent`, select the newly created KB, and you're ready to go.

> Alternatively, run `/update-kb` and select the new KB — the skill will automatically scaffold the directory structure from `demo_KBs` on first use.

---

## About Shared Knowledge

### Development Guidelines — `knowledge/common_KBs/guideline/`

Cross-project development guidelines, including the Code Review focus guide.

### Shared Architecture Decisions — `knowledge/common_KBs/ADRs/`

General architecture decisions extracted and de-identified from individual projects during development, kept as a reference for similar situations in the future.
When adding a new entry, make sure it is fully de-identified (no project names, company names, or business-sensitive information).

Each record captures a real decision: the context, the options that were on the table, the drivers that mattered, and the trade-offs that were accepted.
The intent is to show how the decision was reasoned about, not just what was chosen.

ADRs are categorized by domain (01–08) under `knowledge/common_KBs/ADRs/`.

### Technology Research Notes — `knowledge/common_KBs/tech-research/`

De-identified notes from technology evaluations, framework comparisons, and research spikes. Useful when the same question comes up again in a different project. Topics are organized by domain in [`tech-research/index.md`](knowledge/common_KBs/tech-research/index.md) — covering cloud infrastructure, system performance, DevOps / observability, data, networking, architecture design, frontend, and AI tooling.

---

## AI Workshop — `ai-workshop/`

Local AI development environment for running models on-premise and building AI-driven automation:

- **Inference** — Ollama running local LLMs (e.g., Qwen, Llama); Open WebUI at `localhost:8000` for model tuning and RAG testing
- **Automation** — n8n at `localhost:5678` as the unified execution engine: intent routing via Telegram Bot, scheduled SOP workflows, and an MCP Server endpoint so Claude can drive workflows directly
- **IDE integration** — Continue.dev plugin for IntelliJ with code completion, review, and refactoring powered by local Ollama or Claude API
- **Architecture** — `localAI_architecture.md` contains two-version Mermaid diagrams (V1 with OpenClaw agent layer; V2 with n8n as unified engine)

See [`ai-workshop/README.md`](ai-workshop/README.md) for the full setup guide.

---

## Internal Structure of Each Project KB

### PM KB — `{project_KB}/specs/`

Manages the specs and implementation docs for requirement tickets:

| Document Type | Path | Description |
|---------------|------|-------------|
| Spec (requirement) | `specs/{TICKET}.md` | Feature goals, ACs, data flow (created before development) |
| Impl (implementation) | `specs/impls/{TICKET}-impls.md` | AC-to-implementation mapping, system flow, verification method (created after development) |
| Format guide | `specs/spec-format.md` / `specs/impls/impls-format.md` | Writing standards and templates |

### RD KB — `{project_KB}/source-codex/`

Wiki documents for each microservice and an index of cross-service shared resources:

- `services/{service}/index.md` — Service summary, data structures, API contracts, business logic
- `services/{service}/facts.md` — Code-like table of business-rule facts
- `cross/kafka-topology.md` — Kafka topic ↔ producer / consumer mapping
- `cross/redis-keymap.md` — Redis key prefix ↔ read/write service mapping
- `cross/service-map.md` — Sync status and local path for each service

### SRE KB — `{project_KB}/site-reliability/`

Deployment architecture, CI/CD, operations SOPs, and observability docs. See `site-reliability/index.md` for the routing index.

### Project ADRs — `{project_KB}/ADRs/`

Important in-project architecture decisions; may contain project-identifying information. If they prove valuable after de-identification, they can be extracted into the shared `knowledge/common_KBs/ADRs/`.

### Review History — `{project_KB}/review-history/`

Code review records organized by ticket or topic. Each file captures the review scope, quality issues, performance / atomicity findings, design pattern observations, and follow-up items. Use `/update-kb` to create or append entries.

---

## Updating the Knowledge Base

Use the `/update-kb` skill to update any KB content. It supports:
- Manual updates via ticket number, code diff, feature description, or raw files
- Scheduled scans of each project's `pending/` directory for batch updates
- Creating project architecture decisions and extracting de-identified versions into the shared ADRs
- Logging code review records to `review-history/`
- Adding technology research notes to `common_KBs/tech-research/`

---

---

# Knowledge Hub

軟體開發的知識庫工作坊，每個專案以獨立子資料夾管理自己的專案知識庫，共用規範與決策另置於共用目錄。

---

## 目錄結構

```
engineering-hub/
├── ai-workshop/                     # 本地 AI 開發環境與架構設計
│   ├── README.md                    # 建置指南（Ollama / Open WebUI / n8n / Continue.dev）
│   ├── docker-compose.yml           # Docker 服務定義
│   └── localAI_architecture.md      # 架構圖（V1 / V2）
├── setting/
│   ├── paths.yml                    # 路徑常數定義（@kb/ 別名對應）
│   └── setup-skills-junction.ps1   # 建立 ~/.claude/skills/ junction 的腳本
├── knowledge/
│   ├── common_KBs/                  # 共用知識（所有專案自動載入）
│   │   ├── MASTER_INDEX.md
│   │   ├── guideline/               # 跨專案通用開發規範
│   │   ├── ADRs/                    # 共用架構決策（依領域分類 01–08）
│   │   └── tech-research/           # 技術探討與評估筆記（見 index.md）
│   ├── {project_name}_KBs/          # 專案知識庫（_KBs 後綴命名）
│   │   ├── MASTER_INDEX.md          # 專案總覽 & AI 文件路由規則
│   │   ├── specs/                   # PM KB：需求 spec & 實作 impl
│   │   ├── source-codex/            # RD KB：服務 wiki & 跨服務資源索引
│   │   ├── site-reliability/        # SRE KB：部署、CI/CD、維運 SOP
│   │   ├── ADRs/                    # 專案內架構決策
│   │   ├── review-history/          # Code Review 記錄（依票號 / 主題）
│   │   └── pending/
│   │       ├── jira.txt             # 待建 spec 的需求票清單
│   │       └── logs/                # KB 更新記錄
│   └── demo_KBs/                    # 示範用專案 KB（建立新 KB 時參照）
├── role-flows/                      # 各角色的 AI 查詢流程定義
├── roles/                           # 角色設定（PM / RD / QA / SRE / Reviewer）
└── skills/                          # Claude Code skill 定義
```

---

## 專案知識庫命名規則

- 所有專案 KB 資料夾以 **`_KBs`** 後綴命名（例：`myproject_KBs`）
- `/my-work-agent` 與 `/update-kb` skill 在啟動時自動掃描 `knowledge/` 下所有 `*_KBs` 資料夾供選擇
- `knowledge/common_KBs/guideline/` 與 `knowledge/common_KBs/ADRs/` 為共用知識，**自動載入，不需選擇**

---

## 建立新專案 KB

1. 複製 `knowledge/demo_KBs/` 資料夾，重新命名為 `{project_name}_KBs`
2. 將所有 `【DEMO】` 標記替換為實際專案內容
3. 更新 `MASTER_INDEX.md` 的系統定位、服務清單與 AI 路由規則
4. 啟動 `/my-work-agent` 選擇新建的 KB 即可使用

> 也可直接執行 `/update-kb` 並選擇新建的 KB，skill 會在首次使用時自動從 `demo_KBs` 初始化目錄結構。

---

## 共用知識說明

### 開發規範 — `knowledge/common_KBs/guideline/`

跨專案通用的開發規範，包含 Code Review 重點指南。

### 共用架構決策 — `knowledge/common_KBs/ADRs/`

各專案開發過程中去識別化後提取的通用架構決策，供未來遇到類似情境參考。
新增時請確認已完全去識別化（無專案名稱、公司名稱、商業敏感資訊）。

每筆都記錄一個真實的決策：包括決策背景、替代方案、關鍵驅動因素以及最終權衡取捨。
其目的是記錄決策的推理過程給未來類似情境參考，而不僅僅是最終的選擇。

ADR 依領域分類（01–08）置於 `knowledge/common_KBs/ADRs/` 下。

### 技術探討筆記 — `knowledge/common_KBs/tech-research/`

框架評估、技術選型比較、研究 Spike 的去識別化筆記。當類似問題在其他專案重複出現時可快速查閱。主題依領域分類整理於 [`tech-research/index.md`](knowledge/common_KBs/tech-research/index.md)，涵蓋雲端基礎設施、系統性能、DevOps / 可觀測性、資料與分析、網路基礎、架構設計、前端開發與 AI 工具。

---

## AI 工作坊 — `ai-workshop/`

本地 AI 開發環境，用於本機部署模型與建構 AI 驅動的自動化流程：

- **推理層** — Ollama 在本機執行 LLM（Qwen、Llama 等）；Open WebUI（`localhost:8000`）提供模型調教與 RAG 測試
- **執行層** — n8n（`localhost:5678`）作為統一自動化執行引擎：Telegram Bot 接收指令並路由意圖、執行排程 SOP Workflow，並透過 MCP Server 接口讓 Claude 介面直接驅動 Workflow
- **IDE 整合** — Continue.dev 整合 IntelliJ，支援程式碼補全、審查與重構（本機 Ollama 或 Claude API）
- **架構圖** — `localAI_architecture.md` 收錄 V1（含 OpenClaw Agent 層）與 V2（n8n 統一執行引擎）兩版 Mermaid 架構圖

完整建置步驟見 [`ai-workshop/README.md`](ai-workshop/README.md)。

---

## 各專案 KB 內部結構說明

### PM KB — `{project_KB}/specs/`

管理原始需求、規格與實作文件：

| 文件類型 | 路徑 | 說明 |
|---------|------|------|
| Spec（需求） | `specs/{TICKET}.md` | 功能目標、AC、規格說明、資料流（開發前建立） |
| Impl（實作） | `specs/impls/{TICKET}-impls.md` | AC 對應實作、系統流程、驗測方式（實作後建立） |
| 格式規範 | `specs/spec-format.md` / `specs/impls/impls-format.md` | 撰寫標準與模板 |

### RD KB — `{project_KB}/source-codex/`

各微服務的 wiki 文件與跨服務共享資源索引：

- `services/{service}/index.md` — 服務摘要、資料結構、API 合約、業務邏輯
- `services/{service}/facts.md` — code-like 業務規則事實表
- `cross/kafka-topology.md` — Kafka topic ↔ producer / consumer 對應
- `cross/redis-keymap.md` — Redis key prefix ↔ 讀寫服務對應
- `cross/service-map.md` — 各服務 sync 狀態與本機路徑

### SRE KB — `{project_KB}/site-reliability/`

部署架構、CI/CD、維運 SOP 與可觀測性文件，路由索引見 `site-reliability/index.md`。

### 專案 ADR — `{project_KB}/ADRs/`

專案內重要架構決策，可含專案識別資訊。若日後去識別化後有參考價值，可提取至共用 `knowledge/common_KBs/ADRs/`。

### Review History — `{project_KB}/review-history/`

依票號或主題整理的 Code Review 記錄，包含審查範圍、品質問題、效能 / 原子性問題、設計模式觀察與後續追蹤事項。使用 `/update-kb` 新增或追加條目。

---

## 更新知識庫

使用 `/update-kb` skill 更新任何 KB 內容，支援：
- 手動輸入需求票號、程式碼差異、功能描述或檔案更新
- 排程自動掃描各專案 KB 的 `pending/` 目錄並批次更新
- 專案架構決策建立、去識別化提取至共用 ADRs
- Code Review 記錄寫入 `review-history/`
- 技術探討筆記新增至 `common_KBs/tech-research/`
