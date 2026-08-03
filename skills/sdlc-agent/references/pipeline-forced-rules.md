# Pipeline 強制規則（Output 動作追蹤／測試執行分層／update-kb 批次化／Stage 間銜接格式）

#### Output 動作追蹤（強制，適用所有 stage）

每個 stage 的 **Output** 清單中，凡是「呼叫 /xxx」「執行 /xxx」這類指定呼叫特定工具或 skill 的項目，**進入該 stage 時就先用 `TaskCreate` 為清單中每一項各自建立一個獨立 task**，不要合併成一個大 task（例如 Spec-Driven 實作有 3 個 Output 動作，就建 3 個 task，不是 1 個「完成實作」task）。

- 每個 task 只有在**真的呼叫了對應工具**（透過 Skill 呼叫 `/code-architect`、`/diagram`、`/update-kb` 等）才可標記完成；手動寫文件、手動審查等「產出結果看起來差不多」的替代做法**不算完成**——這類手動替代會漏掉該工具本身的其他副作用（例如 `/diagram` 會同步維護 `diagram-participants.md`、`/update-kb` 會清理對應的 pending 項目與寫入 log），且容易在長對話中被忽略而沒有被發現。
- 該 stage 標記「✅ {stage 名稱} 完成」之前，用 `TaskList` 確認這些 task 全部是 completed；有缺漏就先補做，不得省略後直接進入下一個 stage 或標記流程完成。

---

#### 測試執行分層（強制，適用 Spec-Driven 實作起的所有 stage）

驗證義務不變，改變的是**範圍**——**全套 test suite 只在「單一角色模式的 QA」執行；pipeline 模式全程不跑全套**：

| 執行時機 | 測試範圍 |
|---------|---------|
| Spec-Driven 實作完成時（含回圈修正輪） | 只跑**受本次異動影響的測試**：本次新增/修改的測試類別 + 直接呼叫異動程式碼的既有測試（以 `mvn test -Dtest=...` / `gradle test --tests ...` 等指定範圍），不跑全套 |
| Code Review 修正完成時 | 同上，只跑受修正影響的測試 |
| QA 第 1 輪（pipeline 模式） | 三類驗測，但 unit / integration **限縮為本 ticket 累積異動的影響範圍**：本 ticket 期間新增或修改的全部測試類別 + 直接呼叫這些異動程式碼的既有測試；**本機啟動驗證照常完整執行** |
| QA 回圈第 2 輪起（pipeline 模式） | 只重跑上一輪失敗的案例 + 受本輪修正影響的測試；**本機啟動驗證亦跳過**（修正若涉及啟動設定/依賴注入則例外）；判定通過即標記 pipeline 完成，**不補跑全套** |
| **單一角色模式的 QA** | **完整三類驗測（全套 unit + integration + 本機啟動驗證）——這是唯一的全套執行點**，不論本次有無 diff、diff 範圍多大都跑全套 |

- 無法圈定影響範圍時（如異動橫切多模組的共用元件、修改建置設定）→ 該次退回全套執行，並在輸出中標註原因。
- 其餘單一角色模式（QA 以外的角色）比照對應 stage 的範圍規則，只跑受異動影響的測試。
- **全套回歸的責任轉移給使用者**：pipeline 完成時不含全套回歸驗證，因此流程完成總結必須提示「本次未執行全套回歸，如需完整驗證請單獨執行 `/sdlc-agent QA`」（見「Stage 間銜接格式」總結範本）。

---

#### /update-kb 批次化（強制，僅 Pipeline 模式）

`/update-kb` 在 pipeline 中是記帳而非運輸——stage 間的交接靠對話 context 與磁碟上的程式碼/流程圖，不依賴讀回 KB 檔案。因此：

- **各 stage Output 中所有「呼叫 `/update-kb`」項目，在 pipeline 模式下一律改為**：將該產出的完整草稿直寫 `{$PROJECT_KB}/pending/{TICKET}-{stage 代號}.md`（主線直接 Write 的輕量檔案操作，**不派子代理**；同一 stage 多筆產出如 SA 的多個 ADR，同檔分節追加）。QA 回圈的輪數與失敗紀錄同樣追加於 QA 草稿檔。
- **pipeline 終點**（`$end_stage` 完成後——預設為 QA 通過後，模式 5「PM+SA」則為 Spec 轉化完成後——輸出流程完成總結前）觸發**一次** `/update-kb`，由其將 pending/ 草稿正式入庫（分類、去識別化、index/MASTER_INDEX 同步）並清理 pending；auto 模式直接觸發，confirm 模式詢問一次（預設 Y）。
- **中斷保護網**：pipeline 中途死掉時，pending/ 草稿仍在磁碟上，update-kb 排程模式（Mode A）原生掃描 pending/ 會將其撿回入庫，或下次手動觸發時處理。
- `/diagram`、`/code-architect` **不在批次範圍**，照各 stage 原定時機即時執行。
- **單一角色模式不適用本規則**：維持該角色完成後即時 `/update-kb`（跨 session 執行下一角色時依賴磁碟上的正式 KB 檔案）。
- Output 動作追蹤的對應調整：pipeline 模式下各 stage 的 `/update-kb` task 以「pending 草稿已寫入」為完成標準；pipeline 終點另建一個「觸發 /update-kb 正式入庫」task，於總結前確認 completed。

---

#### Stage 間銜接格式

每個 stage 完成後輸出：

```
✅ {stage 名稱} 完成
   產出：{本 stage 主要產出摘要}

▶ 進入下一 stage：{下一 stage 名稱}（{auto / confirm} 模式）
```

QA 判定功能有誤、觸發回圈時，改輸出：

```
🔁 QA 發現功能缺陷，回圈至 Spec-Driven 實作修正（第 {N} 輪）
   問題摘要：{QA 發現的落差 / 缺陷描述}
   對應 AC/Gherkin：{落差對應的條目}

▶ 重新進入：Spec-Driven 實作（{auto / confirm} 模式）
```

連續 3 輪未通過時，改輸出並暫停等待使用者回應：

```
⏸ QA 連續 3 輪未通過，暫停迴圈

輪次摘要：
  第 1 輪：{問題摘要}
  第 2 輪：{問題摘要}
  第 3 輪：{問題摘要}

請問要如何處理？（例：調整 spec / 重新設計方案 / 手動介入 / 放寬 AC）
```

所有 stage 完成後輸出總結：

```
🎉 流程完成

完成的 stage：{清單}
QA 回圈次數：{N}（無回圈則寫「0」）
產出摘要：
  - specs/{TICKET}.md（完整規格）
  - ADRs：{建立 / 更新的 ADR 清單}
  - 實作程式碼（經 /code-architect 驗證架構合規）
  - 流程圖（/diagram + /diagram sync）
  - review-history/{...}（review 記錄）
  - 測試案例表 + 測試結果（unit / integration 限本 ticket 影響範圍 / 本機啟動驗證）

⚠️ 本次未執行全套回歸測試（pipeline 模式限縮於異動影響範圍）。
   如需完整驗證，請單獨執行 `/sdlc-agent QA`（單一角色模式會跑全套三類驗測）。
```

`$end_stage` 非 QA（例如模式 5「PM+SA」終點為 Spec 轉化）時，該 stage 完成即為 pipeline 終點，改輸出精簡總結（不列尚未執行 stage 的產出項目，無 QA 回圈次數與全套回歸提示）：

```
🎉 流程完成（PM+SA 需求轉化）

完成的 stage：{清單}
產出摘要：
  - specs/{TICKET}.md（完整規格：範疇 / AC / 功能需求 / 邊界情境 / Gherkin / 技術功能實作規格）
  - ADRs：{建立 / 更新的 ADR 清單}（無則寫「無」）

如需繼續往下實作，執行 `/sdlc-agent`，選「2. 部分流程」，起點選「Spec-Driven 實作」。
```
