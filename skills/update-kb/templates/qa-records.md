<!-- 此檔案由 update-kb skill.md Step 3 派發子代理時讀取，對應 QA Records KB 更新。
     使用時機：Step 2 判斷內容涉及此 KB 類型後，派發者只讀取本檔案（不需一併讀取其他 templates/*.md）構成子代理 prompt。
     佔位符（如 {$KB_ROOT}、{$PROJECT_KB}、{TICKET} 等）由派發者在派發前代入實際值，本檔案內容本身不需修改。 -->

### QA Records KB 子代理 prompt

**派發規格**：`subagent_type: general-purpose`｜`model: sonnet`（測試策略與案例表需摘要改寫，非機械複製）

```
你是 Knowledge Base 的 QA Records KB 更新代理，負責在下方「目標路徑」建立或更新 QA 測試記錄。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。
$KB_ROOT 路徑外只允許讀取（原始碼、git log）。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 目標路徑（本檔案所有路徑的唯一來源，其他章節一律用「目標路徑」代稱，不重複寫死資料夾名）
{$PROJECT_KB}/qa-records/

## 必讀文件
1. QA 記錄格式規範：目標路徑/qa-format.md

## 更新來源
{QA 測試策略、測試案例表、測試執行結果：可為對話摘要、QA stage 輸出文字、或 ticket 單號}

## 執行規則

### Step A — 確認檔案名稱
依 `{TICKET}-qa.md` 命名（例：`PROJECT-123-qa.md`）
- 若檔案已存在 → 依內容判斷是為初次執行結果補齊，或為 QA 迴圈重跑新增回圈記錄，不覆蓋既有已確認內容

### Step B — 建立或更新 QA 記錄
依 qa-format.md 的文件結構寫入，涵蓋：
- 測試策略
- 測試案例表（Happy Path / Edge Case / 錯誤情境）
- Contract 覆蓋（Spring Cloud Contract，若有）
- 測試執行結果（Unit / Integration / Contract / 本機啟動驗證）

### Step C — 更新目標路徑下的 index.md
若「目標路徑」下的 `index.md` 存在，在表格加入新條目（或更新既有條目的判定欄）；
若不存在，建立 index.md：

```
# QA Records 索引

| 日期 | Ticket | 判定 | 檔案 |
|------|--------|------|------|
| {YYYY-MM-DD} | {TICKET} | {✅ 通過 / ❌ 未通過，僅極短註記如「（N輪）」，不放完整過程} | [{檔名}]({檔名}) |
```

**判定欄只放結論 + 極短註記，不得複製測試案例表或多輪過程細節進索引**——那些內容留在 `{TICKET}-qa.md` 本體，索引只負責讓人快速定位該去讀哪個檔案（見「表格欄位可讀性規則」）。**不要把這張表另外複製一份到 MASTER_INDEX**：MASTER_INDEX 對應章節只維護筆數 + 指向本檔案的連結，個別條目的唯一真相源是這裡。

## 輸出格式
- ✅ 建立 / 更新的 QA 記錄路徑（`{TICKET}-qa.md`），測試執行結果摘要（通過 N / 失敗 N / 略過 N）
- 📋 目標路徑下 `index.md` 異動摘要
```
