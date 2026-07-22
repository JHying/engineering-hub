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

> 範本格式參照 `{{qa_format}}`

### AC / Gherkin 對齊檢查

逐條核對需求企劃（PM）與 Spec 轉化（SA）階段產生的 AC 與 Gherkin 範本，確認每條都有對應測試案例覆蓋；若測試結果與 AC/Gherkin 有落差，標注落差屬於「測試案例設計問題」或「功能本身確實有誤」——只有後者才需要回報給上游觸發 Spec-Driven 實作修正。

| # | AC / Gherkin 條目 | 對應測試案例 | 是否對齊 | 落差類型（若不對齊） |
|---|------------------|------------|---------|-------------------|

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

## Step 6 — 執行測試並記錄結果（auto 模式）

> **測試範圍不在本檔定義**：以下只規範三類驗測的**內容**。實際要跑全套或限縮於異動影響範圍，
> 依 `my-work-agent` skill 的「測試執行分層」規則判定（摘要：單一角色模式的 QA 跑全套；
> pipeline 模式限縮於本 ticket 異動影響範圍，回圈輪再縮）。本檔與該規則衝突時，以該規則為準。

auto 模式下，Phase 2 完成後執行三類驗測：

1. **Unit test**：撰寫單元測試程式碼並執行
2. **Integration test**：撰寫整合測試程式碼並執行，取得通過 / 失敗 / 略過統計；若有 Spring Cloud Contract，驗證契約測試通過
3. **本機啟動驗證**：此為本機驗測，非部署（部署屬 SRE 職責，不在 QA 範圍）。讀取 `{$PROJECT_KB}/source-codex/services/{service}/sop-service-startup-verification-internal.md`（若存在）並依其步驟執行（build → 重啟服務 → 健康檢查，皆在本機進行）；若專案尚未建立此 SOP，標注 `[待補充：本機啟動驗證 SOP 尚未建立]`，不因此中斷後續流程
4. 呼叫 `/update-kb`，依 `{{qa_format}}` 建立 `{$PROJECT_KB}/qa-records/{TICKET}-qa.md`，記錄測試案例表、範圍與三類驗測結果

confirm 模式下，完成 Phase 2 輸出後：
- 詢問使用者是否執行測試
- 確認後依上方三類驗測執行，完成後呼叫 `/update-kb` 記錄結果

### 功能正確性判定（不分 auto / confirm，三類驗測執行後皆需判定）

對照「AC / Gherkin 對齊檢查」表與三類驗測結果，判定：

| 判定結果 | 條件 | 後續動作 |
|---------|------|---------|
| 通過 | 三類驗測皆過，且對齊 PM / SA 的 AC 與 Gherkin | 先執行下方「通過後：移除多餘註解」，再流程結束（或依 pipeline 進入下一 stage） |
| 測試案例本身問題 | 落差來自測試案例設計錯誤（如前置條件寫錯、預期值誤植） | 修正測試案例後重新執行，不計入回圈輪數 |
| 功能確實有誤 | 落差來自實作行為與 AC / Gherkin 不符 | 回報具體缺陷描述 + 對應 AC/Gherkin 落差，交還 Spec-Driven 實作修正；此輪計入回圈輪數，連續 3 輪未通過則暫停，與使用者討論現況與解決方法 |

### 通過後：移除多餘註解（判定通過、輸出總結前的最後一步）

在功能正確性判定通過後、（pipeline 模式下）輸出「🎉 流程完成」總結前：

1. 掃描**本輪異動**的程式碼（`git diff` 範圍內，非全專案），逐一檢視新增/修改的方法與註解
2. 範圍**不限於**「描述做什麼」的註解——**解釋為什麼的註解（隱藏限制、bug workaround、非顯而易見的業務規則等）同樣要移除**，除非該內容是語言層級硬性要求（如 `@deprecated` 標記本身）才保留最精簡形式
3. 保留：Java 語言/框架層級要求存在的標記（`@deprecated` 等 javadoc tag 本身、`// @formatter:off` 這類工具指令），但去掉其附帶的說明文字
4. 有異動時重新執行受影響測試確認未破壞行為，並將異動一併記錄於本輪的 `/update-kb` 產出（pipeline 模式併入既有 pending 草稿，不另開新草稿）

---

## 關注重點
- AC 覆蓋率（每條 AC 至少一個 Happy Path）
- 邊界值（空值、負數、最大長度、並發）— 數值基準參照 `{{review_guide}}` 系統現狀
- 跨 service 依賴的 Mock 是否完整
- Kafka 事件的冪等性驗證
- 並發 / 跨 Pod 同步場景（Caffeine 失效、分散式鎖競爭、Session 水平擴展）— 參照 `{{review_guide}}` 3-6 章節
