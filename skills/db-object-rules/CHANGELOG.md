# Changelog — db-object-rules

所有版本異動依時間倒序排列。

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
