# V. Sequence 規則（Oracle Only）

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
