# Changelog — my-work-agent

所有版本異動依時間倒序排列。

---

## [2.8] — 2026-07-03

### Added
- 新增「Output 動作追蹤（強制，適用所有 stage）」規則：每個 stage 的 Output 清單中，「呼叫 /xxx」類項目需在進入該 stage 時各自建立獨立 `TaskCreate` task，且只有真的呼叫對應工具才可標記完成；stage 標記完成前需用 `TaskList` 核對這些 task 全部 completed
- Step 5-SINGLE 補充引用「Output 動作追蹤（強制）」，避免單一角色模式下同樣漏執行

### Context
- 起因：實際執行 Spec-Driven 實作 stage 時，因為只建了一個「完成實作」大 task，做完程式碼與手動寫 KB 文件後就直接標記 stage 完成，漏掉了明確要求呼叫的 `/diagram`（且 `/update-kb` 也長期被手動寫檔案取代，未實際呼叫該 skill）。手動替代做法產出的文件表面上跟 skill 產出的格式差不多，導致這個疏漏在多輪對話中都沒被發現，直到使用者事後追問才補做

---

## [2.7] — 2026-07-03

### Added
- QA stage 新增功能正確性判定機制：QA 若判定「功能確實有誤」（區別於測試案例本身問題），回圈至 Spec-Driven 實作修正 → Code Review → QA，重複執行直到功能確定完成；連續 3 輪未通過時暫停迴圈，與使用者討論現況與解決方法
- QA 驗測項目新增「本機啟動驗證」（本機驗測，非部署），依 `source-codex/services/{service}/sop-service-startup-verification-internal.md` 執行（若專案尚未建立，標注待補充不卡流程）
- Stage 間銜接格式新增 `🔁 回圈` 與 `⏸ 暫停迴圈` 輸出格式；流程完成總結補上「QA 回圈次數」

### Changed
- QA stage 的 **Input** 補上 PM/SA 產生的 Gherkin 範本；**工作內容**新增 AC/Gherkin 對齊核對
- Spec-Driven 實作 stage 的 **Input** 補上「QA 回圈修正」來源（缺陷描述 + AC/Gherkin 落差，取代重新從頭實作）
- Step 5-SINGLE 補充說明：單一角色模式下 QA 判定功能有誤時不自動接續 BACKEND，僅提示使用者，維持「只執行該階段」的模式定位

---

## [2.6] — 2026-07-03

### Added
- Step 1.5 新增 `$SOURCE_ROOTS`：選定專案 KB 後讀取 `source-codex/cross/service-map.md` 的本機路徑欄位，記錄各服務對應的本機原始碼路徑；缺漏時延後到實際需要讀寫程式碼的 stage 才向使用者確認
- Step 3 動態路徑注入補上 `$SOURCE_ROOTS` 來源說明，與既有 `$master_indexes` 並列

### Changed
- Spec 轉化（SA）、Spec-Driven 實作（BACKEND）、Code Review（REVIEWER）、QA 四個 stage 的 **Input** 補上 `$SOURCE_ROOTS`：SA 在需生成 impl 時、其餘三者在讀寫實際程式碼時都需要先知道服務對應的本機路徑，不再只憑 spec 內容分析

---

## [2.5] — 2026-07-03

### Changed
- 需求企劃（PM）stage 的 **Input** 補上第三種來源：企劃書 / 原型頁面網址，依格式自動判斷後透過 Playwright MCP 讀取（對應 `role-flows/flow-pm.md` Step 1 同步補上的自動判斷規則與 SSO 登入失敗的退回處理）

---

## [2.4] — 2026-07-03

### Changed
- Step 5-PIPELINE「Pipeline Stage 執行細節」改寫為統一結構：每個 stage 明確拆分為 **Input → 工作內容 → Decision → Output → 交給下一個 Stage** 五個區塊，取代原本的流水號步驟敘述
- 修正 Spec 轉化 stage 工作內容中誤引用 `{{flow_pm}}` 的殘留錯字，改為正確的 `{{flow_sa}}`

---

## [2.3] — 2026-07-01

### Added
- **SA 角色**：新增獨立 SA（System Analyst）角色，對應 Spec 轉化 stage，取代原 PM 兼任 Spec 轉化的雙重職責

### Changed
- Step 2-SINGLE 角色選單：PM 現在只對應需求企劃；SA 獨立列出對應 Spec 轉化（含 ADR 溝通）；移除 PM 的 stage 追加確認問題
- Step 4 pipeline 文件表：Spec 轉化 角色文件從 `{{role_pm}}` 改為 `{{role_sa}}`，流程文件從 `{{flow_pm}}` 改為 `{{flow_sa}}`
- Step 5-SINGLE 角色對應表：PM → 需求企劃，SA → Spec 轉化（含 ADR 溝通）
- Step 5-PIPELINE Spec 轉化 stage 標注：PM + CONSULTANT → SA + CONSULTANT

---

## [2.2] — 2026-07-01

### Changed
- Step 2-SINGLE 角色選單：補充各角色對應的完整工具呼叫說明（`/update-kb`、`/diagram`、`/code-architect` 等）
- PM 角色新增 stage 確認步驟：選 PM 後追加問「需求企劃」或「Spec 轉化（SA）」，明確對應 pipeline stage
- Step 5-SINGLE：不再只說「按流程文件執行」，改為明確對應 Step 5-PIPELINE 各 stage 執行細節（含所有工具呼叫）；SRE 為例外，依 flow_sre 執行後詢問是否 `/update-kb`
- 單一角色模式統一為 confirm 模式

---

## [2.1] — 2026-07-01

### Changed
- MULTI 模式重新命名為 **PREVIEW**，更清楚傳達「開工前輕量雙視角探索」的用途

---

## [2.0] — 2026-07-01

### Added
- **執行模式選擇**（Step 2）：新增四種模式 — 單一角色 / 部分流程 / 完整流程 / MULTI
- **部分流程**（Step 2-PIPELINE）：使用者指定起始 stage（需求企劃 / Spec 轉化 / Spec-Driven 實作 / Code Review / QA），從該 stage 依序執行至 QA
- **完整流程**：從需求企劃執行至 QA 的全 pipeline
- **per-stage auto / confirm 設定**（Step P2）：每個 stage 可獨立選擇 auto（自動執行）或 confirm（每個決策點與使用者確認）
- **Step 5-PIPELINE**：Pipeline 執行引擎，含各 stage 詳細執行邏輯、ADR 溝通整合、`/update-kb` 觸發時機、`/diagram` 與 `/diagram sync` 執行點、stage 間銜接格式與完成總結輸出

### Changed
- Step 2 原「選擇角色」移至 Step 2-SINGLE，單一角色模式下才顯示
- MULTI 模式從 Step 2 角色選項移至獨立的執行模式選項（選項 4）
- Step 4 新增 pipeline 模式的文件預載表（各 stage 對應角色文件與流程文件）

---

## [1.2] — 2026-06-26

### Changed
- 通用 KB（ADRs / tech-research）改為 index-first 載入：subagent 先讀 `common_KBs/MASTER_INDEX.md`，依 Story 主題僅讀取相關 ADR 分類與 tech-research 筆記，不再全量載入
- `common_KBs/guideline/REVIEW_GUIDE.md` 改為 REVIEWER 必讀，其餘角色依需要載入
- Step 1.5 說明：移除「自動載入」措辭，改為「依 Story 主題按需載入」
- Step 3 動態路徑注入：以 `common_KBs/MASTER_INDEX.md` 取代三個個別路徑
- BACKEND / QA Subagent prompts 必讀文件：以「通用 KB 主索引 + 按需讀取」取代全量載入的三個 common_KBs 項目

## [1.1] — 2026-06-26

### Changed
- 共用規範路徑從 `knowledge/guideline/` 移至 `knowledge/common_KBs/guideline/`
- 跨專案 ADR 路徑從 `knowledge/ADRs/` 移至 `knowledge/common_KBs/ADRs/`
- Step 1.5 自動載入清單：新增 `knowledge/common_KBs/tech-research/`（技術探討與研究筆記），說明文字同步更新
- Step 3 動態路徑注入：新增技術研究路徑變數
- BACKEND / QA Subagent prompts：必讀文件新增第 5 項「技術研究」，專案索引順延為第 6 項
- 回答規則知識庫限定：新增 `common_KBs/tech-research/` 為允許來源

---

## [1.0] — 初版

### Added
- 多角色 AI Agent：BACKEND / QA / SRE / PM / CONSULTANT / REVIEWER
- MULTI 模式：同一個 response 並行派發 BACKEND + QA 兩個 Subagent 分析同一 Story，完成後彙整輸出
- Knowledge Hub 整合：自動讀取 `$KB_ROOT`、共用規範、跨專案 ADR、各選定專案 MASTER_INDEX
- 多專案 KB 支援：掃描所有 `_KBs` 子資料夾，供使用者選擇載入範圍
- Jira MCP 整合：輸入 ticket 單號自動拉取 Story 內容，失敗則改請使用者貼文字
- 嚴格知識庫限定回答規則：禁止使用訓練資料或 KB 外知識，找不到資訊時明確告知
- 每則回答附引用來源區塊（📚 參考來源），多來源時逐一列出
