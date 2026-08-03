# Changelog — sdlc-agent

所有版本異動依時間倒序排列。

---

## [2.27] — 2026-08-03

### Changed
- `{{flow_reviewer}}` Step 5 Standards Subagent prompt：改為主線在 Step 3 從 `{{master_index}}` 萃取「系統規格基準」章節純文字，直接貼進 prompt；Standards Subagent 不再拿到 `{{master_index}}` 檔案路徑自行 Read，並在「限制」明文禁止其自行開啟任何 MASTER_INDEX.md
- Step 3 ticket 模式新增第 5 點：主線萃取「系統規格基準」純文字供 Step 5 使用

### Context
- 起因：對雙軸平行審查機制（`[2.25]`）第一次真的做 smoke test（此前只有 read-back 靜態核對，從未實際跑過）——用合成 spec + 一段刻意寫壞的 Java 檔，真的平行派發 Spec-Compliance / Standards 兩個 subagent。多數行為符合設計，但意外發現：Standards Subagent 的 prompt 原本指示「讀取 `{{master_index}}` 的系統規格基準章節」，實際執行時它用 Read 工具讀了整份 MASTER_INDEX.md，連帶看到微服務清單、跨服務通訊拓撲等業務脈絡；子代理誠實回報有看到但「自律」沒有拿來做判斷。這只是靠子代理自覺、不是結構性隔離，不可靠——遂改為主線先萃取單一章節純文字再交給 subagent，並明文禁止其自行讀取整份檔案
- 這次 smoke test 同時驗證了設計意圖成立：Standards Subagent 明確回報「N+1 本身違規不依賴系統規格基準數字，只有嚴重度分級依賴」，且能用 master_index 的具體數字（而非業務目的）判斷嚴重度為 High；Spec-Compliance Subagent 則在未讀 review_guide 的情況下獨立抓到一個真實的目的偏離，交叉驗證雙軸機制的價值成立

---

## [2.26] — 2026-08-03

### Changed
- `references/path-resolution.md` Step 3 移除「以 `$KB_ROOT` 取代檔案中的 `kb` key 值」這句——`setting/paths.yml` 已不再含 `kb` root key（見下方 Context），該句已無對象；`@kb/` 前綴替換規則不受影響，維持原樣
- SKILL.md Step 1「路徑不符時的更新動作」改為只同步 memory 的 `reference_knowledge_base.local.md`，移除同步 `setting/paths.yml` 的 `kb` 行（同一原因，該行已不存在）

### Context
- 起因：`setting/paths.yml` 過去由 `setup-host.ps1`/`.sh` 把各主機真實絕對路徑寫回 git 追蹤的 `kb:` 欄位，曾造成主機路徑洩漏進 git 歷史；改為統一從 gitignored 的 `memory/reference_knowledge_base.local.md` 取得 `$KB_ROOT`，`paths.yml` 從此只保留 `@kb/` 相對路徑的 `regulations` 對照表。sdlc-agent 本身的 `$KB_ROOT` 解析（Step 1 讀 memory）本來就不受影響，本次只是清掉一句因此變得多餘、且現在會誤導的敘述

---

## [2.25] — 2026-08-03

### Changed
- `{{flow_reviewer}}` Step 5 ticket 模式改為雙軸平行審查：「目的驗證」（對照 spec 業務意圖敘事）與「品質/效能/設計模式」（對照 review_guide + 專案級系統規格基準）拆成兩個互不可見對方輸入的 subagent（`general-purpose` / `model: sonnet`，比照 `references/preview-mode.md` 並行派工慣例）；隔離的是「需求描述/AC/功能目標」等業務意圖敘事（避免對原則違規從寬認定），不是系統規模事實——後者的來源是 `{{master_index}}` 的「系統規格基準」章節（專案層級、與 ticket 無關，依異動檔案所屬 service 這個結構性事實對照，不需業務目的），已在 Step 1 載入，不需另向 spec 索取；範圍模式無 spec 可對照，維持單一 pass 不變
- `demo_KBs/MASTER_INDEX.md` 新增「系統規格基準」章節骨架（依 service 列 QPS/TPS、資料量現狀、系統期望目標），落實 `{{review_guide}}` 3-1 節原本就要求、但從未真正建立的章節；尚未填入實際數字的專案，效能瓶頸判斷退回純規則型項目並標注「規模未校準」
- `references/pipeline-stages.md` Code Review stage 工作內容一行同步補充此機制說明

### Context
- 起因：比較外部 skill 庫 mattpocock/skills 的 `code-review` skill（standard 與 spec-compliance 拆平行 subagent 審查，防止交叉污染判斷）後，發現本專案 REVIEWER 單一 pass 內先萃取目的再審品質/效能，理論上有同樣的污染風險；直接沿用本專案已驗證過的 PREVIEW 模式並行派工機制，成本最低
- 初版把 Standards Subagent 隔離範圍設成「完全不得讀 spec/impl」過寬——使用者指出效能瓶頸/資料原子性的嚴重度判斷需要系統規模事實，完全隔離會讓判斷失去依據；第一次修正改為主線從 spec 萃取非功能需求段落傳給 Standards Subagent
- 使用者再追問：不知道業務目的，怎麼知道萃取出的哪段規模事實適用於這段程式碼？這揭露第一次修正仍隱含「需要懂業務目的才能挑出對應規模事實」的循環依賴。回頭查證 `{{review_guide}}` 3-1 節，發現原文已明定門檻值應來自「專案 KB 的 MASTER_INDEX → 系統規格基準」——專案層級、依 service 分列、與 ticket 無關的標準值，對應到程式碼只需要「檔案屬於哪個 service」這個結構性事實，不需業務目的。改用此機制後徹底解開循環依賴；同時發現這個章節在所有專案 KB（含 demo）都從未真正建立過，一併補上骨架

---

## [2.24] — 2026-08-03

### Added
- Step 2 執行模式新增選項 5「PM+SA」：PM → SA（含 CONSULTANT ADR 溝通）依序執行至 Spec 轉化即停止，不進入 Spec-Driven 實作，用於快速需求轉化（確認範疇 / AC / 功能需求定義 / 邊界情境 / Gherkin / 技術功能實作規格）
- Pipeline 機制新增 `$end_stage` 變數（預設 QA，模式 5 固定為 Spec 轉化）；`Step 2-PIPELINE`／`Step 5-PIPELINE`／`references/execution-mode-setup.md`／`references/pipeline-forced-rules.md` 一併支援非 QA 終點的 stage 篩選、auto/confirm 設定與精簡版完成總結
- `references/step0-param-passthrough.md` 執行模式關鍵字補上 `pmsa`/`需求轉化`

### Context
- 起因：原先設計為 PM+SA 各自對同一份原始文件並行分析（比照 PREVIEW 模式），與使用者討論後改為順序執行——SA 的技術規格需建立在 PM 已審過、消除模糊的 AC 上才可靠，且需要 CONSULTANT 銜接 ADR 決策；直接重用既有 Pipeline stage 機制（新增 `$end_stage`）比另寫一份會和 `flow-pm.md` / `flow-sa.md` 內容重複、日後容易兩邊撕裂的並行 subagent prompt 更省維護成本

---

## [2.23] — 2026-07-29

### Removed
- 觸發關鍵字移除 `my-work-agent（舊名）` 別名，僅保留 `sdlc-agent`（使用者指示不需向後相容）

---

## [2.22] — 2026-07-29

### Added
- 角色直通短語：description 觸發關鍵字加入各角色的自然語言短語（分析 story／分析 jira→PM、寫 spec／spec 轉化→SA、KB 諮詢／查知識庫→CONSULTANT、實作 ticket／spec-driven 實作→BACKEND、code review／審查程式碼→REVIEWER、補測試／驗測／測試策略→QA、維運檢查／部署驗證→SRE）
- Step 0 參數對照表新增「角色觸發短語」列：命中即模式 1 並選定對應角色，跳過 Step 2 與角色選單；與明確角色名/模式參數並存時以後者優先
- `references/step0-param-passthrough.md` 補兩個短語直通範例

### Context
- 起因：原觸發關鍵字只能叫起 skill，角色仍要走選單；改為短語即帶角色，等於自然語言版的參數直通

---

## [2.21] — 2026-07-29

### Changed
- Skill 改名：`my-work-agent` → `sdlc-agent`（資料夾、SKILL.md `name`、主標題、`~/.claude/skills/` symlink 一併更新）
- 觸發關鍵字保留 `my-work-agent（舊名）` 作為別名，舊叫法仍可路由
- 同步更新所有引用處：CLAUDE.md、governance/（diagnosis、smoke-test-checklist）、README、setting/check-project-kb.ps1|.sh、role-flows/flow-qa.md、diagram skill、memory 檔
- 歷史 CHANGELOG 條目維持原文（記錄當時名稱），僅本檔標題改名

### Context
- 起因：`my-work-agent` 名稱不描述功能；skill 實際涵蓋 PM → SA → 實作 → Review → QA 全流程，改以 SDLC 命名

## [2.20] — 2026-07-28

### Changed
- 檔名由 `skill.md` 統一改為 `SKILL.md`（檔名大小寫統一，已由主線作業完成，本次僅記錄）
- `SKILL.md` 拆分為骨幹 + `references/`（progressive disclosure）：主檔只留 pipeline stage 骨幹（名稱、編號、1-3 行摘要）、觸發條件與使用方式摘要、auto/confirm 設定機制、回答規則等硬性約束；各 Step 詳細規則、選單文字、輸出格式範例、邊角案例移至同目錄 `references/` 下的主題檔（逐字搬移、內容不改寫）：
  - `references/step0-param-passthrough.md` — 啟動參數解析對照表與範例
  - `references/kb-selection.md` — 專案知識庫選單與載入細節
  - `references/execution-mode-setup.md` — 單一角色選單、Pipeline 起點與 auto/confirm 逐 stage 設定模板
  - `references/path-resolution.md` — 路徑解析與動態注入規則
  - `references/role-flow-loading.md` — 角色/流程文件載入對照表與懶載入規則
  - `references/single-role-execution.md` — 單一角色模式執行細節
  - `references/pipeline-forced-rules.md` — Output 動作追蹤、測試執行分層、/update-kb 批次化、Stage 間銜接格式
  - `references/pipeline-stages.md` — 五個 pipeline stage 的 Input／工作內容／Decision／Output／交給下一個 Stage 完整規則
  - `references/preview-mode.md` — PREVIEW 模式並行分析步驟與 subagent prompt 模板

### Context
- 起因：對齊 context engineering 原則——skill 觸發時 SKILL.md 會整份載入 context，長檔（原約 580 行）造成固定成本浪費；拆分後主檔約 150 行，細節檔僅在對應 Step 實際執行時才被讀取
- 修改前已備份原檔至 `governance/backup/`；pipeline stage 名稱與編號維持不變，僅搬移細節內容，不影響既有呼叫方式

---

## [2.19] — 2026-07-27

### Added
- Spec-Driven 實作 Output 加入「明顯壞味道快篩」自捕步驟：`/code-architect` 前先掃 flag argument / 魔術數字 / 多步驟原子性 / 分層職責 / 命名重複 / 查無資料，並明確標註「廉價自捕、不取代 Code Review stage 的完整 sweep」。清單本體寫在 `role-flows/flow-backend.md` Step 5（單一真相源），skill.md 只引用＋列項名

### Context
- 起因：實作階段自審不夠徹底、把顯而易見的壞味道（flag argument、int 狀態碼、Redis 非原子多寫）留給後續才被抓到。折衷設計：BACKEND 只做廉價高 ROI 快篩（地板），深掃仍留給 REVIEWER stage（fresh eyes + 完整 REVIEW_GUIDE sweep），避免掏空 review 或重複耗 token
- **同步規則**：`flow-backend.md`（清單本體）與 skill.md 實作 Output（引用）為對應內容，其一異動時另一自動同步，不需使用者提醒

---

## [2.18] — 2026-07-27

### Added
- SA stage 新增「回寫 Jira 描述」步驟（詳細行為定義於 `role-flows/flow-sa.md` Step 8，skill.md 於 Spec 轉化 Output 加註指向）：
  - 僅當有指定 Jira 單號、於 KB 入庫後執行；無單號略過
  - 只回寫「功能目標 / 商業規則 / 驗收條件與邊界情境 / Gherkin」四區段，RD 內部細節（資料流、影響範圍等）不回寫
  - **confirm 模式先問使用者要不要回寫、不直接做**；auto 模式可直接回寫
  - **強制去識別化**：移除只有 KB 語境看得懂的專有名詞（ADR 編號與引用、KB 內部檔案路徑、KB 專屬流程術語），保留 LS 單號、程式碼類別/方法名、業務規則、AC、Gherkin
- Spec 轉化 stage 的 **Output 由單一長條 bullet 拆為編號式多項**（1 更新 spec／2 建 impls／3 回寫 Jira），與 Spec-Driven 實作 stage 的編號 Output 一致——每項各自可被「Output 動作追蹤」建 task，避免多步驟擠一條而漏做

### Context
- 起因：使用者指出 Jira 是全團隊/跨團隊閱讀媒介，SA 產出的 spec 四區段回寫 Jira 有助跨團隊溝通，但 KB 專有名詞（如 ADR-????）只有維護 KB 的人看得懂，須先去識別化；且回寫屬外部動作，confirm 模式應先徵詢

---

## [2.17] — 2026-07-22

### Changed
- 「測試執行分層」改為**全套 test suite 只在單一角色模式的 QA 執行**，pipeline 模式全程不跑全套：
  - QA 第 1 輪（pipeline）：unit / integration 限縮為「本 ticket 累積異動的影響範圍」（期間新增/修改的全部測試類別 + 直接呼叫這些異動程式碼的既有測試），本機啟動驗證仍完整執行
  - QA 回圈第 2 輪起（pipeline）：判定通過即完成，**移除原本的「補跑一次最終全套」**
  - 單一角色模式的 QA：一律完整三類驗測（全套 unit + integration + 本機啟動驗證），與本次 diff 範圍無關
- Step 5-SINGLE「QA 角色的例外」補述單一角色 QA 為全套唯一執行點
- 「🎉 流程完成」總結範本加入 ⚠️ 提示：本次未執行全套回歸，如需完整驗證請單獨執行 `/my-work-agent QA`
- 修正 skill.md frontmatter 版號漂移（原停留在 `2.13`，CHANGELOG 已至 2.16），本次一併校正為 `2.17`

### Context
- 起因：使用者盤點「哪些階段與 diff 無關也跑全套」後，決定將全套回歸的成本與時機交還使用者自行控制——pipeline 追求端到端速度，全套回歸改為明確的手動動作，避免全套 suite 拖慢流程中段的 QA 第 1 輪
- 取捨：pipeline 完成不再自帶全套回歸保證，跨模組迴歸風險改由「圈不出影響範圍時退回全套」的既有例外 + 總結提示承接

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
