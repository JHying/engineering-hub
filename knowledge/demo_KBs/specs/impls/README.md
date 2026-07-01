# Impls Knowledge Base

## 目的

記錄各 ticket **實作後**的技術知識，是 Spec 的配對文件。

建立時機：實作完成、PR 合併後由 AI 或 RD 根據 git diff 生成。

## 命名規則

`{TICKET}-impls.md`（例：`DEMO-001-impls.md`）

## 與 Spec 的關係

```
specs/DEMO-001.md       ← 要做什麼（需求 / AC / 資料流）
specs/impls/DEMO-001-impls.md  ← 做了什麼（class 對應 / SA 規格 / 測試）
```

兩份文件合在一起，才是該 ticket 的完整知識。
