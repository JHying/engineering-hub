<!-- 由 SKILL.md Step 4（含 4-1～4-4）連結，完整明細。 -->

## Step 4 — 彙整子代理結果，同步 Meta 檔案

等所有子代理完成後：

### 4-1 同步各 PROJECT_KB 的 MASTER_INDEX.md

對每個更新過的 `$PROJECT_KB`，確認 MASTER_INDEX 是否完整反映：
- PM KB：比照下方 Review History KB，MASTER_INDEX **不重複列出個別條目**，只維護一個指標段落（筆數 + 指向 `specs/index.md` 的連結）；個別條目的建立/更新只寫入 `specs/index.md`（子代理模板 Step D 已涵蓋）
- RD KB：AI 文件路由規則是否有新關鍵字
- SRE KB：site-reliability 文件清單是否有新增
- Review History KB：MASTER_INDEX **不重複列出個別條目**，只維護一個指標段落（筆數 + 指向 `review-history/index.md` 的連結 + 格式規範連結）；個別條目的建立/更新只寫入 `review-history/index.md`（子代理模板 Step C 已涵蓋）
- QA Records KB：比照上一列，MASTER_INDEX 只維護指標段落，個別條目寫入 `qa-records/index.md`（不存在時視同首次建立，建立時依 `review-history/index.md` 的既有格式：日期｜Ticket｜判定｜檔案 四欄，`判定` 欄僅放通過/未通過 + 極短註記，完整過程留在 `qa-records/{TICKET}-qa.md` 本體，不重複塞進索引儲存格——見「表格欄位可讀性規則」）

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
