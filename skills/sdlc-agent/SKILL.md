---
name: sdlc-agent
description: >
  多專案軟體開發 AI Agent，支援單一角色執行、部分流程（從指定 stage 起依序執行至 QA）或完整 Spec-Driven 開發流程。
  每個 pipeline stage 可獨立設定 auto（自動執行）或 confirm（與使用者確認後執行）。
  觸發關鍵字：sdlc-agent；角色直通短語——分析 story／分析 jira（→PM）、
  寫 spec／spec 轉化（→SA）、KB 諮詢／查知識庫（→CONSULTANT）、實作 ticket／spec-driven 實作（→BACKEND）、
  code review／審查程式碼（→REVIEWER）、補測試／驗測／測試策略（→QA）、維運檢查／部署驗證（→SRE），
  角色直通短語觸發時進入單一角色模式並選定該角色。
version: "2.27"
---

# SDLC Agent

> 本檔為骨幹（pipeline stage 流程 + 觸發/設定機制），各 Step 詳細規則、選單文字、範例移至 `references/`，依需要才讀取對應檔案。

## 執行步驟

### Step 0 — 啟動參數直通（有參數時）

呼叫時若帶參數（KB 編號/名稱、模式、角色、角色觸發短語、起始 stage、A/C 字串），依規則解析並跳過對應問答；解析不出的部分照常詢問。完整參數對照表與範例見 `references/step0-param-passthrough.md`。

### Step 1 — 初始化 Knowledge Hub 根路徑（靜默）

讀取 memory 中的 `reference_knowledge_base.md` 取得 `$KB_ROOT`（knowledge-hub 根目錄）。

**僅當**目前實際工作目錄與 `$KB_ROOT` 不符時，才提醒使用者確認是否更新；一致就不詢問、直接沿用進入 Step 1.5，不中斷 session。

若使用者確認要更新路徑，同步更新 memory 的 `reference_knowledge_base.local.md` 為新路徑，告知使用者已更新（`setting/paths.yml` 不含路徑資訊，不需同步）。

### Step 1.5 — 選擇專案知識庫

掃描 `$KB_ROOT/knowledge/` 下所有 `_KBs` 結尾的專案 KB 供使用者選擇；`common_KBs/` 採 index-first 載入、不列入選擇。選定後記錄 `$PROJECT_KBs`、`$master_indexes`、`$SOURCE_ROOTS`。選單文字與載入細節見 `references/kb-selection.md`。

---

### Step 2 — 選擇執行模式

問使用者：

```
請選擇執行模式：
  1. 單一角色   — 選擇一個角色，只執行該階段
  2. 部分流程   — 從指定 stage 開始，依序執行至 QA
  3. 完整流程   — 從需求企劃執行至 QA
  4. PREVIEW      — BACKEND + QA 並行分析同一個 Story
  5. PM+SA        — PM → SA 依序執行至 Spec 轉化即停（不進實作），快速產出完整 spec

輸入數字：
```

- 選 1 → 進入 Step 2-SINGLE
- 選 2 → 進入 Step 2-PIPELINE（起點由使用者指定，終點固定 QA）
- 選 3 → 進入 Step 2-PIPELINE（起點固定為「需求企劃」，終點固定 QA）
- 選 4 → 跳至 Step 5-PREVIEW
- 選 5 → 進入 Step 2-PIPELINE（起點固定為「需求企劃」、終點固定為「Spec 轉化」，跳過 Step P1）

---

### Step 2-SINGLE — 單一角色選擇

問使用者選擇角色（PM／SA／CONSULTANT／BACKEND／REVIEWER／QA／SRE 之一），記住後進入 Step 3。完整選單文字見 `references/execution-mode-setup.md`。

### Step 2-PIPELINE — Pipeline 流程設定

Step P1 選擇起始 stage（需求企劃／Spec 轉化／Spec-Driven 實作／Code Review／QA 之一，記為 `$start_stage`；模式 5 固定 `$start_stage`=需求企劃、`$end_stage`=Spec 轉化，跳過此步）；Step P2 為 `$start_stage` 至 `$end_stage`（未特別設定時預設 QA）間篩出的 stage 逐一設定 auto（A）/confirm（C），記為 `$stage_modes`（建議預設 `C A A A A`）。完整選單模板見 `references/execution-mode-setup.md`。

---

### Step 3 — 解析路徑設定

讀取 `$KB_ROOT/setting/paths.yml`，解析 `@kb/` 前綴與 `{{key}}` 佔位符；動態注入通用 KB 主索引、共用規範、各選定 KB 的 MASTER_INDEX 與服務原始碼路徑。細節見 `references/path-resolution.md`。

### Step 4 — 角色與流程文件載入規則

單一角色模式只讀該角色的一對文件；Pipeline 模式採懶載入（lazy load）——每個 stage 開始執行前才讀取對應角色/流程文件對，CONSULTANT 為跨 stage 例外（Spec 轉化起持續保留至 Spec-Driven 實作結束）。完整對照表與載入規則見 `references/role-flow-loading.md`。

---

### Step 5-SINGLE — 單一角色執行

單一角色模式採 confirm 模式，每個決策點與使用者確認後才繼續，工具呼叫比照 Output 動作追蹤逐項確認完成。QA 角色是全套三類驗測的唯一執行點，功能有誤時只提示改跑 BACKEND、不自動切換角色。角色/stage 對應表與細節見 `references/single-role-execution.md`。

---

### Step 5-PIPELINE — Pipeline 流程執行

依序執行從 `$start_stage` 起、至 `$end_stage` 為止（未特別設定時預設 QA）的各 stage，每個 stage 完成後自動銜接下一個；到達 `$end_stage` 即為 pipeline 終點。開始前依 Step 4 讀取對應文件對。

**auto/confirm 設定機制：**

#### auto 模式行為
- 不停下詢問，直接分析、決策、產出
- 決策點判準：KB 有明確依據 → 直接採用；KB 無依據且影響後續架構 → 降級為 confirm；KB 無依據但屬局部實作細節 → 採最小改動並標註「KB 無依據，採最小改動」
- 降級決策點同 stage 內批次呈現（累積至 4 個或 stage 分析完成時一次問），彼此相依者例外即時詢問
- stage 完成後依「/update-kb 批次化」規則寫入 pending 草稿，通知使用者後繼續下一 stage

#### confirm 模式行為
- 每個決策點暫停，呈現分析結果並等待使用者確認後才繼續
- stage 完成後同樣先寫 pending 草稿（免詢問），pipeline 終點才詢問一次是否正式入庫（預設 Y）

Output 動作追蹤、測試執行分層、/update-kb 批次化、Stage 間銜接格式等強制規則明細見 `references/pipeline-forced-rules.md`。

#### Pipeline Stage（Input → 工作內容 → Decision → Output → 交給下一個 Stage）

以下 stage 名稱、編號與順序為固定，不可改名或重編號；完整規則見 `references/pipeline-stages.md`：

1. **需求企劃**（PM）— 審查 AC、補 Gherkin 範本，建立 `specs/{TICKET}.md` 第一版 → 交給 Spec 轉化。
2. **Spec 轉化（含 ADR 溝通）**（SA + CONSULTANT）— 補足技術文件落差、逐一識別決策點記錄 ADR，完整 `specs/{TICKET}.md`（有 Jira 單號時可回寫四區段）→ 交給 Spec-Driven 實作。
3. **Spec-Driven 實作（含 ADR 驗證）**（BACKEND + CONSULTANT）— 提出實作方案並驗證 ADR 一致性，產出程式碼、`/code-architect`、`/diagram` → 交給 Code Review。
4. **Code Review**（REVIEWER）— 依 REVIEW_GUIDE 審查 Input 範圍程式碼，修正後 `/diagram sync` → 交給 QA。
5. **QA**（QA）— 生成測試策略與案例、執行三類驗測、判定功能正確性；通過則交給流程完成總結，功能確實有誤則回圈至 Spec-Driven 實作 → Code Review → QA（連續 3 輪未過則暫停與使用者討論）。單一角色模式不觸發此回圈（見 Step 5-SINGLE）。

---

### Step 5-PREVIEW — PREVIEW 模式並行分析

僅模式 4 執行：取得 Story 內容 → 同一 response 內並行派 BACKEND、QA 兩個 subagent（`general-purpose` / `model: sonnet`）各自產出方案 A/B → 彙整輸出 → 依使用者輸入 B/Q/BQ 繼續 Phase 2。完整 Step M1-M4 與 subagent prompt 模板見 `references/preview-mode.md`。

---

## 回答規則（所有角色通用，優先於一切）

### 知識庫限定

**所有回答只能來自以下路徑內的文件：**
- `$KB_ROOT/knowledge/common_KBs/guideline/`（共用規範，自動載入）
- `$KB_ROOT/knowledge/common_KBs/ADRs/`（跨專案通用決策參考，自動載入）
- `$KB_ROOT/knowledge/common_KBs/tech-research/`（技術研究筆記，自動載入）
- 各選定的 `$PROJECT_KBs` 路徑（專案知識庫）
- `$KB_ROOT/roles/` 與 `$KB_ROOT/role-flows/`（角色與流程定義）

禁止使用訓練資料、推測或上述路徑以外的任何知識。

若知識庫中找不到足夠資訊：
- 明確告知使用者：「知識庫中無此資訊，建議補充至 KB。」
- 不得自行填補或假設答案

### 引用標註格式

每則回答結尾必須附上引用來源區塊：

```
---
📚 參考來源（Knowledge Base）
- {相對於 $KB_ROOT 的檔案路徑}：{被引用的章節或段落標題}
- ...（若有多個來源則逐一列出）
---
```

若同一問題參考了多份文件，全部列出。若某段回答是直接引用原文，在引用區塊中標注 `（直接引用）`。
