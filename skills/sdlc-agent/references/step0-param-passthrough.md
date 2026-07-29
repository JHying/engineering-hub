# Step 0 — 啟動參數直通（明細）

### Step 0 — 啟動參數直通（有參數時）

呼叫時若帶參數，依下列規則解析並**跳過對應的問答步驟**；解析不出的部分照常詢問：

| 參數樣式 | 解析為 |
|---------|--------|
| `_KBs` 結尾名稱、或 Step 1.5 選單編號 | 選定專案 KB（跳過 Step 1.5 詢問） |
| `single`/`單一`、`pipeline`/`部分`、`full`/`完整`、`preview` | 執行模式 1–4（跳過 Step 2 詢問） |
| 角色名（PM/SA/CONSULTANT/BACKEND/REVIEWER/QA/SRE） | 模式 1 並選定該角色 |
| 角色觸發短語：分析 story／分析 jira（→PM）、寫 spec／spec 轉化（→SA）、KB 諮詢／查知識庫（→CONSULTANT）、實作 ticket／spec-driven 實作（→BACKEND）、code review／審查程式碼（→REVIEWER）、補測試／驗測／測試策略（→QA）、維運檢查／部署驗證（→SRE） | 模式 1 並選定對應角色（跳過 Step 2 與角色選單）；同時出現明確角色名或模式參數時，以角色名/模式參數優先 |
| stage 名稱或編號（搭配 `pipeline`） | `$start_stage`（跳過 Step P1） |
| 連續 A/C 字串（如 `CAAAA`，長度須等於待設定 stage 數） | `$stage_modes`（跳過 Step P2） |

範例：
- `/sdlc-agent 1 full CAAAA` ＝ 第 1 個 KB、完整流程、C A A A A，零問答直接開跑。
- 「補測試 {TICKET}」＝ 單一角色 QA，針對該 ticket 補測試（KB 未指定則照常詢問）。
- 「寫 spec {TICKET}」＝ 單一角色 SA。
