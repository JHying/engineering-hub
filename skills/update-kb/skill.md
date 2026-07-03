---
name: update-kb
description: >
  Knowledge Base 更新技能。支援兩種啟動模式：
  1. 排程自啟動：掃描各專案 KB 的 pending/ 目錄、每日 git 更新，自動判斷涉及的 KB 並派發子代理並行更新。
  2. 使用者自啟動：使用者輸入要更新的內容（ticket/檔案/描述），手動選擇目標專案 KB 後觸發更新流程。
  觸發關鍵字：update-kb、更新知識庫、kb更新、同步知識庫、寫到KB、review history
---

# Update Knowledge Base

## 權限規則（最高優先，所有步驟適用）

- **`$KB_ROOT` 路徑下**：具有完整 CRUD 權限，所有建立 / 修改 / 刪除操作**不需詢問使用者確認**
- **`$KB_ROOT` 路徑外**：僅允許讀取（含 git log、原始碼、設定檔），不執行任何寫入操作
- **共用知識路徑**（`$KB_ROOT/knowledge/common_KBs/guideline/`）：一般更新不修改；僅當使用者明確指示時才更新
- **專案 ADR 路徑**（`{$PROJECT_KB}/ADRs/`）：可含專案識別資訊，隨 PROJECT_KB 的 CRUD 權限一併適用，**不需額外確認**
- **共用 ADR 路徑**（`$KB_ROOT/knowledge/common_KBs/ADRs/`）：僅在「完全去識別化的跨專案通用決策」場景下更新，**需使用者確認**後才執行
- **通用技術研究路徑**（`$KB_ROOT/knowledge/common_KBs/tech-research/`）：技術探討、框架評估、研究筆記，**不需額外確認**

> **ADR 分層原則（來自 README.md）：**
> - `{project_KB}/ADRs/` — 專案內重要架構決策，可含專案識別資訊
> - `knowledge/common_KBs/ADRs/` — 各專案決策去識別化後提取的通用版本，供跨專案參考
> - 兩者互不排斥：同一個決策可先建專案 ADR，日後再去識別化提取至共用 ADR

---

## 內容限制規則（寫入前必查，適用所有 Step）

> **本規則優先於一切**：每次寫入任何路徑前，先執行下方檢查。

### 允許寫入的內容

**所有 git-tracked 路徑**（未被 `.gitignore` 排除）只允許以下兩類內容：

1. **標準技術術語**：框架名稱、設計模式、通用架構詞彙（Spring、Kafka、Redis、Controller、Repository、DTO 等）
2. **無語意佔位符**：任何行業的工程師看到都能理解其為「範例用途」的名稱（`XxxService`、`CategoryType`、`MY_TABLE`、`OWNER`、`ItemRecord` 等）

**判斷標準（一句話）**：把這個詞給一個不認識這個專案的工程師看，他能不能憑技術知識理解它的用途？能 → 可以寫；不能 → 不能寫。

### 例外：可含完整識別資訊的路徑

- 專案 KB（`{$PROJECT_KB}/`）— 本來就是專案私有知識

### 處理流程

1. **寫入前**：逐段確認內容符合「允許寫入」標準
2. **不符合時**：替換為佔位符或通用術語後再寫入；不因「只是範例」而略過
3. **不確定時**：在摘要中標注 ⚠️，讓使用者確認，**不自行決定略過**
4. **輸出摘要**：標注已替換的項目，保持可追蹤

---

## 去識別化檢查清單（強制去識別化路徑適用）

> 適用範圍：`knowledge/common_KBs/ADRs/`、`knowledge/common_KBs/tech-research/`（即 Mode B 選項 5、7 與對應子代理）。
> 與上方「內容限制規則」的差異：內容限制規則適用**所有**路徑（專案 KB 例外，允許完整識別資訊）；本清單專用於**強制去識別化**路徑，標準更嚴格，專案 KB 不適用。

### 識別項目分類

| 類別 | 範例 | 處理方式 |
|------|------|---------|
| 專案 / 產品名稱 | 「某某商城」、「OO 平台」 | 移除，改用「該專案」、「某電商系統」等領域描述 |
| 公司 / 客戶名稱 | 公司全名、客戶簡稱 | 直接移除，不替換 |
| Ticket / 單號 | `PROJ-1234`、`JIRA-567` | 移除；若需保留格式範例，改用 `TICKET-001` |
| 真實 service / class / package 名稱 | `OrderService`、`com.acme.payment` | 改用語意佔位符（`XxxService`、`com.example.domain`） |
| 人名 / email / 帳號 / Slack handle | 真實姓名、`user@company.com` | 直接移除 |
| 內部網域 / IP / hostname / API Key / Token | `internal.company.io`、`10.0.x.x` | 直接移除 |
| 業務專屬代碼（具識別性） | 特定客戶的商品代碼、內部代號 | 改用通用型別名稱（`ItemCode`、`CategoryType`） |

### 一致性要求

同一份文件中若同一識別項目出現多次，**全篇統一使用同一個佔位符**（例：`OrderService` 全文一律改為 `XxxService`，不得前後改成不同名稱），避免讀者誤以為是不同實體。

### 執行流程

1. 寫入前逐段比對上表，標記所有命中的識別項目
2. 建立「識別項目 → 佔位符」對照表（本次任務內部維護，確保全文一致），逐一替換為對應佔位符
3. 完成替換後才寫入目標路徑
4. 替換後仍不確定是否完全去識別化（例：業務邏輯高度依賴特定產業情境，難以抽象化）→ 在摘要中標注 ⚠️，**停止寫入**，等候使用者確認

### 對照表的呈現限制

- 對照表**只能出現在 Step 6 對話最終摘要**中，供使用者核對本次替換是否正確
- **禁止**將對照表寫入任何檔案：不得出現在共用 KB 文件本身、`pending/logs/` 更新記錄、MASTER_INDEX 或其他任何 `$KB_ROOT` 下的檔案
- 原因：對照表含原始識別內容，寫入檔案等同讓業務內容混入通用知識庫；僅留存於當次對話輸出則不會被 KB 收錄

---

## Step 0 — 初始化

讀取 memory 的 `reference_knowledge_base.md` 取得 `$KB_ROOT`（knowledge-hub 根目錄）。

讀取 `$KB_ROOT/setting/paths.yml` 解析所有路徑常數（`@kb/` → `$KB_ROOT/`）。

---

## Step 0.5 — 選擇目標專案 KB

### 排程模式（Mode A）

掃描 `$KB_ROOT/knowledge/` 下所有名稱以 `_KBs` 結尾的子資料夾，**排除 `common_KBs`**（通用 KB 獨立處理），其餘**全部納入**更新範圍（以下稱 `$TARGET_KBs`）。

### 使用者模式（Mode B）

掃描 `$KB_ROOT/knowledge/` 下所有 `_KBs` 結尾子資料夾（**排除 `common_KBs`**），顯示選單：

```
請選擇要更新的專案知識庫（輸入編號，多個以逗號分隔，輸入 all 全選）：
  1. {project_name}_KBs
  2. demo_KBs
  ...
```

等待使用者選擇，記住選定清單（以下稱 `$TARGET_KBs`）。

每個 `$PROJECT_KB` 的根路徑格式為 `$KB_ROOT/knowledge/{project_name}/`。

---

## Step 0.7 — 新 KB Scaffolding（自動偵測）

對每個選定的 `$PROJECT_KB`，檢查 `{$PROJECT_KB}/MASTER_INDEX.md` 是否存在：

- **存在** → 正常進入 Step 1，不做任何 scaffolding。
- **不存在** → 視為新 KB，自動執行以下 scaffolding 後再進入 Step 1：

### Scaffolding 執行規則

1. 讀取 `$KB_ROOT/knowledge/demo_KBs/` 的完整目錄結構

2. 在 `{$PROJECT_KB}/` 下依以下分類規則處理每個檔案：

   **直接複製（格式規範 / 空白模板）：**
   - `specs/spec-format.md`、`specs/README.md`
   - `specs/impls/impls-format.md`、`specs/impls/README.md`
   - `site-reliability/index.md` 及 `site-reliability/` 下所有 `.md`
   - `source-codex/cross/index.md`、`source-codex/cross/service-map.md`
   - `ADRs/index.md`（若存在 `0000-record-architecture-decisions.md` 也一併複製）
   - `review-history/index.md`、`review-history/YYYY-MM-DD-TICKET-service-name.md`（模板檔）
   - `pending/README.md`、`pending/jira.txt`、`pending/logs/.gitkeep`

   **複製後清空示範資料（保留結構，替換內容）：**
   - `MASTER_INDEX.md`：複製結構，將服務清單、AI 路由規則、系統定位等示範文字改為 `[待補充]`；保留各章節標題與說明段落

   **不複製（demo 專屬內容）：**
   - `specs/DEMO-*.md`、`specs/impls/DEMO-*.md`（示範 ticket）
   - `source-codex/services/` 下所有子目錄（示範服務：order-service / payment-service / notification-service 等）
   - `ADRs/` 下編號 `0001` 以上的 `.md`（示範 ADR，非格式說明文件）

3. 完成後告知使用者：「已從 demo_KBs 初始化 KB 結構（格式規範已複製，示範內容已排除），繼續更新流程。」

> **重要**：scaffolding 後立即繼續 Step 1，不等待使用者操作。

---

## Step 1 — 判斷啟動模式

### 模式 A：排程自啟動

> 由 `/schedule` 或 `/loop` 觸發時進入此模式，不等待使用者輸入。

對每個 `$PROJECT_KB` in `$TARGET_KBs`，掃描以下來源，收集待更新內容清單：

| 來源 | 路徑 | 處理方式 |
|------|------|---------|
| Jira ticket 清單 | `{$PROJECT_KB}/pending/jira.txt` | 逐行讀取 ticket ID，嘗試用 Jira MCP 拉取內容 |
| 每日 git 更新 | 各 service repo（路徑見 `{$PROJECT_KB}/source-codex/cross/service-map.md`）| `git log --since="24 hours ago" --oneline` 取得變更 commit，依 service 分組 |

若所有 `$TARGET_KBs` 均無新內容 → 記錄 log「無待更新項目」後結束。

若多個 `$PROJECT_KB` 均有待更新內容，在同一個 response 中**並行**對各 PROJECT_KB 派發 Step 3 的子代理組。

### 模式 B：使用者自啟動

詢問：

```
請輸入要更新的內容（擇一）：
  1. Jira 單號（如 PROJECT-123）
  2. 直接貼上內容或檔案路徑
  3. 描述要更新的功能或異動
  4. 架構決策（更新專案 ADRs，可含專案識別資訊）
  5. 去識別化的架構決策（更新共用 ADRs → `common_KBs/ADRs/`，將依「去識別化檢查清單」自動掃描與替換）
  6. Code Review 記錄（新增 review-history/ 條目，可含 ticket 單號或直接描述）
  7. 技術探討 / 研究筆記（更新 `common_KBs/tech-research/`，將依「去識別化檢查清單」自動掃描與替換）
  8. KB_ROOT 結構性異動（`skills/`、`role-flows/`、`roles/`、`setting/` 等不綁定特定專案的異動，例如 skill 規則調整、審查/稽核結果）

輸入內容：
```

等待使用者輸入後進入 Step 2。

---

## Step 2 — 判斷涉及的知識庫類型

依內容關鍵字判斷需要更新哪些 KB 類型（可多選）：

| 關鍵字 / 特徵 | 涉及 KB |
|--------------|--------|
| Story、AC、spec、需求、驗收條件、功能目標、impl、實作概述 | **PM KB**（`{$PROJECT_KB}/specs/`） |
| service、class、API、Kafka topic、Redis key、DB、git diff、程式碼變更 | **RD KB**（`{$PROJECT_KB}/source-codex/`） |
| 部署、CI/CD、ArgoCD、環境、監控、OTEL、SOP、migration、rollback | **SRE KB**（`{$PROJECT_KB}/site-reliability/`） |
| 架構決策、ADR、技術選型、設計決定（含專案識別資訊） | **專案 ADR**（`{$PROJECT_KB}/ADRs/`） |
| 去識別化架構決策、跨專案通用決策（無任何專案識別資訊） | **共用 ADR KB**（`$KB_ROOT/knowledge/common_KBs/ADRs/`） |
| 技術探討、框架評估、研究筆記、選型比較（去識別化） | **通用技術研究 KB**（`$KB_ROOT/knowledge/common_KBs/tech-research/`） |
| code review、Review、品質問題、效能問題、原子性、[V]、[不處理]、審查範圍、審查結果、review history | **Review History KB**（`{$PROJECT_KB}/review-history/`） |
| skill 規則調整（`skills/*/SKILL.md`）、角色定義（`roles/`）、角色流程（`role-flows/`）、`setting/paths.yml`、README.md、CLAUDE.md 等不綁定特定專案的異動；或針對這些路徑的稽核 / 檢查結果（如去識別化稽核、規則一致性檢查） | **KB_ROOT Meta**（不屬於任何 `$PROJECT_KB`，見下方說明） |

> **KB_ROOT Meta 的處理方式**：這類異動範圍通常明確且單一（例如一次只改一個 skill 的一條規則），**不派發 Step 3 子代理**，由主流程直接讀取、修改、確認即可；`skills/*/SKILL.md` 的內容規則異動仍需依 CLAUDE.md 同步更新該 skill 自己的 CHANGELOG.md。**異動追蹤完全依賴該 CHANGELOG.md + git commit history，update-kb 不另外寫 log**（純稽核、無實際寫入的任務也不需要記錄）。
>
> **一次更新可能同時涉及多個 KB 類型。**
>
> **ADR 判斷規則（先做再去識別化）：**
> 1. 凡涉及架構決策，**優先更新專案 ADR**（`{$PROJECT_KB}/ADRs/`）
> 2. 在寫入前，先掃描 `{$PROJECT_KB}/ADRs/` 確認是否已有相關 ADR：
>    - **已有** → 修訂現有 ADR（更新 date、加 `supersedes`、標注決策翻轉原因），不建立新檔
>    - **沒有** → 建立新編號 ADR（讀取最大現有編號 + 1）
> 3. 若同時需要共用 ADR，在完成專案 ADR 後，確認已完全去識別化才寫入 `knowledge/common_KBs/ADRs/`

---

## Step 3 — 並行派發子代理

**在同一個 response 中**同時發出所有涉及 KB 類型的 `Agent` tool call。

以下是各子代理的 prompt 模板，發出前將所有 `{...}` 替換為實際值：

---

### PM KB 子代理 prompt

```
你是 Knowledge Base 的 PM KB 更新代理，負責更新指定專案 KB 的 specs / impls 文件。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 目標專案 KB 路徑
{$PROJECT_KB}（即 $KB_ROOT/knowledge/{project_name}/）

## 必讀文件（依序讀取）
1. 專案 MASTER_INDEX：{$PROJECT_KB}/MASTER_INDEX.md
2. Spec 格式規範：{$PROJECT_KB}/specs/spec-format.md
3. Impl 格式規範：{$PROJECT_KB}/specs/impls/impls-format.md
4. PM KB 入口：{$PROJECT_KB}/specs/README.md

## 更新來源
{待更新內容或 Jira ticket 號}

## 執行規則

### Step A — 建立或更新 Spec
1. 若有 Jira 單號，用 Jira MCP 拉取完整內容（summary / description / AC / api provider by / is implemented by / status）
2. 依 spec-format.md 格式建立或更新 `{$PROJECT_KB}/specs/{TICKET}.md`
3. 若 spec 已存在，比對現有內容，僅補充缺少的區段，不覆蓋已確認內容
4. 更新 MASTER_INDEX PM KB 的「已建立 Spec」清單

### Step B — 自動判斷是否建立 Impl

**滿足以下所有條件時，自動接續執行 Step C（不需詢問）：**
- Story 狀態為 `READY TO QA`、`完成` 或 `DONE`
- 且 `is implemented by` 欄位中至少一個 ticket 狀態為「完成」
- 且 `{$PROJECT_KB}/specs/impls/{TICKET}-impls.md` 尚不存在

**不滿足條件時**（Story 仍進行中、is implemented by 全部未完成）：跳過 Step C，僅建立 spec。

### Step C — 建立 Impl
1. 讀取已建立的 spec：`{$PROJECT_KB}/specs/{TICKET}.md`
2. 從 Jira 的 "is implemented by" 欄位取得所有已完成的實作 ticket，判斷涉及哪些 service / FE
3. 讀取對應 service 的 `{$PROJECT_KB}/source-codex/services/{service}/facts.md`，提取與本 Story 相關的 class / 流程
4. 依 impls-format.md 格式建立 `{$PROJECT_KB}/specs/impls/{TICKET}-impls.md`：
   - 第一章：逐條 AC 對應實作機制（BE 標 class.method；FE 標「FE {機制描述}」；尚未完成的標 [待補充]）
   - 第二章：code-like-facts 系統流程（每個涉及的 service 獨立區塊）
   - 第三章：驗測方式
   - 第四章：SA 系統需求規格（無異動時明確寫「無新增」）
5. 更新 MASTER_INDEX PM KB 的「已建立 Impl」清單

## 輸出格式
- ✅ 已建立 / 更新的檔案清單
- ⚠️ 需人工補充的區段（標注 [待補充] 的位置）
- 📋 MASTER_INDEX 異動摘要
```

---

### RD KB 子代理 prompt

```
你是 Knowledge Base 的 RD KB 更新代理，負責更新指定專案 KB 的 source-codex 文件。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。
$KB_ROOT 路徑外只允許讀取（git log、原始碼）。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 目標專案 KB 路徑
{$PROJECT_KB}

## 必讀文件（依序讀取）
1. 專案 MASTER_INDEX：{$PROJECT_KB}/MASTER_INDEX.md（服務清單、AI 文件路由規則）
2. 涉及 service 的 index.md + facts.md（依 MASTER_INDEX 路由判斷）

## 更新來源
{待更新內容、git diff 或描述}

## 執行規則

### services 文件更新：
1. 依內容判斷涉及哪個 / 哪些 service
2. 讀取對應 `{$PROJECT_KB}/source-codex/services/{service}/index.md` 與 `facts.md`
3. 比對現有內容，補充或修正：
   - 新增 class / 方法 → 補至 facts.md 的業務邏輯事實
   - 新增 DTO / Entity → 補至 index.md 的資料結構區段
   - 新增 API / Kafka / gRPC 介面 → 補至 index.md 的介面合約區段
   - 異動流程 → 補至對應 flow-diagram.md（Mermaid）
4. 更新 index.md 的「同步狀態」（同步日期、最新 commit）

### 跨服務資源索引更新（cross/）：
依內容提取跨服務共享的資源，更新或建立對應文件：

| 資源類型 | 更新文件 |
|---------|---------|
| 新增 / 修改 Kafka topic | `{$PROJECT_KB}/source-codex/cross/kafka-topology.md` |
| 新增 / 修改 Redis key | `{$PROJECT_KB}/source-codex/cross/redis-keymap.md` |
| 新增 / 修改 MongoDB collection | `{$PROJECT_KB}/source-codex/cross/mongo-colmap.md` |
| service-map sync 狀態 | `{$PROJECT_KB}/source-codex/cross/service-map.md` |

### MASTER_INDEX 更新：
- 若有新 service → 補充 Services 文件索引
- 若有新 AI 文件路由關鍵字 → 補充 AI 文件路由規則

## 輸出格式
- ✅ 已更新的檔案清單（含章節）
- 🔗 cross/ 新增或修改的資源項目
- 📋 MASTER_INDEX 異動摘要
```

---

### SRE KB 子代理 prompt

```
你是 Knowledge Base 的 SRE KB 更新代理，負責更新指定專案 KB 的 site-reliability 文件。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 目標專案 KB 路徑
{$PROJECT_KB}

## 必讀文件（依序讀取）
1. SRE KB 路由索引：{$PROJECT_KB}/site-reliability/index.md
2. 依路由規則決定讀取哪些具體文件

## 更新來源
{待更新內容或描述}

## 執行規則

1. 讀取 `{$PROJECT_KB}/site-reliability/index.md` 的路由規則，判斷內容屬於哪個文件
2. 讀取對應文件的現有內容
3. 依內容類型補充（路由表以 index.md 定義為準，以下為常見對應）：

| 內容類型 | 更新目標（相對於 site-reliability/） |
|---------|-----------------------------------|
| 環境 / 部署架構異動 | `environments.md` |
| CI/CD Pipeline 變更 | `cicd-pipeline.md` |
| 部署策略調整 | `deployment-strategy.md` |
| DB migration SOP 異動 | `sop-db-migration.md` |
| Kafka topic 維運異動 | `sop-kafka.md` |
| 告警指標定義 | `alert-metrics.md` |
| 維運邊界調整 | `operations-boundary.md` |
| 其他 SOP | 對應 sop-*.md（若不存在則建立）|

4. 若更新的內容涉及 index.md 的路由規則，同步更新路由表與文件狀態表

## 輸出格式
- ✅ 已更新的檔案清單（含異動段落）
- 📋 index.md 路由規則是否有異動
```

---

### 專案 ADR 子代理 prompt（架構決策，含專案識別資訊）

```
你是 Knowledge Base 的專案 ADR 更新代理，負責更新指定專案 KB 的 ADRs/ 目錄。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。
專案 ADR 可含專案名稱、服務名稱、class 路徑等識別資訊。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 目標專案 ADR 路徑
{$PROJECT_KB}/ADRs/

## 必讀文件（依序讀取）
1. 若 `{$PROJECT_KB}/ADRs/index.md` 存在，先讀取快速查詢表（檔名與標題摘要）；**不存在**才列出整個 ADRs/ 目錄下所有 .md 檔名

## 更新來源
{架構決策內容}

## 執行規則

### Step A — 先查現有 ADR
依 index.md（或目錄列表）的 ADR 標題，判斷是否已有覆蓋相同主題的 ADR：
- **已有相關 ADR** → 進入 Step B（修訂）
- **無相關 ADR** → 進入 Step C（新建）

### Step B — 修訂現有 ADR
1. 讀取現有 ADR 全文
2. 在 frontmatter 更新 `date`，新增 `supersedes: "{舊日期} {版本說明}"`
3. 在 **決策矩陣** 和 **相關 Case** 中標注異動（舊決策用 `~~刪除線~~` 或 `> ~~舊：...~~`，新決策並排說明）
4. 新增 `### Case N: {主題} — REVISED {YYYY-MM-DD}` 區段，說明：
   - 決策翻轉的原因（哪個假設被推翻、觸發情境）
   - 新的實作方式與 source reference
   - 前後決策比對表（Was / Now）
5. 更新 `More Information` 的 source references

### Step C — 新建 ADR
1. 計算新 ADR 編號（從 Step A 取得的 index.md 條目或目錄列表中找最大編號 + 1，格式 `{nnnn}`）
2. 依以下格式建立 `{$PROJECT_KB}/ADRs/{nnnn}-{kebab-slug}.md`：

```
---
status: "accepted"
date: "{YYYY-MM-DD}"
decision-makers: "{角色或團隊}"
consulted: "{諮詢對象，如 DBA}"
---

# {標題（簡潔描述決策內容）}

## Context and Problem Statement
{描述觸發此決策的背景與問題，可含專案識別資訊}

## Decision Drivers
- {驅動因素 1}
- {驅動因素 2}

## Considered Options
{列出評估過的方案}

## Decision Outcome
{選定方案與理由}

### Decision matrix（若適用）
| 場景 | 機制 | 原因 |
|------|------|------|

### Case N: {具體情境說明}
{詳細說明 + 程式碼範例（若有）}

### Consequences
- Good, because ...
- Bad, because ...

### Confirmation
{確認此決策落地的 code review rule 或 CI 規則}

## Pros and Cons of the Options
{各方案比較}

## More Information
Source references:
- {class 路徑}：{說明}
Related:
- [ADR-{nnnn}]({slug}.md)
```

3. 若 `{$PROJECT_KB}/ADRs/index.md` 存在，在快速查詢表中加入新 ADR

## 輸出格式
- ✅ 修訂 / 建立的 ADR 檔案路徑
- 📋 index.md 是否有異動
- ⚠️ 若修訂現有 ADR，列出「被翻轉的舊決策 vs 新決策」摘要供使用者確認
```

---

### 共用 ADR KB 子代理 prompt（共用，僅在決策去識別化場景派發）

```
你是 Knowledge Base 的共用 ADR KB 更新代理，負責更新跨專案共用的 ADR 知識庫。
所有 ADR 內容必須已去識別化（無專案名稱、公司名稱、人名、商業敏感資訊）。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。

## Knowledge Hub 根路徑
{$KB_ROOT}

## ADR 路徑
{$KB_ROOT}/knowledge/common_KBs/ADRs/

## 必讀文件
1. common_KBs 主索引：{$KB_ROOT}/knowledge/common_KBs/MASTER_INDEX.md
   → 讀完後依內容判斷應歸入哪個 ADR 分類，**再只列出該分類目錄**確認現有最大編號

## 更新來源
{去識別化的架構決策內容}

## 執行規則

1. 依 MASTER_INDEX.md 中的分類說明，判斷 ADR 屬於哪個分類（01~08）
2. 列出**該分類目錄**下的 .md 檔，確認現有最大編號，計算新 ADR 編號
3. 依「去識別化檢查清單」逐段掃描內容，建立「識別項目 → 佔位符」對照表並完成替換；替換後仍不確定是否完全去識別化 → 輸出標注 ⚠️ 後停止，等候使用者確認
4. 依 MADR 格式建立 `{$KB_ROOT}/knowledge/common_KBs/ADRs/{分類目錄}/{nnnn}-{slug}.md`
5. 更新 `{$KB_ROOT}/knowledge/common_KBs/MASTER_INDEX.md` 的 ADR 分類表（若新增了新分類條目）

## 輸出格式（僅回傳給主流程對話顯示，**不得寫入任何檔案**）
- ✅ 建立的 ADR 檔案路徑（含分類目錄）
- 🔒 去識別化對照表（識別項目 → 佔位符；僅供本次對話核對，不寫入 log 或任何 KB 文件）
- 📋 MASTER_INDEX 是否有異動
- ⚠️ 若發現未去識別化的內容，列出需修改的段落
```

---

### 通用技術研究 KB 子代理 prompt（tech-research，技術探討 / 研究筆記）

```
你是 Knowledge Base 的通用技術研究 KB 更新代理，負責在 common_KBs/tech-research/ 建立或更新技術探討筆記。
所有內容必須去識別化（無專案名稱、公司名稱、系統代號）。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 目標路徑
{$KB_ROOT}/knowledge/common_KBs/tech-research/

## 必讀文件
1. tech-research 索引：{$KB_ROOT}/knowledge/common_KBs/tech-research/index.md

## 更新來源
{技術探討結論或研究筆記內容}

## 執行規則

1. 依主題決定檔案名稱：`{kebab-topic}.md`（例：`virtual-threads-vs-reactive.md`）
2. 若同主題筆記已存在 → 追加新段落（標注日期），不覆蓋舊內容
3. 依「去識別化檢查清單」逐段掃描內容，建立「識別項目 → 佔位符」對照表並完成替換；替換後仍不確定是否完全去識別化 → 輸出標注 ⚠️ 後停止，等候使用者確認
4. 依以下格式建立或更新筆記：

---
date: {YYYY-MM-DD}
keywords: {框架名稱、技術名稱}
---

# {技術主題}

## 問題背景
{要解決的問題或評估的情境，已去識別化}

## 研究結論
{發現、比較結果、推薦方向}

## 參考
{相關 ADR 或外部文件連結}

5. 更新 `{$KB_ROOT}/knowledge/common_KBs/tech-research/index.md` 的筆記清單

## 輸出格式（僅回傳給主流程對話顯示，**不得寫入任何檔案**）
- ✅ 建立 / 更新的筆記路徑
- 🔒 去識別化對照表（識別項目 → 佔位符；僅供本次對話核對，不寫入 log 或任何 KB 文件）
- 📋 index.md 異動摘要
- ⚠️ 若發現未去識別化的內容，列出需修改的段落
```

---

### Review History KB 子代理 prompt

```
你是 Knowledge Base 的 Review History KB 更新代理，負責在指定專案 KB 的 review-history/ 目錄建立或更新 Code Review 記錄。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。
$KB_ROOT 路徑外只允許讀取（原始碼、git log）。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 目標路徑
{$PROJECT_KB}/review-history/

## 更新來源
{Code Review 內容：可為對話摘要、review 輸出文字、或 ticket 單號}

## 執行規則

### Step A — 確認檔案名稱
依以下規則命名：`{YYYY-MM-DD}-{ticket-or-topic}-{service}.md`
- 若有 ticket 單號（如 PROJECT-123）→ `2026-06-24-PROJECT-123-order-service.md`
- 若無 ticket → `{YYYY-MM-DD}-{kebab-topic}-{service}.md`（例：`2026-06-24-ws-session-refactor-order-service.md`）
- 若檔案已存在 → 追加新的審查段落（日期區分），不覆蓋舊記錄

### Step B — 建立或更新 Review 記錄
依以下格式寫入（frontmatter + 各章節）：

---
date: {YYYY-MM-DD}
branch: {分支名稱，若已知}
ticket: {ticket 單號，若有}
reviewer: {reviewer 名稱，若已知}
service: {涉及的服務名稱}
scope: {審查範圍一行描述}
mode: {ticket 模式 / 範圍模式}
---

# Code Review — {標題}

## 審查範圍
{涉及的 class 清單，含 package 路徑}

## 品質問題（Quality Issues）
依 class 分組，每項格式：
- **[已修 / 不處理 / 後續追蹤]** {違規類型}：{說明} → 修正：{修正方式}

## 效能瓶頸 / 資料原子性（Performance & Atomicity Issues）
同上格式

## 設計模式（Design Pattern Review）
- [建議引入 / 已使用 / 過度設計] {模式名稱} @ {位置}：{說明}

## 本次修改檔案
| 檔案 | 類型 | 異動摘要 |

## 相關 ADR
- [ADR-{nnnn}]({相對路徑})：{說明}（若有）

## 未解決 / 後續追蹤
| 項目 | 建議行動 |

### Step C — 更新 review-history/index.md
若 `{$PROJECT_KB}/review-history/index.md` 存在，在快速查詢表加入新條目；
若不存在，建立 index.md：

# Review History 索引

| 日期 | Ticket / 主題 | 服務 | 檔案 |
|------|-------------|------|------|
| {YYYY-MM-DD} | {ticket 或主題} | {service} | [{檔名}]({檔名}) |

## 輸出格式
- ✅ 建立 / 更新的 review 記錄路徑
- 📋 index.md 異動摘要
- ⚠️ [待補充] 位置清單（若有資訊不足的欄位）
```

---

## Step 4 — 彙整子代理結果，同步 Meta 檔案

等所有子代理完成後：

### 4-1 同步各 PROJECT_KB 的 MASTER_INDEX.md

對每個更新過的 `$PROJECT_KB`，確認 MASTER_INDEX 是否完整反映：
- PM KB：已建立 Spec / Impl 清單
- RD KB：AI 文件路由規則是否有新關鍵字
- SRE KB：site-reliability 文件清單是否有新增
- Review History KB：`review-history/` 目錄是否已列入 MASTER_INDEX（首次建立時需補充）

### 4-2 同步 setting/paths.yml

確認子代理建立的新文件，是否需要在 `$KB_ROOT/setting/paths.yml` 新增對應 key（通常只有新的共用規範文件才需要）。

### 4-3 同步 role-flows/

若更新涉及 KB 結構或路由規則異動，檢查對應 flow 文件是否需要更新：

| 異動類型 | 檢查 flow |
|---------|----------|
| PM KB 路由規則異動 | `$KB_ROOT/role-flows/flow-pm.md` |
| RD KB 服務文件路由異動 | `$KB_ROOT/role-flows/flow-backend.md`、`flow-qa.md`、`flow-reviewer.md` |
| SRE KB 路由異動 | `$KB_ROOT/role-flows/flow-sre.md` |

### 4-4 確認 README.md 是否需要更新

讀取 `$KB_ROOT/README.md`，檢查以下項目是否與現況一致：

| 檢查項目 | 比對來源 |
|---------|---------|
| 目錄結構圖（`knowledge/` 下的子資料夾） | 實際掃描 `$KB_ROOT/knowledge/` 目錄 |
| 共用知識路徑（`common_KBs/` 的子目錄） | 實際掃描 `$KB_ROOT/knowledge/common_KBs/` 目錄 |
| 專案 KB 內部結構（各 KB 類型的目錄與說明） | 本次更新涉及的 KB 類型 |
| 更新知識庫章節（支援的更新類型清單） | 本次更新涉及的 KB 類型 |

若發現不一致，直接更新 README.md（中英文兩個區段同步修改）。若無須異動，跳過。

---

## Step 5 — 清理 Pending + 記錄 Log

對每個 `$PROJECT_KB`：

### 5-1 清理 pending

| 來源 | 清理方式 |
|------|---------|
| `{$PROJECT_KB}/pending/jira.txt` | 移除已成功處理的 ticket ID 行，保留失敗或跳過的 |
| `{$PROJECT_KB}/pending/` 下的其他 `.md` 檔案 | 刪除已整合到 KB 的檔案 |

### 5-2 寫入更新 Log

> **禁止**將任何子代理輸出的「去識別化對照表」寫入此 log（或任何其他檔案）。Log 中的共用 ADR / 通用技術研究段落僅記錄檔案清單與「已確認去識別化」狀態，不含對照表內容。

建立或追加 `{$PROJECT_KB}/pending/logs/update-{YYYY-MM-DD}.md`：

```markdown
## {YYYY-MM-DD HH:MM} KB 更新記錄

### 觸發模式
{排程自啟動 / 使用者自啟動}

### 目標專案 KB
{$PROJECT_KB}

### 更新來源
{ticket ID 清單 / pending 檔案名稱 / 使用者描述}

### 更新結果

#### PM KB
- 建立：{檔案清單}
- 更新：{檔案清單}
- 待補充：{[待補充] 項目清單}

#### RD KB
- 建立：{檔案清單}
- 更新：{檔案清單}
- cross/ 異動：{項目清單}

#### SRE KB
- 建立：{檔案清單}
- 更新：{檔案清單}

#### 專案 ADR（{$PROJECT_KB}/ADRs/，若有更新）
- 建立：{ADR 檔案清單}
- 修訂：{ADR 檔案清單 + 翻轉決策摘要}

#### 共用 ADR（knowledge/common_KBs/ADRs/，若有更新）
- 建立：{ADR 檔案清單（已確認去識別化）}

#### 通用技術研究（knowledge/common_KBs/tech-research/，若有更新）
- 建立 / 更新：{tech-research 筆記清單（已確認去識別化）}

#### Review History KB（{$PROJECT_KB}/review-history/，若有更新）
- 建立：{review 記錄檔案清單}
- 更新：{追加審查段落的檔案清單}
- index.md：{有異動 / 無異動}

#### Meta 檔案
- MASTER_INDEX：{有異動 / 無異動}
- paths.yml：{有異動 / 無異動}
- flow 檔案：{有異動 / 無異動}
- README.md：{有異動 / 無異動}

### 清理 pending
- 已移除：{清單}
- 保留（失敗 / 跳過）：{清單}
```

---

## Step 6 — 輸出摘要

向使用者輸出本次更新的最終摘要（格式同 Log），並標注所有需人工確認的 `[待補充]` 位置。

若本次更新涉及 KB_ROOT Meta，在摘要中註明異動的 skill/檔案與其 CHANGELOG.md 版本號即可，不需另外的 log 路徑。

若本次更新涉及共用 ADR 或通用技術研究，在摘要末尾附上各子代理回傳的「🔒 去識別化對照表」供使用者核對——**僅呈現於此對話輸出，不寫入 Log 或任何檔案**。

若有 ADR 去識別化疑慮，在摘要末尾列出需要人工確認的段落。

若為排程模式，詢問：「是否需要針對某個更新項目深入補充？」
