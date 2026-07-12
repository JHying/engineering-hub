---
name: user-default-model-sonnet5-xhigh
description: 使用者日常 session 跑 Sonnet 5 + xhigh effort，非 Opus/Fable——影響所有「主線 vs 子代理」成本分析與調度建議
metadata: 
  node_type: memory
  type: user
  originSessionId: 863aadd3-e115-4627-8557-c4ca25d26ee4
---

使用者平常以 **Sonnet 5 + xhigh effort** 執行日常 session（2026-07-12 告知）。

含義：
- 「派 sonnet 子代理省費率」的套利對她**不成立**（主線本來就是 sonnet）；子代理化只剩 context 衛生的價值。
- 成本大頭是 xhigh 的 thinking tokens（按輸出計價）與長 pipeline 的 context 累積。
- 降 effort 的機械性派工（.claude/agents 定義檔設 effort）比降模型更有意義；升級路徑是遇難題升 opus 子代理。
- 提供優化建議前，先以「sonnet 主線」為前提估算，不要假設主線是最貴模型。相關制度見 [[governance-model-dispatch]]。
