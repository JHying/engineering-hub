---
name: sa
description: >
  SA 工作流程。銜接 PM 需求企劃的第一版草稿，補足技術文件落差，產出完整需求規格說明書（specs/{TICKET}.md）。
  每個架構決策點與 CONSULTANT 角色協作確認並記錄 ADR。
---

# SA 工作流程

角色定義見 `{{role_sa}}`

---

## Step 1 — 取得輸入

優先讀取 `{$PROJECT_KB}/specs/{TICKET}.md`（PM 需求企劃產出的第一版）。

若尚不存在，詢問使用者：

```
請輸入 Jira 單號（例：PROJ-123）或直接貼上 Story / 需求描述：
```

- 若輸入單號 → 嘗試用 Jira MCP 拉取；失敗則請使用者貼文字
- 若直接貼文字 → 直接使用

---

## Step 2 — 載入 System Context

依序讀取：
1. `{{master_index}}` — 服務清單、AI 路由規則、技術棧概覽
2. `{{review_guide}}` — 系統規格基準（效能門檻、並發、atomicity 標準）
3. `{$PROJECT_KB}/ADRs/index.md`（若存在）— 現有架構決策快速查詢表

---

## Step 3 — 識別技術缺口

逐節檢查現有 spec（或 Story 內容），對照 `spec-format.md` 標準結構，
標記尚未補足的技術資訊：

| 區段 | 缺口類型 |
|------|---------|
| 資料流 | 缺 class 名稱、topic / table / key 格式、跨 service 呼叫鏈 |
| 影響範圍 | 缺目標 service 清單、受影響層級與 class |
| Contract | 缺 API response 結構、Kafka payload、gRPC / WebSocket 格式 |
| 特殊限制 | 未記錄不能用某方案的原因、key 格式限制、TTL 約束 |
| 非功能需求 | 未對照系統規格基準說明效能目標、並發邊界、atomicity 要求 |

---

## Step 4 — 識別架構決策點，協作 CONSULTANT

對 Step 3 識別出的每一個涉及**技術選型或架構決策**的缺口：

1. 查詢 `{$PROJECT_KB}/ADRs/index.md`（或現有 ADR 清單）確認是否已有相關決策
2. **已有相關 ADR** → 直接依 ADR 結論填補 spec，標注 `[ref: ADR-{nnnn}]`
3. **無相關 ADR** → 作為決策點，依 `{{flow_consultant}}` 分析：
   - 確認需求、系統規模考量、現有架構限制、專案技術棧
   - auto 模式：自行依 KB 內容分析最佳解，確定後呼叫 `/update-kb` 記錄新 ADR
   - confirm 模式：呈現選項，等待使用者確認後呼叫 `/update-kb` 記錄新 ADR

---

## Step 5 — 補足完整 spec

依 `{{spec_format}}` 補齊所有區段，寫入 `{$PROJECT_KB}/specs/{TICKET}.md`：

- **需求描述**：範疇、業務需求、交付標準摘要
- **驗收條件與邊界情境**：逐條 checkbox，每條有明確 input / output
- **功能目標**：條列此 ticket 要達成的事
- **資料流**：code-like facts 格式，可追蹤至 class / topic / table
- **影響範圍**：目標 service 清單 + 受影響層級與 class
- **Contract**：API / Kafka / gRPC / WebSocket 介面規格
- **特殊限制**：設計時不能踩的地雷

---

## Step 6 — 判斷是否建立 impls 文件

檢查此 ticket 是否已有部分實作（Jira 狀態、`is implemented by` 欄位、或使用者說明）：

- **有部分實作** → 讀取對應 service 的 `source-codex/services/{service}/facts.md`，
  依 `{{impls_format}}` 建立 `{$PROJECT_KB}/specs/impls/{TICKET}-impls.md`
- **尚無實作** → 略過，impls 文件由 Spec-Driven 實作 stage 完成後另行建立

---

## Step 7 — /update-kb 記錄產出

呼叫 `/update-kb`，記錄：
- 完整 `specs/{TICKET}.md`
- 本次新建的 ADR 清單（若有）
- `specs/impls/{TICKET}-impls.md`（若 Step 6 有建立）

---

## Step 8 — 回寫 Jira 描述（僅當有指定單號）

**適用條件**：本次 SA 對象有明確 Jira 單號（使用者以單號啟動，或流程中已取得）。無單號 → 略過本步。

**執行時機**：Step 7 完成 KB pending 草稿 / 正式入庫之後。

**回寫內容**：spec 的「功能目標 / 商業規則 / 驗收條件與邊界情境 / Gherkin」四區段。其餘技術細節（資料流、影響範圍、非功能、特殊限制）**不回寫**——屬 RD / KB 內部知識，不進 Jira。

**Confirm 模式：不直接執行——先詢問使用者是否要回寫 Jira 描述**，同意才做。
**Auto 模式**：可直接執行（仍套用下方去識別化）。

### Jira 去識別化（強制，寫入前必做）

Jira 描述是給**全團隊 / 跨團隊**閱讀，須移除只有 KB 語境才看得懂的知識庫專有名詞：

| 類別 | 範例 | 處理 |
|------|------|------|
| ADR 編號與引用 | `ADR-0014`、`[ref: ADR-0013]`、「決策脈絡見 ADR-xxxx」 | 移除；必要時改寫為該決策的白話結論（不提 ADR 編號） |
| KB 內部檔案路徑 | `specs/...`、`ADRs/...`、`source-codex/...`、`pending/...` | 移除 |
| KB 專屬流程 / 分類術語 | 「pending 草稿」、KB stage 代號等 | 改為團隊通用說法或移除 |

**保留**：Jira 單號（`LS-xxxx` 等，團隊可見）、程式碼類別 / 方法名（團隊原始碼）、業務規則、AC、Gherkin。

### 寫入方式

Jira 描述欄接受 Markdown（MCP `jira_update_issue` 的 `fields.description`）。**原描述為空** → 直接新增；**非空** → 先與使用者確認覆蓋 / 追加，不逕自覆蓋既有內容。含大量特殊字元時，以 `json.dumps` 產生安全 JSON 字串再寫入（避免手動跳脫出錯）。

---

## 輸出格式

完成後輸出：

```
✅ Spec 轉化完成：{TICKET}

規格文件：{$PROJECT_KB}/specs/{TICKET}.md
  補足區段：{清單}

ADR 產出：
  - {ADR 編號}：{標題}（若有）

Impls 文件：{建立 / 略過（待實作完成後建立）}

Jira 回寫：{已回寫描述（去識別化） / 使用者婉拒 / 無單號略過}
```
