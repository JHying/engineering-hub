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

## 2026-07-28 有工具的子代理對單點文字漂移有天生抵抗力，煙霧測試注入漂移沒那麼容易
- 情境：執行 demo_KBs 端到端煙霧測試（待辦 project_pending-demo-smoke-test.md）的驗收步驟，故意在 update-kb 的 qa-records 模板改錯目標路徑，想證明煙霧測試抓得到。連續 3 次才成功定位問題：第 1 次是自己手動轉抄 prompt 時留了矛盾線索；第 2 次發現模板裡同一路徑字串寫死在 5 個地方，改 1 處子代理跟多數；第 3 次改成單一來源後，子代理仍靠 Read/Glob 探索到目標資料夾已有既有檔案，用環境證據覆蓋了寫錯的文字指示。
- 教訓：這類「子代理能自己探索環境」的抵抗力，代表煙霧測試若鎖定「已有既有內容的 KB 類型」測路徑漂移，很難测出真陽性；2026-07-05 那次真實 bug 性質上更可能是 Step 2 路由表整條缺漏（子代理根本沒被建立），不是「建立了但寫錯路徑」。
- 以後怎麼做：往後要驗證漂移偵測能力，優先測「全新 KB 類型第一次建立」（無既有檔案可比對）或「Step 2 路由判斷本身」，不要只測「已有內容的資料夾路徑寫錯」這種子代理容易自救的情境。

## 2026-07-28 統一資訊來源時漏查 governance/ 交叉引用,製造出新的規則衝突
- 情境:健檢優化把 model-dispatch.md §0 價格表改成「一律觸發 claude-api skill 查」,追加 diagnosis.md 時才發現其一-1 明寫「主線不觸發 claude-api skill(一次灌數萬 token)」——同一件事兩份 governance 檔方向相反,第一版改法直接抵觸既有實測教訓。
- 教訓:「消除重複來源」的修改本身最容易產生新矛盾;governance/ 各檔互相引用,單看被改的那份會覺得沒問題。
- 以後怎麼做:改 governance/ 任一檔的規則前,先 grep 其他 governance 檔與 CLAUDE.md 對同一主題(關鍵字如 skill 名、檔名、規則名)的引用,把所有引用點列出來一起改;和 2026-07-05「guideline 改版後 roles/flows 沒同步」是同一類病,適用範圍擴大到 governance/ 彼此之間。

## 2026-07-28 CHANGELOG 條目與實作脫鉤:寫了條目但變更從未落地
- 情境:quiz CHANGELOG 存在 [1.4.0]/[1.5.0](2026-07-14)兩條目,描述高併發領域、% 6 輪替、履歷強制章節;git 全歷史查證後確認這些變更從未出現在任何提交過的 SKILL.md,僅 frontmatter 版本號被升過;履歷功能後來以「選用觸發」形式實裝卻沒記條目。拆檔時新條目撞號 1.5.0 才暴露。
- 教訓:CHANGELOG 先行(或改動被還原)而 SKILL.md 沒跟上時,單看任一檔都正常;版本號、CHANGELOG、實際內容三者可以各自漂移。
- 以後怎麼做:改 skill 時核對「frontmatter version = CHANGELOG 最新條目 = 內容實況」三點一致才算完;發現歷史條目與實作不符,在該條目下加「⚠️ 校正」註記保留版本號,不刪改原文。

## 2026-08-05 誤把「主線 session 內角色扮演」當成「per-role 查表派工」
- 情境:tech-research 筆記聲稱「SDLC 六角色仍靠動態查表選 model,無固定綁定」,並據此推導「已有動態彈性可犧牲」的結論；實際查 roles/*.md 與 skills/sdlc-agent/references/pipeline-stages.md 才發現 SDLC 角色是主線 session 用 Skill 工具直接讀文件換人設執行(非 Agent 工具派發),角色本身的模型無條件 inherit session,model-dispatch.md §1 的查表只用在角色內部再派發子任務時,不是角色本身。
- 教訓:「XX 機制已存在,所以不需要 Y」這種會拿來否決提案的論證,前提「XX 存在」不能只轉述前一份研究筆記的敘述,要追到實際執行路徑(這裡是 skill/角色定義檔)才能核實。
- 以後怎麼做:任何「現有機制已覆蓋 X」的論證要寫入 KB 或用來否決提案前,先讀該機制的實際定義檔核實是否真的存在;confirm 後才寫入,不能只憑先前研究筆記帶過。

## 2026-08-05 Explore 留空 model 時,inherit 主線但 capped at Opus——§3「不留空」規則的代價比想像中高
- 情境:對 33 筆歷史 SDLC 子任務派發做語意抽查,發現 2 筆 `Explore` 派發(session 841a8b、4e0161)`model` 參數留空,實際跑的是 `claude-opus-5`,而當時主線實跑 `claude-fable-5`(Fast mode,底層即 Opus 等級)。一度誤判為「Explore 預設值是 opus,跟 haiku/inherit 假設都矛盾」的系統性缺陷;派 claude-code-guide 查官方文件(code.claude.com/docs/en/sub-agents.md)後確認:內建 Explore 的 model 行為就是「inherit 主線,但 capped at Opus」,§0 原本查證的「預設 inherit」沒有錯,不需訂正。真正原因是這兩次派發違反了既有 §3「每次 Agent 呼叫都明寫 model 參數,不留空」規則,撞上主線剛好在 Opus 等級的情境。
- 教訓:「假設某規則有缺口」之前,要先查官方文件排除「規則本身沒錯、只是沒照做」的可能性,不要看到異常數據就急著論斷是制度缺口;Explore 型別不寫 model 的代價比其他型別更不對稱——主線若在 Fast mode/Opus 層級,留空就是白白繼承 Opus,不是單純「繼承一個普通模型」。
- 以後怎麼做:所有 Explore 派發一律顯式帶 `model: haiku`(已寫入 model-dispatch.md §1 備註),不依賴 inherit;主線若切換到 Fast mode/Opus 層級工作時,對所有子任務派發加倍留意是否漏填 model 參數。

## 2026-08-05 worker-mechanical.md 與 model-dispatch.md §1 表的 model 記載不一致,以角色定義檔為準
- 情境:語意抽查發現凡派發 `worker-mechanical` 的任務全部實跑 `sonnet`,但 §1 表「批次機械修改(套用已定案的模式)」那列寫 `haiku`;查 `.claude/agents/worker-mechanical.md` frontmatter 確認是 2026-07-12 建檔時就定案 `model: sonnet`(理由:該角色涵蓋依模板生成文件、pending 草稿寫入等需要一定推理的工作,haiku 恐不夠穩),但 §1 表當時沒有同步更新,造成兩份 governance 檔案自 2026-07-12 起就互相矛盾超過三週未被發現。
- 教訓:新增 `.claude/agents/*.md` 定義檔、且該角色對應到 §1 表既有的某一列時,建檔當下若決定用跟表不同的 model,必須同步改表,否則兩者各自看都「沒問題」,矛盾只在交叉比對時現形(跟 2026-07-28「governance 交叉引用」是同一類病)。
- 以後怎麼做:§1 表已改為 sonnet 對齊 worker-mechanical.md 實際值(2026-08-05);往後新增/修改 `.claude/agents/*.md` 的 model/effort,必須同一次順手比對 §1 表是否有對應列,不一致就一起改。

## 2026-08-05 新增 .claude/agents/worker-security-review.md(記錄,非踩雷)
- 情境:比對 GitHub 上多模型編排專案(pilotfish)的宣告式綁定做法,評估後認為「安全審查/滲透測試/認證授權相關實作」這列風險特徵適合建專屬 agent 檔——漏填 model 時會退回繼承主線,主線若剛好在便宜模式,資安工作就被打折;不像 Explore 那類內建型有「建了新代理不保證被用」的弱點,因為 §1 表寫的 subagent_type 本來就會被直接引用,沒有跟誰搶戲的問題。同一輪也評估了 PreToolUse hook 強制檢查方案,查證後發現業界幾乎無此用法先例、且 Agent 工具 model 參數的 schema 本身有記錄在案的版本間 regression(issue #31027、#44412),風險大於效益,決定不做,只做本項與 prompt-templates.md 模板 1 的警告加強。
- 教訓:同一輪派工優化裡,「建專屬 agent 檔」跟「建 hook 強制檢查」看似都是「機制取代記憶」的同類手段,但前者只是宣告式綁定(業界成熟做法、風險低),後者是攔截式驗證(業界罕見、疊加上游 schema 不穩定的風險)——比較兩個手段前要先查證各自的先例與穩定性,不能因為「精神類似」就等價視之。
- 以後怎麼做:`worker-security-review`(opus, high, tools: Read/Edit/Write/Grep/Glob/Bash)用於安全審查/滲透測試/認證授權相關實作,§1 表已同步引用;之後新增其他高風險/高代價不對稱的派工類別時,優先評估宣告式 agent 檔,不要跳過evaluate直接想 hook。

## 2026-08-08 repo 改名後,`setup-host.ps1` 的 skills junction 沒跟著修,使用者以為「跑過就該裝好」
- 情境:repo 從 `D:\Work\knowledge-hub` 改名為 `D:\Work\engineering-hub` 後(近期 commit「rename and optimize」),使用者稱已執行過 `setup-host.ps1`,但 Skill 工具仍回報 `Unknown skill: quiz`。查 `~/.claude/skills` 實際是 Junction,但 `Target` 仍是舊路徑 `D:\Work\knowledge-hub\skills`(該目錄已不存在)。原因是 `Connect-Link` 函式只檢查「連結是否已存在(`LinkType -eq 'Junction'`)」就 skip,完全不比對 `Target` 是否等於目前 repo 路徑,所以改名後在新路徑重跑腳本也修不好舊連結。
- 教訓:「使用者說已經跑過 setup 腳本」不等於「連結現在是對的」——idempotent 腳本若只判斷「連結存在」而不驗證連結內容,重跑無法自我修復,需要額外檢測。
- 以後怎麼做:懷疑 skill/memory 找不到但使用者確認執行過 setup 時,先用 `Get-Item $link -Force` 讀 `.Target` 跟目前 repo 路徑比對,不要只信「跑過了」的說法;`setup-host.ps1`/`.sh` 的 `Connect-Link`/`link` 已於同日補上 Target 比對、不符就自動 relink(不再只判斷連結是否存在),重跑腳本即可自我修復。
