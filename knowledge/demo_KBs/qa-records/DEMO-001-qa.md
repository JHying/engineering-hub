# DEMO-001 QA 記錄

> 對應 spec：`specs/DEMO-001.md`
> 測試策略：Unit + Integration + Contract（TestContainers：Oracle + Redis + Kafka）
> 執行日期：2026-07-28
> 執行結果：通過 17 / 失敗 0 / 略過 0

---

## 一、測試策略

採 Unit + Integration + Contract 三層驗證：

- **Unit Test**：針對 `OrderDomainService`（冪等邏輯、金額快照取值）與 `InventoryDomainService`（庫存足夠 / 不足分支）以純邏輯驗證，不啟動外部依賴。
- **Integration Test**：以 TestContainers 啟動 Oracle + Redis + Kafka，驗證完整 `POST /orders` 流程（含 DB 行鎖、Redis 冪等 key、Kafka 事件發布與 payment-service consumer 消費）。
- **Contract Test**：`create-order.groovy` 驗證 `POST /orders` request/response 格式，作為 order-service（producer）與下游（consumer）之間的契約保證。

> 對應測試詳見 `specs/impls/DEMO-001-impls.md`「三、驗測方式」章節。

---

## 二、AC / Gherkin 對齊檢查

| # | AC / Gherkin 條目 | 對應測試案例 | 是否對齊 | 落差類型（若不對齊） |
|---|------------------|------------|---------|-------------------|
| 1 | AC1：有效商品 ID 與數量建立訂單，回傳 orderId，狀態 PENDING | `OrderDomainServiceTest`（金額快照取值）+ Integration（完整 POST /orders 流程） | ✅ | - |
| 2 | AC2：庫存不足回傳 HTTP 400 `INSUFFICIENT_STOCK`，不建立訂單 | `InventoryDomainServiceTest`（庫存不足分支） | ✅ | - |
| 3 | AC3：建立成功後發布 `order-created` Kafka 事件，payment-service 啟動付款流程 | Integration（TestContainers Kafka 發布確認） | ✅ | - |
| 4 | AC4：30 秒內重複送出相同商品+數量回傳 HTTP 429，不重複建立訂單 | `OrderDomainServiceTest`（冪等邏輯，Redis key 存在/不存在） | ✅ | - |
| 5 | AC5：金額快照建立時鎖定，後續商品改價不影響此訂單顯示金額 | `OrderDomainServiceTest`（金額快照取值） | ✅ | - |

---

## 三、測試案例表

### Happy Path

| # | 前置條件 | 操作步驟 | 預期結果 | 對應 AC | 結果 |
|---|---------|---------|---------|--------|------|
| 1 | 商品 P-001 庫存充足（stock=50），使用者 U-999 無既存冪等 key | `POST /orders` `{productId: P-001, quantity: 2, userId: U-999}` | 回傳 HTTP 201 `{orderId, status: PENDING}` | AC1 | ✅ |
| 2 | 首次請求，Redis 無對應 idem key | `POST /orders` 首次送出 | 正常建立訂單，Redis 寫入 `order:idem:{userId}:{productId}:{qty}`，TTL=30s | AC4 | ✅ |
| 3 | 訂單建立成功（狀態 PENDING） | 觀察 Kafka topic `order-created` 與 payment-service consumer | payment-service 收到事件、寫入 `PAYMENT_IDEMPOTENCY`，`PaymentDomainService.initiate()` 建立 `PAYMENTS`（status=INITIATED） | AC3 | ✅ |
| 4 | 訂單建立完成後，商品 P-001 價格由 600 調整為 800 | 查詢原訂單金額 | 訂單顯示金額仍為建立當下快照值 600，不受商品改價影響 | AC5 | ✅ |

### Edge Case

| # | 情境描述 | 輸入 / 狀態 | 預期行為 | 嚴重度 | 結果 |
|---|---------|-----------|---------|-------|------|
| 1 | 庫存剛好等於需求量（邊界值） | stock=2, quantity=2 | 建立成功，庫存扣減至 0，不誤判為不足 | 中 | ✅ |
| 2 | 冪等 key TTL 剛好到期（30 秒邊界） | 第一次請求後等待 31 秒，再送出相同 productId+quantity | 視為新請求，正常建立第二筆訂單（非 429） | 中 | ✅ |
| 3 | 並發請求扣同一商品最後 1 件庫存（競態） | 2 個並發請求同時扣同一商品剩餘庫存 1 件 | 僅 1 筆成功建立，另 1 筆回 HTTP 400 `INSUFFICIENT_STOCK`（DB 行鎖 SELECT FOR UPDATE 保護） | 高 | ✅ |

### 錯誤情境

| # | 觸發條件 | 預期 Error Code | HTTP Status | 結果 |
|---|---------|---------------|------------|------|
| 1 | 庫存不足（stock < quantity） | `INSUFFICIENT_STOCK` | 400 | ✅ |
| 2 | 同一使用者 30 秒內重複送出相同 productId+quantity | `DUPLICATE_ORDER`（推斷自 `DuplicateOrderException`，spec/impls 未明定正式代碼字串，見第八節待確認） | 429 | ✅ |

---

## 四、Kafka 事件測試

- **生產端**：驗證 `order-created` payload 格式符合 `OrderCreatedEvent` schema（`orderId`、`userId`、`amount`、`priceSnapshot`、`items`），於 Integration Test（TestContainers Kafka）中確認訂單建立成功後事件確實發布。
- **消費端**：驗證 payment-service `OrderCreatedEventConsumer` 冪等性 —— 以 `PAYMENT_IDEMPOTENCY` table 對 `orderId` 去重，模擬 Kafka at-least-once 重複投遞同一事件，確認第二次消費為 skip、不重複建立 `PAYMENTS` 紀錄。

---

## 五、Spring Cloud Contract

| Contract 檔案 | 覆蓋情境 | 位置 |
|-------------|---------|------|
| `create-order.groovy` | `POST /orders` request/response 格式驗證（含 201 成功情境） | `order-service/src/test/resources/contracts/create-order.groovy` |

---

## 六、測試執行結果

| 測試類型 | 執行數 | 通過 | 失敗 | 略過 |
|---------|-------|------|------|------|
| Unit Test | 12 | 12 | 0 | 0 |
| Integration Test | 4 | 4 | 0 | 0 |
| Contract Test | 1 | 1 | 0 | 0 |
| 本機啟動驗證 | - | - | - | - |

> 本機啟動驗證：`[待補充：demo 專案無可執行服務，此為 update-kb 路由煙霧測試，非真實 QA]`

**整體結果：** ✅ 全部通過

**功能正確性判定：** ✅ 通過（回圈 0 輪）

---

## 七、回圈記錄

第一輪執行，無回圈重跑，不需填寫。

---

## 八、待補充 / 後續追蹤

| 項目 | 原因 | 預計處理時間 |
|------|------|-----------|
| 本機啟動驗證 | demo 專案無可執行服務，此為 update-kb 路由煙霧測試，非真實 QA | 不適用 |
| AC4 錯誤代碼字串 | spec/impls 僅描述 `DuplicateOrderException` 行為與 HTTP 429，未明定正式 Error Code 字串，本記錄暫以 `DUPLICATE_ORDER` 推斷填入 | 待下次 spec 更新時與 SA/開發確認正式代碼 |
| 本記錄性質 | 本記錄為 `/update-kb` QA Records 路由的回歸測試（煙霧測試）產出，測試結果為合成資料，非真實執行的 QA 結果 | 不適用 |
