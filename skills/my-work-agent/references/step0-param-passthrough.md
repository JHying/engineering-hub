# Step 0 — 啟動參數直通（明細）

### Step 0 — 啟動參數直通（有參數時）

呼叫時若帶參數，依下列規則解析並**跳過對應的問答步驟**；解析不出的部分照常詢問：

| 參數樣式 | 解析為 |
|---------|--------|
| `_KBs` 結尾名稱、或 Step 1.5 選單編號 | 選定專案 KB（跳過 Step 1.5 詢問） |
| `single`/`單一`、`pipeline`/`部分`、`full`/`完整`、`preview` | 執行模式 1–4（跳過 Step 2 詢問） |
| 角色名（PM/SA/CONSULTANT/BACKEND/REVIEWER/QA/SRE） | 模式 1 並選定該角色 |
| stage 名稱或編號（搭配 `pipeline`） | `$start_stage`（跳過 Step P1） |
| 連續 A/C 字串（如 `CAAAA`，長度須等於待設定 stage 數） | `$stage_modes`（跳過 Step P2） |

範例：`/my-work-agent 1 full CAAAA` ＝ 第 1 個 KB、完整流程、C A A A A，零問答直接開跑。
