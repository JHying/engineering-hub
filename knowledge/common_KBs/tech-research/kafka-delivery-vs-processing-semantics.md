---
date: 2026-07-27
keywords: Kafka, 投遞語意, delivery semantics, 處理語意, processing semantics, idempotency, exactly-once, at-least-once, transactional.id, enable.idempotence, isolation.level, sendOffsetsToTransaction, processing.guarantee, Kafka Streams
---

# Kafka 投遞語意（at-least-once）與處理語意（idempotent/exactly-once）的區分

**日期**：2026-07-27
**關鍵字**：Kafka, 投遞語意, 處理語意, idempotency, exactly-once, at-least-once, transactional.id, isolation.level, sendOffsetsToTransaction, processing.guarantee

## 問題背景

「Kafka 訊息會不會遺失」與「Kafka 訊息重複投遞會不會造成資料副作用（例如重複扣款、重複建單）」
是兩個常被混為一談的問題，實務討論中甚至會互相誤用詞彙（例如把「處理上不會重複」誤稱為
at-most-once，但實際機制其實是 at-least-once 投遞 + 應用層去重）。需要釐清：

1. 要保證訊息「不遺失」，consumer/producer 端該如何配置（投遞語意，delivery semantics）。
2. 要保證訊息「重複投遞也不會造成業務副作用」，依下游目標不同（Kafka topic vs 外部系統）
   分別該如何設計（處理語意/幂等性，processing semantics / idempotency）。

## 研究結論

### 一、at-least-once 投遞：避免訊息遺失

**Consumer 端**：關閉自動 commit，改為業務邏輯處理成功後才手動 commit。

```properties
enable.auto.commit=false
```

```java
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(500));
    for (ConsumerRecord<String, String> record : records) {
        process(record); // 業務邏輯處理
    }
    consumer.commitSync(); // 處理成功後才手動 commit offset
}
```

若停留在自動 commit 模式（`enable.auto.commit=true`），offset 可能在訊息「還沒處理完」就被
背景執行緒依時間間隔（`auto.commit.interval.ms`）自動 commit；此時若 consumer 當機，重啟後會
從已 commit 的 offset 之後繼續消費，等同漏掉那筆尚未真正處理完的訊息（退化成 at-most-once
的風險）。手動 commit 且明確放在「業務處理成功之後」，才能保證「未 ack 前持續可重試、不遺失」。

**Producer 端**：搭配 `acks=all`（等所有 in-sync replica 確認寫入）與 `retries`，避免訊息連
broker 都沒真正寫入就遺失。

```properties
acks=all
retries=2147483647
```

### 二、處理語意（idempotency）：依下游目標分兩種情境

投遞語意解決「訊息會不會不見」，但 at-least-once 的代價是訊息可能被重複投遞（例如 commit
offset 前當機、重試）。這筆重複投遞會不會造成業務副作用，取決於下游是什麼系統。

#### 情境 A：下游是另一個 Kafka topic（Kafka-to-Kafka）

可用 Kafka 原生 transaction，讓「讀取端 offset commit」與「寫入下游 topic」包進同一個
transaction，兩者要嘛一起成功、要嘛一起失敗。

Producer 端設定：

```properties
transactional.id=my-transactional-producer
enable.idempotence=true
```

下游 consumer 端設定，只讀取已提交的 transaction：

```properties
isolation.level=read_committed
```

應用程式碼把讀取 offset 與寫出訊息包進同一個 transaction：

```java
producer.initTransactions();
try {
    producer.beginTransaction();

    producer.send(new ProducerRecord<>("downstream-topic", key, value));

    Map<TopicPartition, OffsetAndMetadata> offsets = currentOffsets(records);
    producer.sendOffsetsToTransaction(offsets, consumerGroupId);

    producer.commitTransaction();
} catch (Exception e) {
    producer.abortTransaction();
}
```

若使用 Kafka Streams，可直接設定 `processing.guarantee=exactly_once_v2`，由框架代管上述
transaction 行為，不需自行組裝 `sendOffsetsToTransaction()`。

```properties
processing.guarantee=exactly_once_v2
```

#### 情境 B：下游是外部系統（例如資料庫）

Kafka 自身的 exactly-once / transaction 保證管不到 Kafka 生態系以外的系統——`transactional.id`
與 `sendOffsetsToTransaction()` 只能協調「Kafka topic 之間」的原子性，一旦下游是 DB 或其他
外部服務，必須在應用層額外設計 idempotency。常見兩種做法：

**做法 1：業務去重鍵（unique constraint / upsert）**

從訊息取一個唯一 key（業務 ID，或 `topic-partition-offset` 組合），寫入時用 unique
constraint 或 upsert，讓同一則訊息重複處理也只留一筆結果。

```sql
INSERT INTO orders (dedup_key, order_id, amount, status)
VALUES (:topicPartitionOffset, :orderId, :amount, 'CREATED')
ON CONFLICT (dedup_key) DO NOTHING;
```

**做法 2：offset 存進下游系統的同一個 transaction**

不依賴 Kafka 自己的 committed offset store，而是在寫業務資料的同一個 DB transaction 裡，
一併把該訊息的 offset 寫進一張追蹤表；consumer 重啟時，先查詢「上次處理到哪個 offset」，
用 `consumer.seek()` 手動定位，而非信任 Kafka 的 committed offset。如此「業務資料寫成功」
與「這則訊息算處理過」成為同一個原子操作。

```java
// 啟動時：從自訂 offset 追蹤表讀回上次進度，手動 seek
long lastOffset = offsetRepository.getLastProcessedOffset(topicPartition);
consumer.seek(topicPartition, lastOffset + 1);

// 處理時：業務資料寫入與 offset 記錄在同一個 DB transaction
@Transactional
void handle(ConsumerRecord<String, String> record) {
    orderRepository.save(toOrder(record));
    offsetRepository.saveOffset(record.partition(), record.offset());
}
```

### 三、核心結論

「訊息會不會遺失」（投遞保證，delivery semantics）與「重複投遞會不會造成資料副作用」
（處理保證/idempotency，processing semantics）是**兩個分開的決策維度**，實務上常被混為一談、
甚至用詞互相替代。

- Kafka 原生 exactly-once（`transactional.id` + `enable.idempotence` + `read_committed` +
  `sendOffsetsToTransaction()`，或 Kafka Streams 的 `processing.guarantee=exactly_once_v2`）
  **只在 Kafka-to-Kafka 場景適用**。
- 下游若是外部系統（如 DB），Kafka 本身無法提供端到端 exactly-once 保證，必須靠應用層額外
  設計 idempotency（去重鍵 upsert，或把 offset 追蹤併入下游 transaction）。

決策時應分開回答兩個問題：「訊息會不會不見？」（決定 producer/consumer 的 ack 與 commit
配置）與「重複投遞會不會造成副作用？」（決定下游是否需要應用層去重設計），不要用同一組
配置或同一個詞彙同時處理兩者。

## 參考

- [message-broker-comparison.md](message-broker-comparison.md) — MQ 產品選型比較
  （ActiveMQ/RabbitMQ/RocketMQ/Kafka 吞吐、延遲、可用性）與 RabbitMQ 核心概念
  （Exchange/ACK/DLQ），非本篇聚焦的 Kafka 語意配置細節。
- [messaging-protocols-vs-platforms.md](messaging-protocols-vs-platforms.md) — 訊息協議家族
  （MQTT/STOMP/AMQP）vs 自有協議平台（Kafka/Redis）的定位分野，本篇則聚焦 Kafka 內部的
  投遞/處理語意配置實作。
