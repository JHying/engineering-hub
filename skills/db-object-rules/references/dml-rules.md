# VI. DML 規則

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
