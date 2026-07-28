# IV. Index 規則

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
