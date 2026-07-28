# 模式一：生成圖表（`/diagram <範圍描述>`）

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
