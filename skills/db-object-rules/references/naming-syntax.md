# II. 命名與語法規則（Naming & Syntax）

### 2.1 檔案命名格式

```
[Oracle] <SystemName>_<SerialNumber>_<DDL|DML>_<Prod|Stg|Dev>.sql
[MongoDB] <SystemName>_<SerialNumber>_<DDL|DML>_<Prod|Stg|Dev>.js

合法範例：
  SYS_1234_DDL_Prod.sql
  APP_1234_DDL_Stg.sql
  SYS_1234_DML_Dev.js
```

**Regex 驗證（檔名）：**
```
^[A-Z0-9]+_\d+_(DDL|DML)_(Prod|Uat|Dev)\.(sql|js)$
```

### 2.2 Checklist — 逐條規則

| #   | 檢查項目                       | 說明                             | 違規範例                                 |
| --- | -------------------------- | ------------------------------ | ------------------------------------ |
| 1   | **檔名命名正確**                 | 符合上方格式                         | `sys_1234_DDL_prod.sql`              |
| 2   | **相關 Object 名稱一致**         | 同一 Object 全文拼寫一致               | `MY_TABLE 與 MY_TALE` 混用              |
| 3   | **加 Object Owner（Oracle）** | Table 前需加 Schema Owner         | `MY_TABLE` → 應為 `OWNER.MY_TABLE`     |
| 4   | **符號只允許底線**                | 名稱中僅可使用 `_`，不可使用 `-`、`$`、`#` 等 | `ROLE-INFO`、`$ITEM`                  |
| 5   | **語句不能有空白行**               | DDL 語句區塊內不可出現空白行               | CREATE TABLE 欄位間有空行                  |
| 6   | **命令結束要分號（;）**             | 每條語句末尾必須有 `;`                  | `COMMENT ON COLUMN ... IS 'X'` 無 `;` |
| 7   | **名稱以英文字開頭**               | 不可以數字或特殊符號開頭                   | `2ITEM`、`$ITEM`                      |
| 8   | **名稱長度不超過 64 字元**          | Object/Column 名稱 ≤ 64 字元       | —                                    |
| 9   | **避免使用關鍵字和保留字**            | 參考 Oracle / MongoDB 保留字清單      | `ALIAS`、`ALL`、`_id`（MongoDB）         |
| 10  | **Object Name 使用大寫**       | Table Name、Column Name 全大寫     | `role_info`、`userId`                 |
| 11  | **每行不超過 240 字元**           | 超過請斷行                          | —                                    |
| 12  | **使用空白排版，取代 Tab**          | 排版縮排改用空白字元                     | 含 `\t` 的縮排                           |
| 13  | **移除雙引號**                  | 不可使用 `"OWNER"."TABLE"` 形式      | `"ID" NUMBER(2)`                     |
|     |                            |                                |                                      |
