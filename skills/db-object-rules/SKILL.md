---
name: db-object-rules
description: >
  使用此 Skill 來審查、驗證或生成符合專案 DB Objects 規則的 SQL/JS 腳本。
  觸發條件包含：使用者提交 Oracle SQL 或 MongoDB JS 腳本請求審查、
  詢問 DB Object 命名規範、請求生成符合規範的 DDL/DML 語句、
  或要求產生 DB Object 審查報告。
  關鍵字：DB Object、DDL、DML、Oracle、MongoDB、Table、Index、
  Sequence、命名規則、DBA Review、db-object-check。
version: "1.0"
source: DBObjectsRule_3.1.pdf
---

# DB Object Check Skill

## 概述

此 Skill 依據《DB Objects 規則與建議》，
對 Oracle SQL 與 MongoDB JS 腳本進行靜態規則審查，並提供修正建議。

審查涵蓋六大面向：
1. 申請規則（Apply Rule）
2. 命名與語法規則（Naming & Syntax）
3. Table 規則
4. Index 規則
5. Sequence 規則
6. DML 規則

---

## 快速參考

| 審查面向 | 適用對象 | 說明 |
|----------|----------|------|
| 命名與語法 | Oracle / MongoDB | 檔名、Object 名稱、符號、大小寫等格式 |
| Table | Oracle / MongoDB | 欄位型態、Comment、NULL 設定 |
| Index | Oracle / MongoDB | 命名規則、數量合理性、欄位選擇 |
| Sequence | Oracle only | 命名與 CACHE/ORDER 設定 |
| DML | Oracle / MongoDB | COMMIT、資料型態格式 |

---

## I. 申請規則（供說明用，不做靜態分析）

> 這部分為流程規則，**無法靜態分析**，請在輸出報告中以提醒方式呈現。

| 規則 | 說明 |
|------|------|
| 提前通知 | 正式環境異動至少提前 **2 天**通知，建議 **1 週前** |
| 新系統上線 | 至少提前 **2 週**通知 DBA |
| 可提前執行項目 | 請在申請單中**備註說明** |
| 申請人 Stand By | 上線期間申請人/負責人須配合 Stand By |
| 關聯系統通知 | 若異動影響其他 Object/系統，須通知相關負責人 |
| 緊急更新 | 需告知 DBA 影響範圍並通知 Leader |

---

## II. 命名與語法規則（Naming & Syntax）

### 2.1 檔案命名格式

```
[Oracle] <SystemName>_<SerialNumber>_<DDL|DML>_<Prod|Uat|Dev>.sql
[MongoDB] <SystemName>_<SerialNumber>_<DDL|DML>_<Prod|Uat|Dev>.js

合法範例：
  SYS_1234_DDL_Prod.sql
  APP_1234_DDL_Uat.sql
  SYS_1234_DML_Dev.js
```

**Regex 驗證（檔名）：**
```
^[A-Z0-9]+_\d+_(DDL|DML)_(Prod|Uat|Dev)\.(sql|js)$
```

### 2.2 Checklist — 逐條規則

| # | 檢查項目 | 說明 | 違規範例 |
|---|----------|------|----------|
| 1 | **檔名命名正確** | 符合上方格式 | `sys_1234_DDL_prod.sql` |
| 2 | **相關 Object 名稱一致** | 同一 Object 全文拼寫一致 | `MY_TRANSACTION` 與 `MY_TRANSATION` 混用 |
| 3 | **加 Object Owner（Oracle）** | Table 前需加 Schema Owner | `MY_TRANSACTION` → 應為 `OWNER.MY_TRANSACTION` |
| 4 | **符號只允許底線** | 名稱中僅可使用 `_`，不可使用 `-`、`$`、`#` 等 | `ROLE-INFO`、`$ITEM` |
| 5 | **語句不能有空白行** | DDL 語句區塊內不可出現空白行 | CREATE TABLE 欄位間有空行 |
| 6 | **命令結束要分號（;）** | 每條語句末尾必須有 `;` | `COMMENT ON COLUMN ... IS 'X'` 無 `;` |
| 7 | **名稱以英文字開頭** | 不可以數字或特殊符號開頭 | `2ITEM`、`$ITEM` |
| 8 | **名稱長度不超過 64 字元** | Object/Column 名稱 ≤ 64 字元 | — |
| 9 | **避免使用關鍵字和保留字** | 參考 Oracle / MongoDB 保留字清單 | `ALIAS`、`ALL`、`_id`（MongoDB） |
| 10 | **Object Name 使用大寫** | Table Name、Column Name 全大寫 | `role_info`、`userId` |
| 11 | **每行不超過 240 字元** | 超過請斷行 | — |
| 12 | **使用空白排版，取代 Tab** | 排版縮排改用空白字元 | 含 `\t` 的縮排 |
| 13 | **移除雙引號** | 不可使用 `"BAC"."GAMEGROUP"` 形式 | `"ID" NUMBER(2)` |

---

## III. Table 規則

### 3.1 Oracle Table Checklist

| # | 檢查項目 |
|---|----------|
| 1 | **建立 Table Comment**（`COMMENT ON TABLE ... IS '...'`） |
| 2 | **建立 Column Comment**（每個欄位都需要） |
| 3 | 評估 Table Size，判斷是否需要 **Partitioned Table** 或 **Housekeeping** 設定 |
| 4 | 字串欄位若可能超過 4000 字元，改用 **CLOB** |
| 5 | 確認是否有 **DEFAULT Value** |
| 6 | 避免在 Schema 中寫 **DROP 語法**（防止誤刪） |
| 7 | 同名 Column 在不同 Table 中型態與長度**需一致** |
| 8 | 確認 Column **NULL / NOT NULL** 設定 |
| 9 | Column Data Type **長度大小**合理（不過小也不浪費） |

### 3.2 MongoDB Collection Checklist

| # | 檢查項目 |
|---|----------|
| 1 | 必須使用 `db.createCollection` + **Validation（$jsonSchema）** |
| 2 | `required` 欄位需明確列出（等同 NOT NULL） |
| 3 | 每個欄位需明確指定 **bsonType** 與 **description** |
| 4 | 必須包含 `_id` 欄位（`bsonType: 'objectId'`） |
| 5 | 日期資料使用 **date** Data Type |
| 6 | 數值區間限制使用 `minimum` / `maximum` |
| 7 | 固定值清單使用 **enum** |
| 8 | 防止多餘欄位：設定 `additionalProperties: false` |
| 9 | 避免異動 `_id` 欄位 |
| 10 | 避免在 Schema 中寫 **drop collection 語法** |

### 3.3 語法範例

**Oracle:**
```sql
CREATE TABLE OWNER.TEST
(
  COL1 NUMBER NOT NULL,
  COL2 NUMBER(8) DEFAULT 30000 NOT NULL,
  COL3 VARCHAR2(10),
  COL4 TIMESTAMP(6) DEFAULT SYSTIMESTAMP NOT NULL,
  COL5 DATE NOT NULL
);
COMMENT ON TABLE OWNER.TEST IS 'Testing';
COMMENT ON COLUMN OWNER.TEST.COL1 IS 'Column 1';
COMMENT ON COLUMN OWNER.TEST.COL2 IS 'Column 2';
COMMENT ON COLUMN OWNER.TEST.COL3 IS 'Column 3';
COMMENT ON COLUMN OWNER.TEST.COL4 IS 'Column 4';
COMMENT ON COLUMN OWNER.TEST.COL5 IS 'Column 5';
```

**MongoDB:**
```javascript
db.createCollection('TEST', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      title: 'TEST Collection Validation',
      required: ['_id', 'COL1', 'COL2', 'COL4', 'COL5'],
      properties: {
        _id: {
          bsonType: 'objectId',
          description: 'Primary key.'
        },
        COL1: {
          bsonType: 'int',
          description: 'COL1 must be an integer and is required.'
        },
        COL2: {
          bsonType: 'int',
          minimum: 0,
          maximum: 100,
          description: 'COL2 must be an integer (0 ~ 100) and is required.'
        },
        COL3: {
          bsonType: 'string',
          description: 'COL3 must be a string if the field exists.'
        },
        COL4: {
          bsonType: 'double',
          description: 'COL4 must be a double and is required.'
        },
        COL5: {
          bsonType: 'date',
          description: 'COL5 must be a date and is required.'
        }
      },
      additionalProperties: false
    },
    validationLevel: 'strict',
    validationAction: 'error'
  }
});
```

---

## IV. Index 規則

### 4.1 命名規則

| Index 類型 | 命名格式 | 範例 |
|------------|----------|------|
| Primary Key | `<TableName>_PK` | `ACCOUNT_PK` |
| Unique Key | `<TableName>_UK`, `<TableName>_UK1`... | `ACCOUNT_UK` |
| 一般 Index | `<TableName>_<ColumnName>` | `MYORDER_USERID_STATUS` |

### 4.2 Index Checklist

| # | 檢查項目 |
|---|----------|
| 1 | Index **命名符合規則**（見上表） |
| 2 | 重要/常用 SQL 上線前提供，確認 **Index Hint 正確** |
| 3 | 說明 **Index Column 資料分佈**（唯一性、查詢使用頻率） |
| 4 | 若欄位取自 Sequence，開頭加隨機字元避免 **Index Contention（Oracle）** |
| 5 | **避免冗餘 Index**（重複欄位組合的 Index 擇一即可） |
| 6 | 昇降序：無特別需求一律 **ASC（Oracle）/ 1（MongoDB）** |
| 7 | 降序需明確指定：Oracle 用 `DESC`，MongoDB 用 `-1` |

### 4.3 語法範例

**Oracle:**
```sql
-- Primary Key
ALTER TABLE OWNER.ACCOUNT
  ADD CONSTRAINT ACCOUNT_PK PRIMARY KEY (USERID)
  USING INDEX;

-- Unique Key
ALTER TABLE OWNER.ACCOUNT
  ADD CONSTRAINT ACCOUNT_UK UNIQUE (USERID, NAME)
  USING INDEX;

-- 一般 Index
CREATE INDEX OWNER.ACCOUNT_NAME ON OWNER.ACCOUNT (NAME ASC);
```

**MongoDB:**
```javascript
// Unique Key
db.ACCOUNT.createIndex(
  { USERID: 1, NAME: 1 },
  { unique: true, name: 'ACCOUNT_UK' }
);

// 一般 Index
db.ACCOUNT.createIndex(
  { NAME: 1 },
  { name: 'ACCOUNT_NAME' }
);
```

---

## V. Sequence 規則（Oracle Only）

### 5.1 命名規則

```
SEQ<TableName>
範例：SEQACCOUNT
```

### 5.2 Sequence Checklist

| # | 情境 | 建議參數 |
|---|------|----------|
| 1 | 無連續性/一致性需求（一般情境） | `CACHE <CacheSize> NOORDER` |
| 2 | 有連續性/一致性需求（嚴格流水號） | `NOCACHE ORDER`（效能較差） |

### 5.3 語法範例

```sql
CREATE SEQUENCE OWNER.SEQACCOUNT
  MINVALUE 1
  NOMAXVALUE
  INCREMENT BY 1
  START WITH 1
  CACHE 100
  NOORDER;
```

> ※ MongoDB 無 Sequence Object

---

## VI. DML 規則

### 6.1 DML Checklist

| # | 檢查項目 |
|---|----------|
| 1 | **Oracle DML 最後必須加 COMMIT** |
| 2 | 字元資料加**單引號**，數字資料**不加**引號 |
| 3 | 確認無誤輸入符號（`&`、Tab 字元等） |

### 6.2 語法範例

**Oracle:**
```sql
-- Insert
INSERT INTO OWNER.ACCOUNT (NAME, AGE) VALUES ('HERO', 18);
COMMIT;

-- Update
UPDATE OWNER.ACCOUNT SET AGE = 28 WHERE NAME = 'HERO';
COMMIT;

-- Delete
DELETE FROM OWNER.ACCOUNT WHERE NAME = 'HERO';
COMMIT;
```

**MongoDB:**
```javascript
// Insert
db.ACCOUNT.insertOne({ NAME: 'HERO', AGE: 18 });

db.ACCOUNT.insertMany([
  { NAME: 'Alice Smith', AGE: 24 },
  { NAME: 'Bob Johnson', AGE: 35 }
]);

// Update
db.ACCOUNT.updateOne(
  { NAME: 'HERO' },
  { $set: { AGE: 28 } }
);

db.ACCOUNT.updateMany(
  { AGE: { $lt: 30 } },
  { $set: { NAME: 'HERO' } }
);

// Delete
db.ACCOUNT.deleteOne({ NAME: 'HERO' });
db.ACCOUNT.deleteMany({ AGE: { $lt: 30 } });
```

---

## VII. 審查流程指引

當使用者提交腳本進行 DB Object 審查時，依下列流程輸出報告：

### Step 1：識別腳本類型
- 偵測是 Oracle（`.sql`）還是 MongoDB（`.js`）
- 偵測是 DDL 還是 DML

### Step 2：逐項套用對應規則
依序檢查第 II～VI 節的所有 Checklist，
每項標記為：
- ✅ **符合**
- ❌ **違規**（附違規內容與原因）
- ⚠️ **建議**（非強制但最佳實踐）
- ℹ️ **無法靜態判斷**（需人工確認，如 Table Size 評估）

### Step 3：輸出審查報告

報告格式如下：

```
## DB Object 審查報告
檔案：<檔名>
類型：Oracle DDL / MongoDB DML / ...
審查時間：<日期>

### 命名與語法
✅ 檔名格式正確
❌ [第5條] 語句中有空白行 — 第 12 行與第 13 行之間有空行，請移除
⚠️ [建議] 第 3 欄位 COL3 未設定 DEFAULT Value，請確認是否需要

### Table
✅ Table Comment 已建立
❌ COL4 缺少 Column Comment

### Index
✅ 命名符合規則
⚠️ IDX_USERID 與 IDX_USERID_NAME 存在欄位包含關係，建議評估是否移除 IDX_USERID

### DML
❌ UPDATE 語句後缺少 COMMIT

### 申請流程提醒（請人工確認）
ℹ️ 本次為正式環境異動，請確認已在 2 天前通知 DBA
ℹ️ 若為新系統上線，請確認已在 2 週前通知 DBA
```

### Step 4：提供修正後腳本（如適用）
若違規項目有明確修正方向，提供修正版本的片段或完整腳本。

---

## VIII. 常見違規速查

| 違規類型 | 典型錯誤 | 正確寫法 |
|----------|----------|----------|
| 使用雙引號 | `"BAC"."ACCOUNT"` | `OWNER.ACCOUNT` |
| 小寫 Object 名稱 | `role_info` | `ROLE_INFO` |
| 缺少 Schema Owner | `ACCOUNT` | `OWNER.ACCOUNT` |
| 名稱以數字開頭 | `2ITEM` | `ITEM2` |
| 使用非底線符號 | `ROLE-INFO` | `ROLE_INFO` |
| 語句無分號結尾 | `COMMENT ON TABLE OWNER.TEST IS 'x'` | 末尾加 `;` |
| DML 無 COMMIT | `UPDATE ... SET ...` | 末尾加 `COMMIT;` |
| 字串未加引號 | `VALUES (HERO, 18)` | `VALUES ('HERO', 18)` |
| 空白行在 DDL 內 | 欄位定義間有空行 | 移除空行 |
| MongoDB 無 Validation | `db.createCollection('X')` | 加入 `$jsonSchema` validator |
| MongoDB 缺少 `_id` | `required: ['COL1']` | 需包含 `_id` |

---

## IX. 參考資源

| 資源 | 說明 |
|------|------|
| Oracle Keywords & Reserved Words | Oracle 官方保留字清單 |
| MongoDB Keywords | MongoDB 官方保留字清單 |
| SQLPlus Limits | 每行 240 字元上限依據 |
| DBObjectsRule_3.1.pdf | 本 Skill 原始規則文件 |
