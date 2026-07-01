---
name: qa
description: >
  QA Engineer 工作流程。收到 Jira Story 後產出測試策略選擇，再依選擇產出完整測試規劃。
---

# QA Engineer 工作流程

角色定義見 `{{role_qa}}`

---

## Step 1 — 詢問 Jira 單號

```
請輸入要分析的 Jira 單號（例：PROJ-123），或直接貼上 Story 內容：
```

- 若輸入單號格式 → 嘗試用 Jira MCP 拉取 issue 內容
- 若 Jira MCP 不可用或失敗 → 請使用者直接貼上 Story 文字
- 若使用者直接貼文字 → 直接使用

---

## Step 2 — 載入 System Context

依序讀取：
1. `{{master_index}}` — 服務清單與路由規則
2. `{{review_guide}}` — 系統規格基準（現狀 QPS / 資料量）、效能 / 原子性審查標準、技術棧邊界條件參照

---

## Step 3 — 分析 Story，讀取相關文件

### 3a — 服務文件

參照 `{{master_index}}` 的「AI 文件路由規則」判斷涉及哪些 service。

每個涉及的 service，依序讀取：
1. `docs/system/{service}/features.md` — 現有功能範圍
2. `docs/system/{service}/api-spec.md`（若涉及 REST API）
3. `docs/system/{service}/kafka-events.md`（若涉及 Kafka）

### 3b — 實作知識（按需補充）

| 條件 | 讀取文件 |
|------|---------|
| AC 出現 ticket 單號 | `{$PROJECT_KB}/specs/{TICKET}.md`（若存在） |
| 需要 Spring Cloud Contract | skill: `/contract-test` |

---

## Step 4 — 產出 Phase 1（測試策略選擇）

```
## 方案 A：{測試策略標題}
- 做法：（Unit + Integration / E2E 比例）
- 優點：
- 缺點：
- 適合當：

## 方案 B：{測試策略標題}
- 做法：
- 優點：
- 缺點：
- 適合當：

---
請問您選擇方案 A 還是方案 B？
```

---

## Step 5 — 等待選擇，產出 Phase 2（完整測試規劃）

### Happy Path 測試案例
| # | 前置條件 | 操作步驟 | 預期結果 | 對應 AC |

### Edge Case 清單
> 邊界條件數值基準參照對應**專案 KB 的系統規格基準**，審查標準見 `{{review_guide}}` 效能 / 原子性章節（3-2 ～ 3-7）。

| # | 情境描述 | 輸入 / 狀態 | 預期行為 | 嚴重度 |

### 錯誤情境（Error Code 覆蓋）
| # | 觸發條件 | 預期 Error Code | HTTP Status |

### Kafka 事件測試（若涉及事件驅動）
- 生產端：驗證 Event payload 格式
- 消費端：驗證冪等性、亂序處理

### Spring Cloud Contract（若需要）
使用 skill: `/contract-test` 產生 Groovy DSL 契約。

### Mock 清單
| 外部依賴 | Mock 工具 | 需要 stub 的情境 |
|---------|----------|----------------|

---

## 關注重點
- AC 覆蓋率（每條 AC 至少一個 Happy Path）
- 邊界值（空值、負數、最大長度、並發）— 數值基準參照 `{{review_guide}}` 系統現狀
- 跨 service 依賴的 Mock 是否完整
- Kafka 事件的冪等性驗證
- 並發 / 跨 Pod 同步場景（Caffeine 失效、分散式鎖競爭、Session 水平擴展）— 參照 `{{review_guide}}` 3-6 章節
