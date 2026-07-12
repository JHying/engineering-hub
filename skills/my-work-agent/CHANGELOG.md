# Changelog — my-work-agent

所有版本異動依時間倒序排列。

---

## [2.16] — 2026-07-12

### Added
- Step 0「啟動參數直通」：呼叫時可帶 KB 編號/名稱、模式、角色、起點 stage、A/C 字串（如 `CAAAA`）跳過對應問答，`/my-work-agent 1 full CAAAA` 零問答直接開跑
- Step P2 顯示建議預設 `C A A A A`（spec 成形時人工把關一次、其後全自動；需求判斷錯誤是後面階段補不回來的錯），空輸入直接採用；起點非需求企劃時建議首 stage 為 C
- auto 模式「降級決策點批次呈現」：同 stage 內降級為 confirm 的決策點收集後以單次 AskUserQuestion 一次呈現（最多 4 題），相依決策點例外仍即時詢問

### Changed
- QA 回圈修正輪瘦身：Code Review 只審本輪修正 diff 及直接呼叫點（首輪已全量審過）；`/diagram sync` 回圈輪跳過、QA 最終通過後補執行一次；本機啟動驗證回圈輪跳過（修正涉及啟動設定除外）、併入最終全套終驗
- 五個 stage Output 的「呼叫 /update-kb」措辭統一改為「依『/update-kb 批次化』規則記錄」，消除與批次化規則的字面矛盾（read-back 驗證發現，避免逐字執行時仍每 stage spawn 子代理）

### Context
- 起因：使用者詢問是否建議預設 AAAAA。分析結論為否——auto 已有 KB 無依據時的降級安全閥，但 PM 階段的 AC 誤判會讓整條 pipeline「正確地做出錯的東西」（QA 依錯誤 spec 全綠），故唯一人工閘門放在 spec 成形點成本最低、槓桿最大。另盤點出回圈輪的全量 review、每輪 diagram sync 與啟動驗證為剩餘浪費點

---

## [2.15] — 2026-07-12

### Added
- Step 5-PIPELINE 新增「/update-kb 批次化」強制規則（僅 pipeline 模式）：各 stage 的 `/update-kb` 項目改為將產出草稿直寫 `{$PROJECT_KB}/pending/{TICKET}-{stage 代號}.md`（主線輕量直寫、不派子代理）；pipeline 終點一次性觸發 `/update-kb` 正式入庫並清理 pending
- 中斷保護網：pipeline 中途中斷時，pending/ 草稿由 update-kb 排程模式（Mode A）原生掃描撿回入庫
- Output 動作追蹤對應調整：stage 的 /update-kb task 以「pending 草稿已寫入」為完成標準，終點另建「正式入庫」task

### Changed
- auto 模式：stage 完成後由「直接呼叫 /update-kb」改為「草稿直寫 pending/」
- confirm 模式：stage 完成後的 /update-kb 詢問移至 pipeline 終點只問一次（預設 Y），草稿寫入免詢問
- `/diagram`、`/code-architect` 不在批次範圍，維持即時執行；單一角色模式不適用批次化，維持即時 /update-kb（跨 session 依賴磁碟上的正式 KB 檔案）

### Context
- 起因：v2.14 後 auto 模式剩餘的最大 token 消耗為每 stage 各 spawn 一次 /update-kb 子代理（單次約 40–100k tokens，五個 stage 五次）。經確認 stage 間交接依賴對話 context 與磁碟程式碼，不依賴讀回 KB 檔案，/update-kb 屬記帳而非運輸，批次化不影響 pipeline 依賴；中斷耐久性以 pending/ 草稿承接

---

## [2.14] — 2026-07-12

### Added
- Step 5-PIPELINE 新增「測試執行分層」強制規則：全套 test suite 在整條 pipeline 只完整執行一次（QA 第 1 輪）——Spec-Driven 實作與 Code Review 的驗證只跑受本次異動/修正影響的測試（`-Dtest` / `--tests` 指定範圍）；QA 回圈第 2 輪起只重跑失敗案例 + 受修正影響者，判定通過後補跑最終全套確認無迴歸；無法圈定影響範圍時退回全套並標註原因
- Step 4 載入規則新增「共用參考文件不重讀」：master_index、REVIEW_GUIDE、服務文檔、spec/impls 等非角色/流程類文件，pipeline 中第一次讀取後沿用 context 內容，後續 stage 不重讀；檔案中途被寫入/變更才重讀

### Changed
- Spec-Driven 實作、Code Review、QA 三個 stage 的 Output/工作內容同步引用測試分層規則
- 單一角色模式比照對應 stage 的測試範圍（QA 單獨執行視同第 1 輪跑全套）

### Context
- 起因：使用者反映 auto 模式非常耗 token、且自 Spec-Driven 實作起幾乎每個階段都重跑全部 unit test 很耗時。追查確認全套 suite 在一條 pipeline 中會執行 3 次以上（實作驗證、review 修正驗證、QA 三類驗測，回圈再乘輪數），且 master_index / REVIEW_GUIDE / 服務文檔在 BACKEND、REVIEWER、QA 各 stage 的流程文件中被重複要求讀取

---

## [2.13] — 2026-07-06

### Changed
- Step 1（Knowledge Hub 根路徑初始化）改為靜默執行：原本開口第一句話就強制問使用者「確認 Y / 輸入新路徑」才能繼續，每次啟動都中斷 session；改為直接讀取 memory 的 `reference_knowledge_base.md` 取得 `$KB_ROOT` 並沿用，僅當實際工作目錄與記錄不符時才提醒使用者確認是否更新，比照 `update-kb` skill Step 0 與專案 `CLAUDE.md` 的 session 初始化慣例（一致就不詢問）

### Context
- 起因：使用者反映每次啟動 my-work-agent 都被 Step 1 的路徑確認問題中斷，但路徑實際上幾乎不變動，這道問題形同每次都要多回答一次已知答案

---

## [2.12] — 2026-07-05

### Changed
- Step 4 pipeline 模式的文件載入方式改為懶載入（lazy load）：原本啟動時「預載從起始 stage 起所有涉及角色的文件對」，改成 Step 4 只記住 stage 對照表，實際讀檔延後到 Step 5-PIPELINE 各 stage 開始執行前才進行，且明文禁止預先讀取尚未執行之 stage 的檔案
- 新增 CONSULTANT 跨 stage 載入例外：ADR 溝通貫穿 Spec 轉化至 Spec-Driven 實作，進入 Spec 轉化 stage 時隨 SA 一併載入 CONSULTANT 檔案對，保留至 Spec-Driven 實作 stage 結束，中間不重讀、也不在 Spec-Driven 實作 stage 重複載入
- Step 5-PIPELINE 各 stage 開始前的提示語同步補上「先讀取對應檔案對，讀取完成後才輸出 stage 開始訊息」，避免與新載入規則矛盾
- 單一角色模式與 PREVIEW 模式的檔案載入本來就只讀取所選角色 / 對應 subagent 需要的一對檔案，未發現過度預載，僅微調單一角色模式表格說明文字使措辭一致，未變更行為

### Context
- 起因：pipeline 模式啟動時一次讀入起始 stage 之後所有 stage 的角色與流程文件，即使流程尚未執行到後面的 stage，也已把這些檔案內容佔用在對話 context 中，增加不必要的固定成本；改為到了對應 stage 才讀取可降低此開銷

---

## [2.11] — 2026-07-05

### Added
- frontmatter 補上 `version` 欄位

---

## [2.10] — 2026-07-05

### Changed
- Step P2 各 stage auto/confirm 選單：原本把顯示條件（`{若 $start_stage ≤ N}`）直接寫在要印給使用者看的模板區塊內，容易被弱模型照字面原樣印出；改為模板外先以明確規則逐行判斷要列出哪些 stage，模板本身只留純文字與佔位符，不含任何條件標記
- auto 模式行為補上客觀決策判準，取代單純「Agent 依 KB 內容自行判斷最佳解」：KB 有明確依據直接採用、KB 無依據且影響架構則降級 confirm、KB 無依據但屬局部細節則採最小改動並標註
- QA 回圈的功能正確性判定補上可執行判定規則：實作與 AC 預期輸出不符（引用 AC 編號比對）算功能有誤、測試預期值或前置條件與 AC 不一致算測試設計問題、AC 本身模糊則停下向使用者確認語意
- PREVIEW 模式的兩處 Agent 派發（Step M2 初次並行派工、Step M4 的 BQ 再次並行派工）補上明確的 `subagent_type: general-purpose` 與 `model: sonnet`，並註記調度原則見 `governance/model-dispatch.md` §1，避免留空繼承成本較高的模型

---

## [2.9] — 2026-07-05

### Changed
- 修正 Spec-Driven 實作 stage 對 `/code-architect` 的描述：原本寫成「執行 `/code-architect` 產出完整程式碼」，容易被誤讀為由該工具產出程式碼；改為「產出完整程式碼，並執行 `/code-architect` 驗證架構合規，有違規項則修正後重新驗證」，明確該工具的定位是審查而非產碼
- 流程完成總結的產出摘要項目同步修正措辭，避免同樣的誤解

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
