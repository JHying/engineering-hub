---
name: my-work-agent
description: >
  多專案軟體開發 AI Agent，支援單一角色執行、部分流程（從指定 stage 起依序執行至 QA）或完整 Spec-Driven 開發流程。
  每個 pipeline stage 可獨立設定 auto（自動執行）或 confirm（與使用者確認後執行）。
  觸發關鍵字：my-work-agent、分析 story、分析 jira、code review
version: "2.13"
---

# Dev Work Agent

## 執行步驟

### Step 1 — 初始化 Knowledge Hub 根路徑（靜默）

讀取 memory 中的 `reference_knowledge_base.md` 取得 `$KB_ROOT`（knowledge-hub 根目錄）。

**僅當**目前實際工作目錄與 `$KB_ROOT` 不符時，才提醒使用者確認是否更新；一致就不詢問、直接沿用進入 Step 1.5，不中斷 session。

若使用者確認要更新路徑，同步更新 memory 的 `reference_knowledge_base.md`，並將 `$KB_ROOT/setting/paths.yml` 的 `kb` 行更新為新路徑，告知使用者已更新。

### Step 1.5 — 選擇專案知識庫

掃描 `$KB_ROOT/knowledge/` 下所有名稱以 `_KBs` 結尾的直接子資料夾，列出可用的專案 KB 供使用者選擇。

通用知識庫（`knowledge/common_KBs/`）採 **index-first** 載入，**不列入選擇**：
- 執行時先讀 `common_KBs/MASTER_INDEX.md`，依 Story 主題判斷相關的 ADR 分類與 tech-research 筆記後，**只讀取相關項目**
- `common_KBs/guideline/REVIEW_GUIDE.md` 為例外，REVIEWER 角色必讀，其餘角色依需要載入

顯示類似：

```
請選擇要載入的專案知識庫（輸入編號，多個以逗號分隔，如 1,2）：
  1. {project_name}_KBs
  2. {another_project}_KBs
  ...

說明：knowledge/common_KBs 為共用知識，依 Story 主題按需載入。
```

等待使用者回答，記住選定的專案 KB 清單（以下稱 `$PROJECT_KBs`）。

每個選定 KB 的根路徑格式為 `$KB_ROOT/knowledge/{project_name}/`。

若各專案 KB 內含 `MASTER_INDEX.md`，記錄其完整路徑（以下稱 `$master_indexes`，多個 KB 時全部記錄）。

讀取每個選定 KB 的 `source-codex/cross/service-map.md`（若存在），記錄各服務對應的本機原始碼路徑（以下稱 `$SOURCE_ROOTS`，格式：`{service}: {本機路徑}`）。若檔案不存在，或某服務路徑缺漏（標記為 `-` 或 `[待補充]`），先不追問——到 SA / BACKEND / Code Review / QA 這幾個實際需要讀寫該服務程式碼的 stage 時，再向使用者確認實際路徑。

---

### Step 2 — 選擇執行模式

問使用者：

```
請選擇執行模式：
  1. 單一角色   — 選擇一個角色，只執行該階段
  2. 部分流程   — 從指定 stage 開始，依序執行至 QA
  3. 完整流程   — 從需求企劃執行至 QA
  4. PREVIEW      — BACKEND + QA 並行分析同一個 Story

輸入數字：
```

- 選 1 → 進入 Step 2-SINGLE
- 選 2 → 進入 Step 2-PIPELINE（起點由使用者指定）
- 選 3 → 進入 Step 2-PIPELINE（起點固定為「需求企劃」）
- 選 4 → 跳至 Step 5-PREVIEW

---

### Step 2-SINGLE — 單一角色選擇

問使用者：

```
請選擇角色：
  1. PM         — 需求企劃：審查 AC、補 Gherkin 範本、建立 specs/{TICKET}.md 第一版 + /update-kb
  2. SA         — Spec 轉化：補足技術文件落差、完整 specs/{TICKET}.md、含 ADR 溝通 + /update-kb
  3. CONSULTANT — ADR 溝通：決策點分析 + /update-kb 記錄 ADR
  4. BACKEND    — Spec-Driven 實作（含 ADR 驗證、/code-architect、/diagram、/update-kb）
  5. REVIEWER   — Code Review + 修正 + /diagram sync + /update-kb
  6. QA         — 測試策略 + 撰寫 / 執行測試 + /update-kb
  7. SRE        — 部署策略 + 上線 Checklist

輸入數字或名稱：
```

等待使用者回答後記住選擇的角色，進入 Step 3。

---

### Step 2-PIPELINE — Pipeline 流程設定

#### Step P1 — 起點選擇（部分流程時）

> 若選擇「完整流程（模式 3）」，略過此步，起點預設為「需求企劃」。

問使用者：

```
請選擇起始 stage（將從此 stage 依序執行至 QA）：
  1. 需求企劃
  2. Spec 轉化（SA）
  3. Spec-Driven 實作
  4. Code Review
  5. QA

輸入數字：
```

記住起始 stage（以下稱 `$start_stage`）。

#### Step P2 — 各 stage auto / confirm 設定

ADR 溝通為跨階段角色，隨 Spec 轉化與 Spec-Driven 實作的設定一併適用，不單獨設定。

**顯示選單前，先依以下規則逐行判斷要列出哪些 stage（規則本身只用來決定內容，不得出現在顯示給使用者的文字中）：**

- `$start_stage` ≤ 1 → 列出「需求企劃」行，否則省略該行
- `$start_stage` ≤ 2 → 列出「Spec 轉化（含 ADR 溝通）」行，否則省略該行
- `$start_stage` ≤ 3 → 列出「Spec-Driven 實作（含 ADR 驗證）」行，否則省略該行
- `$start_stage` ≤ 4 → 列出「Code Review」行，否則省略該行
- 「QA」行一律列出，不受 `$start_stage` 限制

依上述規則篩出的 stage 清單，依序填入下方模板（模板內只留純文字與佔位符，不得原樣印出任何條件標記）：

```
請為各 stage 設定執行方式（A = auto 自動執行，C = confirm 先與你確認再執行）：

{依上述規則篩出的 stage 清單，每行一個 stage 名稱加冒號}

依上方順序輸入（例：A A C A A）：
```

記住每個 stage 的設定（以下稱 `$stage_modes`），進入 Step 3。

---

### Step 3 — 解析路徑設定

讀取 `$KB_ROOT/setting/paths.yml`，以 `$KB_ROOT` 取代檔案中的 `kb` key 值。

`@kb/` 前綴替換為 `$KB_ROOT/`，`{{key}}` 符號查找 `regulations` 區段對應路徑。

**動態路徑注入：**

- 通用 KB 主索引：`$KB_ROOT/knowledge/common_KBs/MASTER_INDEX.md`（先讀此檔，再按需讀取具體子目錄）
- 共用規範：`$KB_ROOT/knowledge/common_KBs/guideline/REVIEW_GUIDE.md`（REVIEWER 必讀；其餘角色依需要）
- 各選定 KB 的 `MASTER_INDEX.md` 已在 Step 1.5 記錄於 `$master_indexes`
- 各選定 KB 的服務本機原始碼路徑已在 Step 1.5 記錄於 `$SOURCE_ROOTS`

### Step 4 — 角色與流程文件載入規則

**單一角色模式**：只依選擇的角色讀取對應的一對文件，不讀取其餘角色的檔案：

| 角色        | 角色文件                | 工作流程                  |
|------------|----------------------|--------------------------|
| BACKEND    | `{{role_backend}}`   | `{{flow_backend}}`       |
| QA         | `{{role_qa}}`        | `{{flow_qa}}`            |
| SRE        | `{{role_sre}}`       | `{{flow_sre}}`           |
| PM         | `{{role_pm}}`        | `{{flow_pm}}`            |
| CONSULTANT | `{{role_consultant}}`| `{{flow_consultant}}`    |
| REVIEWER   | `{{role_reviewer}}`  | `{{flow_reviewer}}`      |

**Pipeline 模式（懶載入 / lazy load）**：Step 4 本身**不讀取任何 stage 的角色或流程文件**，只記住下表作為 `$start_stage` 起各 stage 對應的檔案路徑對照；實際讀檔動作延後到 Step 5-PIPELINE 各 stage **開始執行前**才進行：

| Stage | 角色文件 | 工作流程 |
|-------|---------|---------|
| 需求企劃 | `{{role_pm}}` | `{{flow_pm}}` |
| Spec 轉化 | `{{role_sa}}` + `{{role_consultant}}` | `{{flow_sa}}` + `{{flow_consultant}}` |
| Spec-Driven 實作 | `{{role_backend}}` + `{{role_consultant}}` | `{{flow_backend}}` + `{{flow_consultant}}` |
| Code Review | `{{role_reviewer}}` | `{{flow_reviewer}}` |
| QA | `{{role_qa}}` | `{{flow_qa}}` |

**載入規則（Pipeline 模式）：**

- 每個 stage 開始執行前，才讀取該 stage 對應列的檔案對；**不得預先讀取尚未開始執行之 stage 的角色或流程文件**。
- **CONSULTANT 為跨 stage 角色，ADR 溝通貫穿 Spec 轉化至 Spec-Driven 實作**：進入「Spec 轉化」stage 時，除了 SA 的檔案對，一併載入 CONSULTANT 的檔案對（`{{role_consultant}}` + `{{flow_consultant}}`）；此檔案對持續保留使用直到「Spec-Driven 實作」stage 結束為止——「Spec-Driven 實作」stage 開始時不需重複載入 CONSULTANT 檔案對，中間也不因換 stage 而重讀。
- 除上述 CONSULTANT 例外，各 stage 之間不共用已讀取的角色/流程檔案；下一個 stage 開始時，只依對照表載入自己該讀的檔案對。
- 「不預先讀取」不等於「可卸載」：已讀入的檔案內容仍留在對話 context 中無法移除，因此更需嚴格遵守「到了才讀」，避免提早讀入尚未執行到的 stage 文件而增加固定 context 成本。

---

### Step 5-SINGLE — 單一角色執行

單一角色模式採 **confirm 模式**：每個決策點與使用者確認後才繼續。

各角色依對應的 pipeline stage 執行細節運行（見 Step 5-PIPELINE Stage 執行細節），包含 `/update-kb`、`/diagram`、`/code-architect` 等所有工具呼叫，並比照「Output 動作追蹤（強制）」以 task 逐項確認完成，不得用手動替代做法省略。角色與 stage 對應如下：

| 角色 | 對應 pipeline stage |
|------|-------------------|
| PM | 需求企劃 |
| SA | Spec 轉化（含 ADR 溝通） |
| CONSULTANT | Spec 轉化中的 ADR 溝通環節（獨立執行） |
| BACKEND | Spec-Driven 實作（含 ADR 驗證） |
| REVIEWER | Code Review |
| QA | QA |
| SRE | 依 `{{flow_sre}}` 執行，完成後詢問是否 `/update-kb` |

流程文件中若引用 `$master_index`，使用 `$master_indexes` 中對應 KB 的路徑；
若引用 `$review_guide`，使用 `{{review_guide}}`（即 `$KB_ROOT/knowledge/common_KBs/guideline/REVIEW_GUIDE.md`）。

**QA 角色的例外**：單一角色模式的定位是「只執行該階段」，因此 QA 判定功能有誤時**不自動跳去執行 BACKEND**；改為僅提示使用者「建議執行 BACKEND 角色修正後重跑 QA」，由使用者自行決定是否切換角色。Pipeline 模式（部分流程 / 完整流程）才會觸發 Step 5-PIPELINE 的自動回圈。

---

### Step 5-PIPELINE — Pipeline 流程執行

依序執行從 `$start_stage` 起的各 stage，每個 stage 完成後自動銜接下一個。

每個 stage 開始執行前，先依 Step 4「載入規則（Pipeline 模式）」讀取該 stage 對應的角色/流程文件對（含 CONSULTANT 跨 stage 例外），讀取完成後才告知使用者：

```
▶ 開始 {stage 名稱}（{auto / confirm} 模式）
```

#### auto 模式行為
- 不停下詢問，直接分析、決策、產出
- 決策點判準（取代單純「自行判斷最佳解」，各 stage 的 auto 決策皆依此執行）：
  - 候選方案在 KB（spec、ADR、guideline）中有明確依據 → 直接採用
  - KB 無依據，且各方案會影響後續架構 → 降級為 confirm，向使用者確認
  - KB 無依據，但屬局部實作細節 → 採最小改動方案，並在輸出中標註「KB 無依據，採最小改動」
- 完成後直接呼叫 `/update-kb` 記錄產出，通知使用者結果後繼續下一 stage

#### confirm 模式行為
- 在每個決策點暫停，呈現分析結果後等待使用者確認
- 使用者確認後才繼續執行
- 完成後詢問使用者是否執行 `/update-kb`（預設 Y）後再繼續下一 stage

---

#### Pipeline Stage 執行細節

各 stage 統一採用下列結構：**Input**（承接上一 stage 的產出）→ **工作內容**（分析 / 產出）→ **Decision**（auto/confirm 分支，行為定義見上方「auto 模式行為」「confirm 模式行為」）→ **Output**（`/update-kb` 記錄的產出物）→ **交給下一個 Stage**（傳遞給下一 stage 的內容）。

**例外**：QA 若判定「功能確實有誤」（非測試案例本身問題），不會前進到流程終點，而是回圈至 **Spec-Driven 實作（含 ADR 驗證）** 修正 → Code Review → QA，重複執行直到功能確定完成。連續 3 輪都未通過時，暫停迴圈並與使用者討論現況與解決方法，不再自動進入第 4 輪。單一角色模式（Step 2-SINGLE）下不觸發自動回圈，見 Step 5-SINGLE 說明。

#### Output 動作追蹤（強制，適用所有 stage）

每個 stage 的 **Output** 清單中，凡是「呼叫 /xxx」「執行 /xxx」這類指定呼叫特定工具或 skill 的項目，**進入該 stage 時就先用 `TaskCreate` 為清單中每一項各自建立一個獨立 task**，不要合併成一個大 task（例如 Spec-Driven 實作有 3 個 Output 動作，就建 3 個 task，不是 1 個「完成實作」task）。

- 每個 task 只有在**真的呼叫了對應工具**（透過 Skill 呼叫 `/code-architect`、`/diagram`、`/update-kb` 等）才可標記完成；手動寫文件、手動審查等「產出結果看起來差不多」的替代做法**不算完成**——這類手動替代會漏掉該工具本身的其他副作用（例如 `/diagram` 會同步維護 `diagram-participants.md`、`/update-kb` 會清理對應的 pending 項目與寫入 log），且容易在長對話中被忽略而沒有被發現。
- 該 stage 標記「✅ {stage 名稱} 完成」之前，用 `TaskList` 確認這些 task 全部是 completed；有缺漏就先補做，不得省略後直接進入下一個 stage 或標記流程完成。

---

**需求企劃**（PM）

- **Input**：Story 內容（Jira 單號、使用者貼上文字，或企劃書 / 原型頁面網址 — 依格式自動判斷；網址則透過 Playwright MCP 讀取，見 `common_KBs/tech-research/playwright-mcp-spec-to-kb-workflow.md`）
- **工作內容**：依 `{{flow_pm}}` 審查 AC 完整性、模糊描述與跨服務依賴，補充 Gherkin 範本
- **Decision**：
  - auto：自行判斷審查結果與 Gherkin 範本是否足夠，直接採用
  - confirm：呈現審查結果與補充的 Gherkin 範本，等待使用者確認
- **Output**：呼叫 `/update-kb` 建立 `specs/{TICKET}.md` 第一版
- **交給下一個 Stage**：`specs/{TICKET}.md` 第一版 → Spec 轉化

---

**Spec 轉化（含 ADR 溝通）**（SA + CONSULTANT）

- **Input**：`specs/{TICKET}.md` 第一版；若本 stage 為起點，改向使用者取得 Story 內容或現有 spec；若已有部分實作需要生成 impl，涉及服務的本機原始碼路徑（`$SOURCE_ROOTS`）
- **工作內容**：
  1. 依 `{{flow_sa}}` 執行 SA 過程，補足技術文件落差
  2. 依 `{{flow_consultant}}` 逐一識別決策點，查詢現有 ADR 與技術棧
- **Decision**：
  - auto：自行分析各決策點，每個確定後呼叫 `/update-kb` 記錄 ADR
  - confirm：每個決策點呈現選項，等待使用者確認後呼叫 `/update-kb` 記錄 ADR
- **Output**：更新完整 `specs/{TICKET}.md`；若此時已有部分實作，同步建立 `specs/impls/{TICKET}-impls.md`
- **交給下一個 Stage**：完整 `specs/{TICKET}.md` + 已記錄的 ADR → Spec-Driven 實作

---

**Spec-Driven 實作（含 ADR 驗證）**（BACKEND + CONSULTANT）

- **Input**：完整 spec、專案 ADR、系統規模考量與技術選型、涉及服務的本機原始碼路徑（`$SOURCE_ROOTS`）；**若為 QA 回圈修正**，改為 QA 回報的具體缺陷描述 + 對應的 AC/Gherkin 落差（而非重新從頭實作）
- **工作內容**：
  1. 依 `{{flow_backend}}` 提出實作方案（回圈修正時聚焦於缺陷本身，不重做整份 spec）
  2. 依 `{{flow_consultant}}` 驗證實作選型與 ADR 一致性
- **Decision**：
  - auto：自行選擇最佳方案直接實作
  - confirm：呈現建議方案，等待使用者選擇後實作
- **Output**：
  1. 產出完整程式碼，並執行 `/code-architect` 驗證架構合規，有違規項則修正後重新驗證
  2. 執行 `/diagram <主要入口類別> 的完整流程`，輸出至 `{$PROJECT_KB}/source-codex/services/{service}/flow-diagram-{TICKET}.md`
  3. 呼叫 `/update-kb` 記錄實作產出；若 `specs/impls/{TICKET}-impls.md` 尚未建立，一併建立
- **交給下一個 Stage**：程式碼異動 + 流程圖 → Code Review

---

**Code Review**（REVIEWER）

- **Input**：此次異動的所有程式碼（依 `$SOURCE_ROOTS` 定位服務本機路徑）
- **工作內容**：依 `{{flow_reviewer}}` 審查此次異動的所有程式碼
- **Decision**：
  - auto：直接套用所有修正
  - confirm：逐一呈現發現的問題，等待使用者確認後修正
- **Output**：
  1. 所有修正完成後執行 `/diagram sync`，更新 `{$PROJECT_KB}/source-codex/services/{service}/flow-diagram-{TICKET}.md`
  2. 呼叫 `/update-kb` 記錄 review 結果與修正紀錄
- **交給下一個 Stage**：修正後程式碼 + review 記錄 → QA

---

**QA**（QA）

- **Input**：spec AC、需求企劃（PM）與 Spec 轉化（SA）產生的 Gherkin 範本、Code Review 後的程式碼（依 `$SOURCE_ROOTS` 定位服務本機路徑）
- **工作內容**：
  1. 依 `{{flow_qa}}` 從 spec AC 生成測試策略與完整測試案例表
  2. 逐條核對測試結果是否對齊 PM / SA 階段產生的 AC 與 Gherkin 範本
  3. 執行三類驗測：unit test、integration test、本機啟動驗證（此為本機驗測，非部署——依 `source-codex/services/{service}/sop-service-startup-verification-internal.md` 執行；專案尚未建立此 SOP 時標注 `[待補充]`，不因此卡住流程）
- **Decision**：
  - auto：自動撰寫並執行單元與整合測試、依 SOP 執行本機啟動驗證，回報結果
  - confirm：呈現測試策略，等待使用者確認後撰寫與執行
  - **功能正確性判定**（測試執行後皆需判定，不分 auto/confirm）：區分落差屬於「測試案例設計問題」還是「功能本身確實有誤」；只有後者才計入回圈輪數。判定規則：
    - 實作行為與 spec AC 的預期輸出不符（引用 AC 編號比對）→ 功能有誤，回 BACKEND 修
    - 測試的預期值或前置條件與 AC 本身不一致 → 測試設計問題，修測試
    - AC 本身模糊無法判定 → 停下向使用者確認 AC 語意
    - 通過（三類驗測皆過，且對齊 AC/Gherkin）→ 交給下一個 Stage（pipeline 終點）
    - 功能確實有誤 → 回圈至 Spec-Driven 實作修正（見下方「例外」說明；連續 3 輪未通過則暫停與使用者討論）
- **Output**：呼叫 `/update-kb` 記錄測試案例表、測試範圍、三類驗測結果；若判定回圈，記錄本輪失敗原因、對應的 AC/Gherkin 落差與目前輪數
- **交給下一個 Stage**：
  - 通過 → （pipeline 終點）測試結果彙總 → 流程完成總結（見下方「Stage 間銜接格式」）
  - 不通過 → 回到 **Spec-Driven 實作（含 ADR 驗證）**，帶入本輪 QA 發現的具體缺陷描述，修正 → Code Review → QA 重複執行

---

#### Stage 間銜接格式

每個 stage 完成後輸出：

```
✅ {stage 名稱} 完成
   產出：{本 stage 主要產出摘要}

▶ 進入下一 stage：{下一 stage 名稱}（{auto / confirm} 模式）
```

QA 判定功能有誤、觸發回圈時，改輸出：

```
🔁 QA 發現功能缺陷，回圈至 Spec-Driven 實作修正（第 {N} 輪）
   問題摘要：{QA 發現的落差 / 缺陷描述}
   對應 AC/Gherkin：{落差對應的條目}

▶ 重新進入：Spec-Driven 實作（{auto / confirm} 模式）
```

連續 3 輪未通過時，改輸出並暫停等待使用者回應：

```
⏸ QA 連續 3 輪未通過，暫停迴圈

輪次摘要：
  第 1 輪：{問題摘要}
  第 2 輪：{問題摘要}
  第 3 輪：{問題摘要}

請問要如何處理？（例：調整 spec / 重新設計方案 / 手動介入 / 放寬 AC）
```

所有 stage 完成後輸出總結：

```
🎉 流程完成

完成的 stage：{清單}
QA 回圈次數：{N}（無回圈則寫「0」）
產出摘要：
  - specs/{TICKET}.md（完整規格）
  - ADRs：{建立 / 更新的 ADR 清單}
  - 實作程式碼（經 /code-architect 驗證架構合規）
  - 流程圖（/diagram + /diagram sync）
  - review-history/{...}（review 記錄）
  - 測試案例表 + 測試結果（unit / integration / 本機啟動驗證）
```

---

### Step 5-PREVIEW — PREVIEW 模式並行分析

> 此步驟只在選擇模式 **4. PREVIEW** 時執行。

#### Step M1 — 取得 Story 內容

問使用者：

```
請輸入要分析的 Jira 單號（例：PROJECT-123），或直接貼上 Story 內容：
```

- 若輸入單號格式 → 嘗試用 Jira MCP 拉取 issue 內容；失敗則請使用者貼文字
- 若直接貼文字 → 直接使用

等待使用者提供內容後，進入 M2。

#### Step M2 — 並行派工兩個 Subagent

**在同一個 response 中**同時發出兩個 `Agent` tool call（不等第一個完成才發第二個）。兩個 Agent 呼叫皆須明確指定：
- `subagent_type: general-purpose`
- `model: sonnet`（角色 stage 子代理屬「實作/分析明確規格」等級；調度原則見 `governance/model-dispatch.md` §1，未來調整只改該處）

以下是兩個 subagent 的 prompt 模板，發出前請將所有 `{...}` 替換為實際值：

---

**BACKEND Subagent prompt：**

```
你是 {$PROJECT_KBs 對應的專案名稱} 的 Backend Developer。

## 任務
分析以下 Story，執行 BACKEND 工作流程的 Step 2～Step 4。
不需等待使用者選擇，直接產出方案 A 與方案 B，並在最後標注推薦方案及原因。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 必讀文件（依序讀取）
1. 角色定義：{role_backend 完整路徑}
2. 工作流程：{flow_backend 完整路徑}
3. 通用 KB 主索引：{$KB_ROOT}/knowledge/common_KBs/MASTER_INDEX.md
   → 讀完後依 Story 主題判斷相關的 ADR 分類（01~08）與 tech-research 筆記，只讀取相關項目
4. 專案索引：{$master_indexes 中各 KB 的 MASTER_INDEX.md 完整路徑}

## Story 內容
{story_content}

## 回答規則
- 只能使用 KB 內文件，不可使用訓練資料或推測
- 若 KB 無相關資訊，說明「KB 無此資訊」，不得假設
- 回答結尾附引用來源區塊（格式：📚 參考來源）
```

---

**QA Subagent prompt：**

```
你是 {$PROJECT_KBs 對應的專案名稱} 的 QA Engineer。

## 任務
分析以下 Story，執行 QA 工作流程的 Step 2～Step 4。
不需等待使用者選擇，直接產出測試策略方案 A 與方案 B，並在最後標注推薦方案及原因。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 必讀文件（依序讀取）
1. 角色定義：{role_qa 完整路徑}
2. 工作流程：{flow_qa 完整路徑}
3. 通用 KB 主索引：{$KB_ROOT}/knowledge/common_KBs/MASTER_INDEX.md
   → 讀完後依 Story 主題判斷相關的 ADR 分類（01~08）與 tech-research 筆記，只讀取相關項目
4. 專案索引：{$master_indexes 中各 KB 的 MASTER_INDEX.md 完整路徑}

## Story 內容
{story_content}

## 回答規則
- 只能使用 KB 內文件，不可使用訓練資料或推測
- 若 KB 無相關資訊，說明「KB 無此資訊」，不得假設
- 回答結尾附引用來源區塊（格式：📚 參考來源）
```

---

#### Step M3 — 彙整輸出

等兩個 subagent 都回傳結果後，以以下格式合併輸出：

```
# Multi-Role 分析報告：{Story 標題或單號}

## BACKEND 分析（實作方案）
{BACKEND subagent 輸出}

---

## QA 分析（測試策略）
{QA subagent 輸出}

---

## 下一步
輸入 B  → 繼續 BACKEND Phase 2（產出完整程式碼）
輸入 Q  → 繼續 QA Phase 2（產出完整測試規劃）
輸入 BQ → 同時進行兩者（再次並行）
```

#### Step M4 — 接收使用者指示

- 輸入 `B` → 以 BACKEND 角色繼續，執行 `{{flow_backend}}` Step 5
- 輸入 `Q` → 以 QA 角色繼續，執行 `{{flow_qa}}` Step 5
- 輸入 `BQ` → 再次並行派兩個 subagent（`subagent_type`、`model` 設定比照 Step M2），各自執行對應 Phase 2，完成後彙整輸出

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
