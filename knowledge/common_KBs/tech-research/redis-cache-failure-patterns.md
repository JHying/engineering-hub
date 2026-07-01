---
date: 2026-06-27
keywords: Redis, 快取穿透, 快取雪崩, 快取擊穿, 布隆過濾器, Cache-Aside, TTL, 互斥鎖
---

# Redis 快取三大異常情境

**日期**：2026-06-27
**關鍵字**：Redis, 快取穿透, 快取雪崩, 快取擊穿, 布隆過濾器, Cache-Aside, TTL, Mutex Lock

## 問題背景

Redis 作為快取層，在高併發下可能因為 key 設計、TTL 策略或熱點問題，導致大量請求繞過快取直接打到 DB，造成系統崩潰。需要針對三種異常情境有對應方案。

---

## 研究結論

### 三種異常情境速覽

| 情境 | 觸發原因 | 影響 |
|------|---------|------|
| 快取穿透（Penetration） | 查詢不存在的 key，每次都打 DB | 惡意攻擊或 BUG 導致 DB 過載 |
| 快取雪崩（Avalanche） | 大量 key 同時過期 | 瞬間流量全打 DB |
| 快取擊穿（Breakdown） | 單一熱點 key 過期瞬間 | 大量請求同時重建快取 |

---

### 1. 快取穿透（Cache Penetration）

> 查詢**不存在**的資料，每次都繞過快取直打 DB

**解決方案：**

**方案一：快取空值**
```java
String value = redis.get(key);
if (value == null) {
    value = db.query(key);
    // 不存在也快取 null，設短 TTL 防堆積
    redis.set(key, value != null ? value : "NULL", SHORT_TTL);
}
```

**方案二：布隆過濾器（Bloom Filter）**
- 在查 Redis 前先判斷 key 是否可能存在
- 存在誤判率（false positive），但無漏判（false negative）
- 適合 key 空間可預知的場景

---

### 2. 快取雪崩（Cache Avalanche）

> 大量快取**同時過期**，流量全部湧向 DB

**解決方案：**

**TTL 加上隨機偏移**（最常用）
```java
int ttl = BASE_TTL + new Random().nextInt(300); // 加 0~5 分鐘隨機偏移
redis.set(key, value, ttl, TimeUnit.SECONDS);
```

**其他方案：**
- **多級快取**：本地 Caffeine 快取 + Redis，Redis 崩也有本地緩衝
- **熔斷降級**：限流保護 DB，返回降級資料

---

### 3. 快取擊穿（Cache Breakdown）

> **熱點 key** 過期瞬間，大量請求同時穿透

**方案一：互斥鎖（Mutex Lock）**
```java
String value = redis.get(key);
if (value == null) {
    if (redis.tryLock(lockKey, 5, TimeUnit.SECONDS)) {
        try {
            value = db.query(key);
            redis.set(key, value, TTL);
        } finally {
            redis.unlock(lockKey);
        }
    } else {
        Thread.sleep(50); // 等待後重試
        return get(key);
    }
}
```

**方案二：永不過期（Logical TTL）**
- 不設實際 TTL，改在 value 中記錄邏輯過期時間
- 背景執行緒非同步更新快取
- 讀取時可能短暫讀到舊值（最終一致性）

---

### 4. 資料不一致（Inconsistency）

> 快取與 DB 資料不同步

| 策略 | 適用場景 | 缺點 |
|------|---------|------|
| Cache-Aside（最常用） | 讀多寫少 | 寫後快取短暫過時 |
| Write-Through | 寫入時同步更新快取 | 增加寫入延遲 |
| Write-Behind | 非同步批次寫入 DB | 有丟失風險 |

**建議模式（Cache-Aside + 刪除快取）：**
```java
// 更新時：先更新 DB，再刪除快取（不是更新快取）
db.update(data);
redis.delete(key); // 下次請求自動重建
```

> 先刪快取再更新 DB 會有競態問題，推薦「先更新 DB，再刪快取」。

---

## 參考

- 來源：Notion 開發學習筆記 — 架構框架 > Redis 快取異常情境
