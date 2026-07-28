# III. Table 規則

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
