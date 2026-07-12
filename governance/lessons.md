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

## 2026-07-07 「完全靜默」的 Session 初始化讓使用者以為規則沒生效
- 情境:07-05 optimize 把每次開場問兩題改成「一致就完全不說」,結果使用者完全看不到任何回饋,回報「claude.md沒生效」——其實是規則有跑,只是靜默到無法察覺。CLAUDE.md 裡寫死的預設路徑 `D:\Work\engineering-hub` 也已過時(KB 已搬到本 repo 自身),進一步加深不一致的印象。
- 教訓:省 token 的「完全靜默」跟「使用者能感知規則有在運作」是兩個互斥目標;規則檔裡若寫死具體數值(路徑等),一旦實際設定變動就會跟著失真,要讓後續維護者能一眼看出兩邊要一起改。
- 以後怎麼做:例行檢查類規則至少留「開場一行回報」而非完全無輸出;規則文字避免寫死會變動的具體值,改用「以 {設定檔} 實際值為準」的動態描述。

## 2026-07-08 REVIEW_GUIDE 版本註記與 skill CHANGELOG 的 Context 段落常洩漏真實業務資訊
- 情境:code-architect 2026-07-07 更新(尚未 commit)裡,REVIEW_GUIDE.md 版本註記寫「來源:封盤結算流程實務案例」(博弈網域詞彙),CHANGELOG.md [2.5] Context 直接寫真實類別名,SKILL.md 範例也複製了真實 bean 名稱(拼字帶真實命名的 typo)——同一份 CHANGELOG 較早版本([2.3])卻已正確用 Foo/Bar 佔位符。
- 教訓:CLAUDE.md 已明文要求 SKILL.md/CHANGELOG.md 去識別化,但只靠動筆當下自覺,沒有寫完後的機械檢查;「Context/起因」段落與版本註記為保留案例真實感最容易被跳過,而 update-kb 的去識別化檢查清單(regex+語意雙軌掃描)適用範圍只涵蓋 common_KBs/ADRs 與 tech-research,guideline 與 skill CHANGELOG 的直接編輯完全不經過這道檢查。
- 以後怎麼做:改任何 skill 的 SKILL.md/CHANGELOG.md 或 common_KBs/guideline/ 後,展示 diff 給使用者確認前,先對新增的「Context/起因」段落與版本註記,逐字套用內容限制規則判準(不認識此專案的工程師能否憑技術知識理解)檢查一次。

## 2026-07-12 新增 .claude/agents worker 定義檔(記錄,非踩雷)
- 情境:使用者主線 session 為 sonnet xhigh,子代理繼承 xhigh,機械性派工也燒高推理預算;Agent 工具本身無 effort 參數。
- 教訓:固定低 effort 的派工角色只能靠 `.claude/agents/*.md` 定義檔(model-dispatch §3 既有結論,本次落實)。
- 以後怎麼做:批次機械修改/模板套用派 `worker-mechanical`(sonnet, low);read-back 驗證/搜尋定位派 `worker-readback`(haiku, low);兩檔隨 repo 攜帶(`.claude/agents/`),新主機執行 `setting/setup-host.ps1|.sh` 接線 memory 與 skills。
