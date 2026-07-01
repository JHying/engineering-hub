# Changelog — my-work-agent

所有版本異動依時間倒序排列。

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
