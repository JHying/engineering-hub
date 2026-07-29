# Pipeline Stage 執行細節（Input → 工作內容 → Decision → Output → 交給下一個 Stage，明細）

**需求企劃**（PM）

- **Input**：Story 內容（Jira 單號、使用者貼上文字，或企劃書 / 原型頁面網址 — 依格式自動判斷；網址則透過 Playwright MCP 讀取，見 `common_KBs/tech-research/playwright-mcp-spec-to-kb-workflow.md`）
- **工作內容**：依 `{{flow_pm}}` 審查 AC 完整性、模糊描述與跨服務依賴，補充 Gherkin 範本
- **Decision**：
  - auto：自行判斷審查結果與 Gherkin 範本是否足夠，直接採用
  - confirm：呈現審查結果與補充的 Gherkin 範本，等待使用者確認
- **Output**：建立 `specs/{TICKET}.md` 第一版——依「/update-kb 批次化」規則記錄（pipeline 模式寫 pending 草稿；單一角色模式即時呼叫 `/update-kb`）
- **交給下一個 Stage**：`specs/{TICKET}.md` 第一版 → Spec 轉化

---

**Spec 轉化（含 ADR 溝通）**（SA + CONSULTANT）

- **Input**：`specs/{TICKET}.md` 第一版；若本 stage 為起點，改向使用者取得 Story 內容或現有 spec；若已有部分實作需要生成 impl，涉及服務的本機原始碼路徑（`$SOURCE_ROOTS`）
- **工作內容**：
  1. 依 `{{flow_sa}}` 執行 SA 過程，補足技術文件落差
  2. 依 `{{flow_consultant}}` 逐一識別決策點，查詢現有 ADR 與技術棧
- **Decision**：
  - auto：自行分析各決策點，每個確定後記錄 ADR（依「/update-kb 批次化」規則）
  - confirm：每個決策點呈現選項，等待使用者確認後記錄 ADR（依「/update-kb 批次化」規則）
- **Output**：
  1. 更新完整 `specs/{TICKET}.md`（依「/update-kb 批次化」規則記錄）
  2. 若此時已有部分實作，同步建立 `specs/impls/{TICKET}-impls.md`
  3. **若有指定 Jira 單號**：於 KB 入庫後依 `{{flow_sa}}` Step 8 回寫 Jira 描述——僅「功能目標 / 商業規則 / 驗收條件與邊界情境 / Gherkin」四區段、強制去識別化 KB 專有名詞（ADR 編號等）；**confirm 模式先問、不直接做**，auto 模式可直接回寫
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
  1. 產出完整程式碼；**執行 `/code-architect` 前先做 `{{flow_backend}}` Step 5「明顯壞味道快篩」自捕**（flag argument / 魔術數字 / 多步驟原子性 / 分層職責 / 命名重複 / 查無資料——廉價自捕，**不取代 Code Review stage 的完整 sweep**），再執行 `/code-architect` 驗證架構合規，有違規項則修正後重新驗證；程式碼驗證依「測試執行分層」規則**只跑受異動影響的測試**
  2. 執行 `/diagram <主要入口類別> 的完整流程`，輸出至 `{$PROJECT_KB}/source-codex/services/{service}/flow-diagram-{TICKET}.md`
  3. 記錄實作產出（依「/update-kb 批次化」規則）；若 `specs/impls/{TICKET}-impls.md` 尚未建立，一併建立
- **交給下一個 Stage**：程式碼異動 + 流程圖 → Code Review

---

**Code Review**（REVIEWER）

- **Input**：此次異動的所有程式碼（依 `$SOURCE_ROOTS` 定位服務本機路徑）；**若為 QA 回圈修正輪**，縮小為本輪修正的 diff——首輪已全量審過，回圈輪只審修正範圍及其直接呼叫點
- **工作內容**：依 `{{flow_reviewer}}` 審查 Input 範圍內的程式碼
- **Decision**：
  - auto：直接套用所有修正
  - confirm：逐一呈現發現的問題，等待使用者確認後修正
- **Output**：
  1. 修正後的驗證依「測試執行分層」規則**只跑受修正影響的測試**
  2. 所有修正完成後執行 `/diagram sync`，更新 `{$PROJECT_KB}/source-codex/services/{service}/flow-diagram-{TICKET}.md`；**QA 回圈修正輪跳過此步**，於 QA 最終通過後、流程完成總結前補執行一次（涵蓋所有回圈輪的累積異動）
  3. 記錄 review 結果與修正紀錄（依「/update-kb 批次化」規則）
- **交給下一個 Stage**：修正後程式碼 + review 記錄 → QA

---

**QA**（QA）

- **Input**：spec AC、需求企劃（PM）與 Spec 轉化（SA）產生的 Gherkin 範本、Code Review 後的程式碼（依 `$SOURCE_ROOTS` 定位服務本機路徑）
- **工作內容**：
  1. 依 `{{flow_qa}}` 從 spec AC 生成測試策略與完整測試案例表
  2. 逐條核對測試結果是否對齊 PM / SA 階段產生的 AC 與 Gherkin 範本
  3. 執行三類驗測：unit test、integration test、本機啟動驗證（此為本機驗測，非部署——依 `source-codex/services/{service}/sop-service-startup-verification-internal.md` 執行；專案尚未建立此 SOP 時標注 `[待補充]`，不因此卡住流程）。測試範圍依「測試執行分層」規則：pipeline 模式第 1 輪限縮為本 ticket 累積異動的影響範圍（本機啟動驗證照常完整執行），回圈第 2 輪起只跑失敗案例 + 受修正影響者且不補跑全套；單一角色模式的 QA 才跑全套
- **Decision**：
  - auto：自動撰寫並執行單元與整合測試、依 SOP 執行本機啟動驗證，回報結果
  - confirm：呈現測試策略，等待使用者確認後撰寫與執行
  - **功能正確性判定**（測試執行後皆需判定，不分 auto/confirm）：區分落差屬於「測試案例設計問題」還是「功能本身確實有誤」；只有後者才計入回圈輪數。判定規則：
    - 實作行為與 spec AC 的預期輸出不符（引用 AC 編號比對）→ 功能有誤，回 BACKEND 修
    - 測試的預期值或前置條件與 AC 本身不一致 → 測試設計問題，修測試
    - AC 本身模糊無法判定 → 停下向使用者確認 AC 語意
    - 通過（三類驗測皆過，且對齊 AC/Gherkin）→ 交給下一個 Stage（pipeline 終點）
    - 功能確實有誤 → 回圈至 Spec-Driven 實作修正（見下方「例外」說明；連續 3 輪未通過則暫停與使用者討論）
- **Output**：記錄測試案例表、測試範圍、三類驗測結果（依「/update-kb 批次化」規則）；若判定回圈，記錄本輪失敗原因、對應的 AC/Gherkin 落差與目前輪數
- **交給下一個 Stage**：
  - 通過 → （pipeline 終點）測試結果彙總 → 流程完成總結（見下方「Stage 間銜接格式」）
  - 不通過 → 回到 **Spec-Driven 實作（含 ADR 驗證）**，帶入本輪 QA 發現的具體缺陷描述，修正 → Code Review → QA 重複執行

