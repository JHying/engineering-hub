---
name: user-default-model-sonnet5-xhigh
description: 使用者日常 session 跑 Sonnet 5 + high effort（2026-07-13 起，原 xhigh 已調降），非 Opus/Fable——影響所有「主線 vs 子代理」成本分析與調度建議
metadata: 
  node_type: memory
  type: user
  originSessionId: 863aadd3-e115-4627-8557-c4ca25d26ee4
---

使用者日常 session 為 **Sonnet 5 + high effort**（2026-07-13 採納建議，由 xhigh 調降；原設定為 2026-07-12 告知）。

含義：
- 「派 sonnet 子代理省費率」的套利對她**不成立**（主線本來就是 sonnet）；子代理化只剩 context 衛生的價值。
- 成本大頭原為 xhigh 的 thinking tokens（按輸出計價）與長 pipeline 的 context 累積；降到 high 後前者已收斂，context 累積仍是主要項。
- 調降依據：主要工作是 /my-work-agent spec-driven pipeline，主線只調度、實作在 subagent；Sonnet 5 的 high ≈ Sonnet 4.6 的 max，品質風險低。
- xhigh 保留給臨時的難題 session（架構取捨、大型重構規劃），用完降回。
- worker-mechanical / worker-readback 定義檔已明寫 effort: low，不受 session effort 影響；其餘未寫 effort 的 subagent 會繼承 session（現為 high）。
- 提供優化建議前，先以「sonnet high 主線」為前提估算，不要假設主線是最貴模型。相關制度見 [[governance-model-dispatch]]。
