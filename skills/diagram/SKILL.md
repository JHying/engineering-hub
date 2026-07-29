---
name: diagram
description: 統一 Mermaid 圖表工具：依描述範圍生成圖表（套用通用顏色規範 + 專案 participant alias）、依 git diff 同步更新。
version: "1.4"
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

呼叫方（例如 `/sdlc-agent`）可額外指定完整輸出路徑，覆蓋預設輸出位置：
- `/diagram <範圍描述> --output <完整檔案路徑>`
- 未指定時，維持預設輸出路徑規則（見「檔案輸出規範」）

明細見：`references/diagram-type-selection.md`（圖表類型自動判斷表）、`references/participant-config.md`（專案 participant alias 設定檔規則）、`references/metadata-format.md`（圖檔頂部 metadata 完整格式）、`references/color-scheme.md`（通用顏色規範全文）。

---

## 模式一：生成圖表（`/diagram <範圍描述>`）

- 無範圍描述時先用 `AskUserQuestion` 詢問入口、類型、AppService 範圍、追蹤深度
- 定位入口 → 追蹤呼叫鏈（Controller/Scheduler → AppService → DomainService/Manager → Repository/Client）→ 維護 diagram-participants.md → 套用顏色規範生成圖 → 寫入 commit hash 等 metadata
- 完整步驟（Step 0-5）見 `references/generate-mode.md`

sequenceDiagram / flowchart 各自的結構慣例、步驟編號規則、語法陷阱，見 `references/sequence-diagram-conventions.md`、`references/flowchart-conventions.md`。

---

## 模式二：同步（`/diagram sync`）

- 探索 repo 中帶 `synced:` metadata 的圖表，讀取各圖的 `synced`/`type`/`covers`
- 對 covers 清單做 git diff，僅在有變動時讀取變動檔案更新對應節點，並依 `type` 套用 sequenceDiagram / flowchart 各自的更新規則，最後更新 synced hash
- 完整步驟（Step 1-5）見 `references/sync-mode.md`

---

## 檔案輸出規範

存放路徑：預設 `docs/<功能名稱>-flow.md`；呼叫方（如 `/sdlc-agent`）有指定輸出路徑時，寫入該指定路徑，其父目錄不存在則自動建立。

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

## 硬性約束

- `type` metadata 只能是 `sequenceDiagram` 或 `flowchart`，由生成時寫入，供 sync 判斷更新規則
- Mermaid `;` 是語句結尾符，箭頭訊息文字內不可使用（用 `<br/>` 換行取代）
- `alt` 外框為虛線是 Mermaid 硬編碼規格，無法透過 themeVariables 改為實線
- `diagram-participants.md` 一律與本次圖表**實際輸出目錄**同目錄，不固定寫死 `docs/`
- sync 模式只讀 git diff 中出現的原始碼，不全量讀取 covers 清單
- 多圖 `synced` hash 不同時，以最舊的 hash 為共同基準
- participant alias 由各專案自行維護，skill 本身不內建任何 alias
