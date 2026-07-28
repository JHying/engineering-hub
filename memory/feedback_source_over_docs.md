---
name: feedback-source-over-docs
description: 原始碼是唯一真相，CLAUDE.md 與既有文件都可能有誤，一律以原始碼核實
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1a3995d1-7e51-41bd-9653-d26b40dcb571
  modified: 2026-07-28T07:10:51.820Z
---

任何文件（含 CLAUDE.md、KB、程式碼註解）都可能過時或錯誤，不可當事實引用。KB 負責的是搜尋成本（位置、why、決策脈絡）而非取代驗證；原始碼負責核實會漂移的具體技術宣稱（函式名稱/簽章、路徑、設定值、狀態機細節）。

**Why:** 使用者明確指出「CLAUDE.md 也有可能是錯的，以原始碼參考為主」；後續澄清：若解讀成「每次都要無差別全面重查原始碼」，KB 就失去存在意義。

**How to apply:** 不是每次都重跑全面驗證。只在(1)文件與原始碼明顯衝突，或(2)要引用/建議會漂移的具體技術細節（函式、路徑、設定、API 行為）且使用者將依此行動時，才回原始碼核實該細節；高層架構脈絡、why、優先序可直接信任 KB。發現文件錯誤要標記出來而非沿用。參見 [[feedback-terse-no-rationale]]。
