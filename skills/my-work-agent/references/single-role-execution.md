# Step 5-SINGLE — 單一角色執行（明細）

### Step 5-SINGLE — 單一角色執行

單一角色模式採 **confirm 模式**：每個決策點與使用者確認後才繼續。

各角色依對應的 pipeline stage 執行細節運行（見 Step 5-PIPELINE Stage 執行細節），包含 `/update-kb`、`/diagram`、`/code-architect` 等所有工具呼叫，並比照「Output 動作追蹤（強制）」以 task 逐項確認完成，不得用手動替代做法省略。角色與 stage 對應如下：

| 角色 | 對應 pipeline stage |
|------|-------------------|
| PM | 需求企劃 |
| SA | Spec 轉化（含 ADR 溝通） |
| CONSULTANT | Spec 轉化中的 ADR 溝通環節（獨立執行） |
| BACKEND | Spec-Driven 實作（含 ADR 驗證） |
| REVIEWER | Code Review |
| QA | QA |
| SRE | 依 `{{flow_sre}}` 執行，完成後詢問是否 `/update-kb` |

流程文件中若引用 `$master_index`，使用 `$master_indexes` 中對應 KB 的路徑；
若引用 `$review_guide`，使用 `{{review_guide}}`（即 `$KB_ROOT/knowledge/common_KBs/guideline/REVIEW_GUIDE.md`）。

**QA 角色的例外**：單一角色模式的 QA 是全套 test suite 的唯一執行點，**一律執行完整三類驗測**（全套 unit + integration + 本機啟動驗證），與本次 diff 範圍無關（見「測試執行分層」）。另外，單一角色模式的定位是「只執行該階段」，因此 QA 判定功能有誤時**不自動跳去執行 BACKEND**；改為僅提示使用者「建議執行 BACKEND 角色修正後重跑 QA」，由使用者自行決定是否切換角色。Pipeline 模式（部分流程 / 完整流程）才會觸發 Step 5-PIPELINE 的自動回圈。

