---
name: feedback-sa-jira-writeback
description: sdlc-agent SA 完成後回寫 Jira 描述的規則——confirm 先問、去識別化 KB 專有名詞
metadata:
  node_type: memory
  type: feedback
---

sdlc-agent 的 SA stage，在完成 KB pending / 入庫之後、且**有指定 Jira 單號**時，新增「回寫 Jira 描述」步驟：只回寫「功能目標 / 商業規則 / 驗收條件與邊界情境 / Gherkin」四區段（資料流、影響範圍等 RD 內部細節不回寫）。

**Confirm 模式：不直接做，先問使用者要不要回寫**；auto 模式可直接做。原描述為空才直接新增，非空要先確認覆蓋/追加。

**去識別化（強制）**：Jira 給全團隊/跨團隊看，須移除只有 KB 語境看得懂的知識庫專有名詞——ADR 編號與引用（如 `ADR-XXXX`、`[ref: ADR-XXXX]`、「決策脈絡見 ADR-xxxx」）、KB 內部檔案路徑（`specs/`、`ADRs/`、`source-codex/`）、KB 專屬流程術語。**保留** ticket 單號、程式碼類別/方法名、業務規則、AC、Gherkin。

**Why:** ADR 編號等只有使用者看得懂，Jira 是跨團隊溝通媒介。
**How to apply:** 已寫入各專案 `role-flows/flow-sa.md` Step 8。寫 Jira 描述含大量特殊字元時，用 `json.dumps` 產生安全 JSON 再送 `jira_update_issue`。相關 [[reference-knowledge-base]]。
