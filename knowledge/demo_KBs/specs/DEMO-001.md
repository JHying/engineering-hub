# DEMO-001 訂單建立功能

## 需求描述

使用者在商品頁按下「立即購買」後，系統應建立訂單並跳轉付款流程。
訂單需記錄品項、數量、金額快照（防止商品改價影響舊訂單）。

範疇：order-service 後端 API + payment-service 付款觸發。

## 驗收條件與邊界情境

- [ ] AC1：送出有效的商品 ID 與數量，系統建立訂單並回傳 orderId，狀態為 PENDING
- [ ] AC2：庫存不足時，回傳 HTTP 400，訊息為 `INSUFFICIENT_STOCK`，不建立訂單
- [ ] AC3：建立成功後，發布 `order-created` Kafka 事件，payment-service 收到後啟動付款流程
- [ ] AC4：同一使用者 30 秒內重複送出相同商品 + 數量，回傳 HTTP 429，不重複建立訂單（冪等保護）
- [ ] AC5：訂單金額快照需在建立時鎖定，後續商品改價不影響此訂單顯示金額

## 功能目標

- 建立訂單 CRUD API（POST /orders）
- 庫存鎖定與驗證
- 金額快照寫入
- 發布 Kafka 事件觸發付款流程
- 冪等保護（Redis 去重）

## 資料流

```
POST /orders → api-gateway → OrderController.createOrder(req)
  → InventoryDomainService.lock(productId, qty)
      reads:  PRODUCTS table（庫存數量）
      writes: PRODUCTS table（庫存 -qty，行鎖）
      庫存不足 → throw InsufficientStockException → HTTP 400
  → OrderDomainService.create(req)
      冪等 key = userId:productId:qty，Redis TTL = 30s
      key 已存在 → throw DuplicateOrderException → HTTP 429
      writes: ORDERS table（status=PENDING, price_snapshot）
              Redis idempotency key
  → KafkaProducer.send("order-created", OrderCreatedEvent)
      payload: { orderId, userId, amount, items }
  → return HTTP 201 { orderId, status: "PENDING" }
```

## 影響範圍

- **目標 Service**：order-service、payment-service（Kafka consumer）
- **新增 / 修改**：
  - order-service：`OrderController`（Controller）、`OrderAppService`（AppService）、`OrderDomainService`（DomainService）、`InventoryDomainService`（DomainService）
  - payment-service：`OrderCreatedEventConsumer`（Kafka consumer，新增）

## 服務間 Contract

**POST /orders 請求：**
```json
{
  "productId": "P-001",
  "quantity": 2,
  "userId": "U-999"
}
```

**POST /orders 回應（201）：**
```json
{
  "orderId": "ORD-20240601-001",
  "status": "PENDING"
}
```

**Kafka event（order-created）：**
```json
{
  "orderId": "ORD-20240601-001",
  "userId": "U-999",
  "amount": 1200,
  "priceSnapshot": 600,
  "items": [{ "productId": "P-001", "quantity": 2 }]
}
```

## 特殊限制

- 庫存鎖定必須使用 DB 行鎖（SELECT FOR UPDATE），禁止 Redis 樂觀鎖（高並發下有競態）
- `price_snapshot` 在訂單建立時寫死，不能用 FK 關聯商品表（防止商品改價污染）
- payment-service 的 Kafka consumer 需實作冪等（`orderId` 去重），因 Kafka at-least-once 語義
