---
date: 2026-06-27
keywords: Redis, In-Memory, Key-Value, Cache, Cluster, Hash Slot, Gossip, Master-Slave, Consistent Hash, 快取預熱
---

# Redis 核心概念：資料結構、快取設計與 Cluster 架構

**日期**：2026-06-27
**關鍵字**：Redis, In-Memory, Key-Value, Cache Stampede, Consistent Hash, Cluster, Hash Slot, Gossip Protocol, Master-Slave

## 問題背景

Redis 是高效能 in-memory KV 資料庫，廣泛作為快取層、分散式鎖、Session Store 使用。理解其資料結構、快取常見問題，以及 Cluster 架構，是設計高可用快取方案的基礎。

---

## 研究結論

### 一、Redis 基本特性

- **In-memory**：所有資料放在主記憶體，讀寫 < 1ms，支援百萬 QPS
- **持久化**：可選 RDB（快照）或 AOF（日誌）方式持久化到磁碟
- **主從備份**：支援 Master-Slave 複製，Master 寫、Slave 讀
- **開源 BSD 協議**

---

### 二、支援的資料結構

| 類型 | 說明 | 適用場景 |
|------|------|---------|
| **String** | 最基本的 KV，最大 512MB，二進位安全 | 計數器、緩存值 |
| **Hash** | Field-Value 映射，適合存物件 | 用戶資料、設定 |
| **List** | 有序字串清單，支援頭尾插入 | 訊息佇列、最近訪問 |
| **Set** | 無序不重複集合，支援交集/聯集 | 標籤、點讚 |
| **Sorted Set（zset）** | 有 score 的有序集合 | 排行榜 |
| **Bitmap** | 位元層級操作 | 用戶簽到、布隆過濾器 |
| **HyperLogLog** | 機率式基數估算 | 大量去重計數（UV） |

---

### 三、快取常見問題與解法

#### 問題 1：只用 Local Cache（應用伺服器本地快取）

- 多台 Server 間快取不同步，用戶可能讀到舊資料
- 水平擴展時新 Server 快取為空
- **解法**：改用集中式 Redis 快取

#### 問題 2：Cache Stampede（快取擊穿 / 快取暴衝）

當 Cache Miss 發生時，大量請求同時打到 DB：

```
// 有問題的流程
a. 從 Redis 取資料 X，有則回傳
b. 從 DB 取資料 X
c. 寫入 Redis
d. 回傳

→ 1000 個並發 Cache Miss → 1000 條 DB 請求同時發出
```

**解法：加鎖（Mutex Lock）**

```
a. 從 Redis 取資料 X，有則回傳
b. 搶資料 X 的鎖（離開時釋放）
c. 再次從 Redis 取資料 X（Double Check），有則回傳
d. 從 DB 取資料 X
e. 寫入 Redis
f. 回傳

→ 只有一條請求進 DB，其餘等待後從 Redis 取
```

> 此問題與 redis-cache-failure-patterns.md 中的「快取擊穿」相同，解法一致。

#### 問題 3：多台 Redis 的 Key 分配問題

傳統 `mod(md5(key), n)` 分配：新增 Redis Server 時（n 改變），所有 cache 全部失效。

**解法：Consistent Hash（一致性雜湊）**

- 新增/移除節點時，只有少部分 Key 需要重新分配
- Redis Cluster 內建此功能（透過 Hash Slot）

#### 問題 4：快取預熱（Cache Warm-up）

系統啟動時快取為空，冷啟動流量全打 DB。

**解法**：用 Crontab 或啟動腳本，在流量來之前預先將熱點資料寫入 Redis。

---

### 四、Redis Cluster 架構

Redis Cluster 解決三大問題：

#### 問題 1：多台 Redis 如何互相協作？

使用 **Gossip 協議**（P2P，無中央管理者）：

- 每個節點維護 Cluster 中所有節點的狀態
- 訊息傳播：A 發現 B 異常 → 告知鄰近節點 → 逐步擴散 → 最終一致

#### 問題 2：Client 如何不透過 Proxy 讀寫？

使用 **Hash Slot**（共 16384 個 Slot）：

```
HASH_SLOT = CRC16(key) mod 16384
```

- Cluster 初始化時，16384 個 Slot 均分給各 Master
- Client 向任意節點詢問 → 節點計算 Slot → 回傳負責的節點 → Client 直連

#### 問題 3：節點掛掉如何自動恢復？

使用 **Master-Slave 架構**（支援 Fail-Over）：

```
Master 1 (Slot 0~5460)     Master 2 (Slot 5461~10922)    Master 3 (Slot 10923~16383)
  └─ Slave 1A                └─ Slave 2A                    └─ Slave 3A
```

- Master 負責讀寫，Slave 備份並分擔讀取
- Master 掛掉 → Slave 自動升為 Master（Fail-Over）
- **注意**：Master-Slave 異步同步，Master 剛寫入但未同步到 Slave 時若掛掉，可能丟失最後一批寫入

**緩解：使用 `WAIT` 指令**，等待 Slave 確認同步再回應。

---

### 五、Redis vs 其他快取

| | Redis | Memcached | 本地快取（Caffeine） |
|-|-------|-----------|-------------------|
| 資料結構 | 豐富（5+ 種） | 只有 String | 依語言 |
| 持久化 | 支援 | 不支援 | 不支援 |
| Cluster | 內建 | 需外部協調 | 無（單機） |
| 適用 | 集中式快取、分散式鎖 | 單純 KV 快取 | 本地熱點快取 |

---

## 參考

- 來源：Notion 開發學習筆記 — 中介層 > Redis 簡介 / Cache / Cluster
