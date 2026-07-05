# 模型調度守則

> 派發 subagent、選模型、設 effort 前必讀。規則寫死,照做即可;例外情況見 [judgment-rubrics.md](judgment-rubrics.md)。
> 撰於 2026-07-05。「已查證」代表當日從官方來源確認過;日期久遠後請重新查證(方法見文末)。

---

## 0. 已查證事實表(不憑記憶,抄這裡)

### 模型 ID 與價格(來源:claude-api skill 模型表,cached 2026-06-24)

| 模型 | Model ID | 輸入 $/1M | 輸出 $/1M | 定位 |
|---|---|---|---|---|
| Claude Fable 5 | `claude-fable-5` | $10.00 | $50.00 | 最強;稀缺,僅特殊 session 可用 |
| Claude Opus 4.8 | `claude-opus-4-8` | $5.00 | $25.00 | 最強常駐 Opus |
| Claude Sonnet 5 | `claude-sonnet-5` | $3.00(至 2026-08-31 前 $2.00) | $15.00(前 $10.00) | 日常主力 |
| Claude Haiku 4.5 | `claude-haiku-4-5` | $1.00 | $5.00 | 快、便宜、簡單任務 |

注意:**不要自行在 ID 後面加日期後綴**(如 `claude-sonnet-5-20260101`),會 404。

### Claude Code 的 subagent 調度介面(來源:code.claude.com/docs/en/sub-agents.md,2026-07-05 由 claude-code-guide 查證)

- 主對話 Agent 工具的 `model` 參數合法值:`sonnet` / `opus` / `haiku` / `fable`(alias),或完整 model ID,或 `inherit`。
- 自訂 subagent 定義檔 `.claude/agents/*.md` frontmatter:
  - `model:` 同上,預設 `inherit`
  - `effort:` 合法值 `low` / `medium` / `high` / `xhigh` / `max`,預設繼承 session(可用級別視模型而定;Haiku 4.5 **不支援** xhigh/max)
  - `tools:` 逗號分隔工具名清單,如 `tools: Read, Grep, Glob, Bash`
- settings.json **沒有** subagent 專用的模型/effort 設定鍵;全域 subagent 預設模型可用環境變數 `CLAUDE_CODE_SUBAGENT_MODEL`(來源:code.claude.com/docs/en/model-config.md)。
- 內建可派發的 agent 類型:`general-purpose`(全工具)、`Explore`(唯讀搜索)、`Plan`(規劃)、`claude-code-guide`(查 Claude Code/API 文件)、`claude`、`statusline-setup`。

### 未確認事項(不要假裝知道)

- 「安全機制把請求導向 Opus 4.8 時,是否消耗原模型的額度窗口」——**未確認,建議到 claude.ai 的 usage 儀表板實測**。
- 各訂閱方案的具體額度數字——無法在 CLI 內查詢,以「隨做隨存、價值排序」對沖。

---

## 1. 指揮官不下場

主對話(通常是較貴的模型)只做三件事:**決策、交辦、整合結論**。以下工作一律派 subagent:

| 工作 | 派給 | model | effort |
|---|---|---|---|
| 找檔案、跨檔搜尋、確認某規則寫在哪 | Explore | haiku | low |
| 讀多檔+彙整摘要 | general-purpose | haiku(彙整需推理時 sonnet) | low/medium |
| 查 Claude Code / API 官方文件 | claude-code-guide | haiku | low |
| 批次機械修改(套用已定案的模式) | general-purpose | haiku | low |
| 實作一個明確規格的功能/腳本 | general-purpose | sonnet | medium/high |
| 重構、跨檔一致性修改 | general-purpose | sonnet | high |
| 規劃複雜實作方案 | Plan | sonnet(極難題 opus) | high |
| 對抗審查、第二意見 | general-purpose | sonnet | high |
| read-back 驗證檔案 | general-purpose | haiku | low |

主線親自動手的唯一正當理由:**換便宜模型就掉品質的判斷**(架構取捨、模糊需求釐清、對使用者的最終回覆),或單一小檔的直接編輯(派發成本反而更高)。

## 2. 交辦三要素(缺一不發)

每個 Agent prompt 必含,模板見 [prompt-templates.md](prompt-templates.md):

1. **目標與動機**:做什麼+為什麼(subagent 沒有主線 context,動機能讓它在邊界情況做對取捨)。
2. **驗收條件**:可客觀檢查的完成標準(「找到定義該規則的檔案與行號」而非「幫我看看」)。
3. **回報格式**:明確規定回什麼、多長(見下節回報合約)。

## 3. 顯式指定 model 與 effort

- 每次 Agent 呼叫都**明寫 `model` 參數**,不留空(留空=繼承主線模型=最貴)。
- 派發起點從上表選;拿不準時:讀多寫少選 haiku,要寫東西選 sonnet。
- effort 目前只能在 `.claude/agents/*.md` frontmatter 或 session 層級設定;主對話 Agent 工具呼叫本身沒有 effort 參數(2026-07-05 查證時的工具 schema 如此)。若需要固定低 effort 的常用角色,依 [maintenance-protocol.md](maintenance-protocol.md) 建 `.claude/agents/` 定義檔。

## 4. 回報合約(subagent 端)

寫進每個交辦 prompt 的固定條款:

- 只回**結論**與**證據指位**(`檔案路徑:行號`),不要貼大段原文。
- 長產物(報告、程式碼、清單)**存檔後回傳路徑**,不要整份貼回。
- 回報長度上限:搜尋/驗證類 ≤20 行;研究/審查類 ≤40 行。
- 找不到/做不到就直說「找不到:{原因}」,不要硬湊答案。

## 5. 升降級路徑

| 情況 | 動作 |
|---|---|
| haiku 做錯一次 | 直接升 sonnet 重派(不要讓 haiku 重試同一題) |
| sonnet 在**同一個子任務**連錯兩次 | 帶完整失敗軌跡(兩次的 prompt、輸出、錯在哪)升 opus |
| opus 也解不了 | 停,整理失敗軌跡問使用者(這通常是需求或環境問題,不是模型問題) |
| 高階模型解出了「模式」(例如確認了修法) | 把模式寫成明確規則,降回 haiku/sonnet 批次套用 |
| 任何同一件事 | 最多重試兩輪;第三輪前必須改變什麼(升級模型、換方法、或問人),否則就是在燒錢 |

升級時 prompt 必附:前幾次的原始交辦內容、實際輸出、驗收條件哪一條沒過。沒有失敗軌跡的升級等於重新抽獎。

## 6. 驗證不自驗

寫產出的 agent(或主線)不能自己宣告合格。固定作法:

- **檔案**:另派 fresh-context subagent(haiku, 唯讀)read-back:給檔案路徑+驗收條件清單,回「每條符合/不符合+行號」。
- **程式碼**:跑測試或實際執行,以輸出為準;沒有測試就先寫一個最小驗證腳本再跑。
- **高風險判斷**(架構決策、要對使用者/外部發布的內容):第二意見——另派一個 subagent 用相同輸入獨立作答,主線比對分歧;或多答案評審擇優(同題派兩個,再派一個評審比較)。
- 驗證 agent 的 prompt **不給撰寫過程與理由**,只給產出與標準——避免被原作者的敘事帶著走。

## 7. 查證方法(當本表過期)

1. 模型 ID/價格:派 `claude-code-guide`(haiku)查 `platform.claude.com/docs/en/about-claude/models/overview.md`。
2. subagent 欄位:同上查 `code.claude.com/docs/en/sub-agents.md`。
3. 查回來後更新本檔第 0 節,並更新查證日期(維護規則見 maintenance-protocol.md)。
