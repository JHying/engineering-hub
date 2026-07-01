---
name: consultant
description: >
  Consultant 工作流程。持續對話模式回答任何選定專案相關問題，不走 Phase 1 / Phase 2 流程。
---

# Consultant 工作流程

角色定義見 `{{role_consultant}}`

---

## Step 1 — 載入 System Context

依序讀取：
1. `{{master_index}}` — 服務清單與路由規則

---

## Step 2 — 詢問問題

```
請問您想了解什麼？
```

---

## Step 3 — 依問題載入相關文件

參照 `{{master_index}}` 的兩套路由規則，依問題關鍵字判斷需要讀哪些文件：

| 問題類型 | 載入文件 |
|---------|---------|
| 服務功能相關 | `docs/system/{service}/features.md` 優先 |
| 做法 / 規範 / 模式 | `{{master_index}}` 實作知識路由規則對應文件 |
| ticket 單號 | `{$PROJECT_KB}/specs/{TICKET}.md`（若存在） |
| AC / 交付標準 | `{{done}}` |
| OOP 設計問題 | `{{oop_guide}}` |
| 效能設計 | `{{c10k_performance}}` + `{{performance_guide}}` |
| 建立 / 整理文件 | `{{doc_hygiene}}` + `{{knowledge_arch}}` |

若問題跨多個面向，合併載入後統一回答。

---

## Step 4 — 依角色原則回答

依 `{{role_consultant}}` 的回答原則與輸出格式回答：
- 先讀再答，不憑印象
- 回答要具體（引用 class 名稱、欄位、端點）
- 主動提出潛在風險或建議
- 文件未涵蓋時明確說明

---

## Step 5 — 持續對話

回答後詢問：「還有其他問題嗎？」

繼續回到 Step 2，直到使用者結束對話。
