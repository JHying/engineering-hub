# SOP：Kafka Topic 異動

## 異動類型分級

| 異動類型 | BREAKING | 需要停機 | 說明 |
|---------|---------|---------|------|
| 新增 topic | N | 否 | 直接建立，consumer 後部署 |
| 修改 partition 數量 | **Y** | 否（但影響順序） | 已消費的訊息不受影響，但 partition key 路由會改變 |
| 修改 consumer group | **Y** | 否 | 需評估 offset 繼承或從頭消費 |
| 刪除 topic | **Y** | 是 | 確認所有 consumer 已停止後執行 |
| 修改 retention 設定 | N | 否 | 僅影響資料保留期，不影響功能 |
| 修改 replication factor | N | 否（需 reassignment）| 需用 kafka-reassign-partitions.sh |

## 新增 Topic SOP

```
1. 確認 topic 名稱（命名規範：{domain}-{event}，例：payment-result）
2. 確認 partition 數量（考量 consumer 並行數，建議與 consumer 副本數一致）
3. 確認 replication factor（prod 建議 3）
4. 建立 topic：
   kafka-topics.sh --create \
     --bootstrap-server {broker}:9092 \
     --topic {topic-name} \
     --partitions {n} \
     --replication-factor 3 \
     --config retention.ms=604800000   # 7 天
5. 確認 topic 建立成功：
   kafka-topics.sh --describe --topic {topic-name} --bootstrap-server {broker}:9092
6. Producer 先部署（先發，consumer 尚未消費也無妨）
7. Consumer 後部署
```

## Partition 數量修改 SOP（BREAKING）

> ⚠️ partition 數量只能增加，**不能減少**（Kafka 不支援）。

```
1. 確認影響範圍：哪些 consumer 依賴 partition key 保序
2. 確認是否需要停機視窗（高頻 topic 修改期間可能造成亂序）
3. 修改 partition：
   kafka-topics.sh --alter \
     --bootstrap-server {broker}:9092 \
     --topic {topic-name} \
     --partitions {new-n}
4. 通知相關 consumer team 注意 partition key 路由變更
5. 監控 consumer lag 是否異常
```

## Consumer Group Offset 管理

```bash
# 查詢 consumer lag
kafka-consumer-groups.sh --bootstrap-server {broker}:9092 \
  --group {group-id} --describe

# 重置 offset 到最新（跳過積壓訊息）
kafka-consumer-groups.sh --bootstrap-server {broker}:9092 \
  --group {group-id} --topic {topic} \
  --reset-offsets --to-latest --execute

# 重置 offset 到指定時間點（回溯）
kafka-consumer-groups.sh --bootstrap-server {broker}:9092 \
  --group {group-id} --topic {topic} \
  --reset-offsets --to-datetime 2024-06-01T00:00:00.000 --execute
```

> ⚠️ `--execute` 必須在 consumer 停止後執行，否則 offset 會被 consumer 覆寫。

## Consumer Lag 告警處理

| Lag 狀態 | 可能原因 | 處理方式 |
|---------|---------|---------|
| Lag 緩慢增長 | Consumer 處理速度不足 | 增加 consumer 副本數或 partition 數 |
| Lag 突然暴增 | Consumer 異常停止 / OOM | 檢查 Pod logs，重啟 consumer |
| Lag 不動（consumer 停止） | consumer group 無成員 | 確認 consumer Pod 狀態 |
| Lag 負數 | offset 被重置到未來 | 緊急排查，可能是誤操作 |

## Dead Letter Queue（DLQ）

- 消費失敗超過 `max.poll.interval.ms` 或業務層 throw Exception 且達重試上限時，訊息移至 `{topic-name}-dlq`
- DLQ 的訊息需人工評估是否需要重送（`kafka-console-producer.sh` 或平台工具）
- DLQ 保留 30 天，逾期自動刪除

## SRE 職責邊界

- **負責**：topic 建立 / 監控 consumer lag / DLQ 維運 / partition 調整協調
- **不負責**：決定 partition key 設計、consumer group 命名、訊息格式
- **可建議**：partition 數量、retention 設定、DLQ 策略
