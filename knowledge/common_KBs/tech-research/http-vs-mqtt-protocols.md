---
date: 2026-06-27
keywords: MQTT, HTTP, IoT, Pub/Sub, QoS, 訊息佇列, 低功耗, 即時通訊, Broker, Topic
---

# HTTP vs MQTT：應用層通訊協議比較

**日期**：2026-06-27  
**關鍵字**：MQTT, HTTP, IoT, Pub/Sub, QoS, 低功耗, 即時通訊, Broker, Topic Filter

## 問題背景

Web 應用與 IoT 設備對通訊協議的需求差異很大：Web 重在資料交換的通用性與相容性，IoT 設備則強調低功耗、低頻寬、不穩定網路下的可靠傳遞。選錯協議會導致電池消耗過快、延遲過高，或設備資源不足。

---

## 研究結論

### 一、核心定位

| | HTTP | MQTT |
|-|------|------|
| **定位** | 無狀態請求/回應應用層協議 | 輕量級訊息佇列遙測傳輸協議（Message Queue Telemetry Transport） |
| **通訊模型** | 同步請求/回應（Request/Response） | 非同步發布/訂閱（Publish/Subscribe） |
| **連線模式** | 每次請求獨立建立（HTTP/1.1 可 keep-alive） | 持久連線（Client 保持與 Broker 的長連線） |
| **Header 大小** | 數百 Bytes 起（含大量 metadata） | 最小僅 **2 Bytes** |
| **適用場景** | 網頁內容傳輸、REST API、一般資料交換 | IoT 設備、即時通訊、低功耗網路 |

---

### 二、MQTT 架構

```
Publisher（發布者）          Broker（訊息代理）         Subscriber（訂閱者）
  設備 A                        MQTT Server               後端伺服器
  設備 B    ─── publish ──→   topic: sensor/temp  ──→    監控儀表板
  設備 C                                                    App 客戶端
```

**三個角色：**
- **Publisher**：發送訊息到指定 Topic（通常是感測器、設備）
- **Broker**：訊息中介，負責接收、過濾、轉發（如 Eclipse Mosquitto、EMQX）
- **Subscriber**：訂閱 Topic，接收對應訊息

**Topic 過濾機制：**
```
sensor/+/temperature   ← 單層萬用字元（匹配 sensor/room1/temperature）
sensor/#               ← 多層萬用字元（匹配所有 sensor/ 子路徑）
```

---

### 三、MQTT QoS（訊息服務品質）

| QoS 等級 | 名稱 | 說明 | 適用場景 |
|---------|------|------|---------|
| **QoS 0** | At most once（最多一次） | 發送即忘，不確認，可能遺失 | 感測器高頻資料（偶爾遺失可接受） |
| **QoS 1** | At least once（至少一次） | 確保送達，但可能重複 | 告警訊息、狀態更新 |
| **QoS 2** | Exactly once（僅一次） | 嚴格確保且不重複，開銷最大 | 金融交易、指令控制 |

---

### 四、HTTP vs MQTT 特性對比

| 特性 | HTTP | MQTT |
|------|------|------|
| **功耗** | 較高（頻繁建連、大封包） | 低（持久連線、小封包） |
| **頻寬** | 較高 | 極低（header 最小 2 Bytes） |
| **即時性** | 差（需輪詢或 Long Polling） | 優（Broker 主動推送） |
| **雙向通訊** | 困難（需 WebSocket 輔助） | 原生支援 |
| **網路可靠性** | 依賴穩定網路 | 設計於不穩定、高延遲網路 |
| **訊息保證** | 無內建機制 | QoS 0/1/2 三級保證 |
| **生態相容性** | 極廣（瀏覽器、所有語言） | IoT 設備廣泛支援，Web 端需橋接 |
| **安全** | TLS/HTTPS | TLS + Username/Password + Client Certificate |

---

### 五、選型建議

| 場景 | 建議協議 |
|------|---------|
| Web 前後端 API 資料交換 | HTTP / REST |
| 瀏覽器即時通訊 | WebSocket（或 HTTP/SSE） |
| IoT 感測器資料上傳（低頻寬、低功耗） | MQTT |
| 設備遠端控制指令下發 | MQTT（QoS 1 或 2） |
| 大量設備同時上報（Fan-in） | MQTT + Broker |
| 需要 CDN 快取、靜態資源 | HTTP |

> **實務常見架構**：IoT 設備透過 MQTT 上報資料至 Broker，後端服務訂閱 Broker 取得資料後，再透過 HTTP REST API 對外提供查詢介面。

---

## 參考

- 來源：worktile.com/kb/p/72806
- 相關筆記：[network-protocol-stack.md](network-protocol-stack.md)（HTTP 底層協議棧：TCP/IP、TLS）、[message-broker-comparison.md](message-broker-comparison.md)（AMQP / RabbitMQ / Kafka）
