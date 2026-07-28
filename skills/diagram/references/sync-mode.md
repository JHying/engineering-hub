# 模式二：同步（`/diagram sync`）

### Step 1：探索流程圖

```bash
grep -rl "synced:" docs/ 2>/dev/null || grep -rl "synced:" . --include="*.md"
```

找不到 → 回報「找不到任何流程圖，請先執行 `/diagram <範圍描述>` 建立圖表」，結束。

### Step 2：讀取各圖 metadata

對每個圖讀取 `synced` hash、`type`、`covers` 清單。若多個圖 hash 不同，以**最舊的 hash** 為共同基準。

### Step 3：git diff，判斷是否需要更新

```bash
git diff {synced-hash} HEAD -- {covers 中的每個路徑}
```

- diff 為空 → 跳過
- 有 diff → 繼續

### Step 4：讀有變動的檔案，更新對應節點

只讀 diff 中出現的原始碼（不全量讀取 covers 清單）。

依 metadata 的 `type` 分別套用更新規則：

**共用原則（兩種類型皆適用）：**
- 以程式碼為準，只修改有差異的節點文字、連線、分支條件
- 確保跨圖 `click` 連結仍指向正確檔案
- 若 `covers` 有過時路徑（檔案改名或移動），一併更新

**`type: sequenceDiagram`：**
- `%%{init: ...}%%` 顏色區塊缺失時自動補回
- 比對 diff 中出現的元件與該圖表所在目錄下的 `diagram-participants.md`（見「專案 Participant 設定檔」，非固定 `docs/`），將尚未收錄的新元件追加至設定檔
- 保持圖表內的 participant alias 與同目錄的 `diagram-participants.md` 一致

**`type: flowchart`：**
- 更新 subgraph 標籤、節點文字、決策條件
- 不套用 participant alias（flowchart 不使用）
- 不補 `%%{init: ...}%%`（flowchart 不需要）

### Step 5：更新 synced hash

```bash
git log --oneline -1
```

將每個**有修改**的圖的 `synced` hash 更新為最新 commit hash。
