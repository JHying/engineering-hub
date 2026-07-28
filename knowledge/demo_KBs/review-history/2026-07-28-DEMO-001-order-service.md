---
date: 2026-07-28
branch: (不適用，demo_KBs 為文件示範)
ticket: DEMO-001
reviewer: 煙霧測試（update-kb 路由回歸驗證）
service: order-service, payment-service
scope: 對照 specs/DEMO-001.md 與 specs/impls/DEMO-001-impls.md 的目的驗證 + 品質/效能/設計模式三區塊審查
mode: ticket 模式
---

# Code Review — DEMO-001 訂單建立功能

> 對應 spec：`specs/DEMO-001.md`｜實作：`specs/impls/DEMO-001-impls.md`
> ⚠️ 本次為 update-kb Review History 路由回歸驗證用的煙霧測試，demo_KBs 無實際可審查的原始碼，內容為對照 spec / impls 文件合成之審查記錄。

## 目的驗證

達成，AC1–AC5 對照 spec 逐條核實無偏離：

| AC | spec 要求 | impls 對應機制 | 結果 |
|----|-----------|----------------|------|
| AC1 | 有效商品 ID + 數量 → 建立訂單，回傳 orderId，狀態 PENDING | `OrderAppService.createOrder()` → `OrderRepository.save()` | 無偏離 |
| AC2 | 庫存不足 → HTTP 400 `INSUFFICIENT_STOCK`，不建立訂單 | `InventoryDomainService.lock()` 拋 `InsufficientStockException`，`GlobalExceptionHandler` 對應 400 | 無偏離 |
| AC3 | 建立成功後發布 `order-created` Kafka 事件，payment-service 啟動付款流程 | `OrderEventPublisher.publish()` → `OrderCreatedEventConsumer.consume()` | 無偏離 |
| AC4 | 30 秒內重複送出相同商品+數量 → HTTP 429，不重複建立 | Redis idem key `order:idem:{userId}:{productId}:{qty}`，TTL 30s，命中拋 `DuplicateOrderException` | 無偏離 |
| AC5 | 金額快照鎖定，不受後續商品改價影響 | `ORDERS.price_snapshot` 建立時寫死數值，無 FK 關聯 `PRODUCTS` | 無偏離 |

---

## 審查範圍

| 類別 | Class |
|------|-------|
| Controller | `OrderController`（order-service） |
| AppService | `OrderAppService`（order-service） |
| DomainService | `OrderDomainService`（order-service） |
| DomainService | `InventoryDomainService`（order-service） |
| EventPublisher | `OrderEventPublisher`（order-service） |
| Repository | `OrderRepository`（order-service） |
| Kafka Consumer | `OrderCreatedEventConsumer`（payment-service） |

---

## 品質問題（Quality Issues）

✅ 無品質問題（0 項）

---

## 效能瓶頸 / 資料原子性（Performance & Atomicity Issues）

### InventoryDomainService

- **[不處理]** 並行 / DB：`lock()` 使用 `SELECT FOR UPDATE` 行鎖進行庫存扣減
  - 問題：高並發下同商品的下單請求會排隊等待行鎖釋放，需確認鎖等待時間是否影響 API 回應延遲
  - 風險：極端流量下可能造成請求堆積或逾時
  - 說明（不處理）：spec「特殊限制」章節已明確記載此為刻意設計——「庫存鎖定必須使用 DB 行鎖，禁止 Redis 樂觀鎖（高並發下有競態）」，屬既定架構決策，非本次審查發現的新問題，不在此變更

---

## 設計模式（Design Pattern Review）

- **[已使用]** Repository Pattern @ `OrderRepository` — 合適，將 `ORDERS` 表存取封裝於 Repository 介面，AppService/DomainService 不直接依賴持久層細節
- 過度設計：無
- 建議引入：無

---

## 本次修改檔案

> 依 `specs/impls/DEMO-001-impls.md` 記載之異動範圍整理（demo_KBs 無實際原始碼，下表為文件對照，非真實 diff）

| 檔案 | 類型 | 異動摘要 |
|------|------|---------|
| `OrderController.java` | 新建 | `POST /orders` endpoint |
| `OrderAppService.java` | 新建 | 協調庫存鎖定、訂單建立、事件發布 |
| `OrderDomainService.java` | 新建 | 冪等檢查（Redis）、訂單 entity 建立 |
| `InventoryDomainService.java` | 新建 | `SELECT FOR UPDATE` 庫存鎖定 |
| `OrderEventPublisher.java` | 新建 | 發布 Kafka `order-created` |
| `OrderRepository.java` | 新建 | JPA Repository |
| `OrderCreatedEventConsumer.java`（payment-service） | 新建 | 消費 `order-created`，含 `PAYMENT_IDEMPOTENCY` 去重 |

---

## 相關 ADR

- [ADR-0001 服務間通訊協議選型](../ADRs/0001-service-communication-protocol.md) — order-service → payment-service 採 Kafka 非同步事件，符合此決策的「跨服務非同步事件」場景對應

---

## 未解決 / 後續追蹤

| 項目 | 建議行動 |
|------|---------|
| 本記錄為 update-kb 路由煙霧測試產出，非真實 Code Review 結果，demo_KBs 無實際可審查的原始碼 | 僅供驗證 Review History 路由與檔案/索引格式正確性，不作為真實審查依據 |
| `InventoryDomainService.lock()` 高並發下鎖等待時間未實測 | 若日後有真實效能數據，補充至此記錄或另開專項效能審查 |

---

# R2 複審記錄（2026-07-28）

> round: R2（第二輪複審）｜reviewer: 未知（合成資料）｜service: order-service
> ⚠️ 同為 update-kb Review History 路由回歸驗證用的合成測試資料，非真實 Code Review 結果。

## 審查範圍

| 類別 | Class |
|------|-------|
| AppService | `OrderAppService`（order-service） |
| DTO | 訂單建立請求 DTO（order-service） |

---

## 品質問題（Quality Issues）

### OrderAppService
- **[已修]** DDD 分層違規：金額驗證邏輯誤置於 AppService 層，違反 DDD 分層規範（業務驗證應下沉至 Domain Service 層）→ 修正：金額驗證邏輯移至 Domain Service，`OrderAppService` 僅保留編排職責

### DTO（訂單建立請求）
- **[已修]** 命名慣例：欄位 `orderAmt` 為縮寫，不符全名慣例 → 修正：改名為 `orderAmount`

---

## 效能瓶頸 / 資料原子性（Performance & Atomicity Issues）

✅ 無效能 / 原子性問題

---

## 設計模式（Design Pattern Review）

✅ 無設計模式問題

---

## 本次修改檔案

| 檔案 | 類型 | 異動摘要 |
|------|------|---------|
| `OrderAppService.java` | 修改 | 移除誤置的金額驗證邏輯，改為呼叫 Domain Service，僅保留編排 |
| `OrderDomainService.java` | 修改 | 新增金額驗證邏輯（下沉自 AppService） |
| 訂單建立請求 DTO | 修改 | 欄位 `orderAmt` 改名為 `orderAmount` |

---

## 相關 ADR

- 無（demo_KBs 目前無 DDD 分層規範專屬 ADR）

---

## 未解決 / 後續追蹤

| 項目 | 建議行動 |
|------|---------|
| 無未解決項目，R2 兩項發現（DDD 分層違規、DTO 命名）皆已修復並複審通過 | — |
