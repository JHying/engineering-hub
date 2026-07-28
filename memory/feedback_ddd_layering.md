---
name: feedback_ddd_layering
description: Manager 層不做業務決策（不拋業務例外）；技術結果透傳給 Domain Service 解讀
metadata:
  node_type: memory
  type: feedback
---

Manager 層只回傳技術結果（boolean / null / 數值），不拋業務例外、不做業務判斷。
業務規則的解讀與例外拋出必須在 Domain Service 層。

**Why:** 某次修 bug 時，初版把業務例外（如「已存在」類例外）拋在 Manager 層的一個 `savePendingXxx` 方法裡，違反 DDD 分層。使用者要求修正，改為 Manager 回傳 boolean、Domain Service 解讀並拋例外。

**How to apply:**
- 任何 Infra 操作（NX、Lua、DB 查詢）回傳技術結果時，Manager 只做格式轉換或透傳
- 「這個結果代表業務違規嗎？」的判斷永遠在 Domain Service
- 具體模板：
  ```
  Infra    → 回傳 boolean / Optional / 數值
  Manager  → 透傳（最多加 javadoc 說明語意）
  Domain   → if (!result) throw new XxxException(...)
  App      → catch XxxException → 轉換為 response
  ```
