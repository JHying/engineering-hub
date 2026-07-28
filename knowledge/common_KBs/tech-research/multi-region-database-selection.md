---
date: 2026-07-28
keywords: AWS, Oracle, MongoDB, DynamoDB, Cassandra, CAP, PACELC, ACID, NewSQL, 跨區, multi-region, Global Tables, Global Clusters
---

# AWS 跨地理區域（Multi-Region）資料庫選型比較

**日期**：2026-07-28
**關鍵字**：AWS, Oracle, MongoDB, DynamoDB, Cassandra, CAP, PACELC, ACID, NewSQL, 跨區, multi-region, Global Tables, Global Clusters

## 問題背景

團隊要為一個多地理區域部署的即時分析系統做資料庫選型，需要比較 AWS 上各資料庫在「跨區複寫」能力上的差異，以及跨區能力與 ACID 強一致性之間的取捨。

本篇聚焦「跨區/multi-region」場景與 CAP / PACELC / ACID 的關聯，與同庫 [nosql-vs-rdbms.md](nosql-vs-rdbms.md) 聚焦的「單機/單區選型」定位不同，屬於不同主題的延伸研究。

---

## 研究結論

### 一、Oracle（RDS for Oracle 或 EC2 自架）

- 強 ACID、複雜 JOIN、stored procedure 齊全，適合遷移既有企業系統、帳務/財務類需要嚴格一致性的場景
- 跨區弱點：AWS 沒有原生的 Oracle 多區 active-active 方案。跨區要嘛用 Data Guard（async standby，DR 用，非同時可寫），要嘛上 GoldenGate 做 active-active 複寫——授權費貴、維運複雜、衝突處理要自己設計
- Oracle 骨子裡是為單一權威節點設計的，跨區是「事後加裝」的能力，不是原生架構

### 二、MongoDB（自架 / MongoDB Atlas / AWS DocumentDB）

- Document model，schema 彈性、內建 sharding + replica set
- 跨區用 Atlas Global Clusters：可用 zone sharding 把資料依地理位置釘選到特定 region（同時滿足資料落地法規 + 就近讀寫延遲）
- 注意：AWS 的 DocumentDB 不是真正的 MongoDB——它是包了 MongoDB API 相容層、底層存儲用 Aurora 架構，不支援真正的分散式 sharding 寫入擴展，跨區靠 Global Database（storage 層複寫 + 唯讀複本），若需要完整 MongoDB 功能（真 sharding、完整 aggregation、multi-doc transaction），應選 Atlas 而非 DocumentDB
- ACID 澄清：MongoDB 4.0 起支援 single-replica-set 多文件交易，4.2 起支援 sharded cluster 跨分片交易，是貨真價實的 ACID，只是效能代價高、官方也不建議把它當主要設計模式用（單文件寫入本來就原子，這才是 MongoDB 建議的資料建模方向）

### 三、DynamoDB

- AWS 原生全託管、serverless，內部細節封閉
- Global Tables：開箱即用 multi-master 跨區複寫，維運成本最低，是 AWS 原生「零維運」跨區選項的代表
- Item/attribute 資料模型，單表設計為主，access pattern 要先想好，沒有 JOIN

### 四、Cassandra（自架 / Amazon Keyspaces）

- Wide-column store，masterless、peer-to-peer gossip ring 架構
- 一致性可調：per-query 可指定 Consistency Level（ONE/QUORUM/ALL），是它相對 DynamoDB 最大的優勢——同一張表不同查詢可自行權衡一致性換延遲
- 跨區複寫用 NetworkTopologyStrategy，Cassandra 設計之初就是為多資料中心而生（源自 Amazon Dynamo 論文，與 DynamoDB 同源但走開源路線）
- Clustering key 適合 time-series、大量寫入場景
- ACID 澄清：Cassandra 沒有傳統 ACID。只有 Lightweight Transaction（LWT）——用 Paxos 做單一 partition 內的 compare-and-set，沒有多列/多表的 rollback 機制。這是它身為 AP 系統（犧牲強一致換可用性/延遲）的設計必然，不是功能缺失
- Amazon Keyspaces 是 AWS 託管的 Cassandra 相容服務，減輕維運但 CQL 功能有 gap

### 五、DynamoDB vs Cassandra 比較表

| 面向 | DynamoDB | Cassandra（含 Amazon Keyspaces） |
|---|---|---|
| 定位 | AWS 專屬全託管、serverless | 開源，可自架／多雲／on-prem，Keyspaces 是 AWS 託管相容版 |
| 一致性控制 | 較固定（單區 eventually/strongly consistent 讀，跨區 Global Tables 是 last-writer-wins） | per-query 可調（ONE/QUORUM/ALL） |
| 架構 | 內部細節封閉，AWS 管理 | Masterless、peer-to-peer gossip ring，架構透明可調 |
| 跨區複寫 | Global Tables，開箱即用 multi-master | NetworkTopologyStrategy，設計之初就為多資料中心而生 |
| 資料模型 | Item/attribute（單表設計為主） | Wide-column，clustering key 適合 time-series |
| 維運 | 零維運，按 RCU/WCU 或 on-demand 計費 | 自架要管 ring/compaction/repair；Keyspaces 減輕但 CQL 功能有 gap |
| 生態整合 | 原生綁 IAM、Streams、Lambda trigger | CQL 語法接近 SQL，跨雲移植性較好 |

### 六、與 CAP 定理 / PACELC 的關聯

- 這些「原生跨區」的系統（DynamoDB Global Tables、Cassandra、MongoDB Atlas Global Clusters）本質上都偏 AP（CAP 定理中犧牲一致性換可用性/分區容錯）
- ACID 要求的強一致性在地理分散、高延遲的網路環境下，天生就跟「低延遲多寫入點」衝突
- PACELC 補充：就算沒有 partition，一致性與延遲之間仍有 trade-off（P 分區時選 A 或 C；否則（Else）選 Latency 或 Consistency）

### 七、需要「跨區 + 完整 ACID」時的選項：NewSQL / Distributed SQL

- 若真的兩者都要，業界的答案是跳出傳統 RDBMS/NoSQL 框架，走 NewSQL / Distributed SQL：
  - Google Spanner：GCP 原生，靠 TrueTime 原子鐘做全球強一致
  - CockroachDB
  - YugabyteDB
- AWS 自己最接近的是 Aurora Global Database，但它是單一 writer region + 唯讀複本（可 promote），不是真正的多區同時寫入強一致，離 Spanner 那種等級還有距離

### 八、決策速查表

| 條件 | 建議 |
|---|---|
| 遷移舊系統、要複雜 JOIN/交易，可接受跨區維運成本 | Oracle（RDS），跨區走 Data Guard/GoldenGate |
| 要完整 MongoDB 功能 + 地理分區 sharding | MongoDB Atlas（避免 DocumentDB，除非能接受閹割版） |
| 要 AWS 原生、零維運、真正 multi-region active-active、access pattern 簡單固定 | DynamoDB Global Tables |
| 要超高寫入吞吐、time-series、需要 per-query 精細調一致性、或不想被 AWS 綁死 | Cassandra / Amazon Keyspaces |
| 需要跨區 + 完整強一致 ACID | NewSQL：Google Spanner / CockroachDB / YugabyteDB；AWS 內最接近方案為 Aurora Global Database（非真正多寫） |

---

## 參考

無
