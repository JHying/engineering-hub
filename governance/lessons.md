# 踩雷教訓(追加式,格式見 maintenance-protocol.md §3)

## 2026-07-05 subagent 的工具集和主線不一樣
- 情境:對抗審查的 subagent 用 ToolSearch 查不到 TaskCreate,判定它不存在;但主線同 session 用過該工具。
- 教訓:TaskCreate 等任務工具是「延遲載入」且 subagent 環境可能沒有;工具存在與否要在**自己的環境**驗證,不能替別的環境下結論。
- 以後怎麼做:規則裡引用工具時,附「先 ToolSearch 載入;不可用時的替代做法」;審查他人環境的工具可用性一律標「存疑」。

## 2026-07-05 guideline 改版後,引用它的 roles/flows 沒同步
- 情境:REVIEW_GUIDE 第五節 2026-07-03 改版為「CI 覆蓋確認」,但 role-reviewer.md 仍寫「不重複檢查」、flow-reviewer.md 仍用舊章節名,導致 /code-architect 在 review 階段實際上會被跳過。
- 教訓:規範檔改版時,引用它的角色/流程檔不會自己更新;單看任一檔都「沒問題」,矛盾只在交叉對照時現形。
- 以後怎麼做:改 guideline/ 任何檔後,grep `roles/` 與 `role-flows/` 中對該檔(或其章節名)的引用,逐處同步;skill 宣稱與被呼叫 skill 介面同理。

## 2026-07-05 Glob 命中數 ≠ 實際檔案數
- 情境:主線裸 `Glob *` 顯示 890 筆命中,寫進診斷;審查者用 find 實測 knowledge/ 僅約 345 檔。
- 教訓:Glob 命中數受 pattern 與隱藏目錄影響,直接當「repo 規模」引用會失真。
- 以後怎麼做:要引用檔案數量,用 `find {目錄} -type f | wc -l` 對具體目錄實測;或改用相對描述(「遠超單次可讀量」)。
