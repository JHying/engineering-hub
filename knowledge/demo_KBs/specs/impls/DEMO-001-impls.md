# DEMO-001 實作概述

> 對應 spec：`specs/DEMO-001.md`
> 涉及服務：order-service（後端主力）、payment-service（Kafka consumer）
> 同步 commit：abc1234（KB 對應版本）

---

## 一、AC 實作概述

> 所有 AC 均為後端實作，無前端改動。AC5（金額快照）透過 DB 欄位設計保證。

| AC | 涉及層 | 實作機制 |
|----|--------|---------|
| AC1：有效訂單建立回傳 orderId，狀態 PENDING | BE | `OrderAppService.createOrder()` → `OrderRepository.save()` |
| AC2：庫存不足回傳 400 | BE | `InventoryDomainService.lock()` → 拋 `InsufficientStockException` → `GlobalExceptionHandler` 對應 HTTP 400 |
| AC3：發布 order-created Kafka 事件 | BE | `OrderDomainService.create()` 成功後 `OrderEventPublisher.publish()` |
| AC4：30 秒內重複送出回傳 429 | BE | `OrderDomainService` 建立前查 Redis key `order:idem:{userId}:{productId}:{qty}`，已存在拋 `DuplicateOrderException` |
| AC5：金額快照不受商品改價影響 | BE | `ORDERS.price_snapshot` 欄位在建立時直接寫死數值，無 FK 關聯 PRODUCTS 表 |

---

## 二、功能異動範圍與系統流程

### 異動範圍

- `OrderController`（新增）：`POST /orders` endpoint
- `OrderAppService`（新增）：協調庫存鎖定、訂單建立、事件發布
- `OrderDomainService`（新增）：冪等檢查、訂單 entity 建立
- `InventoryDomainService`（新增）：SELECT FOR UPDATE 庫存鎖定
- `OrderEventPublisher`（新增）：Kafka 發布 `order-created`
- `OrderRepository`（新增）：JPA Repository
- payment-service / `OrderCreatedEventConsumer`（新增）：Kafka consumer

### 系統流程（code-like-facts）

**[order-service] 建立訂單主流程：**
```
OrderController.createOrder(CreateOrderRequest)
  → OrderAppService.createOrder(req)
      → InventoryDomainService.lock(productId, qty)
            reads:  PRODUCTS（SELECT FOR UPDATE）
            qty available ≥ req.qty
              → writes: PRODUCTS（stock -= req.qty）
            qty < req.qty
              → throw InsufficientStockException → HTTP 400 INSUFFICIENT_STOCK
      → OrderDomainService.create(req)
            idem_key = "order:idem:{userId}:{productId}:{qty}"
            RedisClient.get(idem_key)
              key exists → throw DuplicateOrderException → HTTP 429
              key not exists
                → RedisClient.set(idem_key, orderId, TTL=30s)
                → writes: ORDERS（orderId, status=PENDING, price_snapshot=product.price）
      → OrderEventPublisher.publish(OrderCreatedEvent)
            sends: Kafka "order-created" { orderId, userId, amount, items }
      → return HTTP 201 { orderId, status: "PENDING" }
```

**[payment-service] 消費 order-created 事件：**
```
OrderCreatedEventConsumer.consume(OrderCreatedEvent)
  → idem check: PAYMENT_IDEMPOTENCY table（orderId 去重）
      已存在 → skip（Kafka at-least-once 保護）
      不存在 → writes: PAYMENT_IDEMPOTENCY
               → PaymentDomainService.initiate(orderId, amount)
                     writes: PAYMENTS（status=INITIATED）
```

---

## 三、驗測方式

| 測試類型 | 對象 | 涵蓋範圍 |
|---------|------|---------|
| Unit Test | `OrderDomainServiceTest` | 冪等邏輯（Redis key 存在 / 不存在）、金額快照取值 |
| Unit Test | `InventoryDomainServiceTest` | 庫存足夠 / 不足分支 |
| Integration Test | TestContainers（Oracle + Redis + Kafka） | 完整 POST /orders 流程、Kafka 發布確認 |
| Contract Test | `contracts/create-order.groovy` | POST /orders request / response 格式 |

---

## 四、SA 系統需求規格實作

- **Redis key**：`order:idem:{userId}:{productId}:{qty}`，TTL = 30s，存放於 order-service
- **Kafka topic**：`order-created`，producer = order-service，consumer = payment-service
- **DB（Oracle）**：
  - `ORDERS`（新增欄位：`price_snapshot NUMBER(10,2)`）
  - `PAYMENT_IDEMPOTENCY`（新增 table：`order_id VARCHAR2(50) PRIMARY KEY`）
- **Config 變更**：無
- **合約異動**：新增 `POST /orders` REST API（詳見 spec Contract 章節）
- **特殊行為說明**：庫存鎖定失敗時不發 Kafka，訂單不建立；事件發布採用「DB 先寫，再發 Kafka」模式（Write-Ahead 原則，防止 DB 失敗但事件已發）
