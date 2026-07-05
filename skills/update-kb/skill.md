---
name: update-kb
description: >
  Knowledge Base 更新技能。支援兩種啟動模式：
  1. 排程自啟動：掃描各專案 KB 的 pending/ 目錄、每日 git 更新，自動判斷涉及的 KB 並派發子代理並行更新。
  2. 使用者自啟動：使用者輸入要更新的內容（ticket/檔案/描述），手動選擇目標專案 KB 後觸發更新流程。
  觸發關鍵字：update-kb、更新知識庫、kb更新、同步知識庫、寫到KB、review history
version: "1.12"
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

### 機械化偵測規則（regex 先掃 + 語意比對補漏，兩者都要跑，不是二選一）

> regex 負責掃出**候選**，命中不等於一定要刪，但每個命中都必須逐一檢視、比照上表決定是否替換；regex 掃不到的（如專案代稱、業務邏輯情境）仍須靠語意比對補漏，不可只跑 regex 就視為完成去識別化。

| 目標 | Regex / 樣式 | 說明 |
|------|-------------|------|
| Ticket / 單號 | `[A-Z]{2,10}-\d+` | 通用格式，涵蓋各專案代碼前綴，不綁定單一專案 |
| Email | `\S+@\S+\.\S+` | 含個人信箱、共用信箱別名 |
| IPv4 | `\b\d{1,3}(\.\d{1,3}){3}\b` | 含內外部 IP，命中一律視為候選 |
| 內部網域 | `*.internal`、`*.local`、公司網域樣式（如企業自訂網域字尾） | 依實際遇到的公司網域樣式擴充，不限於範例中的字尾 |

**掃描範圍（強制）**：不得只掃正文段落，**必須涵蓋巢狀內容**——貼入文本中的程式碼註解、log / stacktrace 片段、diff 內文，皆須以上表 regex 逐一掃描；這些內容常夾帶 ticket 單號、真實 hostname、email 卻因「看起來像程式碼」而被略過，須特別留意。

### 一致性要求

同一份文件中若同一識別項目出現多次，**全篇統一使用同一個佔位符**（例：`OrderService` 全文一律改為 `XxxService`，不得前後改成不同名稱），避免讀者誤以為是不同實體。

### 執行流程

1. **雙軌掃描**（兩者都要跑）：
   a. **Regex 先掃**：依上方機械化偵測規則表，對全文（含巢狀的程式碼註解、log/stacktrace、diff 內文）跑一輪 regex，列出所有候選命中位置
   b. **語意比對補漏**：regex 跑完後，再逐段比對「識別項目分類」表（專案 / 產品名稱、公司名稱、真實 service/class/package 名稱、業務專屬代碼等 regex 無法偵測的類型），標記所有命中的識別項目
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
   - `ADRs/index.md`（`demo_KBs/ADRs/` 目前僅含 `index.md` 與示範 ADR `0001-service-communication-protocol.md`，後者屬示範內容、依下方「不複製」規則排除，不隨 index.md 一併複製）
   - `review-history/index.md`、`review-history/YYYY-MM-DD-TICKET-service-name.md`（模板檔）
   - `pending/README.md`、`pending/jira.txt`、`pending/logs/.gitkeep`
   - `qa-records/qa-format.md`（若 `{$PROJECT_KB}/qa-records/` 目錄不存在，一併建立）

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
| qa、測試案例、測試結果、qa-records、{TICKET}-qa | **QA Records KB**（`{$PROJECT_KB}/qa-records/{TICKET}-qa.md`，格式規範見 `qa_format`） |
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

> 調度原則見 governance/model-dispatch.md。

依 Step 2 判定的 KB 類型，**只讀取**下表對應的 `templates/*.md` 構成子代理 prompt；不得一次讀取全部模板。每個模板檔已內含「派發規格」（`subagent_type` / `model`），依模板標注的值填入 Agent tool call，不自行留空（留空即繼承主線模型）。發出前將模板中所有 `{...}` 替換為實際值。

| KB 類型 | 模板檔路徑 | subagent_type | model |
|--------|-----------|---------------|-------|
| PM KB（specs / impls） | `templates/pm-spec.md` | general-purpose | sonnet |
| RD KB（source-codex） | `templates/rd-source-codex.md` | general-purpose | haiku |
| SRE KB（site-reliability） | `templates/sre.md` | general-purpose | haiku |
| 專案 ADR（`{$PROJECT_KB}/ADRs/`） | `templates/project-adr.md` | general-purpose | sonnet |
| 共用 ADR（`common_KBs/ADRs/`） | `templates/common-adr.md` | general-purpose | sonnet |
| 通用技術研究（`common_KBs/tech-research/`） | `templates/tech-research.md` | general-purpose | sonnet |
| Review History（`review-history/`） | `templates/review-history.md` | general-purpose | sonnet |
| QA Records（`qa-records/`） | `templates/qa-records.md` | general-purpose | sonnet |

> 各模板檔路徑皆相對於本 skill 目錄（`skills/update-kb/templates/`）。

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
