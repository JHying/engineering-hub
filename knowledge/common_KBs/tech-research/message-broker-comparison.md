---
date: 2026-06-27
keywords: Message Broker, RabbitMQ, Kafka, AMQP, MQ, 訊息佇列, Exchange, 解耦, 異步, 削峰
---

# Message Broker 選型與 RabbitMQ 核心概念

**日期**：2026-06-27
**關鍵字**：Message Broker, RabbitMQ, Kafka, AMQP, Exchange, Queue, 解耦, 異步, 削峰

## 問題背景

微服務架構中服務間通訊有同步（HTTP/gRPC）與非同步（MQ）兩種模式。MQ 解決的核心問題是解耦、異步與削峰，但不同 MQ 產品在吞吐量、延遲、可靠性上各有取捨，需依場景選型。

協議層面的定位（MQTT/STOMP/AMQP 家族 vs Kafka/Redis 自有協議、選型思考順序）見 [messaging-protocols-vs-platforms.md](messaging-protocols-vs-platforms.md)。（2026-07-12 註記）

---

## 研究結論

### 一、MQ 三大作用

| 作用 | 說明 |
|------|------|
| **解耦** | 服務之間不直接依賴，透過 MQ 傳遞消息 |
| **異步** | 主流程放入 MQ 後不等待，從流程非同步處理 |
| **削峰** | 高峰期請求先堆入 Queue，消費者按能力消費，避免系統崩潰 |

---

### 二、四大 MQ 選型比較

| 特性 | ActiveMQ | RabbitMQ | RocketMQ | Kafka |
|------|---------|---------|---------|-------|
| 開發語言 | Java | Erlang | Java | Scala |
| 單機吞吐量 | 萬級 | 萬級 | 10 萬級 | 10 萬級 |
| 消息延遲 | ms 級 | **µs 級** | ms 級 | ms 級內 |
| 可用性 | 高（主從） | 高（主從） | 非常高（分布式） | 非常高（分布式） |
| 消息丟失 | 低 | 低 | 理論不丟 | 理論不丟 |
| 管理介面 | 一般 | **好** | Web Console | 無（需第三方） |
| 協議 | AMQP、STOMP 等多種 | AMQP | 自定義 | 自定義 |
| 適用場景 | 傳統企業 MQ | 低延遲、靈活路由 | 大規模企業 | 大數據、日誌流 |

**選型建議：**
- 需要靈活路由、低延遲、管理介面好 → **RabbitMQ**
- 需要高吞吐、大數據流處理 → **Kafka**

---

### 三、AMQP 協議核心模型

```
Publisher → Exchange → Binding → Queue → Consumer
               └──────── Virtual Host / Broker ───────┘
```

#### Exchange 四種類型

| 類型 | 路由規則 | 典型用途 |
|------|---------|---------|
| **Direct** | Routing Key 完全匹配 | 點對點精確路由 |
| **Fanout** | 廣播到所有綁定 Queue | 群發通知、排行榜更新 |
| **Topic** | Routing Key 模糊匹配（`*`、`#`） | 按主題分類路由 |
| **Headers** | 依 Message Headers 匹配 | 少用 |

---

### 四、RabbitMQ 核心概念

| 概念 | 說明 |
|------|------|
| Exchange | 交換機，負責路由消息到 Queue |
| Queue | 存放待消費消息的隊列（持久化 / 暫存） |
| Binding | Exchange 到 Queue 的路由規則 |
| Channel | 共享 TCP 連線的輕量虛擬連線（每執行緒一個） |
| vHost | 虛擬主機，隔離不同環境 / 業務的 Exchange + Queue |
| ACK | 消費者確認回執，未 ACK 前 Broker 不刪除消息 |
| DLQ | Dead Letter Queue，無法路由或被拒絕的消息 |

#### 消息確認模式

- **自動確認**：Broker 發送後立即刪除（可能丟消息）
- **顯式確認**：消費者處理完後發送 ACK，Broker 才刪除（推薦）

#### 前端整合

RabbitMQ 開啟 Web STOMP 插件後，前端可透過 WebSocket + STOMP 直連，實現 Browser ↔ RabbitMQ 即時通訊。

---

## 參考

- 來源：Notion 開發學習筆記 — 中介層 > MQ Message Broker / RabbitMQ
