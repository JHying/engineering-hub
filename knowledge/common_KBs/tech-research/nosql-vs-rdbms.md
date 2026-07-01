---
date: 2026-06-27
keywords: NoSQL, RDBMS, CAP, MongoDB, Oracle, MySQL, 關聯式, 非關聯式, 選型, 分散式
---

# NoSQL vs RDBMS 資料庫選型

**日期**：2026-06-27
**關鍵字**：NoSQL, RDBMS, CAP 定理, MongoDB, Oracle, MySQL, Key-Value, Document, Column, Graph

## 問題背景

系統設計選擇資料庫時，關聯式（RDBMS）與非關聯式（NoSQL）各有適用場景。錯誤選型會導致效能瓶頸、維護困難，或無法滿足一致性要求。

---

## 研究結論

### 一、RDBMS（關聯式資料庫）

| 屬性 | 說明 |
|------|------|
| **代表** | MySQL, PostgreSQL, Oracle, SQL Server |
| **資料模型** | 表格（行 + 欄），固定 Schema |
| **查詢** | SQL，支援複雜 JOIN |
| **一致性** | ACID（強一致性） |
| **擴展** | 垂直擴展為主，水平擴展困難 |

**最適情境：**
- 資料結構固定，有複雜關聯查詢
- 金融、ERP、帳務系統（需要 ACID + foreign key）
- 複雜 SQL 報表、stored procedure

---

### 二、NoSQL（非關聯式資料庫）

| 類型 | 代表 | 適用情境 |
|------|------|---------|
| **Key-Value** | Redis | 快取、Session、排行榜 |
| **Document** | MongoDB | 彈性 JSON 結構、API 資料 |
| **Column** | Cassandra, HBase | 大規模寫入、時序資料 |
| **Graph** | Neo4j | 社交關係、推薦系統 |

**最適情境：**
- 大量非結構化資料，Schema 頻繁變動
- 超高寫入 QPS（毫秒級延遲需求）
- 需要水平擴展、多地理區域部署
- IoT、Log、社交媒體、即時分析

---

### 三、CAP 定理

分散式系統三特性只能同時滿足兩個：

| 特性 | 說明 |
|------|------|
| **C（Consistency）一致性** | 每次讀取都能拿到最新寫入的資料 |
| **A（Availability）可用性** | 每次請求都有回應（即使部分節點失效） |
| **P（Partition Tolerance）分區容錯** | 網路分區時系統仍能運作 |

| 選擇 | 代表 | 說明 |
|------|------|------|
| CP | Zookeeper, HBase | 犧牲可用性，保強一致 |
| AP | Cassandra, DynamoDB | 犧牲一致性，保可用性 |
| CA | 傳統 RDBMS | 不考慮分區（單機部署） |

> 實務上 P 幾乎必選（網路分區無法避免），所以實際選擇是 CP 或 AP。

---

### 四、選型決策表

| 條件 | 建議 |
|------|------|
| 高頻率寫入、Schema 不固定 | NoSQL（MongoDB） |
| 高一致性、資料關聯複雜 | RDBMS（Oracle / MySQL） |
| 快速迭代 / 雲端原生 | NoSQL（MongoDB） |
| 傳統企業應用、複雜商業邏輯 | RDBMS |
| 需要多地部署、Sharding | NoSQL |
| 交易、回滾、財務安全 | RDBMS |

---

### 五、MongoDB 詳細適用分析

**適合：**
- 大量寫入 + Schema 彈性（Log, Event, IoT）
- App/API JSON 資料（BSON ↔ JSON 零成本）
- 快速開發 Prototype（省去正規化設計時間）
- 聚合分析（Aggregation Pipeline 效率高）
- 橫向擴充（內建 Sharding）

**不適合：**
- 複雜 ACID 事務（multi-doc transaction 效能差）
- 多表 JOIN 邏輯（NoSQL 無 foreign key，需應用層處理）
- 銀行/財務/帳務系統（強一致性要求）

---

## 參考

- 來源：Notion 開發學習筆記 — DB相關 > NoSQL v.s. RDBMS
