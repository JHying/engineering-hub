---
name: pending-demo-smoke-test
description: "待辦:建立 demo_KBs 端到端煙霧測試機制,防止 skill 之間「宣稱 vs 介面」漂移"
metadata: 
  node_type: memory
  type: project
  originSessionId: 140f7114-3292-4bf4-8db2-ae3495f16f7a
---

**待辦任務**(2026-07-05 記錄,使用者指示「下次做」):建立 demo_KBs 端到端煙霧測試。

**為什麼**:2026-07-05 的 skill 體檢發現的問題全是同一類——orchestrator 宣稱與被呼叫 skill 介面漂移(update-kb 缺 QA 路由、my-work-agent 誤述 code-architect、diagram 路徑對不上),個別 skill 單看都沒問題,只有跑通整條鏈才會現形。詳見 `D:\Work\engineering-hub\governance\lessons.md` 的同日條目。

**要做什麼**:
1. 設計一個固定的迷你測試票(放 demo_KBs,例如 DEMO-001),涵蓋 PM→SA→BACKEND→REVIEWER→QA 各 stage 的最小輸出。
2. 定義煙霧測試流程:對 demo_KBs 跑 `/my-work-agent` PREVIEW 或迷你 pipeline(全 stage auto),驗證每個 stage 的產出檔案確實落地(specs/、impls/、review-history/、qa-records/、flow-diagram)且 /update-kb 各路由都被走到。
3. 產出一份 checklist(放 governance/ 或 demo_KBs/),明訂「改任何 skill 後跑一次」的觸發時機。
4. 執行成本考量:全程用 haiku/sonnet subagent,主線只驗結果。

**驗收**:跑完一輪後,故意注入一個介面漂移(如改掉一個路由關鍵字),煙霧測試要能抓到。

相關:[[feedback_narrate-then-act]]
