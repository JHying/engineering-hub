---
date: 2026-06-27
keywords: OLTP, OLAP, ACID, 資料倉庫, BigQuery, 讀寫分離, 列式儲存, ETL
---

# OLTP vs OLAP 與 ACID 特性

**日期**：2026-06-27
**關鍵字**：OLTP, OLAP, ACID, 資料倉庫, BigQuery, 列式儲存, ETL, BI

## 問題背景

系統設計時常需要區分「交易型資料庫」與「分析型資料庫」的使用情境，兩者在架構、一致性要求、查詢模式上截然不同，混用會造成效能問題或設計缺陷。

---

## 研究結論

### OLTP（Online Transaction Processing）線上事務處理

- 支援日常業務操作，強調即時性與一致性
- 大量短小事務，**寫入密集**
- 嚴格遵守 ACID，確保多用戶並發下資料正確性
- 典型用途：電商訂單、銀行轉帳、ERP

### OLAP（Online Analytical Processing）線上分析處理

- 大量擷取資料進行聚合分析，**讀取密集**
- 列式儲存（Columnar Storage）效率更高
- 不強調一致性，重視查詢速度
- 典型用途：BI 報表、資料倉庫、大數據分析

---

### 對比表

| | OLTP | OLAP |
|--|------|------|
| 操作 | 新增/修改/刪除 | 查詢/分析 |
| 資料量 | 少（當前資料） | 大（歷史資料） |
| 回應時間 | 毫秒級 | 秒至分鐘級 |
| 典型 DB | MySQL, Oracle, MSSQL | BigQuery, Redshift, ClickHouse |
| 模式 | 第三正規化 | 星型 / 雪花型 |
| 雲端服務 | Cloud SQL, RDS | BigQuery, Amazon Redshift |

---

### ACID 四大特性（OLTP 核心要求）

| 特性 | 說明 |
|------|------|
| **Atomicity（原子性）** | 事務中所有操作全部完成或全部不完成，不中途結束 |
| **Consistency（一致性）** | 事務前後資料庫完整性不被破壞 |
| **Isolation（隔離性）** | 多個並發事務互不影響（隔離級別：Read Uncommitted → Serializable） |
| **Durability（持久性）** | 事務完成後修改永久保存，即使系統故障也不丟失 |

> 隔離級別由低到高：Read Uncommitted → Read Committed → Repeatable Read → Serializable

---

### 搭配使用模式

```
OLTP（寫入、保證一致性）
        ↓ ETL / CDC
OLAP（歷史資料分析、BI 報表）
```

兩者互補：OLTP 確保資料正確性，OLAP 提供商業洞察。典型架構為 OLTP 資料庫定期 ETL 到資料倉庫（如 BigQuery），再用 BI 工具查詢。

---

### Database vs Data Warehouse

| | Database（資料庫） | Data Warehouse（資料倉庫） |
|--|-----------------|------------------------|
| 使用情境 | 應用程式即時讀寫 | 多來源資料深度分析 |
| 特色 | ACID / key-value | 高度結構化，有 ETL 過程 |
| 地端 | MySQL, MongoDB | Snowflake, IBM Db2 Warehouse |
| 雲端 | Cloud SQL, Bigtable | BigQuery, Redshift, Azure Synapse |

---

## 參考

- 來源：Notion 開發學習筆記 — DB相關 > OLTP v.s OLAP
