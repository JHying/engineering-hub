---
name: quiz
description: 從 tech-research 知識庫隨機抽題，以面試考題風格出題（選擇題或簡答題），協助溫故知新、讓眼睛休息。另有 interview 模式：模擬科技大廠面試官深入追問架構、微服務、Spring、Java 底層、高併發實務、ADR 決策復盤，可指定領域；interview design 為多階段 system design 長題模擬。支援獨立呼叫或由 /loop 定時觸發。
version: "1.7.0"
---

# quiz

每次呼叫從 `knowledge/common_KBs/tech-research/` 隨機抽取一個主題，出一道面試風格題目。

| 呼叫方式                       | 說明                                                            |
| -------------------------- | ------------------------------------------------------------- |
| `/quiz`                    | 立即出一題（獨立使用，KB 模式）                                             |
| `/quiz interview`          | 面試官模式：模擬大廠深度面試，每次隨機選領域（見「模式 B」章節）                             |
| `/quiz interview {領域}`     | 面試官模式並指定領域：`架構`/`微服務`/`spring`/`java`/`高併發`/`adr`             |
| `/quiz interview ... {職級}` | 可另指定目標職級 `senior`/`staff`/`architect`（預設 staff），追問強度與評析基準隨之校準 |
| `/quiz interview 參考履歷 ...` | 履歷錨定模式：對話中有履歷/案例時，題目錨定其實際記載出題（見「履歷錨定」章節）                      |
| `/quiz interview design`   | System Design 長題模擬：多階段完整系統設計面試（見「模式 B-D」章節）                   |
| `/loop 30m /quiz`          | 每 30 分鐘自動出一題，session 開始時手動啟動一次即可                              |

兩者互不影響：手動 `/quiz` 不會干擾 loop 計時器。

## 模式判斷

- 無參數、或參數不以 `interview` / `面試` 開頭 → **模式 A（KB 溫習模式）**：執行 Step 1–4
- 參數以 `interview` 或 `面試` 開頭 → 檢查後續參數（可複合出現，順序不拘）：
  - 含 `design` → **模式 B-D（System Design 長題）**：直接執行「模式 B-D」章節
  - 含領域名（`架構`/`architecture`、`微服務`/`microservices`、`spring`、`java`、`高併發`/`concurrency`、`adr`）→ **模式 B** 並鎖定該領域
  - 含職級（`senior`/`staff`/`architect`）→ 設定目標職級（見「目標職級校準」），未指定預設 `staff`
  - 含 `參考履歷`/`resume`，或使用者以自然語言要求以履歷出題 → 啟用「履歷錨定」規則
  - 提及目標公司/職缺 → 以該職缺水準推定目標職級
  - 無其他參數 → **模式 B** 並每次隨機選領域

---

## 模式 A — KB 溫習模式（`/quiz`）

無參數時：讀取 `setting/paths.yml` 取得 KB 路徑，以 timestamp 對 tech-research 檔案數取餘數隨機選題（30 分鐘一區間），依 timestamp 奇偶決定選擇題／簡答題，回答後附解析與來源章節引用。

明細（Step 1–4、輸出格式、範例）見 `references/mode-a-kb-quiz.md`。

---

## 模式 B — 面試官模式（`/quiz interview`）

模擬科技大廠（MANGO 級）資深面試官，依領域（架構設計/微服務/Spring 底層/Java 底層/高併發/ADR 決策復盤，未指定時秒級隨機輪替）出題，依候選人回答品質追問（層數依目標職級 senior/staff/architect 上限），觸及知識邊界即停、換維度或收尾，最後給職級落點評析。

明細（人設、出題領域表、知識來源、ADR 專屬規則、追問機制、職級校準、收尾評析格式、履歷錨定）見 `references/mode-b-interview.md`。

---

## 模式 B-D — System Design 長題（`/quiz interview design`）

面試官人設同模式 B。模擬 45–60 分鐘 staff/architect 級系統設計面試，分五階段（需求澄清→容量估算→高層設計→deep dive→故障與演進）互動，每階段等候選人作答才進下一階段，一題到底，收尾評析含分階段小結。

明細（題目來源、五階段流程表、收尾評析、專屬原則）見 `references/mode-bd-system-design.md`。

---

## 注意事項

- 每次呼叫只出一題，不自動連續出題
- **模式 A 的出題與答題解析**只能引用當題 tech-research 檔案的實際記載；模式 B 依其「知識來源」規則不受此限
- **答題後的延伸討論**（使用者追問、概念延伸、比較不同技術）不受 KB 限制，可使用通用技術知識回答；若討論內容值得記錄，詢問是否執行 `/update-kb`
- 由 `/loop` 觸發時行為與手動呼叫完全相同，無需特殊處理
