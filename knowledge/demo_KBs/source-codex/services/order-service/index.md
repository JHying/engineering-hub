# order-service — Wiki Entry

> 快速摘要 | 資料結構 | 介面合約 | 業務邏輯

---

## 快速摘要

| 項目 | 內容 |
|------|------|
| 職責 | 接收下單請求、管理訂單狀態機（PENDING → PAID → SHIPPED → DONE） |
| 技術 | Spring Boot 3.x, JPA（Oracle）, Kafka producer, Redis |
| 入站 | REST（api-gateway 轉發）|
| 出站 | Kafka `order-created`（→ payment-service） |
| DB | Oracle `ORDER_DB`，tables: `ORDERS`, `PRODUCTS` |
| Cache | Redis key prefix `order:` |

---

## 資料結構

### ORDERS 表（Oracle）

| 欄位 | 型態 | 說明 |
|------|------|------|
| order_id | VARCHAR2(50) PK | 訂單 ID，格式：`ORD-{yyyyMMdd}-{seq}` |
| user_id | VARCHAR2(50) | 下單使用者 |
| status | VARCHAR2(20) | PENDING / PAID / SHIPPED / DONE / CANCELLED |
| price_snapshot | NUMBER(10,2) | 建立時商品單價快照（不受後續改價影響） |
| quantity | NUMBER(5) | 購買數量 |
| product_id | VARCHAR2(50) | 商品 ID（非 FK，防止關聯污染） |
| created_at | TIMESTAMP | 建立時間 |
| updated_at | TIMESTAMP | 最後更新時間 |

### Redis Key

| Key | 格式 | TTL | 用途 |
|-----|------|-----|------|
| 冪等 key | `order:idem:{userId}:{productId}:{qty}` | 30s | 防止 30 秒內重複下單 |

---

## 介面合約

### POST /orders（建立訂單）

**Request：**
```json
{
  "userId": "U-999",
  "productId": "P-001",
  "quantity": 2
}
```

**Response 201：**
```json
{
  "orderId": "ORD-20240601-001",
  "status": "PENDING"
}
```

**錯誤回應：**
| HTTP | code | 說明 |
|------|------|------|
| 400 | INSUFFICIENT_STOCK | 庫存不足 |
| 429 | DUPLICATE_ORDER | 30 秒內重複送出相同訂單 |

### Kafka `order-created`（outbound）

```json
{
  "orderId": "ORD-20240601-001",
  "userId": "U-999",
  "amount": 1200,
  "priceSnapshot": 600,
  "items": [{ "productId": "P-001", "quantity": 2 }]
}
```

---

## 業務邏輯

- **庫存鎖定**：SELECT FOR UPDATE 行鎖，確保高並發下不超賣
- **金額快照**：建立時複製商品現價至 `price_snapshot`，後續商品改價不影響
- **冪等保護**：30 秒內同一 userId + productId + qty 組合只建立一次訂單
- **事件發布順序**：DB 先寫成功後再發 Kafka（Write-Ahead 模式），防止事件孤兒
- **狀態機**：`PENDING` → (payment-service 通知) → `PAID` → (倉儲通知) → `SHIPPED` → `DONE`
