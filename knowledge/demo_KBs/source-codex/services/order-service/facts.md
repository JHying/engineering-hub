# order-service — 業務邏輯事實

> 機械抽取自 codebase 的業務規則事實。
> 格式：每行一個可查核的 fact，保持 code-like，不寫散文。

---

## 訂單建立規則

```
OrderDomainService.create(req)
  pre-condition: InventoryDomainService.lock() 已成功（庫存扣除完成）
  idem_key = "order:idem:{req.userId}:{req.productId}:{req.quantity}"
  Redis.get(idem_key) exists → throws DuplicateOrderException
  Redis.get(idem_key) not exists
    → Redis.set(idem_key, orderId, TTL=30s)
    → Order entity: status=PENDING, price_snapshot=PRODUCTS.price (at create time)
    → ORDERS table insert
```

## 庫存鎖定規則

```
InventoryDomainService.lock(productId, qty)
  SELECT stock FROM PRODUCTS WHERE product_id=? FOR UPDATE
  stock >= qty → UPDATE PRODUCTS SET stock = stock - qty WHERE product_id=?
  stock < qty  → throws InsufficientStockException
```

## 事件發布規則

```
OrderEventPublisher.publish(event)
  trigger: after ORDERS insert committed
  sends: Kafka topic "order-created"
  payload keys: orderId, userId, amount, priceSnapshot, items[]
  failure: log error, do NOT rollback order（Kafka 送失敗不影響訂單已建立）
```

## 冪等保護規則

```
idem_key TTL = 30 seconds
同一 userId + productId + quantity 在 TTL 內重複送出 → HTTP 429
TTL 過期後可重新下單（視為新請求）
```

## 狀態機轉換（由外部觸發）

```
PENDING → PAID:      payment-service 通知（REST callback 或 Kafka payment-result）
PAID → SHIPPED:      倉儲系統通知
SHIPPED → DONE:      物流確認送達
任意狀態 → CANCELLED: 明確取消請求（DONE 後不可取消）
```
