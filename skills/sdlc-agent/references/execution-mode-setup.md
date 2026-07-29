# 執行模式細部設定（Step 2-SINGLE ／ Step 2-PIPELINE，明細）

### Step 2-SINGLE — 單一角色選擇

問使用者：

```
請選擇角色：
  1. PM         — 需求企劃：審查 AC、補 Gherkin 範本、建立 specs/{TICKET}.md 第一版 + /update-kb
  2. SA         — Spec 轉化：補足技術文件落差、完整 specs/{TICKET}.md、含 ADR 溝通 + /update-kb
  3. CONSULTANT — ADR 溝通：決策點分析 + /update-kb 記錄 ADR
  4. BACKEND    — Spec-Driven 實作（含 ADR 驗證、/code-architect、/diagram、/update-kb）
  5. REVIEWER   — Code Review + 修正 + /diagram sync + /update-kb
  6. QA         — 測試策略 + 撰寫 / 執行測試 + /update-kb
  7. SRE        — 部署策略 + 上線 Checklist

輸入數字或名稱：
```

等待使用者回答後記住選擇的角色，進入 Step 3。

---

### Step 2-PIPELINE — Pipeline 流程設定

#### Step P1 — 起點選擇（部分流程時）

> 若選擇「完整流程（模式 3）」，略過此步，起點預設為「需求企劃」。

問使用者：

```
請選擇起始 stage（將從此 stage 依序執行至 QA）：
  1. 需求企劃
  2. Spec 轉化（SA）
  3. Spec-Driven 實作
  4. Code Review
  5. QA

輸入數字：
```

記住起始 stage（以下稱 `$start_stage`）。

#### Step P2 — 各 stage auto / confirm 設定

ADR 溝通為跨階段角色，隨 Spec 轉化與 Spec-Driven 實作的設定一併適用，不單獨設定。

**顯示選單前，先依以下規則逐行判斷要列出哪些 stage（規則本身只用來決定內容，不得出現在顯示給使用者的文字中）：**

- `$start_stage` ≤ 1 → 列出「需求企劃」行，否則省略該行
- `$start_stage` ≤ 2 → 列出「Spec 轉化（含 ADR 溝通）」行，否則省略該行
- `$start_stage` ≤ 3 → 列出「Spec-Driven 實作（含 ADR 驗證）」行，否則省略該行
- `$start_stage` ≤ 4 → 列出「Code Review」行，否則省略該行
- 「QA」行一律列出，不受 `$start_stage` 限制

依上述規則篩出的 stage 清單，依序填入下方模板（模板內只留純文字與佔位符，不得原樣印出任何條件標記）：

```
請為各 stage 設定執行方式（A = auto 自動執行，C = confirm 先與你確認再執行）：

{依上述規則篩出的 stage 清單，每行一個 stage 名稱加冒號}

建議預設：C A A A A（spec 成形時人工把關一次，其後全自動——需求判斷錯誤是唯一
後面階段補不回來的錯，且此閘門成本最低）；起點非需求企劃時，建議首個 stage 為 C、其餘 A。

依上方順序輸入（例：A A C A A），或直接按 Enter 採用建議預設：
```

記住每個 stage 的設定（以下稱 `$stage_modes`），進入 Step 3。
