---
date: 2026-08-03
keywords: Claude Code skill 架構、需求澄清機制、Code Review 雙軸審查、SDLC agent 設計
---

# 私有 KB + SDLC Pipeline 工作坊 vs 公開 GitHub Skill 套件架構比較

## 問題背景

評估一套私有、多專案共用的 Claude Code KB + SDLC pipeline agent 系統，與一套公開分發、跨組織的
通用 GitHub skill 套件（含其中一個需求澄清類 skill）在架構理念上的異同，藉此檢視本工作坊現有機制
是否有可借鏡之處，並落地可執行的優化。

## 研究結論

1. **定位差異**——對方是公開分發、跨組織的通用 skill 套件（GitHub 星數達 198k，其中需求澄清類單一
   skill 累計 691k 次安裝），model-agnostic、原子化、透過 plugin/npx 裝進任何 repo，訴求解決 AI 協作
   的四個通用失敗模式（misalignment / verbosity / non-functional code / architecture decay）。
   本工作坊是私有單組織多專案共用的 KB + SDLC pipeline agent 系統，skill 只是 KB 的存取層，核心資產
   是 KB 本身（需求 spec、服務原始碼索引、架構決策記錄、QA 記錄）+ issue tracker/瀏覽器自動化 MCP
   整合 + 去識別化流程 + memory/governance 治理層。兩者不是同一種產品：對方賣的是「可攜的最佳實踐
   skill」，本工作坊做的是「可攜的知識庫＋流程引擎」。

2. **架構理念**——對方 user-invoked（編排型）skill 可呼叫 model-invoked（可重用 discipline）skill，
   明確兩層組合模型。本工作坊的核心 pipeline skill 是單一大 skill，細節拆到 references/ 依需要懶
   載入，同樣做到「本體薄、按需展開」的效果，但沒有拆出可被其他角色流程呼叫的獨立 discipline
   skill——這是架構層面的差異，非缺陷。

3. **需求澄清機制**——對方的逐題澄清機制是一次只問一題、每題附上建議答案、等使用者回饋才問下一題，
   直到決策樹每個分支都收斂；能自己查代碼庫確認的事實不問使用者，只問真正需要使用者判斷取捨的部分。
   本工作坊原本的 PM / BACKEND 角色在需求分析階段，是單輪呈現「方案 A / 方案 B」兩個包裝好的選項，
   使用者一次選一個——對簡單決策夠快，但遇到牽動後續架構、影響多個服務、或需求描述本身有矛盾的複雜
   決策點，單輪二選一可能無法逼出所有隱含假設。

4. **Code Review 機制**——對方 code-review skill 用平行 subagent 拆開「coding standard 是否遵守」與
   「是否達成 spec 目的」兩個審查軸，避免同一個審查過程因為知道業務意圖而對原則違規從寬認定（交叉污染
   判斷）。本工作坊原本的 Code Reviewer 角色在 ticket 模式下，單一 pass 內先萃取 ticket 目的與精神，
   再依此背景審查品質/效能/設計模式，理論上有同樣的污染風險。

5. **架構腐化防護**——對方的架構改善 skill 主動掃描全部程式碼庫並產出視覺化報告。本工作坊的架構規則
   審查 skill 是刻意設計成 diff-scoped 的被動審查（只審本次異動或指定範圍），呼應「測試只跑受影響
   範圍」的一致設計哲學。評估後認為這是有意的設計取捨（控制審查成本、聚焦當次異動），不是需要補的
   缺口，暫不跟進全庫主動掃描。

6. **跨 session 銜接**——對方 handoff skill 產出交接筆記供下一個 session 接續工作。本工作坊有
   pending/ 草稿機制：pipeline 流程中斷時，各階段產出留在 pending/ 目錄，排程模式會自動掃描並撿回
   入庫。評估後認為這是比對方臨時筆記更強的機制（是持久化知識庫本身，而非一次性筆記），不需要另外補
   一個 handoff skill。

7. **共享詞彙**——對方用一份 CONTEXT.md 建立跨 session 的 domain model 共享詞彙，降低溝通 verbosity。
   本工作坊用服務索引文件記錄各服務的功能邊界與路由規則，偏「服務路由 + 現況」導向，不是「ubiquitous
   language 詞彙表」導向。目前沒有觀察到「同一業務詞彙在不同服務間語意混淆」的實際痛點證據，列為觀察
   項，非急迫，暫不跟進建立獨立詞彙表機制。

## 已落地優化

本次分析後，同一次工作中已完成落地（非僅為研究結論）：

**A. Code Reviewer 角色 ticket 模式改為雙軸平行 subagent 審查**
「目的驗證」（對照 spec 判斷是否達成業務目的）與「品質/效能/設計模式原則審查」拆成兩個互不可見對方
輸入的 subagent（各自限制對方的檔案存取範圍，避免其中一個 subagent 因為知道另一軸的資訊而放寬判斷
標準），比照本工作坊既有的「多角色平行分析」機制，成本最低、風險最低。範圍模式（無 spec 可對照）
維持單一 pass 不變，因為本就不存在污染風險。

**B. 新增共用「深度追問協定」參照文件**
供 SA 轉化規格、CONSULTANT 記錄架構決策時，遇到「決策點會牽動後續架構、影響 2 個以上服務、需求描述
本身矛盾、或可行方案超過 2 個」的複雜決策時，改用逐題收斂機制（一次只問一題、附建議答案、先自己查
KB/程式碼再問、決策樹分支收斂後才定案），取代原本的單輪二選一呈現；決策簡單時仍沿用原本的單輪流程，
不影響既有快速路徑。

## 參考

- https://github.com/mattpocock/skills
