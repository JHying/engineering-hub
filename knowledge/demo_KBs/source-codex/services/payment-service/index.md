# payment-service — Wiki Entry

> 快速摘要 | 資料結構 | 介面合約 | 業務邏輯

---

## 快速摘要

payment-service 負責付款生命週期管理，包含接收 Kafka `order-created` 事件後發起付款請求、呼叫第三方金流 Gateway、處理付款結果（成功 / 失敗 / 逾時），以及透過 Kafka `payment-result` 通知下游服務。
對外暴露 REST API 供 api-gateway 轉發（查詢付款狀態、手動觸發重試）。
共享資源：Redis key `payment:idem:{orderId}`（冪等保護，TTL 24h）；`payment:status:{orderId}`（付款狀態快取，TTL 30m）。
Kafka Consumer：`order-created`；Kafka Producer：`payment-result`。
Oracle DB 儲存付款主記錄與冪等去重表。

---

## 基本資訊

| 項目 | 內容 |
|------|------|
| 服務職責 | 付款流程核心。消費 `order-created`、呼叫金流 Gateway、管理付款狀態機（INITIATED → PROCESSING → SUCCESS / FAILED）、發布 `payment-result` 廣播結果 |
| 技術棧 | Spring Boot 3.x（Undertow）、Kafka（Consumer + Producer）、Redis（Lettuce）、Oracle（Spring Data JPA）、RestClient（HTTP 呼叫 Gateway） |
| 關鍵設計 | Kafka at-least-once + DB 冪等去重（`PAYMENT_IDEMPOTENCY` 表），防止同一 orderId 重複付款 |

---

## 資料結構

### PAYMENTS 表（Oracle）

| 欄位 | 型態 | 說明 |
|------|------|------|
| payment_id | VARCHAR2(50) PK | 付款 ID，格式：`PAY-{yyyyMMdd}-{seq}` |
| order_id | VARCHAR2(50) | 對應訂單 ID（非 FK，避免跨服務強耦合） |
| user_id | VARCHAR2(50) | 付款使用者 |
| amount | NUMBER(12,2) | 付款金額 |
| status | VARCHAR2(20) | INITIATED / PROCESSING / SUCCESS / FAILED / TIMEOUT |
| gateway_tx_id | VARCHAR2(100) | 第三方 Gateway 回傳的交易 ID |
| gateway_code | VARCHAR2(20) | Gateway 回傳錯誤碼（失敗時填入） |
| retry_count | NUMBER(2) | 已重試次數（上限 3 次） |
| created_at | TIMESTAMP | 建立時間 |
| updated_at | TIMESTAMP | 最後更新時間 |

### PAYMENT_IDEMPOTENCY 表（Oracle）

| 欄位 | 型態 | 說明 |
|------|------|------|
| order_id | VARCHAR2(50) PK | 去重 key（一個訂單只能有一筆付款） |
| payment_id | VARCHAR2(50) | 對應的 paymentId |
| created_at | TIMESTAMP | 首次消費時間 |

### Redis Key

| Key | 格式 | TTL | 用途 |
|-----|------|-----|------|
| 冪等 key | `payment:idem:{orderId}` | 24h | 防止 Kafka 重複消費同一 orderId |
| 付款狀態快取 | `payment:status:{orderId}` | 30m | 供 api-gateway 快速查詢付款狀態 |
| Gateway 逾時追蹤 | `payment:gateway-pending:{orderId}` | 5m | 標記正在等待 Gateway 回應的請求 |

---

## 介面合約

### REST API

**GET /payments/{orderId}（查詢付款狀態）**

Response 200：
```json
{
  "paymentId": "PAY-20240601-001",
  "orderId": "ORD-20240601-001",
  "status": "SUCCESS",
  "amount": 1200.00,
  "updatedAt": "2024-06-01T10:05:30Z"
}
```

錯誤回應：
| HTTP | code | 說明 |
|------|------|------|
| 404 | PAYMENT_NOT_FOUND | 查無此訂單的付款記錄 |

**POST /payments/{orderId}/retry（手動觸發重試，需 Admin 權限）**

Response 200：`{ "triggered": true }`

錯誤回應：
| HTTP | code | 說明 |
|------|------|------|
| 409 | MAX_RETRY_EXCEEDED | 已達重試上限（3 次） |
| 409 | PAYMENT_ALREADY_SUCCESS | 付款已成功，無需重試 |

### Kafka Consumer：`order-created`

消費後執行付款流程，冪等保護（DB + Redis 雙層）。

### Kafka Producer：`payment-result`

```json
{
  "orderId": "ORD-20240601-001",
  "paymentId": "PAY-20240601-001",
  "status": "SUCCESS",
  "amount": 1200.00,
  "gatewayTxId": "GW-TX-ABC123",
  "timestamp": "2024-06-01T10:05:30Z"
}
```

---

## 業務邏輯

### 付款觸發流程（消費 order-created）

- **冪等保護**：先查 `PAYMENT_IDEMPOTENCY`，`orderId` 存在則 skip（Kafka at-least-once 防護）
- **DB 冪等寫入**：INSERT `PAYMENT_IDEMPOTENCY`（PK 唯一約束）成功後才繼續，失敗（重複 key）則 skip
- **付款記錄建立**：INSERT `PAYMENTS`（status = INITIATED），寫 Redis `payment:idem:{orderId}`
- **Gateway 呼叫**：`POST ${payment.gateway.base-url}/charge`，設定逾時 30s
  - 成功（200）：UPDATE status = SUCCESS，發 `payment-result`（SUCCESS）
  - 失敗（Gateway 錯誤碼）：UPDATE status = FAILED，gateway_code 記錄，發 `payment-result`（FAILED）
  - 逾時：UPDATE status = TIMEOUT，寫 Redis `payment:gateway-pending:{orderId}`，排程 5 分鐘後主動查詢 Gateway 狀態

### 付款重試規則

- `retry_count >= 3` → 禁止重試，回傳 409
- 狀態為 SUCCESS → 禁止重試，回傳 409
- 狀態為 PROCESSING → 禁止重試（進行中），回傳 409
- 其餘狀態（FAILED / TIMEOUT）且 retry_count < 3 → 允許重試，retry_count + 1

### 逾時補償排程（`@Scheduled(fixedDelay = 300_000)`）

- 掃描 Redis `payment:gateway-pending:*`
- 對每個 key 呼叫 Gateway `/query` 查詢交易狀態
- 依回傳更新 PAYMENTS 並發 `payment-result`
- 查無記錄（Gateway 已逾期）→ 標記 FAILED，發通知

---

## Shared Resources

| Key / Table | 類型 | 操作 | 說明 |
|------------|------|------|------|
| `payment:idem:{orderId}` | Redis（TTL 24h） | RW | 付款服務自身冪等 key |
| `payment:status:{orderId}` | Redis（TTL 30m） | RW | 付款狀態快取（供 api-gateway 讀取） |
| `payment:gateway-pending:{orderId}` | Redis（TTL 5m） | RW | Gateway 逾時追蹤 |
| PAYMENTS | Oracle | RW | 付款主記錄 |
| PAYMENT_IDEMPOTENCY | Oracle | RW | Kafka 消費去重（DB 層防護） |

---

## 同步狀態

- 同步日期：2024-06-01
- 最新 commit：def5678
- **狀態：SYNCED**
