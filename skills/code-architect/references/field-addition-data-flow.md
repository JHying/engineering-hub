## 新增欄位的資料流追蹤規則

在多層架構中新增欄位時，必須追蹤**完整的資料流鏈路**，不能只追蹤到 VO 和 Mapper 就停止。

```
來源（MongoDB / gRPC / 外部 API）
  ↓ Entity / Proto
  ↓ Mapper
  ↓ VO
  ↓ Mapper
  ↓ Cache 類別（infra/data/cache/）  ← 容易遺漏
  ↓ Redis 儲存
```

若漏掉 Cache 類別，MapStruct 會**靜默忽略**該欄位（因為 `ReportingPolicy.IGNORE` 不報錯），導致欄位無法存進 Redis。

```java
// ❌ 只更新了 VO，漏掉 Cache 類別
// → MapStruct 不報錯，欄位在 Redis 中永遠是 null

// ✅ VO 與對應的 Cache 類別都要加上新欄位
```
