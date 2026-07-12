# Changelog — update-kb

所有版本異動依時間倒序排列。

---

## [1.14] — 2026-07-08

### Added
- **新增「表格欄位可讀性規則」章節**（緊接內容限制規則之後，去識別化檢查清單之前）：單一表格儲存格若塞入 3 個以上不同面向的獨立事實（規模數字 + 時間限制 + 架構原因 + 待補充項等），視為過度密集，須拆成「主表格精簡摘要列 + 下方結構化子表格（項目/數值/說明）」，子表格每列只放一件事；棄用數值用刪除線標注並簡述原因與日期，不得整段塞回備註欄

### Context
- 起因：某專案 KB 的 `MASTER_INDEX.md` 系統規格基準表中某一列，因連續三輪技術分析修正（時間預算拆解、並行架構發現、舊估算口徑棄用）逐次疊加內容，最終單一儲存格塞入約 8 件不相關的事實（規模數字、時間限制、架構原因、待補充項、已棄用的舊數值等）混在一段文字裡，使用者直接反饋「好難閱讀」；修正方式為拆成主表格摘要列 + 獨立的結構化子表格，同時要求此規則寫入 skill 本身，避免未來同類型多輪技術分析疊加時重蹈覆轍

---

## [1.13] — 2026-07-08

### Changed
- **去識別化檢查清單擴大適用範圍**：原本僅涵蓋 `common_KBs/ADRs/`、`common_KBs/tech-research/`（Mode B 選項 5、7），現擴大為「專案 KB（`{$PROJECT_KB}/`）以外的所有 git-tracked 內容」——新增涵蓋 `common_KBs/guideline/`、`skills/*/SKILL.md`、`CHANGELOG.md`、`role-flows/`、`roles/`、`setting/`、`README.md`、`CLAUDE.md`、`governance/` 等 KB_ROOT Meta 路徑（Mode B 選項 8），且明確不論異動經由本 skill 派發或由主流程 / 其他 skill 直接編輯產生，皆須套用
- Step 2 路由表「KB_ROOT Meta」列補上 `common_KBs/guideline/`：先前完全沒有路由項目涵蓋 guideline 更新
- 「對照表的呈現限制」段落：從「只能出現在 Step 6」放寬為「當次對話最終摘要」，涵蓋 KB_ROOT Meta / 直接編輯類異動不走 Step 6 的情況；並新增 CHANGELOG.md 為禁止寫入對照表的路徑之一

### Context
- 起因：2026-07-08 發現 `REVIEW_GUIDE.md` 版本註記與 `code-architect/CHANGELOG.md` 的 Context 段落直接洩漏真實業務詞彙與類別名——兩者皆屬「內容限制規則」（軟性、主觀判斷）管轄範圍，未經過「去識別化檢查清單」（regex＋語意雙軌掃描）的機械檢查；追查發現該清單的適用範圍設計上就只綁定 Mode B 選項 5、7，guideline 與 skill CHANGELOG 的直接編輯流程完全不會觸發它，屬設計缺口而非執行疏漏
- 對應 `governance/maintenance-protocol.md` §2 同步新增直接編輯前的去識別化自檢步驟，兩處為同一次修正

### Changed
- **Step 3 拆分為外部模板檔**：原本內嵌於 skill.md 的 8 份子代理 prompt（PM / RD / SRE / 專案 ADR / 共用 ADR / tech-research / Review History / QA Records）逐字搬移至同目錄新建的 `templates/` 子目錄（`pm-spec.md`、`rd-source-codex.md`、`sre.md`、`project-adr.md`、`common-adr.md`、`tech-research.md`、`review-history.md`、`qa-records.md`），內容（含各模板的「派發規格」`subagent_type` / `model` 標注）逐字保留、零語意變動
- Step 3 本體改為精簡調度表（KB 類型 | 模板檔路徑 | subagent_type | model），並明確指示派發時依 Step 2 判定結果**只讀取**對應的單一模板檔，不得一次讀取全部模板

### Context
- 起因：skill.md 全載約 850 行，但單次觸發通常只用到 1～2 種 KB 類型的子代理模板，其餘 6～7 份模板內容純屬固定 context 成本；拆分後 skill.md 降至約 390 行，派發時按需讀取對應模板即可，不影響既有子代理 prompt 的實際內容或派發規則

---

## [1.11] — 2026-07-05

### Fixed
- **Step 0.7 Scaffolding**：直接複製清單中「`ADRs/index.md`（若存在 `0000-record-architecture-decisions.md` 也一併複製）」為過期引用，`demo_KBs/ADRs/` 下實際並無此檔案；改為說明實際目錄內容（僅 `index.md` 與示範 ADR `0001-service-communication-protocol.md`），並釐清示範 ADR 依「不複製」規則排除、不隨 index.md 一併複製

### Added
- frontmatter 補上 `version` 欄位

### Context
- 起因：定期稽核 skill frontmatter 與內容一致性時發現此過期引用；先實查 `demo_KBs/ADRs/` 實際檔案清單，確認 `0000-record-architecture-decisions.md` 不存在後修正表述

---

## [1.10] — 2026-07-05

### Changed
- **Step 3 全部 8 個子代理模板**（PM / RD / SRE / 專案 ADR / 共用 ADR / tech-research / Review History / QA Records）補上派發規格：統一 `subagent_type: general-purpose`；`model` 依內容性質標注——需摘要與改寫的（PM、專案 ADR、共用 ADR、tech-research、Review History、QA Records）用 `sonnet`，屬結構性事實登錄 / 條目追加的（RD、SRE）用 `haiku`
- **去識別化檢查清單**：執行流程 Step 1 改為「雙軌掃描」——regex 先掃 + 語意比對補漏，兩者皆須執行，不可只跑其一

### Added
- Step 3 開頭新增一行調度原則引用：「調度原則見 governance/model-dispatch.md」
- 去識別化檢查清單新增「機械化偵測規則」小節：Ticket / 單號（`[A-Z]{2,10}-\d+`）、Email（`\S+@\S+\.\S+`）、IPv4（`\b\d{1,3}(\.\d{1,3}){3}\b`）、內部網域樣式（`*.internal`、`*.local`、公司網域樣式）四類 regex；並明訂掃描範圍須涵蓋巢狀內容（程式碼註解、log / stacktrace 片段、diff 內文），不得只掃正文段落

### Context
- 起因：既有 Step 3 子代理模板全數未標注 `subagent_type` / `model`，派發時預設繼承主線模型，成本與任務複雜度不匹配；去識別化檢查清單僅有語意判斷步驟，缺乏可機械執行的偵測規則，容易漏抓格式明確的識別資訊（ticket 單號、email、IP、內部網域），且巢狀在程式碼片段中的識別資訊過去常被略過

---

## [1.9] — 2026-07-05

### Added
- **Step 2 路由表**：新增 QA Records KB 判斷規則（`qa`、測試案例、測試結果、qa-records、`{TICKET}-qa` 等關鍵字），目標路徑 `{$PROJECT_KB}/qa-records/{TICKET}-qa.md`，格式規範引用 `qa_format`
- **QA Records KB 子代理 prompt**（新）：讀取 `qa-format.md`，依票號建立或追加 `{TICKET}-qa.md`（測試策略、測試案例表、Contract 覆蓋、測試執行結果），完成後回報建立 / 更新路徑與結果摘要
- **Step 0.7 Scaffolding**：新 KB 初始化時，`qa-records/qa-format.md` 納入「直接複製」清單，`qa-records/` 目錄不存在時一併建立

### Context
- 起因：QA 工作流程結束時會呼叫 `/update-kb` 寫入 QA 記錄，但先前版本的路由表、子代理清單與新 KB scaffolding 皆未涵蓋 `qa-records/`，導致此類更新實際上無路可派，記錄從未落地

---

## [1.8] — 2026-07-03

### Fixed
- **Review History KB 子代理 prompt**：檔名範例殘留真實服務名稱與 ticket 單號，改用通用佔位符（`PROJECT-123`、`order-service`），符合本檔案自己規範的「內容限制規則」

---

## [1.7] — 2026-07-03

### Removed
- **Step 5-3**（KB_ROOT 層級異動 Log）：移除。KB_ROOT Meta 異動改為完全依賴各 skill/檔案自身的 CHANGELOG.md + git commit history 追蹤，不再另外寫入 `pending/logs/kb-root-update-*.md`
- Step 6 輸出摘要移除「已寫入 KB_ROOT Meta log」的提示，改為僅註明異動的 skill/檔案與版本號

### Context
- [1.6] 引入 Step 5-3 後，使用者認為與各 skill 自己的 CHANGELOG.md、git history 重複記錄，決定 KB_ROOT Meta 只需保留 Step 2 的路由分類（判斷「這是不綁定專案的異動、不派發子代理」），不需要額外的 log 機制
- Step 2「KB_ROOT Meta」分類與 Mode B 選項 8 予以保留——原本的路由缺口（`skills/` 等路徑完全沒有被任何 Step 辨識）仍是實質問題，只是解法從「額外寫 log」改為「維持路由辨識、追蹤交回各自的 CHANGELOG + git history」

---

## [1.6] — 2026-07-03

### Added
- **Step 2 路由表**：新增「KB_ROOT Meta」分類，涵蓋 `skills/`、`role-flows/`、`roles/`、`setting/`、README.md、CLAUDE.md 等不綁定特定專案的異動或稽核結果，補上原本權限規則已宣告（`$KB_ROOT` 完整 CRUD）但 Step 2～5 從未實際涵蓋的路由缺口
- **Step 5-3**（新）：KB_ROOT 層級異動 Log，寫入 `$KB_ROOT/pending/logs/kb-root-update-{YYYY-MM-DD}.md`，記錄「異動 / 稽核事實」（含無實際寫入的稽核類任務），不重複 skill 自身 CHANGELOG 或其他文件內容
- Mode B 選單新增選項 8「KB_ROOT 結構性異動」
- Step 6 輸出摘要補充：涉及 KB_ROOT Meta 時需註明已寫入的 Step 5-3 log 路徑

### Context
- 起因：`skills/code-architect` 規則更新後，使用者詢問「LOG呢」才發現此類異動完全沒有落地記錄——舊版 Step 2～5 只認 `{$PROJECT_KB}` 底下的內容類型，`skills/` 等 KB_ROOT 層級路徑從未被任何 Step 涵蓋，也沒有對應的 log 路徑

---

## [1.5] — 2026-07-01

### Added
- **去識別化檢查清單**（`## 去識別化檢查清單`）：在「內容限制規則」後新增獨立章節，專用於強制去識別化路徑（共用 ADR、通用技術研究）。條列識別項目分類（專案 / 公司名稱、ticket 單號、真實 service / class / package 名稱、人名 / email、內部網域 / IP、業務專屬代碼）與對應處理方式；要求同一文件內識別項目替換須全篇一致。
- 共用 ADR KB 子代理、通用技術研究 KB 子代理的輸出格式新增「🔒 去識別化對照表」欄位，於 Step 6 對話最終摘要中顯示供使用者核對。
- 明確規範對照表的呈現限制：只能出現在對話輸出（Step 6 最終摘要），**禁止**寫入 `pending/logs/` 更新記錄、KB 文件本身或任何其他檔案，避免原始業務內容被任何檔案留存。

### Changed
- 共用 ADR KB 子代理、通用技術研究 KB 子代理的執行規則：原本模糊的「確認內容是否已完全去識別化」步驟，改為明確依「去識別化檢查清單」逐段掃描、建立對照表並完成替換
- Mode B 選單選項 5、7 說明文字補充「將依去識別化檢查清單自動掃描與替換」
- Step 5-2（寫入更新 Log）新增禁止項：子代理輸出的去識別化對照表不得寫入 log

---

## [1.4] — 2026-07-01

### Added
- **內容限制規則**（`## 內容限制規則`）：在權限規則區塊後新增獨立章節。採正向約束：git-tracked 路徑只允許標準技術術語與無語意佔位符，判斷標準為「不認識此專案的工程師能否憑技術知識理解」。例外僅限專案 KB 路徑。

---

## [1.3] — 2026-06-26

### Added
- Step 4-4「確認 README.md 是否需要更新」：每次執行結束前，自動比對 `$KB_ROOT/README.md` 與實際目錄結構、本次涉及的 KB 類型，若有不一致則直接更新（中英文同步）
- Step 5 log 模板的 Meta 檔案區塊新增 `README.md：{有異動 / 無異動}` 欄位

---

## [1.2] — 2026-06-26

### Changed
- 共用 ADR KB 子代理：必讀文件改為 index-first — 先讀 MASTER_INDEX.md 判斷分類，再**只列出該分類目錄**，不再掃描全部 8 個分類
- 專案 ADR 子代理：Step A 改為 index-first — 有 `ADRs/index.md` 時先讀快速查詢表判斷相似 ADR；無 index.md 才列出目錄
- 專案 ADR 子代理 Step C：明確引用 Step A 已讀資料計算新編號，避免重複掃描

## [1.1] — 2026-06-26

### Added
- 通用技術研究 KB（`common_KBs/tech-research/`）：新增 Mode B 選項 7「技術探討 / 研究筆記」，並新增對應 tech-research 子代理 prompt
- Step 2 路由表：新增 tech-research 判斷規則（技術探討、框架評估、研究筆記觸發通用技術研究 KB）
- Step 5 log 模板：新增「通用技術研究」段落

### Changed
- 共用 ADR 路徑從 `knowledge/ADRs/` 移至 `knowledge/common_KBs/ADRs/`
- 共用規範路徑從 `knowledge/guideline/` 移至 `knowledge/common_KBs/guideline/`
- Step 0.5 專案 KB 掃描：明確排除 `common_KBs`（通用 KB 獨立處理，非專案 KB）
- Mode B 選項 5 說明補充目標路徑 `common_KBs/ADRs/`
- 共用 ADR 子代理 prompt：更新路徑、調整為依 8 大分類目錄判斷，更新 MASTER_INDEX 異動規則

---

## [1.0] — 初版

### Added
- 兩種啟動模式：排程自啟動（掃描 `pending/`、每日 git 更新）、使用者自啟動（輸入 ticket / 檔案 / 描述）
- 多 KB 類型並行更新：PM KB（specs/）、RD KB（source-codex/）、SRE KB（site-reliability/）、專案 ADR、共用 ADR、Review History
- 各 KB 類型同時發出 Agent tool call，並行派發子代理
- 新 KB 自動 scaffolding：偵測到 MASTER_INDEX 缺失時，從範本 KB 複製目錄結構，排除示範內容
- ADR 分層管理：專案 ADR（可含識別資訊）與共用 ADR（強制去識別化）分開維護流程；修訂現有 ADR 時標注決策翻轉原因
- Review History KB：依 Code Review 內容建立或追加記錄，自動更新 index.md
- 權限邊界：`$KB_ROOT` 內完整 CRUD，`$KB_ROOT` 外僅允許讀取
- 自動清理 `pending/` 已處理項目，並寫入更新 log（`pending/logs/update-YYYY-MM-DD.md`）
- 更新完成後同步確認 MASTER_INDEX、paths.yml、role-flows 一致性
