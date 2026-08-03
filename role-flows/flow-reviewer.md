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
- CI 覆蓋確認（曾為「審查不涵蓋範圍」，需先確認對應項目是否真的由 CI 涵蓋，未確認前 Review 階段自行檢查）

審查輸出**必須依序包含三區塊**（詳見 `{{review_guide}}` 頂部格式定義）：
1. 品質問題（Quality Issues）
2. 效能瓶頸 / 資料原子性（Performance & Atomicity Issues）
3. 設計模式（Design Pattern Review）

---

## Step 5 — 執行 Review 並輸出結果

### ticket 模式：雙軸平行審查（避免目的驗證污染原則判斷）

目的驗證（「這段程式碼想做什麼」）與原則審查（「這段程式碼寫得對不對」）是兩種不同性質的判斷——知道 ticket 的**業務意圖敘事**（需求描述、AC、功能目標），容易對違規「從寬解讀」（例如認為某個壞味道是「為了達成目的的合理取捨」）。

但效能瓶頸/資料原子性的嚴重度判斷確實需要規模事實（同一段迴圈查詢，10 筆與千萬筆資料的嚴重度不同）——這不代表 Standards Subagent 需要知道業務目的才能判斷規模。`{{review_guide}}` 第 3-1 節已明定：效能門檻不是逐 ticket 判斷，而是「對應專案 KB 的 MASTER_INDEX → 系統規格基準」這個**專案層級、與 ticket 無關**的標準值（現有 QPS/TPS、資料量現狀）；要知道哪個服務適用哪組數字，只需要「這個異動檔案屬於哪個 service」這個**結構性事實**（從檔案路徑/package 判斷，不是業務意圖），不需要知道這個 ticket 想達成什麼。`{{master_index}}` 已在 Step 1 載入，可直接引用，不需另外向 spec 要規模資訊——這樣才不會為了取得規模事實而繞回需要知道業務意圖的老路。

因此要隔離的只有「業務意圖敘事」，不是「系統規模事實」，後者的正確來源是專案級 `{{master_index}}`，不是這張 ticket 的 spec。ticket 模式**在同一個 response 中**同時發出兩個 `Agent` tool call（不等第一個完成才發第二個），`subagent_type: general-purpose`、`model: sonnet`（比照 `references/preview-mode.md` 的並行派工慣例），兩者互不看對方的輸入與輸出：

**Spec-Compliance Subagent prompt：**

```
你是 Code Reviewer，這次只負責「目的驗證」，不做品質/效能/設計模式判斷（那是另一個 subagent 的職責，與你的判斷互相獨立)。

## 任務
對照 Spec 與 Impl，判斷本次程式碼異動是否達成 ticket 的目的與精神。

## Spec
{$PROJECT_KB}/specs/<TICKET>.md

## Impl
{$PROJECT_KB}/specs/impls/<TICKET>-impls.md

## 本次異動檔案清單
{changed_files}

## 輸出
- 目的與精神：<萃取結果>
- 結果：<達成 / 偏離>（偏離時列出「要 A 做 B」的具體位置與修正方向）

## 限制
不得讀取或引用 `{{review_guide}}`，不做品質/效能/設計模式判斷。
```

**Standards Subagent prompt：**

```
你是 Code Reviewer，這次只負責「原則型審查」——只依程式碼本身、review_guide、與下方提供的專案級系統規格基準判斷是否違規，不需要也不得知道這個 ticket 想達成什麼業務目的（避免因為知道意圖而對違規從寬認定）。

## 任務
1. 呼叫 `/code-architect`，範圍為本次異動的所有檔案，取得架構違規。
2. 依 `{{review_guide}}` 對以下檔案審查品質（OOP / Clean Code / SOLID / DDD）、效能瓶頸 / 資料原子性、設計模式三個面向；`/code-architect` 的違規項併入「品質問題」區塊。判斷效能瓶頸嚴重度時，依每個異動檔案所屬的 service（從檔案路徑 / package 判斷，結構性事實，非業務意圖），對照下方系統規格基準表取得該 service 的門檻值。

## 本次異動檔案清單
{changed_files}

## 系統規格基準（來自 {{master_index}}，專案層級、與本 ticket 無關的標準值）
{{master_index}} 的「系統規格基準」章節原文（現有 QPS/TPS、資料量現狀、系統期望目標，依 service 分列）；**若該專案 MASTER_INDEX 尚未建立此章節** → 略過規模比對，效能瓶頸僅依 review_guide 3-2～3-6 的規則型判斷（N+1、非原子操作、鎖範圍等，這些違規本身不因規模而改變對錯），並在輸出中標注「⚠️ 專案 KB 尚無系統規格基準，嚴重度未依實際規模校準」

## 輸出
依下方格式輸出「品質問題」「效能瓶頸 / 資料原子性」「設計模式」三區塊（格式見下）。

## 限制
不得讀取 spec / impl 檔案，不得詢問或推測這個 ticket 的需求描述 / AC / 功能目標。系統規格基準只能用來判斷效能瓶頸的**嚴重度**，不得用它調整品質原則（OOP / SOLID / DDD）與設計模式的判斷標準。
```

等兩個 subagent 都回傳後，合併為以下格式：

```
## Code Review：<TICKET>

### 目的驗證
- **目的與精神**：<Spec-Compliance Subagent 輸出>
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

沒有 spec 可對照，本就不存在「目的驗證污染原則判斷」的風險——維持單一 pass（主線直接呼叫 `/code-architect` + 依 `{{review_guide}}` 審查），不派雙 subagent。輸出略去「目的驗證」區塊與「摘要」中的「目的驗證」列，其餘三區塊與格式相同。

---

## Step 6 — diagram sync（pipeline 模式）

若由 pipeline 觸發（非單獨呼叫），所有修正完成後：

執行 `/diagram sync`，更新 `{$PROJECT_KB}/source-codex/services/{service}/flow-diagram-{TICKET}.md` 的 Mermaid 圖，反映 review 後的最終程式碼。

---

## Step 7 — 持續對話（單一角色模式）

完成後詢問：「還有其他要 Review 的嗎？」

繼續回到 Step 2，直到使用者結束。
