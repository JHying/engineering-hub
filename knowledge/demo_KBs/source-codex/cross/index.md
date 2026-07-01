# Cross-Service Resources 索引

> 跨服務共享資源統一索引，以服務為主軸 upsert。
> 每次異動服務間資源（Kafka topic、Redis key、DB schema）時更新此目錄。

## 索引文件

| 文件 | 說明 |
|------|------|
| [service-map.md](service-map.md) | 各服務 sync 狀態、本機路徑、負責人 |

## 查詢方式

- **「這個 Kafka topic 由誰發、誰收？」** → 在此目錄建立 `kafka-topology.md`
- **「這個 Redis key 誰寫誰讀？」** → 在此目錄建立 `redis-keymap.md`
- **「這張 DB table 涉及哪些服務？」** → 在此目錄建立 `db-tablemap.md`

> 以上文件在 demo_KBs 中尚未建立，依實際需求新增。
