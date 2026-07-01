# DEMO-002 採購申請驗證（多步驟驗證 + 批次核准）

**初版：** 2026-07-01  
**企劃書：** （由 Playwright MCP 讀取原型頁面後生成，原型工具：Figma Prototype）  
**範疇：** procurement-service（後端）

---

## 需求描述

使用者透過 WebSocket 連線提交採購申請（單品 / 批量複製 / 重複上期申請）時，後端依序執行 7 步驟驗證。
驗核時機改為**批次核准**：提交時只做 Redis 暫存；與預算審核系統的遠端核准呼叫改在**採購週期截止事件**觸發時批次送出。

---

## 功能目標

- 後端按優先序（Step 1 → 7）執行所有驗證
- 單品申請：某步驟失敗 → 停止後續，回傳對應錯誤
- 批量申請（複製 / 重複上期）：各品項獨立驗證，部分品項失敗不影響其他品項（部分步驟例外）
- 驗核時機：`doApply` 只做 Redis NX；預算上限核查（Step 6）改在週期截止時批次送出

---

## 驗收條件與邊界情境

### Step 1 — 申請時間窗口（後端）
- [ ] 申請落在可申請時段內 → 通過
- [ ] 超出可申請時段 → 全部品項拒絕，中央訊息：申請未成功
- 注：前端計時僅供提示，以後端時間為準

### Step 2 — 品項類別採購上限（前端 + 後端）
- [ ] 該類別本期剩餘可採購數量 > 0 → 通過
- [ ] 剩餘數量 = 0（類別已滿）→ 該品項跳過申請，**不顯示 Hint**
- [ ] 重複上期：已滿類別跳過（無 Hint），其他品項繼續 Step 4

### Step 3 — 供應商衝突規則（前端 + 後端）
- [ ] 無衝突 → 通過
- [ ] 同一申請中存在互斥供應商（A 廠與 B 廠不可同期採購）→ 拒絕，Hint：供應商衝突
- [ ] 複製 / 重複上期：同期申請不改變已選廠商，不會發生衝突，步驟略過

### Step 4 — 最低訂購量（前端 + 後端）
- [ ] `(本次申請量 + 本期已申請量) >= 廠商最低訂購量` → 通過
- [ ] 未達最低訂購量 → 拒絕，Hint：最低訂購量: {0}
- [ ] 不執行自動調整（低於最低訂購量廠商不接單，無意義）
- [ ] 重複上期（限量變動）：未達最低量的品項跳過（有 Hint），其他品項繼續 Step 5

### Step 5 — 最高訂購量（前端 + 後端）
- [ ] `(本次申請量 + 本期已申請量) <= 單次採購上限` → 通過
- [ ] 已達上限 → 拒絕，Hint：採購上限: {0}
- [ ] 已申請 < 上限但本次超過 → **自動調整(1)** = `min(本次申請量, 上限 - 已申請量)`，繼續 Step 6
- [ ] 重複上期：已達上限的品項跳過（有 Hint），其他品項繼續

### Step 6 — 全公司預算上限（僅後端，批次核准時核查）
- [ ] `其他部門已佔用 + 本次申請(或自動調整(1)) <= 全公司預算上限` → 通過
- [ ] 超過 → 拒絕，中央訊息：申請未成功（**不自動調整**，申請人無法得知他人佔用量）
- [ ] 重複上期：超過的品項跳過，其他品項繼續 Step 7
- 注：此步驟在週期截止時批次呼叫預算審核系統核查，非提交即時呼叫

### Step 7 — 部門預算餘額（前端 + 後端）

**單品申請：**
- [ ] 部門預算餘額 = 0 → 拒絕，Hint：部門預算不足
- [ ] 部門預算餘額 < 自動調整(1) 金額 → **自動調整(2)** = `min(自動調整(1) 金額, 部門預算餘額)` → 執行金額最小單位處理
  - 結果 = 0 → 拒絕，Hint：部門預算不足
  - 結果 > 0 → 通過，以結果金額提交

**批量申請（複製 / 重複上期）：**
- [ ] 所有待申請品項金額加總 > 部門預算餘額 → 全部拒絕，Hint 顯示在**觸發元件**（按鈕處）

### 金額最小單位處理（Section 5）
- [ ] 最小採購單位 ≥ 1：申請金額 = `floor(部門預算餘額)`
- [ ] 最小採購單位 < 1：申請金額 = 無條件捨去至最小採購單位的最大倍數
- [ ] 結果 = 0 → 拒絕
- 範例：部門預算餘額 0.7 萬、最小採購單位 0.5 萬 → 申請 0.5 萬；餘額 0.3 萬 → 0，拒絕

---

## 資料流

```
ProcurementAppService.createRequest(req, meta)
  → getValidatedRequest(req, meta)
      APPLY / BULK / REPEAT → getValidatedApplyRequest
        validationService.ensurePeriodKeyPresent(periodKey, requestId)
        validationService.ensureNoDuplicateApply(requestId)
          reads: TEMP_REQ_IDS:{requestId} status
        validationService.bindingCurrentPeriodEvent(validateVO)
        validationService.checkSubmissionWindow(validateVO)        # Step 1
        validationService.checkVendorConflict(validateVO)          # Step 3
        validationService.filterByPurchaseLimit(validateVO)        # Step 2 + Step 4 + Step 5
          reads: PurchaseLimitLocalClient → PurchaseLimitRedisClient (miss 時)
          writes: PurchaseLimitLocalClient.put(userPeriodKey, cache)
          mutates: validateVO.items（移除超限品項，自動調整(1)）
        validationService.calcTotalAmount(validateVO)
        validationService.checkDeptBudget(validateVO)              # Step 7（基礎）
          reads: BudgetRedisClient.getPendingTotal(userKey)
      REVOKE → getValidatedRevokeRequest
        (Step 1、ensureNoDuplicateRevoke、bindingCurrentPeriodEvent、checkSubmissionWindow only)
  → executeRequest(req, validateVO)
      doApply:
        tempRequestService.saveIfAbsent(req)
          writes: [SAVE_LUA] TEMP_REQ_IDS:{requestId} NX EX60s
                              SADD TEMP_USR_REQS:{userPeriodKey} EXPIRE
          NX 失敗 = REVOKE 先到 → 跳過 createNewRequest
        budgetStateService.getCurrentDisplayBudget(req)
          reads: BudgetRedisClient.getPendingTotal(userKey)
        returns: ApplyResponseDTO（成功不送 WS 回應）

採購截止時 ProcurementCloseAppService.doBatchApproval(event, userKey)
  → tempRequestService.getAllPending(userPeriodKey)
      reads: TEMP_USR_REQS:{userPeriodKey} → TEMP_REQ_IDS:{requestId}...
  → budgetVerifyService.verifyBatch(pendingRequests)    # Step 6（預算審核系統）
      HTTP POST → 外部預算審核服務（timeout=5000ms）
  → budgetStateService.saveApproved / logRejected
  → tempRequestService.clearUserPeriodRequests(userPeriodKey)
      writes: DEL TEMP_USR_REQS, TEMP_REQ_IDS（batch）
  → PurchaseLimitLocalClient.clearByPeriodKey(periodKey)
```

---

## 影響範圍

- **目標 Service**：procurement-service
- **涉及層級**：
  - AppService：`ProcurementAppService`、`ProcurementCloseAppService`
  - DomainService：`ProcurementValidationService`、`BudgetStateService`、`TempRequestService`、`BudgetVerifyService`
  - Manager：`TempRequestManager`、`BudgetVerifyManager`、`PendingBudgetManager`、`PurchaseLimitManager`
  - Infra：`TempRequestRedisClient`、`BudgetRedisClient`、`BudgetVerifyClient`、`PurchaseLimitLocalClient`

---

## 前後端 Contract

**後端 → 前端（WebSocket，申請回應）**
- 成功：不送 WS 回應（前端由品項數量遞增確認）
- 失敗：`WsMessageType.APPLY`，`ApplyResponseDTO.errorCode`
- 截止核准：`WsMessageType.PERIOD_CLOSE`，`PeriodCloseDTO`（含 `approvedRequestIds`）

**錯誤碼優先序**

| 優先序 | 步驟 | 後端行為 |
|--------|------|---------|
| 1 | 申請時間窗口 | 中央訊息：申請未成功 |
| 2 | 品項類別採購上限 | 跳過（重複上期）/ 不顯示 Hint |
| 3 | 供應商衝突 | 中央訊息：申請未成功 |
| 4 | 最低訂購量 | 中央訊息：申請未成功 |
| 5 | 最高訂購量 | 中央訊息：申請未成功 |
| 6 | 全公司預算上限 | 中央訊息：申請未成功（批次核查後通知）|
| 7 | 部門預算不足 | 中央訊息：申請未成功 |

---

## 特殊限制

- Step 6 全公司預算上限：申請人無法得知他人已佔用量，**不執行自動調整**，超過直接拒絕
- Step 4 最低訂購量：**不執行自動調整**（低於廠商最低訂購量無法成立訂單）
- 預算核查時機：週期截止批次，非每筆即時
- `BudgetVerifyClient` timeout：5000ms，timeout 才送 cancel 通知；業務拒絕不送
- 批量 Hint 位置：顯示在觸發元件（批量複製 / 重複上期按鈕），不在品項列表上方
