# Step 4 — 角色與流程文件載入規則（明細）

### Step 4 — 角色與流程文件載入規則

**單一角色模式**：只依選擇的角色讀取對應的一對文件，不讀取其餘角色的檔案：

| 角色        | 角色文件                | 工作流程                  |
|------------|----------------------|--------------------------|
| BACKEND    | `{{role_backend}}`   | `{{flow_backend}}`       |
| QA         | `{{role_qa}}`        | `{{flow_qa}}`            |
| SRE        | `{{role_sre}}`       | `{{flow_sre}}`           |
| PM         | `{{role_pm}}`        | `{{flow_pm}}`            |
| CONSULTANT | `{{role_consultant}}`| `{{flow_consultant}}`    |
| REVIEWER   | `{{role_reviewer}}`  | `{{flow_reviewer}}`      |

**Pipeline 模式（懶載入 / lazy load）**：Step 4 本身**不讀取任何 stage 的角色或流程文件**，只記住下表作為 `$start_stage` 起各 stage 對應的檔案路徑對照；實際讀檔動作延後到 Step 5-PIPELINE 各 stage **開始執行前**才進行：

| Stage | 角色文件 | 工作流程 |
|-------|---------|---------|
| 需求企劃 | `{{role_pm}}` | `{{flow_pm}}` |
| Spec 轉化 | `{{role_sa}}` + `{{role_consultant}}` | `{{flow_sa}}` + `{{flow_consultant}}` |
| Spec-Driven 實作 | `{{role_backend}}` + `{{role_consultant}}` | `{{flow_backend}}` + `{{flow_consultant}}` |
| Code Review | `{{role_reviewer}}` | `{{flow_reviewer}}` |
| QA | `{{role_qa}}` | `{{flow_qa}}` |

**載入規則（Pipeline 模式）：**

- 每個 stage 開始執行前，才讀取該 stage 對應列的檔案對；**不得預先讀取尚未開始執行之 stage 的角色或流程文件**。
- **CONSULTANT 為跨 stage 角色，ADR 溝通貫穿 Spec 轉化至 Spec-Driven 實作**：進入「Spec 轉化」stage 時，除了 SA 的檔案對，一併載入 CONSULTANT 的檔案對（`{{role_consultant}}` + `{{flow_consultant}}`）；此檔案對持續保留使用直到「Spec-Driven 實作」stage 結束為止——「Spec-Driven 實作」stage 開始時不需重複載入 CONSULTANT 檔案對，中間也不因換 stage 而重讀。
- 除上述 CONSULTANT 例外，各 stage 之間不共用已讀取的角色/流程檔案；下一個 stage 開始時，只依對照表載入自己該讀的檔案對。
- **共用參考文件不重讀**：master_index、REVIEW_GUIDE、服務文檔（features / architecture / api-spec 等）、spec / impls 等**非角色/流程類**文件，pipeline 中第一次讀取後即沿用 context 內容；後續 stage 的流程文件再要求讀取同一檔案時，跳過重讀、直接引用已載入內容。唯一例外：該檔案在 pipeline 中途被寫入或變更（spec 更新、`/update-kb` 寫入、程式碼異動連帶更新文檔）→ 重讀該檔取得最新版。
- 「不預先讀取」不等於「可卸載」：已讀入的檔案內容仍留在對話 context 中無法移除，因此更需嚴格遵守「到了才讀」，避免提早讀入尚未執行到的 stage 文件而增加固定 context 成本。
