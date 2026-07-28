# Step 1.5 — 選擇專案知識庫（明細）

### Step 1.5 — 選擇專案知識庫

掃描 `$KB_ROOT/knowledge/` 下所有名稱以 `_KBs` 結尾的直接子資料夾，列出可用的專案 KB 供使用者選擇。

通用知識庫（`knowledge/common_KBs/`）採 **index-first** 載入，**不列入選擇**：
- 執行時先讀 `common_KBs/MASTER_INDEX.md`，依 Story 主題判斷相關的 ADR 分類與 tech-research 筆記後，**只讀取相關項目**
- `common_KBs/guideline/REVIEW_GUIDE.md` 為例外，REVIEWER 角色必讀，其餘角色依需要載入

顯示類似：

```
請選擇要載入的專案知識庫（輸入編號，多個以逗號分隔，如 1,2）：
  1. {project_name}_KBs
  2. {another_project}_KBs
  ...

說明：knowledge/common_KBs 為共用知識，依 Story 主題按需載入。
```

等待使用者回答，記住選定的專案 KB 清單（以下稱 `$PROJECT_KBs`）。

每個選定 KB 的根路徑格式為 `$KB_ROOT/knowledge/{project_name}/`。

若各專案 KB 內含 `MASTER_INDEX.md`，記錄其完整路徑（以下稱 `$master_indexes`，多個 KB 時全部記錄）。

讀取每個選定 KB 的 `source-codex/cross/service-map.md`（若存在），記錄各服務對應的本機原始碼路徑（以下稱 `$SOURCE_ROOTS`，格式：`{service}: {本機路徑}`）。若檔案不存在，或某服務路徑缺漏（標記為 `-` 或 `[待補充]`），先不追問——到 SA / BACKEND / Code Review / QA 這幾個實際需要讀寫該服務程式碼的 stage 時，再向使用者確認實際路徑。
