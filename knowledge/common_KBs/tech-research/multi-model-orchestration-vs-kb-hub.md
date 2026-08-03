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
  無固定綁定。
- Engineering Hub 已有「產出不自驗」規則（read-back 用 fresh-context subagent、高風險判斷取
  第二意見），對應 pilotfish 的 Plan-verifier / Verifier 獨立驗證概念——這塊已覆蓋，非缺口。
- Engineering Hub 已用模型別名（sonnet/opus/haiku）而非硬編碼模型 ID，避免棄用時要全面改寫——
  這塊已對齊 pilotfish 的做法。
- 缺口：
  1. 無自動降級鏈設計，模型不可用時只能靠人工升降級路徑。
  2. 無安全工作專屬路由規則，安全審查/實作沒有強制走最高模型層級的保證。
  3. 無成本節省的量化實測數據佐證派工決策，全憑經驗判斷。
  4. SDLC 高頻角色未做 frontmatter 硬綁定，每次仍需人工判斷查表，增加認知負擔。

## 待評估的優化方向（尚未落地，供未來參考，非最終決策）

1. 考慮將 SDLC 六角色也比照 `worker-mechanical` 模式做 `.claude/agents/*.md` frontmatter 綁定，
   減少每次動態查表的認知負擔。
2. 考慮補一條安全工作專屬路由規則（安全審查/實作一律走最高模型層級）。
3. 是否需要自動降級鏈設計，取決於實際遇到模型不可用的頻率，非立即急需。
4. 可考慮在 `lessons.md` 累積派工升降級的量化案例（例如「原訂 X 模型失敗兩次升級到 Y」的紀錄），
   逐步建立自己的成本/品質實證基礎，而非只憑經驗判斷。

## 參考

- pilotfish 專案：https://github.com/Nanako0129/pilotfish（公開 GitHub 專案）
- 對應自有規則：`governance/model-dispatch.md`（模型調度守則）、
  `.claude/agents/worker-mechanical.md`、`.claude/agents/worker-readback.md`
