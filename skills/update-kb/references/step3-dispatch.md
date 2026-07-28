<!-- 由 SKILL.md Step 3 連結，完整明細。 -->

## Step 3 — 並行派發子代理

**在同一個 response 中**同時發出所有涉及 KB 類型的 `Agent` tool call。

> 調度原則見 governance/model-dispatch.md。

依 Step 2 判定的 KB 類型，**只讀取**下表對應的 `templates/*.md` 構成子代理 prompt；不得一次讀取全部模板。每個模板檔已內含「派發規格」（`subagent_type` / `model`），依模板標注的值填入 Agent tool call，不自行留空（留空即繼承主線模型）。發出前將模板中所有 `{...}` 替換為實際值。

| KB 類型 | 模板檔路徑 | subagent_type | model |
|--------|-----------|---------------|-------|
| PM KB（specs / impls） | `templates/pm-spec.md` | general-purpose | sonnet |
| RD KB（source-codex） | `templates/rd-source-codex.md` | general-purpose | haiku |
| SRE KB（site-reliability） | `templates/sre.md` | general-purpose | haiku |
| 專案 ADR（`{$PROJECT_KB}/ADRs/`） | `templates/project-adr.md` | general-purpose | sonnet |
| 共用 ADR（`common_KBs/ADRs/`） | `templates/common-adr.md` | general-purpose | sonnet |
| 通用技術研究（`common_KBs/tech-research/`） | `templates/tech-research.md` | general-purpose | sonnet |
| Review History（`review-history/`） | `templates/review-history.md` | general-purpose | sonnet |
| QA Records（`qa-records/`） | `templates/qa-records.md` | general-purpose | sonnet |

> 各模板檔路徑皆相對於本 skill 目錄（`skills/update-kb/templates/`）。
