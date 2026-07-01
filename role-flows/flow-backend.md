---
name: backend
description: >
  Backend Developer 工作流程。收到 Jira Story 後產出實作方案選擇，再依選擇產出完整 Java 程式碼。
---

# Backend Developer 工作流程

角色定義見 `{{role_backend}}`

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
2. `{{review_guide}}` — 技術棧審查標準、品質原則（OOP / SOLID / DDD）、效能基準（系統現狀為門檻）、設計模式

---

## Step 3 — 分析 Story，讀取相關文件

### 3a — 服務文件（系統現況）

參照 `{{master_index}}` 的「AI 文件路由規則」判斷涉及哪些 service。

每個涉及的 service，依序讀取：
1. `docs/system/{service}/features.md` — 現有功能，判斷新功能要加在哪
2. `docs/system/{service}/architecture.md` — 技術架構與設計決策
3. 依需求補讀：
   - 涉及 REST API → `api-spec.md`
   - 涉及 Kafka → `kafka-events.md`
   - 涉及狀態機 → `state-machine.md`

跨多個 service → 各自完整讀取後整合。

### 3b — 實作知識（按需補充）

參照 `{{master_index}}` 的「實作知識路由規則」：

| 條件 | 讀取 / 參照 |
|------|-----------|
| AC 出現 ticket 單號，Spec KB 已存在 | `{$PROJECT_KB}/specs/{TICKET}.md`（直接讀取） |
| AC 出現 ticket 單號，Spec KB **不存在**，有企劃書原型頁面 | 執行 **Step 3c**（Playwright MCP 自動生成 Spec + Impl KB） |
| 涉及高併發 / Redis / Kafka / 批次 / 跨 Pod 同步 | `{{review_guide}}` 第三章（已載入，直接參照） |
| 設計模式選擇（Strategy / Aggregator / Factory） | `{{review_guide}}` 第四章（已載入，直接參照） |
| 任何 Story（BACKEND 必讀） | `{{unit_test}}` |
| 新增或修改 Mapper | `{{mapper_test}}` |

---

## Step 3c — Spec KB 不存在時：Playwright MCP 讀取原型頁面

當 `{$PROJECT_KB}/specs/{TICKET}.md` 尚不存在，且企劃書發布在 Axshare / Figma Prototype 等工具時，
可讓 Claude 直接讀取原型頁面，自動完成「原型 → 差距分析 → Spec + Impl KB 生成」。

### 操作步驟

1. 取得原型頁面 URL（Axshare share link，需確認頁面名稱 `p=` 參數指向正確分頁）
2. 告知 Claude：

   ```
   用 playwright 去讀 {原型頁面 URL}
   看目前實作還缺什麼功能
   ```

3. Claude 依序執行：
   - `playwright_navigate` → 開啟頁面
   - `playwright_get_visible_text` → 提取 AC 條件與流程說明
   - 比對現有程式碼，列出 ✅ 已實作 / ⚠️ 部分實作 / ❌ 未實作
4. 確認差距分析無遺漏後，指示 Claude：

   ```
   KB 生成 {TICKET} 的 story 與 impl，補充待處理
   ```

5. 生成 `{$PROJECT_KB}/specs/{TICKET}.md` + `{$PROJECT_KB}/specs/impls/{TICKET}-impls.md`
6. 完成後繼續 **Step 4**（方案選擇）

### 前置條件

- Claude Code 需設定 Playwright MCP（`@playwright/mcp@latest`）
- 需安裝與 MCP 版本對應的 Chromium：

  ```bash
  # 確認 MCP 使用的 playwright 版本，再安裝對應 chromium
  npx playwright@{對應版本} install chromium
  ```

  詳細版本對齊方式見：`common_KBs/tech-research/playwright-mcp-spec-to-kb-workflow.md`

---

## Step 4 — 產出 Phase 1（方案選擇）

```
## 方案 A：{標題}
- 做法：
- 優點：
- 缺點：
- 適合當：

## 方案 B：{標題}
- 做法：
- 優點：
- 缺點：
- 適合當：

---
請問您選擇方案 A 還是方案 B？
```

---

## Step 5 — 等待選擇，產出 Phase 2（Java 程式碼）

使用者選擇方案後，產出：
1. 完整 Java 程式碼（含所有需要新增/修改的類別）
2. 程式碼必須符合 skill: `/code-architect` 規範
3. 附上修改清單：修改了哪些檔案、原因

### 程式碼規範重點
- 分層：Controller → AppService → DomainService → Manager → Infra
- 不寫多餘 comment，命名即文件
- MapStruct 做 DTO 轉換（100% method coverage）
- 不在 Controller 寫業務邏輯
- Kafka 事件依專案 toolbox 規範管理，不手動建 KafkaTemplate bean
- 實作需自審：品質（OOP / SOLID / DDD）、效能（對照 `{{review_guide}}` 系統現狀門檻）、設計模式（避免過度設計）

### Manager 層分層鐵則（勿犯）
Manager 只包裝 Infra 操作、回傳技術結果；**不拋業務例外、不做業務判斷**。

| 層 | 職責 | 例外/判斷 |
|----|------|---------|
| Infra | 執行 Redis / DB 操作，回傳技術結果（boolean / Optional / 數值） | 只拋技術例外（DataAccessException 等） |
| Manager | 透傳 Infra 結果，最多加 javadoc 說明語意 | ❌ 不拋業務例外 |
| Domain Service | **解讀結果、做業務決策** | ✅ `if (!result) throw new XxxException(...)` |
| App Service | catch 業務例外 → 轉換為 response | ✅ `catch (XxxException e) → generateFailedResponse` |

```
// ✅ 正確分層（Redis NX 為例）
Infra:    Boolean saved = setIfAbsent(key, value, ttl);  return saved;
Manager:  return xxxRepository.saveItem(data);               // 透傳 boolean
Domain:   if (!xxxManager.savePendingItem(req)) throw new ItemAlreadyExistsException(...);
App:      catch (ItemAlreadyExistsException e) → generateFailedResponse(req);

// ❌ 錯誤：Manager 做業務判斷
Manager:  if (!result) throw new ItemAlreadyExistsException(...);  // 不應在此層
```

---

## 注意事項
- 分析期間有任何不清楚 → 直接問使用者，不要假設
- 跨多個 service → 各自文件全部讀取後整合
- Jira MCP 拉到的資訊不足 → 詢問使用者補充
