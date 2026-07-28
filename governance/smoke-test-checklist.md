# Skill 生態系煙霧測試 Checklist

> 目的：`my-work-agent`／`update-kb` 等 skill 彼此呼叫時，orchestrator 對被呼叫 skill 的描述容易跟該 skill 實際介面/輸出路徑「各自看沒問題、合起來才現形」的漂移。單一 skill 的單元檢查抓不到這類問題，只有真的跑一次跨 skill 的鏈路才會現形。
> 起源：2026-07-05 skill 體檢發現 `update-kb` 缺 QA 路由、`my-work-agent` 誤述 `code-architect`、`diagram` 路徑對不上（詳見 `governance/lessons.md`）。本 checklist 回應待辦 `project_pending-demo-smoke-test.md`。

---

## 何時要跑

- 修改任何 `skills/*/SKILL.md`（或 `skill.md`）本體規則後
- 修改任何 `skills/update-kb/templates/*.md` 後
- 修改任何 `role-flows/*.md` 或 `roles/*.md` 後
- 覺得「這個改動應該不影響別的 skill」但改動涉及**檔案路徑、路由規則、或另一個 skill 的呼叫方式**時——這種「應該沒事」的直覺正是過去踩雷的來源，優先跑一次
- 定期健檢（無明確觸發事件時，建議每累積 5～10 個 ticket 或每季至少一次）

## 固定測試夾具

- **測試票**：`demo_KBs/specs/DEMO-001.md`（訂單建立功能）+ `specs/impls/DEMO-001-impls.md`——PM/SA/BACKEND 產出已固定存在，不需重建
- **目標 KB**：`demo_KBs`（示範用，無真實原始碼，Code Review／QA 內容為合成但格式真實的資料，不代表真實審查結果）

## 執行步驟

1. **選定要驗證的路由**：依「這次改了什麼」決定要跑哪幾條（不需每次全跑八條 KB 類型路由，跑跟改動相關的即可）
2. **呼叫 `/update-kb`**，Mode B，KB 選 `demo_KBs`，內容針對 DEMO-001 給合成但格式真實的 Review/QA/其他 KB 類型資料（範本見 2026-07-28 執行紀錄，下方）
3. **驗證產出落地**：
   - 檔案是否真的寫進 `demo_KBs/{對應目錄}/`（不是誤寫進其他專案 KB）
   - `MASTER_INDEX.md` 對應章節是否同步（依 2026-07-28 起的新規則：**只放筆數 + 連結指標，不逐條複製進 MASTER_INDEX**——若子代理把整條記錄複製進 MASTER_INDEX，代表 Step 4-1 或對應模板檔的指示又跑掉了）
   - 個別 index.md（`review-history/index.md`、`qa-records/index.md`）是否正確新增/更新條目
4. **驗證 `/code-architect`、`/diagram` 的路徑聲明**：不需要在 demo_KBs 跑（無真實原始碼），改為對照 `my-work-agent` skill.md 裡對這兩個 skill 的行為描述，跟該 skill 自己 SKILL.md 的實際輸出規則逐句核對；或直接引用最近一次真實專案 pipeline 執行的實測結果作為佐證（見下方 2026-07-28 紀錄）

## 驗收標準：故意注入漂移，確認測試會抓到

不能只驗證「正常路徑會過」，必須驗證「壞掉時測試真的會失敗」，否則測試本身可能是假陽性：

1. 找一個現有路由規則（例如某個 Step 4-1 檢查清單項目、或某個 KB 類型的路由關鍵字），暫時刪除或改錯
2. 重跑上方「執行步驟」對應那條路由
3. 確認：產出**沒有**正確落地、或 MASTER_INDEX 沒有被正確同步——測試要能感知到壞掉，不能悶不吭聲地「看起來也沒事」
4. 還原注入的漂移，重跑一次確認恢復正常

## 2026-07-28 執行紀錄（首次執行，含意外發現）

**跑的路由**：Review History KB + QA Records KB，對象 DEMO-001。

**結果**：兩條路由都正確把檔案寫進 `demo_KBs/review-history/`、`demo_KBs/qa-records/`，沒有誤寫其他 KB——證實「update-kb 缺 QA 路由」這個 2026-07-05 的舊 bug 目前**沒有**復發。

**意外發現的真實漂移**（不是故意注入的，是這次執行途中自然發現）：
- 某專案 KB 的 `MASTER_INDEX.md`「QA Knowledge Base」表格漏了最新一筆 QA 記錄——追到 `update-kb` Step 4-1 的同步檢查清單從未列過「QA Records KB」這一項，只列 PM/RD/SRE/Review History 四類，是清單本身的設計缺口，已修正（`update-kb` CHANGELOG `[1.15]`）
- 修正過程再發現 MASTER_INDEX 逐條複製 Review History/QA 條目的舊做法本身有問題：與各自 `index.md` 重複維護且已經漂移不同步（`review-history/index.md` 18 筆，MASTER_INDEX 當時只有 9 筆）、密集儲存格違反「表格欄位可讀性規則」、且 MASTER_INDEX 是每個 role 起手必讀檔案，逐條累加會讓它隨專案歷史無上限變胖——已改為「MASTER_INDEX 只放指標」（同一次 `[1.15]`），並回頭遷移了某專案 KB 既有 10 筆 QA 記錄到新建的 `qa-records/index.md`

**驗收（注入漂移）**：三次嘗試才成功注入出真正的失敗，過程本身是比「一次成功」更有價值的發現，見下方「驗收紀錄」與方法論註記。

**佐證 `/code-architect`／`/diagram` 路徑聲明**：2026-07-28 同日稍早在某真實專案 KB 跑過一次完整 `my-work-agent` pipeline，`/code-architect` 產出的違規報告格式與 `my-work-agent` skill.md 描述一致，`/diagram` 實際寫入路徑 `source-codex/services/{service}/flow-diagram-{TICKET}.md` 與宣稱一致——當次為真實跑法非本 checklist 產出，列於此作為同日交叉佐證。

**補測 PM KB 路由**（同日稍後，使用者追問「PM/SA/BACKEND 產出也要一起測試，而且跟 Review History、QA Records 一樣有 index 問題」）：比對後確認某專案 KB 的 `MASTER_INDEX.md` PM Knowledge Base 區塊確實有相同問題，且更嚴重——逐條累加的「已建立 Spec」「已建立 Impl」表格單一儲存格塞入 3000+ 字元完整決策歷程。修正方式同一套：新建 `specs/index.md` 為唯一真相源、`templates/pm-spec.md` 新增 Step D 維護該索引、MASTER_INDEX 改為只放指標（詳見 `update-kb` CHANGELOG `[1.15]`）。

修正後對 `demo_KBs` 執行一次真實驗證（非本身即為 spec 首次建立，而是既有 DEMO-001 spec 的技術澄清補充，藉此驗證 Step A 更新既有 spec 時，Step D 不會誤觸發重複列）：子代理正確在 `specs/DEMO-001.md` 補上澄清段落，`specs/index.md` 與 `MASTER_INDEX.md` PM 區塊皆維持原樣、未產生任何重複列或逐條複製——驗證通過。過程中子代理主動發現我在測試指示中誤植的 AC 編號（誤稱 AC3，實際應為 AC2），依原始碼核實後自行修正並回報，屬子代理善用工具自我修正的又一例證（見下方「方法論註記」）。

---

## 驗收紀錄

| 日期 | 注入的漂移 | 預期結果 | 實際結果 | 已還原 |
|------|-----------|---------|---------|--------|
| 2026-07-28（第1次） | 手動組 subagent prompt 時把「目標路徑」改成錯的 `qa/`，但同一個 prompt 的「必讀文件」行手滑仍寫對的 `qa-records/qa-format.md` | 子代理應寫進錯的 `qa/` 目錄 | 子代理寫進正確的 `qa-records/`——測試無效，因為漂移只存在於「我手動轉抄的 prompt」，不是真的模板漂移；且 prompt 本身自相矛盾給了子代理修正的線索 | 是（清掉測試檔案） |
| 2026-07-28（第2次） | 直接改模板檔 `templates/qa-records.md` 的「## 目標路徑」欄位為 `qa/`，改叫子代理自己讀模板檔執行、明確要求不要自行修正 | 子代理應寫進錯的 `qa/` 目錄 | 子代理仍寫進 `qa-records/`——查證後發現模板檔裡 `qa-records/` 這個字串**獨立寫死在 5 個地方**（開頭說明句、必讀文件、Step C ×2、輸出格式），我只改了 1 處，子代理面對 5:1 的內部矛盾合理地跟多數；**這本身是一個真的技術債（路徑非單一來源），已修正** | 是（清掉測試檔案 + 修正模板單一來源化） |
| 2026-07-28（第3次） | 路徑已單一來源化後，只改「## 目標路徑」這唯一一處為 `qa/` | 子代理應寫進錯的 `qa/` 目錄 | **仍然寫進 `qa-records/`**——推測子代理有 Read/Glob 等工具，執行時探索到 `{$PROJECT_KB}/qa-records/` 底下已有 `qa-format.md`、`DEMO-001-qa.md` 等真實檔案，`qa/` 目錄則不存在，用環境證據覆蓋了文字指示 | 是（清掉測試檔案 + 還原模板） |

### 方法論註記（三次嘗試的真正結論）

沒有真的成功注入出「子代理寫進錯誤路徑」這個失敗模式——但過程證明的事更有價值：**有工具存取能力的子代理，對單點的文字路徑漂移有天生抵抗力**，只要目的地資料夾已有可比對的既有檔案，子代理會用環境證據自我修正，不會盲從一句寫錯的指示。這代表：

- 2026-07-05 那次「update-kb 缺 QA 路由」的真實舊 bug，性質上更可能是 **Step 2 路由表整條缺漏**（根本沒被判定要派這個 KB 類型，子代理從未被建立），而不是「子代理被建立但寫錯資料夹」——前者子代理沒有機會用環境證據自救，後者有
- 這份 checklist 若要測試「路徑寫錯」這類漂移，對**已有既有內容的 KB 類型**（如本例 qa-records）意義有限，天生會被子代理帶工具探索的能力掩蓋；更該測試的是**全新 KB 類型第一次建立**（無既有檔案可比對）、或 **Step 2 路由判斷本身**（決定要不要派工，而非派工後寫哪裡）
- 對「單一來源 vs 多處寫死同一個值」本身，這次意外驗證了單一來源化的價值不在「測試好不好注入漂移」，而在**真的手動編輯時**（人或 AI）更不容易改一半漏一半——第 2 次嘗試已經是真實案例
