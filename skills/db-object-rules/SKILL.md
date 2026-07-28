---
name: db-object-rules
description: >
  使用此 Skill 來審查、驗證或生成符合專案 DB Objects 規則的 SQL/JS 腳本。
  觸發條件包含：使用者提交 Oracle SQL 或 MongoDB JS 腳本請求審查、
  詢問 DB Object 命名規範、請求生成符合規範的 DDL/DML 語句、
  或要求產生 DB Object 審查報告。
  關鍵字：DB Object、DDL、DML、Oracle、MongoDB、Table、Index、
  Sequence、命名規則、DBA Review、db-object-check。
version: "1.2"
source: 本檔為規則唯一來源（原始 PDF 未隨知識庫提供，勿嘗試查找）
---

# DB Object Check Skill

## 概述

此 Skill 依據《DB Objects 規則與建議》，
對 Oracle SQL 與 MongoDB JS 腳本進行靜態規則審查，並提供修正建議。

審查涵蓋六大面向：
1. 申請規則（Apply Rule）— 明細見 `references/apply-process.md`
2. 命名與語法規則（Naming & Syntax）— 明細見 `references/naming-syntax.md`
3. Table 規則 — 明細見 `references/table-rules.md`
4. Index 規則 — 明細見 `references/index-rules.md`
5. Sequence 規則 — 明細見 `references/sequence-rules.md`
6. DML 規則 — 明細見 `references/dml-rules.md`

---

## 快速參考

| 審查面向 | 適用對象 | 說明 | 明細檔 |
|----------|----------|------|--------|
| 申請流程 | Oracle / MongoDB | 通知時限、Stand By 等流程規則（無法靜態分析） | `references/apply-process.md` |
| 命名與語法 | Oracle / MongoDB | 檔名、Object 名稱、符號、大小寫等格式 | `references/naming-syntax.md` |
| Table | Oracle / MongoDB | 欄位型態、Comment、NULL 設定 | `references/table-rules.md` |
| Index | Oracle / MongoDB | 命名規則、數量合理性、欄位選擇 | `references/index-rules.md` |
| Sequence | Oracle only | 命名與 CACHE/ORDER 設定 | `references/sequence-rules.md` |
| DML | Oracle / MongoDB | COMMIT、資料型態格式 | `references/dml-rules.md` |

---

## 硬性約束（Must，不可違反）

以下為各面向中**必須**遵守、審查時優先標記為 ❌ 的核心規則；完整 Checklist 見上表對應明細檔。

- 檔名須符合 `<SystemName>_<SerialNumber>_<DDL|DML>_<Prod|Uat|Dev>.(sql|js)` 格式
- Oracle Table/Object 前必須加 Schema Owner（如 `OWNER.TABLE`）
- 名稱只能使用底線 `_`，不可用 `-`、`$`、`#` 等符號；且須以英文字開頭
- 不可使用雙引號包住 Object/Column 名稱
- Object/Column Name 一律大寫；長度 ≤ 64 字元；每行 ≤ 240 字元
- DDL 語句區塊內不可有空白行；每條語句結尾須加分號 `;`
- Oracle Table 必須建立 Table Comment 與 Column Comment
- MongoDB Collection 必須用 `$jsonSchema` 定義 validator，並包含 `_id`、`required`、`additionalProperties: false`
- Index 命名須符合 `<TableName>_PK` / `_UK` / `_<ColumnName>` 規則
- Sequence 命名須為 `SEQ<TableName>`（Oracle only）
- Oracle DML 語句最後必須加 `COMMIT`；字元資料加單引號、數字不加引號
- 避免在 Schema 中寫 `DROP`／`drop collection` 語法

---

## 審查流程指引

當使用者提交腳本進行 DB Object 審查時，依下列流程輸出報告：

### Step 1：識別腳本類型
- 偵測是 Oracle（`.sql`）還是 MongoDB（`.js`）
- 偵測是 DDL 還是 DML

### Step 2：逐項套用對應規則
依序檢查「快速參考」表中六個面向的 Checklist（各面向明細檔如上），
每項標記為 ✅ 符合 / ❌ 違規（附原因）/ ⚠️ 建議 / ℹ️ 無法靜態判斷（需人工確認）。

### Step 3：輸出審查報告
依固定格式輸出審查報告（報告樣板見 `references/review-report-format.md`），
涵蓋命名與語法、Table、Index、DML 各段落，並附申請流程提醒。

### Step 4：提供修正後腳本（如適用）
若違規項目有明確修正方向，提供修正版本的片段或完整腳本。

常見違規對照見 `references/common-violations.md`；
保留字等外部依據見 `references/reference-resources.md`。
