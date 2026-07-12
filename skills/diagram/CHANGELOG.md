# Changelog — diagram

所有版本異動依時間倒序排列。

---

## [1.2] — 2026-07-08

### Fixed
- `diagram-participants.md` 路徑固定寫死 `docs/`，未考慮圖表用 `--output` 覆蓋輸出到其他位置（例如整合流程將圖表存進 KB 的 `source-codex/services/{service}/`）的情境，導致參與者設定檔與它描述的圖表分散在兩個不相關目錄，且圖表輸出到 KB 時完全不會被自動探索到。改為：`diagram-participants.md` 一律放在**與本次圖表實際輸出目錄相同**的目錄，未覆蓋輸出路徑時仍是預設的 `docs/diagram-participants.md`，行為不變；有覆蓋時跟隨移到該目錄

---

## [1.1] — 2026-07-05

### Added
- `/diagram <範圍描述>` 新增選填的輸出路徑參數（`--output <完整檔案路徑>`），供呼叫方（例如整合流程的其他 skill）指定完整輸出路徑，覆蓋預設輸出位置

### Changed
- 檔案輸出規範調整為：預設仍輸出至 `docs/<功能名稱>-flow.md`；呼叫方有指定輸出路徑時，改寫入該指定路徑，父目錄不存在則自動建立

---

## [1.0] — 合併重構

### Changed
- 合併 `mermaid-diagram` 與 `sync-diagram` 為統一的 `diagram` skill
- 圖表類型（`sequenceDiagram` / `flowchart TD`）改由使用者指定或自動判斷，並寫入 metadata `<!-- type: -->`，供 sync 依類型套用正確更新規則
- Participant alias 改由各專案自行維護 `docs/diagram-participants.md`；skill 不內建任何 alias，每次執行自動比對並補入新元件

### Added
- `/diagram <範圍描述>`：生成圖表，套用通用顏色規範 + 專案 participant alias，自動寫入 `synced` / `type` / `covers` metadata
- `/diagram`（無參數）：互動詢問入口、類型、AppService 範圍、追蹤深度後執行
- `/diagram sync`：依 `type` metadata 分別套用 sequenceDiagram / flowchart 更新規則
- 通用顏色規範（`loopLineColor` / `signalTextColor` / `labelTextColor` / `loopTextColor`）內建於 skill，所有專案一致

### Removed
- `mermaid-diagram`：獨立 skill 已整併
- `sync-diagram`：獨立 skill 已整併，`/sync-diagram init` 模式整合為生成模式的互動詢問

---

## 歷史紀錄 — sync-diagram [1.0] — 初版

### Added
- `/sync-diagram`：依 git diff 同步更新已有 Mermaid 流程圖
- `/sync-diagram init`：從零探索專案，生成初始流程圖
- 以 `<!-- synced: -->` / `<!-- covers: -->` metadata 追蹤變動範圍
- 找不到帶 metadata 的流程圖時自動提示改用 `init` 模式
- 不含任何專案特定資訊，路徑與類別對應由各流程圖 `covers` 自行宣告
