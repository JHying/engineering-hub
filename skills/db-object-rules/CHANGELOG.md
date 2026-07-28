# Changelog — db-object-rules

所有版本異動依時間倒序排列。

---

## [1.2] — 2026-07-28

### Changed
- SKILL.md 拆分為骨幹＋references/（progressive disclosure）：主檔僅保留
  frontmatter、觸發條件、審查流程步驟骨幹（Step 1-4）與硬性約束摘要，
  細節規則表、語法範例、審查報告格式移至同目錄 `references/` 子目錄：
  - `references/apply-process.md`（申請流程規則）
  - `references/naming-syntax.md`（命名與語法規則）
  - `references/table-rules.md`（Table 規則與語法範例）
  - `references/index-rules.md`（Index 規則與語法範例）
  - `references/sequence-rules.md`（Sequence 規則與語法範例）
  - `references/dml-rules.md`（DML 規則與語法範例）
  - `references/review-report-format.md`（審查報告輸出格式）
  - `references/common-violations.md`（常見違規速查表）
  - `references/reference-resources.md`（外部參考資源清單）

### Context
- 起因：對齊 context engineering 原則——skill 觸發時 SKILL.md 全文會載入
  context，長檔案造成不必要的 token 消耗；改為主檔留流程骨幹、
  細節檔在實際需要時才由子代理讀取

---

## [1.1] — 2026-07-05

### Changed
- frontmatter `source` 欄位：原指向 `DBObjectsRule_3.1.pdf`，該檔案未隨知識庫提供且不會補齊，改為說明性表述「本檔為規則唯一來源」，避免後續模型浪費時間尋找不存在的來源 PDF
- 第 IX 節「參考資源」表：同一筆過期 PDF 引用一併改為「本檔（SKILL.md）」

### Context
- 起因：定期稽核 skill frontmatter 發現 `source` 欄位指向的原始規則 PDF 從未隨知識庫存放，且使用者確認不會補提供

---

## [1.0] — 初版

### Added
- 依據專案 DB Object 命名規範文件
- Oracle SQL 腳本靜態規則審查（Table、Index、Sequence、Column 命名規範）
- MongoDB JS 腳本靜態規則審查（Collection、Field 命名規範）
- DDL / DML 語句生成，符合命名規範
- DBA Review 報告輸出格式
