---
name: reviewer
description: >
  Reviewer 工作流程。支援 ticket 模式（PROJ-XXX 目的驗證 + 原則審查）與範圍模式（僅原則審查）。
---

# Reviewer 工作流程

角色定義見 `{{role_reviewer}}`

---

## Step 1 — 載入 System Context

依序讀取：
1. `{{master_index}}` — 服務清單（確認涉及的 service）
2. `{{role_reviewer}}` — 審查層級與輸出格式
3. `{{review_guide}}` — 技術棧分類、品質 / 效能 / 設計模式審查標準、系統規格基準

---

## Step 2 — 詢問審查範圍

```
請輸入審查範圍：
  - 指定 ticket 單號（例：PROJ-123）→ ticket 模式（目的驗證 + 原則審查）
  - 指定檔案 / class 清單 → 範圍模式（僅原則審查）
```

- 若輸入 ticket 單號格式 → 進入 ticket 模式
- 若輸入檔案或 class 清單 → 進入範圍模式
- 若未提供任何範圍 → 主動詢問，不自動降級

---

## Step 3 — 載入審查材料

**ticket 模式：**
1. 讀 `{$PROJECT_KB}/specs/<TICKET>.md`
2. 讀 `{$PROJECT_KB}/specs/impls/<TICKET>-impls.md`
3. 從 impl 的影響清單取得實際審查的 class 範圍
4. 萃取「目的與精神」：
   - spec 有「目的與精神」段落 → 直接採用
   - 否則從「問題背景」「功能目標」「設計方向」綜合歸納

**範圍模式：**
直接使用使用者提供的 class / 檔案清單，跳過目的萃取。

---

## Step 4 — 載入審查規範

讀取統一審查規範：`{{review_guide}}`

此文件涵蓋：
- 品質審查（OOP、Clean Code、SOLID、DDD）
- 效能瓶頸 / 資料原子性（系統現狀為強制門檻、系統期望目標僅供參考、跨 Pod 同步）
- 設計模式（Singleton、Factory Method、Abstract Factory、Aggregator Pattern、Spring Aggregator Pattern）
- 技術棧分類表（Java、Spring Cloud 2025、Spring Boot 3、Spring Data JPA/Mongo、WebSocket、Kafka、Redis、Oracle、gRPC、HTTP、Undertow、Tomcat、JAR、WAR、Servlet、JDBC、JSP、Vue）
- 審查不涵蓋範圍

審查輸出**必須依序包含三區塊**（詳見 `{{review_guide}}` 頂部格式定義）：
1. 品質問題（Quality Issues）
2. 效能瓶頸 / 資料原子性（Performance & Atomicity Issues）
3. 設計模式（Design Pattern Review）

---

## Step 5 — 執行 Review 並輸出結果

### ticket 模式輸出格式

```
## Code Review：<TICKET>

### 目的驗證
- **目的與精神**：<萃取結果>
- **結果**：<達成 / 偏離>
  （若偏離，列出「要 A 做 B」的具體位置與修正方向）

---

### 品質問題（Quality Issues）
#### <ClassName>
- [ ] **違規類型**：<OOP / Clean Code / SOLID / DDD>
  **原則**：<被違反的原則，例：SRP、Tell Don't Ask、封裝>
  **發現**：`<違規程式碼片段>`
  **修正**：`<修正方向或程式碼>`

（無問題時明確寫：✅ 無品質問題）

---

### 效能瓶頸 / 資料原子性（Performance & Atomicity Issues）
#### <ClassName>
- [ ] **問題類型**：<DB / Redis / Kafka / HTTP / 並行 / 跨Pod / WebSocket>
  **發現**：`<違規程式碼片段>`
  **風險**：<說明在現狀或期望目標下的影響>
  **修正**：`<修正方向或程式碼>`

（無問題時明確寫：✅ 無效能 / 原子性問題）

---

### 設計模式（Design Pattern Review）
- **已使用**：
  - <模式名稱> @ `<ClassName / 方法>` — <合適 / 誤用，說明原因>
- **過度設計**：
  - <位置> — <說明，例：僅一個實作卻抽介面>
- **建議引入**：
  - <模式名稱> @ `<位置>` — <引入理由與不引入的代價>

（三個子項若均無內容，明確寫：✅ 無設計模式問題）

---

### 摘要
- 目的驗證：<達成 / N 處偏離>
- 品質問題：<N 項>
- 效能 / 原子性問題：<N 項>
- 設計模式問題：<N 項>
```

### 範圍模式輸出格式

略去「目的驗證」區塊與「摘要」中的「目的驗證」列，其餘三區塊與格式相同。

---

## Step 6 — 持續對話

完成後詢問：「還有其他要 Review 的嗎？」

繼續回到 Step 2，直到使用者結束。
