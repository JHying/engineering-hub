# 快速診斷:此 harness 的三大失血點與修法

> 寫給之後在此環境長期作業的模型(Sonnet / Opus / Haiku 等級)。
> 每一條都是本環境實測觀察到的,不是通論。修法照做即可,不需要重新判斷。
> 撰於 2026-07-05(Fable 5 session)。維護規則見 [maintenance-protocol.md](maintenance-protocol.md)。

---

## 一、最漏 token 的前三名

### 1. `claude-api` skill 的觸發條件過寬,一次灌入數萬 token

**現象**:這個 skill 的觸發條款寫著「提示詞出現 Claude/Anthropic/模型名就要先讀」。一旦觸發,它會把**所有語言**的 SDK 文件全文塞進 context(實測一次載入約等於數萬 token)。在這個 KB 維運環境裡,對話提到「模型」「Claude」的頻率很高,但真正需要寫 Anthropic API 程式碼的情境幾乎為零。

**修法(可直接照做)**:
- 只在「使用者要求撰寫或修改『呼叫 Claude API 的程式碼』」時才觸發 `claude-api` skill。
- 只是要查模型 ID、價格、effort 值 → 先查 [model-dispatch.md](model-dispatch.md) 的已查證表,不要觸發 skill。
- 表上沒有、又必須即時查證 → 派 `claude-code-guide` subagent(model: haiku)去查,主線不觸發。

**正例**:使用者說「幫我寫一支 Python 腳本呼叫 Claude API 做批次分類」→ 觸發 skill。
**反例**:使用者說「派個 sonnet subagent 去掃 repo」→ 這只是調度,查 model-dispatch.md 即可,觸發 skill 就是漏 token。

### 2. 主線自己讀大檔、掃 repo

**現象**:本 repo `knowledge/` 底下有 300+ 個檔案(2026-07 實測約 345 檔,單一專案 KB 就有完整 source-codex)。主線直接 Glob 寬鬆 pattern 或逐檔 Read,幾輪就吃掉大半 context。本 session 實測:裸 `Glob *` 一次回傳數百筆路徑,遠超單次可讀量。

**修法(可直接照做)**:
- 觸發條件:預估要讀 **3 個以上檔案**、或**單檔超過 300 行**、或**不知道目標在哪個檔**。
- 動作:派 `Explore` subagent(唯讀搜索)或 `general-purpose`(需要讀+彙整),要求只回「結論 + 檔案:行號」。prompt 範本見 [prompt-templates.md](prompt-templates.md) 的「搜尋型」。
- 主線只允許直接讀:單一已知路徑、預期 ≤300 行、且接下來要親自編輯的檔案。

**正例**:「@PROJECT 的 Kafka topic 命名規則在哪?」→ 派 Explore,收回「knowledge/@PROJECT_KBs/source-codex/cross/kafka-topology.md:12」。
**反例**:主線自己 Read 五個 ADR 檔再彙整——彙整品質不會更好,context 卻永久佔用。

### 3. Glob / Grep 不設範圍與上限

**現象**:`Glob("*")`、`Grep(pattern)` 不加 path/type/head_limit,在這個 repo 會回傳數百筆(`file-history/` 之類的垃圾目錄也會中獎)。

**修法(可直接照做)**:
- Glob 一律帶具體子目錄與副檔名:`knowledge/@PROJECT_KBs/ADRs/*.md`,不寫裸 `*` 或 `**/*`。
- Grep 先用 `output_mode: "count"` 或 `files_with_matches` 探路,確認命中量再用 `content`;`content` 模式帶 `head_limit`(建議 ≤50)。
- 對 `C:\Users\User\.claude\` 永遠不要跑寬鬆 Glob(裡面有 700+ 個 file-history 快照)。

---

## 二、最易失焦的前三名

### 1. 「說了但沒做」——承諾句取代工具呼叫

**現象**:長回覆結尾寫「我會在背景同步到 KB」「稍後處理」,然後什麼工具都沒呼叫。這是本環境已被使用者糾正過的實際教訓(見 memory:`feedback_narrate-then-act`),CLAUDE.md 也已有紀律條款。弱模型在長輸出後特別容易犯。

**修法**:寫下任何「我會/我將」之前,檢查同一則回覆內是否已包含對應的工具呼叫。做不到當下派發(例如還要先分類),就先 `TaskCreate` 佔位(注意:它是延遲載入工具,先用 ToolSearch `select:TaskCreate,TaskUpdate` 載入;環境沒有就在回覆中明列待辦文字),完成後才標 completed。回覆送出前自查最後一段:若是承諾句而無工具呼叫,回去補上。

### 2. Session 初始化與例行儀式吃掉開場

**現象**:舊版 CLAUDE.md 要求每個 session 開場先問兩題(KB 路徑+定時考題),KB 路徑其實幾乎永遠不變。已改為「異常才問」(見新版 CLAUDE.md),不要退回逐題詢問的寫法。

**修法**:開場直接做事。只有 `setting/paths.yml` 的 `kb` 與實際工作目錄不一致時才提示。長任務進行中不啟動 `/loop` 類週期干擾。

### 3. KB 同步的分類猶豫變成主線長篇討論

**現象**:對話產生值得記錄的結論時,模型在主線反覆分析「這算 tech-research 還是 ADR 還是 guideline」,燒 token 又中斷主工作。

**修法**:照 CLAUDE.md 的分級表二分:能明確判為免確認路徑(tech-research/、專案 ADR)→ 直接背景派發;其餘一律先問使用者一句話(給 2-3 個選項),不要自己長篇推理。判準:分類不能從表上直接對上、需要開始比較兩個選項優劣,就代表該問了。

---

## 三、最易出錯的前三名

### 1. 憑記憶填模型 ID 與 API 參數

**現象**:訓練資料裡的模型名(如 `claude-3-5-sonnet-20241022`)多數已退役;自行拼裝帶日期後綴的 ID 會 404。effort、thinking 等參數在新模型上已多次改版。

**修法**:模型 ID、價格、effort 值一律抄 [model-dispatch.md](model-dispatch.md) 的已查證表;表上沒有的,派 `claude-code-guide`(haiku)查官方文件,查不到就對使用者標註「未查證」,**絕不編造**。

### 2. Windows 雙 shell 混用出錯

**現象**:此環境同時有 PowerShell 5.1(主要)與 Git Bash。常見炸點:PS 5.1 沒有 `&&`/`||`;PS 預設寫檔編碼是 UTF-16 LE(其他工具讀不了);bash 路徑是 `/d/Work/...` 而 PS 是 `D:\Work\...`。

**修法**:
- 檔案讀寫一律用 Read/Write/Edit 專用工具,不用 shell 重導向寫檔。
- PS 內要串連命令用 `;` 或 `if ($?)`,不寫 `&&`。
- 若必須用 PS 寫檔,必帶 `-Encoding utf8`。
- POSIX 語法(heredoc、`&&`)一律走 Bash 工具,並用 `/d/...` 路徑。

### 3. 自驗自己的產出

**現象**:寫完檔案或改完程式立即宣告完成。同一個 context 內的自我檢查,會沿用同樣的盲點,等於沒驗。

**修法**(依產出類型):
- 檔案類:派 fresh-context subagent(model: haiku)read-back——只給檔案路徑與驗收條件,不給撰寫過程,回報「符合/不符合+行號」。
- 程式碼類:實際執行測試或跑起來看行為,貼輸出;測試失敗就照實說失敗。
- 高風險判斷(架構決策、對外發布):第二意見——派另一個 subagent 用相同輸入獨立作答,比對分歧點。
- 詳細判準見 [judgment-rubrics.md](judgment-rubrics.md) 的「品質底線怎麼驗」。
