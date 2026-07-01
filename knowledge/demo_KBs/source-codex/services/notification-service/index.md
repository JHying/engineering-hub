# notification-service — Wiki Entry

> 快速摘要 | 資料結構 | 介面合約 | 業務邏輯

---

## 快速摘要

notification-service 負責訂單事件的對外通知，消費 Kafka `payment-result` 事件後依使用者偏好透過 Email 或 SMS 送出通知。
服務無 REST inbound（純 Kafka-driven），所有通知行為由事件觸發。
共享資源：Redis key `notif:sent:{orderId}:{channel}`（防重複發送，TTL 1h）；`NOTIFICATION_LOG` 表記錄每次發送結果。
對外依賴 Email Provider 與 SMS Provider 的 HTTP API，兩者均設有熔斷降級：主要 Provider 失敗時切換備用 Provider。

---

## 基本資訊

| 項目 | 內容 |
|------|------|
| 服務職責 | 訂單狀態通知。消費 `payment-result`，依使用者偏好（Email / SMS / 兩者）發送通知，記錄發送結果；不主動對外暴露 REST API |
| 技術棧 | Spring Boot 3.x（Virtual Thread）、Kafka Consumer（Spring Cloud Stream）、Redis（Lettuce）、Oracle（Spring Data JPA）、RestClient（HTTP 呼叫 Email / SMS Provider）、Resilience4j（CircuitBreaker） |
| 關鍵設計 | 事件驅動、無狀態推送（通知紀錄寫 DB 但不影響業務流程）；Provider 熔斷降級防止單一 Provider 故障阻塞整個通知鏈 |

---

## 資料結構

### NOTIFICATION_LOG 表（Oracle）

| 欄位 | 型態 | 說明 |
|------|------|------|
| notif_id | VARCHAR2(50) PK | 通知 ID，格式：`NOTIF-{yyyyMMddHHmmss}-{seq}` |
| order_id | VARCHAR2(50) | 來源訂單 ID |
| user_id | VARCHAR2(50) | 收件使用者 |
| channel | VARCHAR2(10) | EMAIL / SMS |
| status | VARCHAR2(10) | SENT / FAILED / SKIPPED |
| provider | VARCHAR2(30) | 實際使用的 Provider（primary / backup） |
| error_msg | VARCHAR2(500) | 失敗原因（STATUS=FAILED 時填入） |
| created_at | TIMESTAMP | 發送時間 |

### Redis Key

| Key | 格式 | TTL | 用途 |
|-----|------|-----|------|
| 去重 key | `notif:sent:{orderId}:{channel}` | 1h | 防止 Kafka 重複消費造成重複發送 |
| 使用者偏好快取 | `notif:pref:{userId}` | 10m | 使用者通知偏好（Email / SMS / BOTH）快取 |

---

## 介面合約

### Kafka Consumer：`payment-result`

消費 `payment-result` 事件，觸發通知流程。

消費後冪等保護：
- 查 Redis `notif:sent:{orderId}:{channel}` 是否存在 → 存在則 skip（TTL 1h 防重複）

### 對外 HTTP（Email Provider）

`POST ${notif.email.base-url}/send`

```json
{
  "to": "user@example.com",
  "subject": "訂單付款成功通知",
  "templateId": "ORDER_PAYMENT_SUCCESS",
  "variables": {
    "orderId": "ORD-20240601-001",
    "amount": "1200.00",
    "currency": "TWD"
  }
}
```

### 對外 HTTP（SMS Provider）

`POST ${notif.sms.base-url}/send`

```json
{
  "to": "+886912345678",
  "message": "您的訂單 ORD-20240601-001 付款成功，金額 TWD 1,200。"
}
```

---

## 業務邏輯

### 通知觸發流程（消費 payment-result）

```
NotificationEventConsumer.consume(PaymentResultEvent)
  → idem check: Redis get("notif:sent:{orderId}:{channel}")
      key exists → skip（Kafka at-least-once 防護）
      key not exists
        → UserPreferenceService.getPreference(userId)
              reads: Redis "notif:pref:{userId}"（cache hit）
              cache miss → HTTP GET user-service /users/{userId}/preferences
                        → Redis.set("notif:pref:{userId}", pref, TTL=10m)
        → 依 preference 分派通知：
            EMAIL → EmailNotificationService.send(event)
            SMS   → SmsNotificationService.send(event)
            BOTH  → 同時派發（Virtual Thread 並行）
        → Redis.set("notif:sent:{orderId}:{channel}", "1", TTL=1h)
        → INSERT NOTIFICATION_LOG（status=SENT or FAILED）
```

### Provider 熔斷降級（Resilience4j CircuitBreaker）

```
EmailNotificationService.send(req)
  → CircuitBreaker("email-primary")
      primary provider 呼叫
      失敗（CircuitBreaker OPEN 或 HTTP 非 2xx）
        → CircuitBreaker("email-backup")
            backup provider 呼叫
            失敗 → INSERT NOTIFICATION_LOG(status=FAILED, error_msg)
                   log error（不 throw，不影響 Kafka offset commit）
```

### 通知內容依付款狀態變化

| payment-result.status | 通知主題 | 模板 ID |
|----------------------|---------|---------|
| SUCCESS | 付款成功 | `ORDER_PAYMENT_SUCCESS` |
| FAILED | 付款失敗，請重試 | `ORDER_PAYMENT_FAILED` |
| TIMEOUT | 付款處理中，請稍候 | `ORDER_PAYMENT_TIMEOUT` |

### 使用者偏好不存在時

- 查無偏好設定（user-service 回 404 或 Redis miss）→ 預設發 EMAIL
- 不中斷流程，記錄 `NOTIFICATION_LOG(provider=default-fallback)`

---

## Shared Resources

| Key / Table | 類型 | 操作 | 說明 |
|------------|------|------|------|
| `notif:sent:{orderId}:{channel}` | Redis（TTL 1h） | RW | 發送冪等 key，防 Kafka 重複消費 |
| `notif:pref:{userId}` | Redis（TTL 10m） | RW | 使用者通知偏好快取 |
| NOTIFICATION_LOG | Oracle | W | 每次發送結果記錄（只寫不改） |

---

## 同步狀態

- 同步日期：2024-06-01
- 最新 commit：ghi9012
- **狀態：SYNCED**
