# Claude Code 工作規則(索引)

本檔只做路由,長內容都在 `governance/`,依觸發條件按需讀取,**不要一開場就全部讀完**。
改本檔或 governance/ 前,先讀 `governance/maintenance-protocol.md`。

## Session 初始化(每個 session 第一則回覆固定回報一行,不逐項詢問)

1. 比對 `setting/paths.yml` 的 `kb` 與實際工作目錄:
   - 一致 → 第一則回覆附一行「KB 路徑:{實際路徑}(已確認一致)」
   - 不一致 → 提示使用者確認是否更新 paths.yml
2. 同一行附註「如需定時複習可說 `/loop 30m /quiz`」,不主動啟動,僅提示選項存在。
3. 僅第一則回覆執行一次,同一 session 後續不重複。

## 按需讀取路由

| 情境(觸發條件) | 先讀 |
|---|---|
| 要派發 subagent、選模型、設 effort | `governance/model-dispatch.md` |
| 要寫交辦 prompt(搜尋/實作/重構/研究/審查) | `governance/prompt-templates.md` |
| 拿不準:要不要升級模型/算不算完成/該不該問使用者/是不是方向錯了 | `governance/judgment-rubrics.md` |
| 要修改 CLAUDE.md、governance/、skill | `governance/maintenance-protocol.md` |
| 反覆出錯、token 燒太快、感覺失焦 | `governance/diagnosis.md` |
| 第一次在此環境作業、想了解制度來由 | `governance/handover-letter.md` |

## 硬規則(常駐,無條件遵守)

1. **模型 ID 與 API 參數不憑記憶填**:先抄 `governance/model-dispatch.md` 的已查證表;
   表上沒有→派 `claude-code-guide`(haiku)查官方文件;查不到→標「未查證」,不編造。
2. **大量讀取派 subagent**:要讀 3 個以上檔案、單檔超過 300 行、或不知道目標在哪
   →派 Explore / general-purpose,主線只收「結論+檔案:行號」。
3. **說要做就同回覆做**:任何「我會/我將/稍後」都必須在同一則回覆內附上對應工具呼叫;
   當下派不了就先 `TaskCreate` 佔位,派發完成才標 completed。
   (TaskCreate 是延遲載入工具:先用 ToolSearch 查 `select:TaskCreate,TaskUpdate` 載入 schema;
   若此環境確實沒有該工具,改為在回覆中明列待辦清單文字,下一則回覆優先補派。)
4. **改檔先備份**:修改 CLAUDE.md、governance/、skill 前,
   先複製到 `governance/backup/{原檔名}.{YYYY-MM-DD}.bak`。
   (例外:maintenance-protocol.md 權限表標 ✅ 的操作——lessons.md 追加、查證表更新——免備份。)
5. **產出不自驗**:宣告完成前,檔案用 fresh-context subagent read-back、
   程式碼用測試或實跑、高風險判斷加第二意見。詳見 judgment-rubrics.md。

## Skill 開發規範

- 修改任何 skill 的 `SKILL.md`,同一次工作中必須同步更新該 skill 的 `CHANGELOG.md`
  (版本號、日期、Added / Changed / Removed)。
- SKILL.md 與 CHANGELOG.md 均需去識別化(不含專案名稱、ticket 編號、真實類別名稱)。

## 知識庫整合規範(每次對話都適用)

KB 分兩類:**專案 KB**(特定專案的規範/架構/業務邏輯)與**通用 KB**(跨專案研究與共用規範)。

對話中產生值得記錄的結論(技術決策、研究結論、規範確立)時,按下表處理;
若分類無法從下表**直接對上**、需要比較兩個選項優劣才能決定,就直接問使用者(給 2-3 個選項),
不要自己長篇推理:

| 內容類型 | 動作 |
|---|---|
| 通用技術研究(`tech-research/`)、專案 ADR | 免確認:直接觸發 `/update-kb`,寫入依 skill Step 3 開**背景 subagent** 執行(勿在主線讀寫檔案),主線只收摘要、事後回報一行「已存入哪個檔」 |
| 共用 ADR(`common_KBs/ADRs/`) | 先問使用者是否同步+存哪個分類,確認後同樣背景 subagent 寫入 |
| guideline(`common_KBs/guideline/`) | 不主動觸發,僅使用者明確指示才處理 |
| 分不出類、或橫跨多類 | 比照風險較高者:先問 |

執行紀律同硬規則 3:觸發同步的工具呼叫必須與判斷在同一則回覆內,否則 TaskCreate 佔位。

**需要先載入 KB context 再做事時**:先問使用者要讀哪類 KB(專案 KB 指定專案、通用 KB 直接載入),
確認後用 `/my-work-agent consultant` 模式載入。
