---
date: 2026-08-03
keywords: 多模型編排、模型調度、Claude Code、成本優化、SDLC pipeline、知識庫治理
---

# Claude Code 多模型編排層與知識庫 + SDLC Pipeline 系統定位比較

## 問題背景

評估自有 Engineering Hub（知識庫 + SDLC pipeline 系統）與公開 GitHub 專案 pilotfish（多模型編排層，
專門針對 Claude Code 做成本路由）的用途與長項比較。Engineering Hub 管理多專案知識庫、驅動
PM → SA → CONSULTANT → BACKEND → REVIEWER → QA 六角色 SDLC pipeline、並掛載一組工程 skill；
pilotfish 只做一件事：依任務性質把工作路由到不同模型層級，不管知識庫、不管 SDLC 流程。兩者非競品，
而是互補——一個管知識與流程，一個管模型路由——本次研究目的是找出 pilotfish 的模型調度設計中，
有哪些可以回饋到 Engineering Hub 既有的模型派工規則。

## 研究結論

**pilotfish 核心設計**：三層架構——`settings.json` 定義主編排器模型與自動降級鏈、`agents/*.md`
讓八個角色代理各自綁定固定模型層級、`CLAUDE.md` 用角色名（而非模型名）撰寫委派規則，模型棄用時
只需改一行 agent 定義即可全面生效。八個角色分工：

- Scout（haiku，唯讀查詢）
- Plan-verifier（opus，唯讀審查計劃）
- Mech-executor（sonnet，機械性重構/測試/文件）
- Executor（sonnet，需判斷的實作）
- Security-reviewer / Security-executor（opus，安全工作專屬路由，避免低成本模型誤觸發安全分類拒絕）
- Verifier（opus，獨立新鮮 context 驗證結果，避免自我審查偏誤）
- Explore（haiku，覆蓋內建 Explore）

有實測 benchmark 佐證成本節省：官方基準顯示「編排器配合次階模型工作者」可達到 96% 全高階模型效能，
成本僅 46%；社群實驗回報 58–74% 節省區間。安裝機制為冪等，只寫入全域 config，不侵入專案內容。

**與 Engineering Hub 現況對照**：

- Engineering Hub 的 `governance/model-dispatch.md` 是對應的模型調度規則，但形式不同——現況是
  「規則表 + 主線人工查表後在 Agent 呼叫顯式填 model」，只有兩個機械性角色
  （`worker-mechanical`＝sonnet/low、`worker-readback`＝haiku/low）做了 `.claude/agents/*.md`
  frontmatter 硬綁定；SDLC 六角色（PM/SA/BACKEND/REVIEWER/QA/SRE）仍靠動態查表選 model，
  無固定綁定。（2026-08-05 校正：此句前提不準確。SDLC 角色是透過 Skill 工具在主線 session 內
  直接執行——讀角色/流程定義檔、換人設繼續對話，並非透過 Agent 工具派發成 subagent；因此「角色
  本身」用什麼模型，是無條件繼承當前 session 的模型，並不存在對派工表的查詢動作，談不上「動態
  查表選 model」。派工表的查表機制實際發生在角色執行過程中、若需要再往下派發子任務（例如找程式碼、
  批次修改）時，屬於子任務層級，跟「角色本身」是兩個不同層級的事，不能混為一談。）
- Engineering Hub 已有「產出不自驗」規則（read-back 用 fresh-context subagent、高風險判斷取
  第二意見），對應 pilotfish 的 Plan-verifier / Verifier 獨立驗證概念——這塊已覆蓋，非缺口。
- Engineering Hub 已用模型別名（sonnet/opus/haiku）而非硬編碼模型 ID，避免棄用時要全面改寫——
  這塊已對齊 pilotfish 的做法。
- 缺口：
  1. 無自動降級鏈設計，模型不可用時只能靠人工升降級路徑。
  2. 無安全工作專屬路由規則，安全審查/實作沒有強制走最高模型層級的保證。
  3. 無成本節省的量化實測數據佐證派工決策，全憑經驗判斷。
  4. SDLC 高頻角色未做 frontmatter 硬綁定，每次仍需人工判斷查表，增加認知負擔。
     （2026-08-05 校正：同上，角色本身並不存在「每次人工判斷查表」這個動作——角色是無條件繼承
     session model；真正會發生人工查表判斷的，是角色執行過程中再往下派發子任務的那一刻，缺口
     描述的認知負擔對象應更精確為「子任務派發時的查表判斷」，而非角色本身的模型選擇。）

## 待評估的優化方向（尚未落地，供未來參考，非最終決策）

1. 考慮將 SDLC 六角色也比照 `worker-mechanical` 模式做 `.claude/agents/*.md` frontmatter 綁定，
   減少每次動態查表的認知負擔。
2. 考慮補一條安全工作專屬路由規則（安全審查/實作一律走最高模型層級）。
3. 是否需要自動降級鏈設計，取決於實際遇到模型不可用的頻率，非立即急需。
4. 可考慮在 `lessons.md` 累積派工升降級的量化案例（例如「原訂 X 模型失敗兩次升級到 Y」的紀錄），
   逐步建立自己的成本/品質實證基礎，而非只憑經驗判斷。

## 決策結果（2026-08-05）

延續上節四項優化方向，逐項決策如下：

1. **SDLC 六角色（PM/SA/CONSULTANT/BACKEND/REVIEWER/QA）比照 `worker-mechanical` 模式做
   frontmatter 硬綁定** — 不採用。
   pilotfish 的八角色是按「工作性質」分工（唯讀查詢/機械重構/需判斷實作/安全），任務同質、
   每次調用性質相近，固定綁定才划算；Engineering Hub 的 SDLC 六角色是按「開發流程階段」劃分，
   同一角色任務難度落差極大（例如同一角色這次可能是簡單任務、下次是複雜跨服務任務），固定綁定
   等於放棄現有依任務難度動態選模型的彈性。（2026-08-05 校正：「現有依任務難度動態選模型的彈性」
   這句前提有誤——角色本身目前是無條件繼承 session model，角色層級並沒有逐次查表動態選模型的
   機制在運作，動態查表只發生在角色內部再往下派發子任務時；因此不能算「角色層級已有等效機制」。
   但決策結論不受影響：SDLC 角色任務異質性大、同一角色任務難度落差極大，本來就不適合固定綁定，
   這個核心理由不需要依賴「已有動態選模型彈性」這個前提也成立，故維持不採用固定綁定的結論。）
   現有模型別名機制（sonnet/opus/haiku）已達到「棄用時改一行」的效果，這條增量價值只剩「省查表
   認知負擔」，不足以抵銷犧牲彈性的代價。兩者是不同座標軸的分工邏輯，生搬硬套是偽對齊。

2. **安全工作專屬路由規則（安全審查/實作一律走最高模型層級）** — 採用，已落地。
   安全審查/實作出錯代價遠高於一般任務，值得保底最高模型層級；落地成本極低（規則表加一列）；
   跟既有「高風險判斷用第二意見」邏輯一致，是同一種「風險優先於成本」邏輯的延伸，非新哲學。
   即使當下沒有實際踩雷案例佐證，仍屬合理超前部署，因為安全工作的高風險屬性是明確既知、
   非假設性的。
   落地內容：`governance/model-dispatch.md` §1 派工表新增一列「安全審查/滲透測試/認證授權相關
   實作 → general-purpose / opus / high」，並加註安全相關工作一律走最高模型層級、不適用其他列的
   省成本邏輯。落地日期 2026-08-05。

3. **自動降級鏈設計（模型不可用時）** — 不採用，維持研究當時「非立即急需」的結論。
   現有踩雷記錄中沒有「模型不可用」的案例，單人低頻使用場景不像高併發服務情境容易撞限流；
   現有「同一子任務連錯升級」的人工升降級路徑已覆蓋「模型能力不足」，「不可用」是另一種故障
   模式，目前沒證據是真痛點；設計這條需要額外定義「什麼算不可用」「降級到哪層」，違反「不為
   假設性情境設計」的原則。等真的遇到模型不可用的實際案例再回頭評估。

4. **在踩雷教訓記錄中累積派工升降級的量化案例** — 採用，已落地，但採輕量化做法。
   現有踩雷記錄條目都是質性教訓，沒有「原訂 X 模型失敗兩次升級到 Y」這種數值案例；累積後能讓
   「要不要升級」從經驗直覺變有實證支撐；落地成本幾乎零——升級路徑本來就會發生，只是多記
   一筆，是既有流程的自然延伸。不另建機制或檔案，避免變成累積但沒被複用的死內容。
   落地內容：`governance/model-dispatch.md` §5 升降級路徑，於既有段落後加一句提醒：升級發生時
   同時在踩雷教訓記錄記一筆（任務類型、原模型、升級後模型、失敗原因），供之後校準派工表起始
   層級。落地日期 2026-08-05。

### 補充稽核（2026-08-05）：子任務層級查表的格式合規性

延續上方「角色層級無條件繼承 session model、查表只發生在子任務層級」這個修正後的前提，額外做了
一次歷史稽核：掃描本機 6 個曾執行過 SDLC 角色任務的歷史 session 逐字稿，共找到 33 次角色內部
子任務的 Agent 派發，結果 100% 都明確指定了 model 參數（無留空繼承案例），格式面符合
`model-dispatch.md` §3「顯式指定 model 與 effort」的要求。

稽核範圍限制：本次稽核只驗證「有沒有明確填 model」的格式合規，**未驗證**「填的 model 是否語意上
對應派工表 §1 正確的那一列」（例如某次子任務性質其實是「找檔案」卻填了較高階模型而非應對應的
輕量模型，這種語意層級的錯配不會被本次稽核抓到）。如需更強的驗證信心，需要對抽樣案例逐一做語意
核對，目前尚未執行，不宜將本次稽核結果解讀為「派工表已驗證有效」。

## 第二輪稽核與落地（2026-08-05）

延續「補充稽核（2026-08-05）」點出的稽核範圍限制——當時只驗證 33 次子任務派發「有沒有填 model」
的格式合規，未驗證「填的 model 語意上是否對應派工表正確的那一列」。本節記錄補做語意層級抽查後
的結果、由此衍生的一項調研（是否該用機制取代人工記憶），與已落地的優化。

### 33 筆歷史派發的語意層級抽查結果

逐筆比對 33 次歷史派發的實際任務內容與 `governance/model-dispatch.md` §1 表，依任務性質分類比對
選用的 model 是否正確——不只是「有沒有填」，是「填的對不對」。結果：27 次符合、4 次不符合、
2 次屬表未涵蓋的任務性質（非錯誤，任務性質介於既有分類之間，留供之後補列參考）。

不符合的 4 次拆成兩組成因：

- **2 次：自訂 agent frontmatter 與派工表矛盾。** `worker-mechanical` 的 `model: sonnet` 與 §1
  表當時登記的 haiku 不一致。查證後確認 sonnet 是該角色建檔時的定案（理由：角色涵蓋依模板生成
  文件、pending 草稿寫入等需要一定推理的工作），但派工表沒同步更新，兩份 governance 檔案矛盾多週
  未被發現。已決定以角色定義檔為準，訂正派工表。
- **2 次：內建 `Explore` 留空 model，實跑 Opus。** 一度誤判為「Explore 預設值是 opus」的系統
  缺陷，查證官方文件（code.claude.com/docs/en/sub-agents.md）後確認：內建 Explore 留空 model 時
  的正確行為是「inherit 主線模型，但 capped at Opus」，這是文件記載的既有行為，不是新發現的缺陷。
  真正原因是這兩次派發違反了既有規則「每次 Agent 呼叫都明寫 model 參數，不留空」，恰好撞上主線
  當時在 Opus 等級的 Fast mode。修正認知後，強化了既有規則的警告文字，而非訂正原本就正確的官方
  行為記載。

### PreToolUse hook 可行性與業界先例調研

由上述第二組成因衍生出一個問題：要不要用 Claude Code 的 PreToolUse hook，在工具呼叫層級攔截
「派發內建 inherit 型 agent（如 Explore）卻沒填 model 參數」的呼叫，用機制取代人工記憶。這跟
本篇筆記原本比較的對照專案（pilotfish）的宣告式綁定是不同流派：**宣告式綁定 vs 攔截式驗證**。

調研結論：

- 技術上可行：PreToolUse 能讀到完整 tool_input，可用 `permissionDecision: 'deny'` 擋下呼叫
  （不是靠 exit code），但 matcher 只能比對工具名稱，組合條件需寫在 hook 腳本邏輯內。
- 業界先例幾乎沒有：社群公認的 hooks 範例庫（disler/claude-code-hooks-mastery，約 3.9k star）的
  PreToolUse 範例全部是危險指令攔截、敏感檔案保護、secret 掃描類，沒有「派發參數完整性檢查」這個
  用途。唯一算對得上的專案（tzachbon/claude-model-router-hook，約 58 star）刻意選擇 warn（提示）
  而非 deny（強制擋）。
- 關鍵風險：Claude Code 官方 repo 有記錄在案的 issue（#31027、#44412），顯示 Agent/Task 工具的
  model 參數 schema 在不同版本間曾經整個消失過，也有 hook 改寫 model 值被靜默忽略的案例——代表
  這塊 schema 本身還不穩定，建立強制攔截機制的維護成本與版本風險偏高。
- **決策：不建置 deny 版本的 hook**（風險大於效益，且不是業界常見做法），改為僅強化文件層級的
  警告。

### 已落地的優化

- `governance/model-dispatch.md` §1 表「批次機械修改」列訂正為 sonnet（對齊自訂 agent 實際值）；
  新增「安全審查/滲透測試/認證授權相關實作」列，引用專屬自訂 agent。
- `governance/model-dispatch.md` §0/§3 新增 Explore 留空風險的明確警告（inherit capped at
  Opus，附實測案例）。
- `governance/prompt-templates.md` 搜尋型範本的建議文字，從一般敘述句改為強制警告格式，明講
  model 是 tool call 參數、不在 prompt 內文、留空的真實代價。
- 新建 `worker-security-review` 自訂 agent 定義檔（model: opus、effort: high），供安全審查/
  滲透測試/認證授權相關實作固定走最高模型層級，不受一般派工省成本邏輯影響。

## 參考

- pilotfish 專案：https://github.com/Nanako0129/pilotfish（公開 GitHub 專案）
- 對應自有規則：`governance/model-dispatch.md`（模型調度守則）、
  `.claude/agents/worker-mechanical.md`、`.claude/agents/worker-readback.md`
