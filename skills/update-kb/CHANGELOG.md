# Changelog — update-kb

所有版本異動依時間倒序排列。

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
