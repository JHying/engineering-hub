# Changelog — update-kb

所有版本異動依時間倒序排列。

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
