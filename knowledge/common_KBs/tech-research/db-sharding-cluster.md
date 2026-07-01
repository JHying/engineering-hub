---
date: 2026-06-27
keywords: Sharding, 分庫分表, 讀寫分離, Hash Sharding, Range Sharding, DB Cluster, Master Slave
---

# DB Cluster 與 Data Sharding 策略

**日期**：2026-06-27
**關鍵字**：Sharding, 分庫分表, 讀寫分離, Hash-based, Range-based, Directory-based, Master-Slave

## 問題背景

單一資料庫在 QPS > 1,000 或資料量超過億筆後，垂直擴展（加硬體）邊際效益遞減，需要水平分散（Sharding）來突破單節點瓶頸。

---

## 研究結論

### 一、DB Cluster 架構（讀寫分離）

```
           「Write」
             ↓
Client → Master DB
             ↓ 同步複寫
  Slave 1 | Slave 2 | Slave 3
     ↑         ↑         ↑
           「Read」
```

- **Master**：負責寫入，保證一致性
- **Slave**：負責讀取，分散讀壓力
- 適合**讀多寫少**場景

---

### 二、Data Sharding 三大策略

#### 1. Hash-based Sharding（雜湊分片）

```
Shard = hash(Primary Key) % 分片數量
```

- **優點**：資料平均分散，熱點少
- **缺點**：難以完成範圍查詢；擴充分片數時需 Rehash

#### 2. Range-based Sharding（範圍分片）

```
Shard 1: ID 1 ~ 1,000,000
Shard 2: ID 1,000,001 ~ 2,000,000
```

- 也可按 Timestamp 範圍切分
- **優點**：簡單直觀，支援範圍查詢
- **缺點**：可能存在熱點（如最新資料集中在同一 Shard）

#### 3. Directory-based Sharding（目錄分片）

- 維護一張 Key-Value 映射表，記錄資料屬於哪個 Shard
- **優點**：靈活，可任意調整分片規則
- **缺點**：映射表本身成為單點瓶頸，需高可用設計

---

### 三、Sharding 帶來的挑戰

| 問題 | 說明 |
|------|------|
| 跨庫 JOIN | 資料在不同 Shard，JOIN 需應用層聚合 |
| 分散式事務 | 跨 Shard 操作難保 ACID，需 Saga / 2PC |
| 主鍵策略 | 不能用自增 ID（各 Shard 衝突），改用 UUID 或雪花 ID |
| 熱點 Shard | Hash 分片可緩解，Range 分片需手動 Rebalance |

---

### 四、相關工具

| 工具 | 說明 |
|------|------|
| ShardingSphere | Apache 開源，支援 MySQL 分片 |
| MyCat | MySQL 分片中間件 |
| Vitess | YouTube 開發，大規模 MySQL 方案 |
| MongoDB | 內建 Sharding 支援 |

---

## 參考

- 來源：Notion 開發學習筆記 — DB相關 > DB Cluster - Data Sharding
