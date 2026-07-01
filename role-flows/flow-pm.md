---
name: pm
description: >
  PM 工作流程。收到 Jira Story 後審查需求完整性，產出澄清方向選擇，再依選擇產出完整需求審查報告。
---

# PM 工作流程

角色定義見 `{{role_pm}}`

---

## Step 1 — 詢問 Jira 單號

```
請輸入要分析的 Jira 單號（例：PROJ-123），或直接貼上 Story 內容：
```

- 若輸入單號格式 → 嘗試用 Jira MCP 拉取 issue 內容
- 若 Jira MCP 不可用或失敗 → 請使用者直接貼上 Story 文字
- 若使用者直接貼文字 → 直接使用

---

## Step 2 — 載入 System Context

依序讀取：
1. `{{master_index}}` — 服務清單與路由規則
2. `{{pm_kb}}` — PM Knowledge Base 入口（spec / impl 結構、路由規則）

---

## Step 3 — 分析 Story，讀取相關文件

參照 `{{master_index}}` 的「AI 文件路由規則」判斷涉及哪些 service。

每個涉及的 service，依序讀取：
1. `knowledge/source-codex/services/{service}/index.md` — 確認現有功能邊界與介面合約
2. `knowledge/source-codex/services/{service}/api-spec.md`（若涉及 REST API）

若 story 有對應 spec，讀取 `{$PROJECT_KB}/specs/{TICKET}.md`。

---

## Step 4 — 產出 Phase 1（澄清方向選擇）

```
## 方案 A：{需求完整度要求標題}（例：嚴格版 — 全部 AC 補齊後再開工）
- 做法：
- 優點：
- 缺點：
- 適合當：

## 方案 B：{需求完整度要求標題}（例：務實版 — 先做核心 AC，次要 AC 下個 Sprint）
- 做法：
- 優點：
- 缺點：
- 適合當：

---
請問您選擇方案 A 還是方案 B？
```

---

## Step 5 — 等待選擇，產出 Phase 2（完整需求審查報告）

### AC 完整性檢查
| # | AC 原文 | 問題 | 建議補充 |
|---|--------|------|---------|

### AC 缺漏點（應補充但未寫的）
| # | 缺漏情境 | 影響範圍 | 優先度 |

### 模糊描述清單
| # | 模糊 AC | 問題點 | 建議明確化寫法 |

### 與既有功能衝突點
| # | 衝突功能 | 衝突描述 | 解決方向 |

### 跨 Team 依賴確認項目
| 依賴方 | 需要確認的事項 | 截止時間 |

### Gherkin 範本（可選）
為不明確的 AC 補充 Given/When/Then 範例：
```gherkin
Feature: {Story 標題}

  Scenario: {Happy Path}
    Given {前置條件}
    When {操作}
    Then {預期結果}

  Scenario: {Edge Case}
    Given ...
    When ...
    Then ...
```

---

## 關注重點
- 每條 AC 是否「可測試」（有明確的 input / output）
- 是否有隱含的前置條件沒寫出來
- 跨 service 的行為是否有對應的 AC
- 效能、並發等非功能性需求是否被遺漏
