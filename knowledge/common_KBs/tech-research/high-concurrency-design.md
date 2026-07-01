---
date: 2026-06-27
keywords: 高併發, RPS, QPS, TPS, 鎖, 悲觀鎖, 樂觀鎖, 分布式鎖, Redisson, 讀寫分離, 分庫分表, Saga, TCC, CQRS, Event Sourcing, Redis Lua, CAS, 冪等性, INCRBY, DECRBY, SET NX
---

# 高併發設計：指標、鎖機制與分布式鎖

**日期**：2026-06-27
**關鍵字**：高併發, RPS, QPS, TPS, 悲觀鎖, 樂觀鎖, 分布式鎖, Redisson, Redis SETNX, 分庫分表, Saga, TCC, CQRS, Event Sourcing

## 問題背景

系統承受高流量時，需要從指標評估、應用層優化、資料庫優化三個維度設計。同時，多節點部署下 JVM 內建鎖失效，需要分布式鎖機制保證互斥。

---

## 研究結論

### 一、高併發常用指標

| 名詞 | 說明 |
|------|------|
| RPS | 每秒請求數（應用層，衡量 API / Web 服務吞吐） |
| QPS | 每秒查詢數（資料庫層，衡量 DB 讀寫能力） |
| PV | 頁面瀏覽量（24 小時內訪問頁面數） |
| UV | 獨立訪客數（同一訪客多次只計一次） |
| 吞吐量 | 單位時間內處理的請求量 |
| 併發數 | 系統同時處理的請求數 |
| 響應時間（RT） | 請求發出到收到響應的時間 |

> RPS 與 QPS 的關鍵差異：RPS 衡量應用層入口流量，QPS 衡量資料庫層查詢壓力；一次 RPS 請求可能觸發多次 QPS 查詢。

### 二、依請求規模（RPS）的建議方案

| RPS 範圍  | 建議方案        |
| ------- | ----------- |
| < 50    | 一般伺服器即可     |
| > 100   | DB 快取、負載平衡  |
| > 800   | CDN 加速、負載均衡 |
| > 1,000 | 分庫分表、讀寫分離   |
| > 2,000 | 業務拆分、微服務架構  |

### 三、依交易規模（TPS）的架構建議

TPS 衡量完整事務（ACID）的吞吐，每筆 transaction 涉及多步驟操作，成本遠高於單次 RPS 請求。架構重心隨規模從「強一致性」逐步轉向「放寬一致性換取吞吐」。

| TPS 範圍 | 架構重心 | 關鍵模式 |
|---------|---------|---------|
| < 100 | 強一致性優先 | 單體 + 本地事務（ACID、`@Transactional`） |
| 100 – 1,000 | 讀寫壓力分散 | 讀寫分離、連線池（HikariCP）、`@Async` 非同步 |
| 1,000 – 10,000 | 削峰 + 分布式事務 | MQ 削峰、Saga / TCC、冪等設計 |
| > 10,000 | 一致性降級換吞吐 | CQRS、Event Sourcing、最終一致性（BASE） |

#### 各層架構流程

**< 100 TPS — 本地事務**
```
Request → Service → DB（單一事務，ACID 保證）
```

**100 – 1,000 TPS — 讀寫分離 + 非同步**
```
Write → Master DB
Read  → Slave DB（或 Redis 快取）
耗時操作 → @Async / CompletableFuture
```

**1,000 – 10,000 TPS — MQ 削峰 + 分布式事務**
```
Request → 校驗 → MQ（Kafka）→ Consumer 非同步處理
                                ↓
                     Saga / TCC 協調跨服務事務
```
- **Saga**：每步有補償操作，失敗時反向回滾（最終一致）
- **TCC**（Try / Confirm / Cancel）：預留資源 → 確認 → 或取消（強一致但複雜）
- 必須設計**冪等**防止 MQ 重試導致重複交易

**> 10,000 TPS — CQRS + Event Sourcing**
```
Command Side：寫入 Event Log（append-only）→ 發布 Event
Query Side  ：訂閱 Event → 更新 Read Model（獨立 DB / Redis）
```
- 讀寫完全解耦，各自獨立擴展
- 以 Event Log 為事實來源，狀態可重放
- 一致性模型從 ACID 降級為 BASE（最終一致）

#### 業界 TPS 參考值

| 系統 | 峰值 TPS |
|------|---------|
| VISA 全球 | 均值 ~1,700，峰值 ~24,000 |
| 支付寶（雙十一） | 峰值 ~54,000（2019） |
| Bitcoin | ~7（協議上限） |

#### 一致性 vs 吞吐量取捨

```
吞吐量  高 ←————————————————————————→ 低
        BASE         最終一致       ACID
        Event Sourcing  Saga/TCC  本地事務
        CQRS         MQ削峰       讀寫分離
一致性  低 ←————————————————————————→ 高
```

---

### 四、通訊層並發模型：Virtual Thread + XNIO（WebSocket 事務處理）

傳統 thread-per-connection 在高併發 WebSocket 場景下會因 OS thread 記憶體與排程開銷達到上限（C10K 問題）；Reactive 雖可解決，但需全面改寫 call stack。Virtual Thread 提供第三條路：保留 imperative 程式碼風格，同時達到 reactive 級別吞吐。

#### 兩層執行模型

```
┌─ XNIO Event Loop（少量 platform threads，≈ CPU 核心數）─────┐
│  負責：accept connection、讀取 WS frames（non-blocking）      │
│  規則：不可 park / block，不轉換為 virtual threads            │
└──────────────────────────┬──────────────────────────────────┘
                           │ frame 交付
┌─ Virtual Thread Executor ▼──────────────────────────────────┐
│  負責：業務邏輯、DB query、Redis、gRPC、外部 HTTP            │
│  特性：blocking 呼叫時 park，釋放 carrier thread 給其他 VT  │
│  規模：可同時調度數十萬 virtual threads，stack 開銷極低      │
└─────────────────────────────────────────────────────────────┘
```

#### 與 TPS 架構的關係

Virtual Thread 消除的是**通訊層的 I/O 等待瓶頸**，而不是業務事務本身的複雜度：

| 瓶頸來源 | Virtual Thread 的效果 |
|---------|----------------------|
| OS thread 耗盡（連線數） | 直接解決，可承載 C10K+ 並發連線 |
| I/O 等待（DB / Redis / gRPC） | 透過 park 釋放 carrier thread，不浪費 |
| 業務邏輯 CPU 計算 | 無幫助，CPU-bound 任務需另設 bounded platform-thread pool |
| 下游資源 QPS 上限（DB / Redis） | 無幫助，需配合分庫分表 / 讀寫分離 |

#### 注意事項

- **CPU-bound 任務**不應在 virtual threads 上執行，避免 carrier thread 被佔滿，需另設獨立 bounded platform-thread pool
- **Tracing context** 不自動跨 virtual thread 傳遞，需在 executor 層手動 wrap（e.g. MDC copy）
- **Synchronized pinning**：若 virtual thread 內部呼叫到含 `synchronized` 的程式碼，會 pin 到 carrier thread 失去讓出能力，需注意第三方函式庫相容性（參見 ADR-0019）

#### 對交易並發的實際效果

Virtual Thread 解決的是**等待期間互卡**，而非業務資源競爭：

```
Platform Thread（傳統）：
Thread 1: [業務] [==等DB==] [業務]     ← 等待期間卡住，無法服務其他請求
Thread 2: [業務] [==等Redis==] [業務]

Virtual Thread：
VT 1:  [業務] park...      resume [業務]   ← park 後 carrier thread 立刻給 VT 3
VT 2:  [業務]      park... resume [業務]
VT 3:  [業務] [業務]                       ← 趁 VT1/VT2 park 時執行
```

- **不同用戶 / 不同資源的交易**：真正並行，I/O 等待期間不互佔 thread，吞吐量大幅提升
- **相同資源的交易**（同一筆訂單、同一帳戶餘額）：仍需鎖（DB `FOR UPDATE`、Redisson）保證資料正確性，這是業務層的互斥，不是 thread 模型能解決的

> Virtual Thread 與鎖機制是互補的兩層：前者消除 I/O 等待造成的 thread 浪費，後者處理業務資源的競爭衝突。

> 參考：[ADR-0019 — Virtual threads over reactive for I/O-bound concurrency](../ADRs/02-coding-standards/0019-virtual-threads-over-reactive.md)

---

### 五、各層優化策略

- **前端**：減少 HTTP 請求、非同步載入、瀏覽器快取、壓縮
- **流量**：防盜鏈、限流
- **服務端**：頁面靜態化、佇列緩衝
- **Web 伺服器**：負載平衡（多 Tomcat / Undertow 節點）
- **資料庫**：Redis 快取、分庫分表、讀寫分離、建立索引、Partition Table

---

### 六、鎖機制

#### 悲觀鎖（Pessimistic Lock）

> 假設衝突一定發生，先鎖再操作

- Java：`synchronized`、`ReentrantLock`
- DB：`SELECT ... FOR UPDATE`
- **優點**：強制順序，資料絕對安全
- **缺點**：吞吐量下降，長事務影響用戶體驗

#### 樂觀鎖（Optimistic Lock）

> 假設衝突不一定發生，操作前先確認版本

- 在表中新增 `version` 欄位，更新前比對
- **優點**：不阻塞，吞吐量高
- **缺點**：高衝突場景下大量重試，人工實現可能有漏洞

#### 死鎖（Deadlock）預防

- 固定加鎖順序
- 使用 `tryLock` 設定超時

#### Java 常用鎖

| 鎖 | 說明 |
|----|------|
| `synchronized` | 最基本的互斥鎖 |
| `ReentrantLock` | 可重入鎖，支援 tryLock 超時 |
| `ReadWriteLock` | 讀讀不互斥，提高讀吞吐 |
| `StampedLock` | 比 ReadWriteLock 更高效，支援樂觀讀 |

---

### 七、分布式鎖

#### 為什麼需要？

JVM 內建的 `synchronized` 只能鎖單一進程。多節點（Pod）部署時，需要跨節點互斥，要求：
- **互斥性**：任意時刻只有一個節點持有鎖
- **鎖超時**：持有鎖的節點異常時，其他節點仍能獲取
- **防誤解鎖**：只有持有鎖的人才能解鎖

#### 常見實作比較

| 方式 | 說明 | 效能 |
|------|------|------|
| Redis SETNX | `SET key value NX PX ms`，原子操作 | 高 |
| Redisson | 封裝 Redis，Watch Dog 自動續期 | 高 |
| Zookeeper | 臨時有序節點，可靠性高 | 中 |
| DB 唯一索引 | `SELECT FOR UPDATE` | 低，不建議高併發用 |

#### Redisson 範例（Spring Boot）

```java
RLock lock = redissonClient.getLock("myLock");
try {
    lock.lock(10, TimeUnit.SECONDS);
    // 臨界區業務邏輯
} finally {
    lock.unlock();
}
```

#### 注意事項

- Key 必須包含業務前綴，確保唯一性
- 必須設定過期時間，避免死鎖
- 釋放鎖前確認 value 是否是自己的（防誤解鎖）

---

### 八、Redis 交易原子性設計模式

在高併發交易場景中，Redis 透過 Lua script 的原子性，提供三個互補的設計模式。三者解決的問題不同，可依需求單獨或組合使用。

#### 模式一：安全增減（防止超限）

`INCRBY` / `DECRBY` 本身是原子的，但無法防止數值超出邊界（例如庫存扣成負數）。需用 Lua 將「檢查 + 操作」合為一個原子單元：

```lua
-- 安全扣減：current >= amount 才允許扣，否則拒絕
local current = tonumber(redis.call('GET', KEYS[1]))
if current == nil then return -1 end          -- key 不存在
if current < tonumber(ARGV[1]) then return -2 end  -- 數量不足
return redis.call('DECRBY', KEYS[1], ARGV[1])
```

**適用**：庫存扣減、配額消耗、座位預留等需防止超限的計數場景

> 數值建議以**整數最小單位**儲存（避免浮點精度問題），例如金額存分而非元。

---

#### 模式二：冪等性保護（防止重複執行）

分布式環境下，MQ 重試或網路重傳可能導致同一操作被觸發多次。以唯一請求 ID 搭配 `SET NX` 確保只執行一次：

```lua
-- 以 requestId 為 key，NX 保證只有第一次能寫入
-- KEYS[1] = 資源 key, KEYS[2] = 冪等 key（requestId）
local inserted = redis.call('SET', KEYS[2], '1', 'NX', 'EX', tonumber(ARGV[2]))
if inserted == false then
    return -99   -- 重複請求，直接拒絕
end
-- 通過冪等檢查，再執行實際操作
local current = tonumber(redis.call('GET', KEYS[1]))
if current == nil then return -1 end
if current < tonumber(ARGV[1]) then return -2 end
return redis.call('DECRBY', KEYS[1], ARGV[1])
```

**requestId** 由呼叫端在發起請求前生成（如 UUID），帶在 header 或 body，同一業務操作無論重試幾次都帶同一個 ID：

```
第一次請求（requestId: req-abc）→ SET req-abc NX → 成功 → 執行操作
第二次請求（requestId: req-abc）→ SET req-abc NX → 失敗 → 回傳重複
```

**適用**：任何需要防止重複執行的操作（扣款、送出通知、狀態變更）

---

#### 模式三：CAS（Compare-and-Swap，條件更新）

只有當前狀態符合預期，才允許轉移到下一個狀態。防止非法狀態跳躍，也防止多個 worker 同時搶佔同一個任務：

```lua
-- KEYS[1] = 狀態 key
-- ARGV[1] = 期望的當前狀態, ARGV[2] = 要更新成的目標狀態
local current = redis.call('GET', KEYS[1])
if current == ARGV[1] then
    redis.call('SET', KEYS[1], ARGV[2])
    return 1   -- 成功
end
return 0       -- 狀態不符，拒絕更新
```

**典型狀態機範例**：

```
pending → processing → completed
                     ↘ failed

Worker A、B 同時嘗試將 pending 改為 processing：
  Worker A → Lua: current("pending") == expected("pending") → SET → 成功
  Worker B → Lua: current("processing") == expected("pending") → 不符 → 拒絕
```

若需更嚴格的防護，可加入 `version` 欄位，與 DB 樂觀鎖的 `WHERE version = ?` 概念相同：

```lua
local data = redis.call('HMGET', KEYS[1], 'status', 'version')
if data[1] == ARGV[1] and data[2] == ARGV[2] then
    redis.call('HMSET', KEYS[1],
        'status', ARGV[3],
        'version', tostring(tonumber(ARGV[2]) + 1))
    return 1
end
return 0
```

**適用**：任務狀態流轉、工作搶佔、流程節點推進

---

#### Cluster 注意事項

| 注意點 | 說明 |
|-------|------|
| 同一 Lua script 的所有 key 必須在同一 hash slot | Cluster 限制；若需跨 key 原子操作，用 hash tag `{group}` 強制同 slot，但會降低分散效果 |
| hash tag 可能造成熱點 | 同一 `{group}` 下的 key 全落同一 node，流量集中時需評估 |
| 關鍵計數 key 不要設 TTL | 意外過期後 GET 回 nil，Lua script 需有 `if current == nil` 防禦 |
| 用 `CLUSTER KEYSLOT {key}` 驗證分布 | 確認命名策略實際產生的 slot 分布是否均勻 |

#### 三個模式總覽

| 模式 | 解決的問題 | 核心機制 |
|------|-----------|---------|
| 安全增減 | 數值超限（庫存變負、配額超用） | Lua check + DECRBY |
| 冪等性保護 | 重複請求（MQ retry、網路重傳） | SET NX + requestId |
| CAS | 非法狀態轉移、concurrent 搶佔 | Lua compare + SET |

---

### 九、資料庫分庫分表

| 策略 | 說明 | 優缺點 |
|------|------|--------|
| 讀寫分離 | 寫入走 Master，讀取走 Slave | 有效分散讀壓力 |
| 分庫分表 | 業務隔離，分散式儲存 | 跨庫 JOIN、分散式事務複雜 |
| Partition Table | 同一資料庫內按欄位切割（如 Timestamp） | 無跨庫問題，但單機上限 |
| 建立索引 | 高頻查詢欄位建索引 | 加速查詢，寫入略慢 |

> Redis 快取搭配悲觀鎖約可承受 5 萬 QPS。

---

## 參考

- 來源：Notion 開發學習筆記 — 架構框架 > 高併發
