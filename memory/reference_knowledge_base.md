---
name: reference-knowledge-base
description: Knowledge Hub 根路徑，供 sdlc-agent skill Step 1 作為預設值
metadata: 
  node_type: memory
  type: reference
  originSessionId: f19dad93-3484-47f2-ac77-4c7c934fe4d9
---

Knowledge Hub 根路徑因主機而異，實際路徑見同目錄下的 `reference_knowledge_base.local.md`（由 `setting/setup-host.ps1` 執行時自動產生，不進 git）。該檔不存在時，代表尚未在本機執行過 `setup-host.ps1`，需先執行。

`setting/paths.yml` 中的 `kb` 欄位即指向本機的 Knowledge Hub 根路徑。

專案 KB 清單（`knowledge/` 下以 `_KBs` 結尾的資料夾）：
- `common_KBs`（通用知識庫，非專案 KB，index-first 載入）
- `demo_KBs`
- 專案 KB A
- 專案 KB B
