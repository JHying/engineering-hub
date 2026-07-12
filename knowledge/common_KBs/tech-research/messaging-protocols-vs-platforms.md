---
date: 2026-07-12
keywords: MQTT, STOMP, AMQP, Kafka, RabbitMQ, Redis Pub/Sub, Redis Streams, Message Broker, Pub/Sub, Commit Log, Consumer Group, RESP, 訊息佇列, 選型
---

# 訊息協議 vs 自有協議平台：MQTT/STOMP/AMQP、Kafka 與 Redis Pub/Sub

## 問題背景

HTTP、MQTT、STOMP、AMQP、Kafka、Redis Pub/Sub 常被混為一談地放在同一個「訊息系統」框架下
比較，但它們其實分屬不同層次：有的是標準化的 wire-level 訊息協議（MQTT / STOMP / AMQP），
有的是帶專屬協議的平台（Kafka、Redis）。需要釐清「訊息協議 vs 自有協議平台」的分野、
各自的語意強弱，以及實務選型時的判斷順序。

本篇聚焦協議家族與語意定位；MQ 產品選型比較（ActiveMQ/RabbitMQ/RocketMQ/Kafka 吞吐、
延遲、可用性）與 RabbitMQ 核心概念（Exchange/ACK/DLQ）見
[message-broker-comparison.md](message-broker-comparison.md)。

> 本篇屬一般技術知識整理，**未逐項查證官方文件**；後續若查證官方文件可補充更新。

## 研究結論

### 一、HTTP vs MQTT 與訊息協議家族（MQTT / STOMP / AMQP）

#### 1. 為什麼常拿 HTTP 與 MQTT 比較

- 兩者同層：都是 TCP 上的 L7 應用協議，比較本身不是分層錯誤。常見比較情境是 IoT／裝置
  上報：「裝置要用 HTTP POST 上報，還是 MQTT publish？」
- 但比較的真正軸線是**互動模型**而非協議名稱：HTTP = client 發起的 request/response
  （pull、一對一、每次請求獨立）；MQTT = 持久連線 + broker 中介的 publish/subscribe
  （push、一對多、有 session 狀態）。所以「HTTP vs MQTT」其實是「request/response vs
  pub/sub」的簡稱——這個直覺是對的。
- 附帶差異：MQTT 固定頭最小僅 2 bytes、為不穩定網路設計（QoS 0/1/2、retained message、
  Last Will and Testament）；HTTP 文字頭冗長、無內建 QoS。
- 邊界註記：HTTP 也有 push 型變體（SSE、streaming、HTTP/2 push），純二分法在現代 HTTP 上
  已模糊，比較時應指明是「傳統 request/response 用法」。

#### 2. MQTT 與 STOMP 像，因為是同一家族：wire-level 訊息協議

MQTT、STOMP、AMQP 都是「broker 中介的訊息語意協議」：皆定義 pub/sub、都可跑在原生 TCP 上、
也都可作為 WebSocket subprotocol（呼應
[network-protocol-stack.md](network-protocol-stack.md) 第六節「WebSocket 與 Subprotocol
分層」堆疊圖中三者並列的位置）。

| 面向 | MQTT | STOMP | AMQP 0-9-1 |
|------|------|-------|------------|
| 編碼 | binary、極精簡 | 文字 frame（易讀易實作） | binary、功能最豐富 |
| 設計目標 | IoT／低頻寬／不穩定網路 | 簡單互通、web 前端接 broker | 企業訊息（exchange/routing key/交易） |
| 可靠性語意 | QoS 0/1/2、retained、LWT | ack 模式（無 QoS 分級、無 retained/LWT） | ack/confirm、交易 |
| Topic 語法 | 階層式 + 萬用字元（`+`、`#`） | destination 字串（語意由 broker 決定） | exchange + binding |

- **Broker 生態**：Mosquitto / EMQX / HiveMQ 為 MQTT 原生；RabbitMQ 原生 AMQP、以 plugin
  支援 MQTT 與 STOMP；ActiveMQ 多協議並存。所以「有些 queue 預設走 MQTT」通常指 MQTT 原生
  broker，而通用 broker 多半是「一個 broker、多個協議門面」。
- **選擇時的思考順序**：先選互動模型（request/response vs pub/sub），再依環境（裝置受限
  程度、web 前端、企業整合）選協議，最後才是 broker。

### 二、Kafka 的定位：不屬於 MQTT/STOMP/AMQP 家族

#### 1. Kafka 用自己的 wire protocol

- Kafka 不支援 STOMP / AMQP / MQTT：client 與 broker 之間走 Kafka 專有的 binary protocol
  （版本化的 API：produce、fetch、metadata、offset commit 等），必須用 Kafka client
  library（Java client、librdkafka 等）連線。
- 與第一節家族協議「一個 broker、多個協議門面」相反：Kafka 是「一種協議、專屬生態」；
  跨協議互通靠外掛橋接（Kafka Connect、REST Proxy、MQTT gateway 等），並非 broker 原生
  門面。

#### 2. 缺 exchange/routing 是設計哲學不是功能缺口

Kafka 本質是**分散式、分區、可複寫的 commit log**，不是傳統 message broker。

| 面向 | AMQP 型 broker（RabbitMQ） | Kafka |
|------|---------------------------|-------|
| 路由 | exchange + routing key + binding，broker 端靈活路由 | 只有 topic + partition（依 key hash 或自訂 partitioner），無 broker 端內容路由 |
| 消費模型 | broker push、逐訊息 ack | consumer pull、以 offset 追蹤進度 |
| 訊息生命週期 | ack 後刪除 | 依 retention（時間/大小）保留，與是否被消費無關，可回放（rewind offset） |
| 設計哲學 | smart broker / dumb consumer | dumb broker / smart consumer |
| 過濾 | broker 端 binding 條件 | consumer 端自行過濾，或交給 stream processing（Kafka Streams / ksqlDB） |

之所以不採標準訊息協議：STOMP / AMQP 的語意（逐訊息 ack、broker 管理投遞狀態）與 log 語意
（offset、批次 fetch、sequential I/O、page cache）不相容；Kafka 的吞吐設計依賴自有協議的
批次與零拷貝路徑。

#### 3. 一句話總結

「Kafka 有沒有 STOMP？」的正確視角：MQTT / STOMP / AMQP 是「訊息協議」，Kafka 是「帶專屬
協議的分散式 log 平台」——比較 Kafka 與 RabbitMQ 時，比的是儲存與消費模型，不是 wire
protocol 家族成員。

### 三、Redis Pub/Sub 的定位與選型情境

#### 1. Redis Pub/Sub 的定位

- 走 Redis 自己的 RESP 協議（SUBSCRIBE / PUBLISH 命令），與 Kafka 同屬「自有協議」陣營，
  不是 MQTT / STOMP / AMQP 家族。
- 語意是全場最弱的：**fire-and-forget、at-most-once**——無持久化、無 ack、無 queue 緩衝；
  訊息只投遞給「當下在線」的訂閱者，訂閱者離線或處理不及就直接遺失，也無法回放。
- 本質是「in-memory 廣播/信號機制」，不是 message queue。
- 補充：Redis 5.0 起另有 **Streams**（XADD / XREADGROUP）：持久化 log 結構 + consumer
  group + ack + pending list，語意接近輕量版 Kafka；另外 List（LPUSH / BRPOP）常被當簡易
  work queue。「拿 Redis 當 MQ」通常應指 Streams 而非 pub/sub。

#### 2. 五種機制對照表

| 面向 | Redis Pub/Sub | Redis Streams | RabbitMQ（AMQP） | Kafka | MQTT broker |
|------|---------------|---------------|------------------|-------|-------------|
| 持久化/回放 | 無 | 有（可 trim） | ack 後刪除 | retention + 回放 | QoS 1/2 + retained（單則） |
| 投遞保證 | at-most-once | at-least-once（ack/pending） | at-least-once（ack/confirm） | at-least-once（可配合 idempotence/交易） | QoS 0/1/2 |
| 離線訂閱者 | 遺失 | 可補讀 | queue 暫存 | offset 續讀 | persistent session 暫存 |
| 吞吐定位 | 高（記憶體廣播） | 中高 | 中 | 極高（批次+順序 I/O） | 面向大量低頻連線 |
| 額外基礎設施 | 通常已有 Redis | 通常已有 Redis | 要多養一套 broker | 要多養一套叢集 | 要多養一套 broker |

#### 3. 實務選型情境

- **Redis Pub/Sub**：同基礎設施內、可容忍遺失的即時信號——快取失效廣播、多實例 WebSocket
  fan-out（通知所有 pod 推播給各自連線的 client）、線上狀態/儀表板刷新。優勢是零新增元件、
  延遲極低。
- **Redis Streams**：已有 Redis、量級中等的輕量任務佇列/事件流，不想為此多養一套
  Kafka / RabbitMQ。
- **RabbitMQ**：任務分派（work queue）、需要複雜路由（exchange/binding）、逐訊息 ack、
  延遲佇列、死信、優先級——「smart broker」場景。
- **Kafka**：高吞吐事件流、event sourcing、log 聚合、多個獨立 consumer group 各自讀同一份
  歷史、stream processing、需要回放。
- **MQTT broker**：大量不穩定終端（IoT/行動裝置）連線管理、LWT、QoS 分級。

選型第一問是「訊息掉了要不要緊？」——要緊就先排除 pub/sub；第二問是「要不要回放歷史？」——
要就往 Kafka / Streams；再來才是吞吐與維運成本。

## 參考

- [network-protocol-stack.md](network-protocol-stack.md) — 網路分層基礎（OSI/TCP/IP、L4/L7
  分流）與 WebSocket subprotocol 概念（第六節），本篇的協議分層討論以其為前提。
