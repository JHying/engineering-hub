# DEMO-002 實作概述

> 對應 spec：`specs/DEMO-002.md`  
> 涉及服務：procurement-service（後端）  
> 同步 commit：（依實際 commit 填入）  
> 生成方式：Playwright MCP 讀取 Figma Prototype 原型頁面後差距分析產出

---

## 一、AC 實作概述

> Step 1 / 3 / 4 / 5 / 7 基礎已實作；Step 7 自動調整與最小單位處理、批量預算邏輯**待補充**（見「待處理」章節）。

| AC | 涉及層 | 實作狀態 | 實作機制 |
|----|--------|---------|---------|
| Step 1 申請時間窗口 | BE | ✅ | `ProcurementValidationService.checkSubmissionWindow` |
| Step 2 品項類別採購上限 | BE | ⚠️ 待確認 | `filterByPurchaseLimit` 是否含已滿類別排除邏輯 |
| Step 3 供應商衝突 | BE | ✅ | `ProcurementValidationService.checkVendorConflict` |
| Step 4 最低訂購量 | BE | ✅ | `ProcurementValidationService.filterByPurchaseLimit` |
| Step 5 最高訂購量 自動調整(1) | BE | ✅ | `filterByPurchaseLimit`，移除超限品項 |
| Step 6 全公司預算上限 | 外部審核 | ✅ | 週期截止 `verifyBatch` 送預算審核服務 |
| Step 7 部門預算基礎檢查 | BE | ✅ | `checkDeptBudget`（`totalAmount > deptBudget - pendingTotal`）|
| Step 7 自動調整(2) | BE | ❌ 未實作 | 應 `min(自動調整(1), 部門預算餘額)`，目前直接拋例外 |
| 金額最小單位處理（Section 5） | BE | ❌ 未實作 | 依最小採購單位做小數點捨去 |
| 批量 vs 單品預算邏輯差異 | BE | ❌ 未實作 | 批量申請加總 > 餘額全部拒絕（不自動調整）|
| APPLY / REVOKE 驗證路徑分離 | BE | ✅ | `getValidatedApplyRequest` / `getValidatedRevokeRequest` |
| REVOKE 狀態機簡化 | BE | ✅ | `REVOKE_OR_PREEMPT_LUA`，PENDING / REVOKE 兩態 |
| 週期截止批次核准 | BE | ✅ | `ProcurementCloseAppService.doBatchApproval` |
| 截止時離線使用者處理 | BE | ✅ | `SessionConfig.periodLastSessionMap` |

---

## 二、功能異動範圍與系統流程

### 異動範圍

**新增：**
- `ProcurementCloseAppService` — 週期截止批次核准主入口
- `ProcurementValidationService` — 7 步驟驗證
- `TempRequestService` — pending 申請暫存管理
- `BudgetVerifyService` — 批次送審 HTTP client（外部預算審核服務）
- `PurchaseLimitLocalClient` — per-period JVM local cache（`ConcurrentMap<UserPeriodKey, PurchaseLimitCache>`）
- `PeriodCloseDTO` — 週期截止事件 DTO（含 `approvedRequestIds`）

**刪除：**
- `RequestLocalCache`（JVM local 逐筆快取，改為 Redis 暫存）
- `PollingVerifyService`（原逐筆即時審核，改為批次）

**搬移：**
- `ProcurementCloseKafkaController` → 從舊套件搬至 `procurementClose/` 套件

### 系統流程

#### 申請流程（doApply）

```
ProcurementAppService.createRequest(dto, meta)
  → getValidatedApplyRequest(dto, validateVO)
      validationService.ensurePeriodKeyPresent(periodKey, requestId)
      validationService.ensureNoDuplicateApply(requestId)
        reads: TEMP_REQ_IDS:{requestId} status
      validationService.bindingCurrentPeriodEvent(validateVO)
      validationService.checkSubmissionWindow(validateVO)        # Step 1
      validationService.checkVendorConflict(validateVO)          # Step 3
      validationService.filterByPurchaseLimit(validateVO)        # Step 4 / 5
        reads: PurchaseLimitLocalClient → PurchaseLimitRedisClient（miss 時）
        writes: PurchaseLimitLocalClient.put(userPeriodKey, cache)
        mutates: validateVO.items（移除超限品項，自動調整(1)）
      validationService.calcTotalAmount(validateVO)
      validationService.checkDeptBudget(validateVO)              # Step 7（基礎）
        reads: BudgetRedisClient.getPendingTotal(userKey)
  → doApply(req)
      tempRequestService.saveIfAbsent(req)
        writes: [SAVE_LUA] TEMP_REQ_IDS:{requestId} NX EX60s
                            SADD TEMP_USR_REQS:{userPeriodKey} EXPIRE
        NX 失敗 = REVOKE 先到 → 跳過 createNewRequest
      budgetStateService.getCurrentDisplayBudget(req)
      returns: ApplyResponseDTO（成功不送 WS 回應）
```

#### 撤銷流程（doRevoke）

```
ProcurementAppService.createRequest(dto, meta)
  → getValidatedRevokeRequest(dto, validateVO)
      validationService.ensurePeriodKeyPresent
      validationService.ensureNoDuplicateRevoke(requestId)
        reads: TEMP_REQ_IDS:{requestId}
        status==REVOKE → AlreadyExistsException
      validationService.bindingCurrentPeriodEvent
      validationService.checkSubmissionWindow
  → doRevoke(req)
      budgetStateService.executeRevoke(req)
        [REVOKE_OR_PREEMPT_LUA] CAS TEMP_REQ_IDS:{requestId} PENDING→REVOKE
        deductPendingTotal: [DEDUCT_AND_MAYBE_CLEAR_LUA]
      budgetStateService.getCurrentDisplayBudget
```

#### 週期截止批次核准流程（doBatchApproval）

```
ProcurementCloseAppService.broadcastClose(event)
  → sessionConfig.getPeriodLastSessions(periodId)   # Map.copyOf（含離線 user）
  → per-user CompletableFuture.runAsync:
      doBatchApproval(event, userKey)
        tempRequestService.getAllPending(userPeriodKey)
          reads: TEMP_USR_REQS:{userPeriodKey} → TEMP_REQ_IDS:{requestId}...
        budgetVerifyService.verifyBatch(pendingRequests)    # Step 6
          HTTP POST → 外部預算審核服務（timeout=5000ms）
        tempRequestService.deductAllPending(userKey, pendingRequests)
          writes: [DEDUCT_LUA] PENDING_BUDGET:{userKey}
        success → budgetStateService.saveApproved(approvedRequests)
                    writes: DB PROCUREMENT_REQUESTS（status=APPROVED）
        timeout → per-item logRejected(log) + sendCancelNotification
        biz-reject → per-item logRejected(log)（審核系統已處理，不重送）
        tempRequestService.clearUserPeriodRequests(userPeriodKey)
          writes: DEL TEMP_USR_REQS, TEMP_REQ_IDS（batch）
        PurchaseLimitLocalClient.clearByPeriodKey(periodKey)
      session.isOpen() → WsMsgUtils.send（PeriodCloseDTO）
        payload: approvedRequestIds
```

---

## 三、驗測方式

| 測試類型 | 對象 | 涵蓋範圍 | 狀態 |
|---------|------|---------|------|
| Unit Test | `ProcurementValidationServiceTest` | checkSubmissionWindow / checkDeptBudget / filterByPurchaseLimit 邊界 | ❌ 未建 |
| Integration Test | `DoBatchApprovalIT` | success / timeout / biz-reject 三路；離線 user 有 pending 申請 | ❌ 未建 |
| Integration Test | `TempRequestRedisClientTest` | REVOKE pre-emptive；APPLY CAS；SAVE_LUA 原子性 | ❌ 未建 |
| Unit Test | `PurchaseLimitManagerTest` | getLimit（cache hit / miss） | ⚠️ 部分覆蓋 |

---

## 四、SA 系統需求規格實作

- **Redis key**：
  - `TEMP_REQ_IDS:{requestId}`：TTL=60s，存申請狀態（PENDING / REVOKE）
  - `TEMP_USR_REQS:{userPeriodKey}`：TTL=60s，存 requestId set
  - `PENDING_BUDGET:{userKey}`：待核准金額累計，週期截止後批次扣除
  - `USER_SESSION_LOCK:{userKey}`：連線鎖，Lua 條件刪除防競態

- **訊息佇列**：
  - `ProcurementCloseKafkaController` 搬移，topic 名稱不變

- **DB**：`PROCUREMENT_REQUESTS`（schema 不異動），requestId 來源 DB sequence

- **Config 變更**：
  - `budget.verify.timeout`：外部預算審核服務 HTTP timeout（預設 5000ms）

- **合約異動（WS）**：
  - 新增 `WsMessageType.PERIOD_CLOSE`，payload `PeriodCloseDTO`（含 `approvedRequestIds`）
  - 申請成功不送 WS 回應

---

## 五、待處理（Pending）

### P1 — Step 7 部門預算自動調整（單品申請）

**規格：** 預算不足時不直接拒絕，應自動縮減：
```
自動調整(2) = min(自動調整(1) 金額, 部門預算餘額)
→ 執行金額最小單位處理
→ 結果 = 0 → 拒絕
→ 結果 > 0 → 以結果金額提交
```
**現況：** `checkDeptBudget` 直接拋例外，無自動調整。

---

### P1 — Section 5 金額最小單位處理

**規格：**
```
最小採購單位 ≥ 1  → 申請金額 = floor(部門預算餘額)
最小採購單位 < 1  → 申請金額 = floor(餘額 / 最小採購單位) * 最小採購單位
結果 = 0          → 拒絕
```
**現況：** 完全未實作，需新增 `adjustByMinUnit(budget, minUnit)` 工具方法。

---

### P2 — 批量 vs 單品的預算邏輯差異

**規格：**
- 批量申請：加總 > 部門預算餘額 → 全部拒絕（不自動調整）
- 單品申請：自動調整(2) 後才拒絕

**現況：** 所有 action type 走同一路徑，未區分。

---

### P2 — Step 2 品項類別採購上限驗核確認

**現況：** `filterByPurchaseLimit` 是否已含「類別已滿 → 跳過該品項」邏輯待確認。

---

### 測試補齊（Pending）

| 目標 | 場景 |
|------|------|
| `ProcurementValidationService.checkDeptBudget` | 自動調整(2) + 最小單位各 boundary |
| `ProcurementValidationService.filterByPurchaseLimit` | 類別已滿；Min / Max 各 boundary |
| `TempRequestRedisClient` | REVOKE pre-emptive；APPLY CAS；SAVE_LUA 原子性 |
| `BudgetVerifyService` | timeout vs 業務拒絕的回傳值差異 |
| `ProcurementCloseAppService.doBatchApproval` | success / timeout / biz-reject 三路 |
| 離線 user 截止核准 | pending 申請正常處理；不送 WS 回應 |
