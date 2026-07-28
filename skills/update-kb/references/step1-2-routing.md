<!-- 由 SKILL.md Step 1 / Step 2 連結，完整明細。 -->

## Step 1 — 判斷啟動模式

### 模式 A：排程自啟動

> 由 `/schedule` 或 `/loop` 觸發時進入此模式，不等待使用者輸入。

對每個 `$PROJECT_KB` in `$TARGET_KBs`，掃描以下來源，收集待更新內容清單：

| 來源 | 路徑 | 處理方式 |
|------|------|---------|
| Jira ticket 清單 | `{$PROJECT_KB}/pending/jira.txt` | 逐行讀取 ticket ID，嘗試用 Jira MCP 拉取內容 |
| 每日 git 更新 | 各 service repo（路徑見 `{$PROJECT_KB}/source-codex/cross/service-map.md`）| `git log --since="24 hours ago" --oneline` 取得變更 commit，依 service 分組 |

若所有 `$TARGET_KBs` 均無新內容 → 記錄 log「無待更新項目」後結束。

若多個 `$PROJECT_KB` 均有待更新內容，在同一個 response 中**並行**對各 PROJECT_KB 派發 Step 3 的子代理組。

### 模式 B：使用者自啟動

詢問：

```
請輸入要更新的內容（擇一）：
  1. Jira 單號（如 PROJECT-123）
  2. 直接貼上內容或檔案路徑
  3. 描述要更新的功能或異動
  4. 架構決策（更新專案 ADRs，可含專案識別資訊）
  5. 去識別化的架構決策（更新共用 ADRs → `common_KBs/ADRs/`，將依「去識別化檢查清單」自動掃描與替換）
  6. Code Review 記錄（新增 review-history/ 條目，可含 ticket 單號或直接描述）
  7. 技術探討 / 研究筆記（更新 `common_KBs/tech-research/`，將依「去識別化檢查清單」自動掃描與替換）
  8. KB_ROOT 結構性異動（`skills/`、`role-flows/`、`roles/`、`setting/` 等不綁定特定專案的異動，例如 skill 規則調整、審查/稽核結果，將依「去識別化檢查清單」自動掃描與替換）

輸入內容：
```

等待使用者輸入後進入 Step 2。

---

## Step 2 — 判斷涉及的知識庫類型

依內容關鍵字判斷需要更新哪些 KB 類型（可多選）：

| 關鍵字 / 特徵 | 涉及 KB |
|--------------|--------|
| Story、AC、spec、需求、驗收條件、功能目標、impl、實作概述 | **PM KB**（`{$PROJECT_KB}/specs/`） |
| service、class、API、Kafka topic、Redis key、DB、git diff、程式碼變更 | **RD KB**（`{$PROJECT_KB}/source-codex/`） |
| 部署、CI/CD、ArgoCD、環境、監控、OTEL、SOP、migration、rollback | **SRE KB**（`{$PROJECT_KB}/site-reliability/`） |
| 架構決策、ADR、技術選型、設計決定（含專案識別資訊） | **專案 ADR**（`{$PROJECT_KB}/ADRs/`） |
| 去識別化架構決策、跨專案通用決策（無任何專案識別資訊） | **共用 ADR KB**（`$KB_ROOT/knowledge/common_KBs/ADRs/`） |
| 技術探討、框架評估、研究筆記、選型比較（去識別化） | **通用技術研究 KB**（`$KB_ROOT/knowledge/common_KBs/tech-research/`） |
| code review、Review、品質問題、效能問題、原子性、[V]、[不處理]、審查範圍、審查結果、review history | **Review History KB**（`{$PROJECT_KB}/review-history/`） |
| qa、測試案例、測試結果、qa-records、{TICKET}-qa | **QA Records KB**（`{$PROJECT_KB}/qa-records/{TICKET}-qa.md`，格式規範見 `qa_format`） |
| skill 規則調整（`skills/*/SKILL.md`）、共用審查規範（`common_KBs/guideline/`）、角色定義（`roles/`）、角色流程（`role-flows/`）、`setting/paths.yml`、README.md、CLAUDE.md 等不綁定特定專案的異動；或針對這些路徑的稽核 / 檢查結果（如去識別化稽核、規則一致性檢查） | **KB_ROOT Meta**（不屬於任何 `$PROJECT_KB`，見下方說明） |

> **KB_ROOT Meta 的處理方式**：這類異動範圍通常明確且單一（例如一次只改一個 skill 的一條規則），**不派發 Step 3 子代理**，由主流程直接讀取、修改、確認即可；寫入前依「去識別化檢查清單」跑一輪雙軌掃描（不只本節上方的內容限制規則）；`skills/*/SKILL.md` 的內容規則異動仍需依 CLAUDE.md 同步更新該 skill 自己的 CHANGELOG.md。**異動追蹤完全依賴該 CHANGELOG.md + git commit history，update-kb 不另外寫 log**（純稽核、無實際寫入的任務也不需要記錄）。
>
> **一次更新可能同時涉及多個 KB 類型。**
>
> **ADR 判斷規則（先做再去識別化）：**
> 1. 凡涉及架構決策，**優先更新專案 ADR**（`{$PROJECT_KB}/ADRs/`）
> 2. 在寫入前，先掃描 `{$PROJECT_KB}/ADRs/` 確認是否已有相關 ADR：
>    - **已有** → 修訂現有 ADR（更新 date、加 `supersedes`、標注決策翻轉原因），不建立新檔
>    - **沒有** → 建立新編號 ADR（讀取最大現有編號 + 1）
> 3. 若同時需要共用 ADR，在完成專案 ADR 後，確認已完全去識別化才寫入 `knowledge/common_KBs/ADRs/`
