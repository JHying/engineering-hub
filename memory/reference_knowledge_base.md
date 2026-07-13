---
name: reference-knowledge-base
description: Knowledge Hub 根路徑，供 my-work-agent skill Step 1 作為預設值
metadata: 
  node_type: memory
  type: reference
  originSessionId: f19dad93-3484-47f2-ac77-4c7c934fe4d9
---

Knowledge Hub 根路徑：`C:\<workspace>\knowledge-hub`

此路徑同時也是本專案（knowledge-hub repo）的工作目錄本身，`setting/paths.yml` 中的 `kb` 欄位即指向此路徑。

專案 KB 清單（`knowledge/` 下以 `_KBs` 結尾的資料夾）：
- `common_KBs`（通用知識庫，非專案 KB，index-first 載入）
- `demo_KBs`
- 專案 KB A
- 專案 KB B
