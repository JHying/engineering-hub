---
name: diagram
description: 統一 Mermaid 圖表工具：依描述範圍生成圖表（套用通用顏色規範 + 專案 participant alias）、依 git diff 同步更新。
version: "1.2"
---

# diagram

| 呼叫方式 | 行為 |
|----------|------|
| `/diagram <範圍描述>` | 依描述找到相關程式碼，生成圖表並寫入 metadata |
| `/diagram` | 無範圍時互動詢問後再執行 |
| `/diagram sync` | 依 git diff 更新所有帶 metadata 的圖 |

範圍描述範例：
- `/diagram OrderController 的完整流程`
- `/diagram OrderController + OrderAppService 的建立訂單流程`
- `/diagram 排程報表流程，從 ReportScheduler 開始`

### 輸出路徑參數（選填）

呼叫方（例如 `/my-work-agent`）可額外指定完整輸出路徑，覆蓋預設輸出位置：
- `/diagram <範圍描述> --output <完整檔案路徑>`
- 未指定時，維持預設輸出路徑規則（見「檔案輸出規範」）

---

## 專案 Participant 設定檔

路徑：與本次圖表**實際輸出目錄**同一目錄下的 `diagram-participants.md`。

- 未使用 `--output` 覆蓋時，預設輸出目錄為 `docs/`，故路徑為 `docs/diagram-participants.md`
- 使用 `--output <完整檔案路徑>` 時（例如呼叫方將圖表輸出到 KB 內的 `{$PROJECT_KB}/source-codex/services/{service}/`），`diagram-participants.md` 跟隨放在**同一目錄**，不固定寫死 `docs/`——參與者設定檔理應與它描述的圖表放在一起，才會在同一次 `/diagram sync` 或後續生成時被正確探索與維護
- 一個專案若在不同目錄下累積多份圖表（例如同時有 `docs/` 下的圖與 KB 內的圖），對應也會有多份 `diagram-participants.md`，各自維護該目錄下圖表用到的 alias，不強制合併

```markdown
<!-- diagram-participants -->
actor User
participant GW as api-gateway
participant SVC as order-service
participant CACHE as redis
participant DB as postgres
participant MQ as kafka
participant EXT as external-api
```

- 生成 / sync 時自動讀取（對應目錄下的那一份），**每次執行**都比對追蹤到的元件，補入尚未收錄的 alias
- 不存在時依追蹤到的元件名稱自動建立初稿並寫入該目錄
- 各專案自行維護此檔，skill 本身不內建任何 alias

---

## 流程圖 Metadata 格式

每個圖檔最頂部宣告（Mermaid block 之前）：

```markdown
<!-- synced: {commit-hash} -->
<!-- type: sequenceDiagram -->
<!-- covers:
  path/to/SourceFile1.java
  path/to/SourceFile2.java
-->
```

`type` 固定為 `sequenceDiagram` 或 `flowchart`，由生成時寫入，供 sync 判斷更新規則。

---

## 通用顏色規範（所有專案一致）

### sequenceDiagram init 區塊

```
%%{init: {'theme': 'base', 'themeVariables': {'loopLineColor': '#9673A6', 'signalColor': '#ffffff', 'signalTextColor': '#ffffff', 'labelTextColor': '#000000', 'loopTextColor': '#ffffff'}}}%%
```

| 變數 | 顏色 | 作用 |
|------|------|------|
| `loopLineColor` | `#9673A6`（紫色） | `loop` / `alt` 外框線與 `else` 分隔線 |
| `signalColor` | `#ffffff`（白色） | 箭頭線條本身（`->>` / `-->>`） |
| `signalTextColor` | `#ffffff`（白色） | 箭頭線上的訊息文字 |
| `labelTextColor` | `#000000`（黑色） | `alt` / `loop` / `else` 關鍵字標籤 |
| `loopTextColor` | `#ffffff`（白色） | `alt` / `loop` 標頭列的條件描述文字 |

> 注意：`alt` 外框為虛線，是 Mermaid 硬編碼規格，無法透過 themeVariables 改為實線。

---

## 圖表類型選擇

使用者指定時以指定為準；自動判斷時依下表：

| 情境 | 類型 |
|------|------|
| 跨元件 / 服務的訊息傳遞、資料流（Controller → Infra） | `sequenceDiagram` |
| 排程觸發的完整流程（含外部系統互動） | `sequenceDiagram` |
| 特定方法內的條件分支、狀態機、演算法邏輯（不限層級，可為 DomainService / Manager / 任意方法） | `flowchart TD` |

---

## 模式一：生成圖表（`/diagram <範圍描述>`）

### Step 0：確認範圍（無參數時）

若使用者未輸入範圍描述，用 `AskUserQuestion` 依序詢問：

1. **要畫哪個入口或流程？**（Controller 名稱、Scheduler、特定方法名稱、或流程描述）
2. **圖表類型？**（自動判斷 / 指定 `sequenceDiagram` / 指定 `flowchart TD`；預設自動判斷）
3. **此次要指定特定的 AppService 嗎？**（用於只想畫入口下某條特定業務流程；若否則追該入口下所有 AppService；入口為特定方法時略過此題）
4. **要追到哪一層？**（預設：從入口往下全部追，畫出完整流程；若只需高層概覽可指定截止層）

取得回答後再繼續後續步驟。

### Step 1：解析範圍，找到入口檔案

依使用者描述定位入口，入口可以是任意層級的類別或方法：

- `sequenceDiagram`：通常從 Controller / Scheduler / Handler 開始
- `flowchart TD`：可以是任意方法（DomainService、Manager、或其他層的特定方法）

在 `src/` 下搜尋：

```bash
# 範例
grep -rl "class OrderController" src/
grep -rl "@Scheduled" src/
grep -rl "class OrderDomainService" src/   # flowchart 入口範例
```

### Step 2：追蹤呼叫鏈

從入口依序往下追，範圍以使用者描述為準：

```
Controller / Handler / Scheduler
  → AppService
    → DomainService / Manager
      → Repository / Client（DB、Cache、MQ、gRPC、HTTP）
```

追蹤重點：
- 方法呼叫順序與條件分支（每個 `if/else` → `alt/else`）
- 外部系統互動（DB、Cache、MQ、gRPC、外部 API）
- 例外處理與 fallback 路徑
- 呼叫鏈 > 5 層時先追主幹，側枝以子圖或 `click` 連結表示

記錄所有讀過的原始碼路徑，作為 `covers` 清單。

### Step 3：維護 diagram-participants.md

先依 Step 5 將採用的圖表輸出路徑，決定 `diagram-participants.md` 應在的目錄（與圖表同一目錄，見「專案 Participant 設定檔」）。追蹤完成後，比對追蹤到的所有元件名稱與該目錄下既有設定檔的差異：

- **不存在** → 依追蹤到的元件名稱產生初稿後寫入該目錄的 `diagram-participants.md`
- **存在** → 讀取現有 alias，將**尚未收錄的新元件**追加至檔案末尾

> 每次生成都執行此步驟，確保隨著程式碼增長，設定檔持續完整。

### Step 4：生成圖表

依情境選擇類型，套用通用顏色規範與 participant alias 生成 Mermaid 圖。

### Step 5：取得 commit hash，寫入檔案

```bash
git log --oneline -1
```

輸出至指定路徑（依「檔案輸出規範」：預設 `docs/<功能名稱>-flow.md`，呼叫方有指定輸出路徑時寫入指定路徑），metadata 含 `synced` hash、`type`（`sequenceDiagram` 或 `flowchart`）、`covers` 清單。

---

## sequenceDiagram 規範

### 結構慣例

- 排程觸發：`Note over SVC: @Scheduled fixedDelay=Xms`
- 迴圈：`loop for each <類型>`
- 條件分支：`alt <條件描述>` / `else <條件描述>` / `end`
- 例外拋出：`Note over SVC: throw XxxException（...）`
- 成功結尾：`Note over SVC: ✅ ...`
- 失敗結尾：`Note over SVC: ❌ ...`
- 交排程重試：`Note over SVC,CACHE: 🔁 下次排程重試`
- 非同步：`Note over SVC: CompletableFuture async → ...`
- 中文描述，步驟前加編號（`1.` `2a.` `2b.`）

### 步驟編號規則

- 主線：`1.` `2.` `3.` ...
- 分支內：`2a.` `2b.`、`3a.` `3b.`（alt/else 各自從父步驟 + 字母開始）

### 常見語法陷阱

`;` 是 Mermaid 語句結尾符，箭頭訊息文字內不可使用：

- ❌ `CACHE ->> SVC: INCR key; DEL if 0`
- ✅ `CACHE ->> SVC: INCR key<br/>DEL if 0`

---

## flowchart 規範

### 結構慣例

- 排程起點：`START(["@Scheduled fixedDelay=Xms\n方法名稱()"])`
- 迴圈：`subgraph LOOP1["for each <類型>"]` ... `end`（可巢狀）
- 決策菱形：`{條件描述}`
- 例外：`[/"throw XxxException\n'...'"/]`
- 正常動作：`["動作描述"]`
- 終點成功：`(["✅ 完成描述"])`
- 終點失敗：`(["❌ 失敗描述"])`
- 相同職責節點用 `subgraph` 分組（Controller、AppService、Manager 等）
- 外部系統用 `(["..."])` 或 `[("...")]`
- 流程步驟順序標示用 `[1][2][3]...`

---

## 檔案輸出規範

存放路徑：預設 `docs/<功能名稱>-flow.md`；呼叫方（如 `/my-work-agent`）有指定輸出路徑時，寫入該指定路徑，其父目錄不存在則自動建立。

```markdown
<!-- synced: {commit-hash} -->
<!-- type: sequenceDiagram -->
<!-- covers:
  path/to/SourceFile.java
-->

# <流程標題>

---

```mermaid
%%{init: ...}%%
sequenceDiagram
...
```
```

### 多段圖串接

結尾 Note 標明接續：
```
Note over SVC: ✅ 繼續下一階段（見 xxx-verify-flow.md）
```
下一張圖開頭說明：
```markdown
> 接續 `xxx-flow.md` 中「...」之後的步驟
```

---

## 模式二：同步（`/diagram sync`）

### Step 1：探索流程圖

```bash
grep -rl "synced:" docs/ 2>/dev/null || grep -rl "synced:" . --include="*.md"
```

找不到 → 回報「找不到任何流程圖，請先執行 `/diagram <範圍描述>` 建立圖表」，結束。

### Step 2：讀取各圖 metadata

對每個圖讀取 `synced` hash、`type`、`covers` 清單。若多個圖 hash 不同，以**最舊的 hash** 為共同基準。

### Step 3：git diff，判斷是否需要更新

```bash
git diff {synced-hash} HEAD -- {covers 中的每個路徑}
```

- diff 為空 → 跳過
- 有 diff → 繼續

### Step 4：讀有變動的檔案，更新對應節點

只讀 diff 中出現的原始碼（不全量讀取 covers 清單）。

依 metadata 的 `type` 分別套用更新規則：

**共用原則（兩種類型皆適用）：**
- 以程式碼為準，只修改有差異的節點文字、連線、分支條件
- 確保跨圖 `click` 連結仍指向正確檔案
- 若 `covers` 有過時路徑（檔案改名或移動），一併更新

**`type: sequenceDiagram`：**
- `%%{init: ...}%%` 顏色區塊缺失時自動補回
- 比對 diff 中出現的元件與該圖表所在目錄下的 `diagram-participants.md`（見「專案 Participant 設定檔」，非固定 `docs/`），將尚未收錄的新元件追加至設定檔
- 保持圖表內的 participant alias 與同目錄的 `diagram-participants.md` 一致

**`type: flowchart`：**
- 更新 subgraph 標籤、節點文字、決策條件
- 不套用 participant alias（flowchart 不使用）
- 不補 `%%{init: ...}%%`（flowchart 不需要）

### Step 5：更新 synced hash

```bash
git log --oneline -1
```

將每個**有修改**的圖的 `synced` hash 更新為最新 commit hash。
