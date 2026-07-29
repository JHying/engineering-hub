---
name: update-kb
description: >
  Knowledge Base 更新技能。支援兩種啟動模式：
  1. 排程自啟動：掃描各專案 KB 的 pending/ 目錄、每日 git 更新，自動判斷涉及的 KB 並派發子代理並行更新。
  2. 使用者自啟動：使用者輸入要更新的內容（ticket/檔案/描述），手動選擇目標專案 KB 後觸發更新流程。
  觸發關鍵字：update-kb、更新知識庫、kb更新、同步知識庫、寫到KB、review history
version: "1.18"
---

# Update Knowledge Base

> 本檔只留流程骨幹，各 Step 明細與規則全文見 `references/` 對應檔案；`templates/` 為子代理 prompt 模板、
> `templates/formats/` 為 KB 格式規範正典（spec / impls / qa），除下述 Step 0.7 引用外不在本檔涵蓋範圍。

## 啟動模式

- **模式 A（排程自啟動）**：由 `/schedule` 或 `/loop` 觸發，不等待使用者輸入，自動掃描各專案 KB 的 `pending/` 與每日 git 更新。
- **模式 B（使用者自啟動）**：使用者輸入 ticket / 檔案 / 描述，手動選擇目標 `$PROJECT_KB` 後觸發。

明細見 `references/step1-2-routing.md`。

---

## 硬性約束（所有 Step 皆適用，寫入前必查）

### 權限規則
`$KB_ROOT` 內完整 CRUD、免確認；`$KB_ROOT` 外唯讀；共用知識、共用 ADR 路徑另有限制。
明細見 `references/permission-rules.md`。

### 內容限制規則
git-tracked 路徑只允許標準技術術語與無語意佔位符；專案 KB（`{$PROJECT_KB}/`）例外可含完整識別資訊。
明細見 `references/content-rules.md`。

### 表格欄位可讀性規則
單一表格儲存格塞入 3 個以上不同面向事實時，須拆成主表格摘要列 + 結構化子表格。
明細見 `references/content-rules.md`。

### 去識別化檢查清單
專案 KB 以外的所有 git-tracked 內容皆適用；regex 掃描 + 語意比對雙軌並行，建立對照表逐一替換後才寫入；對照表僅存在於當次對話摘要，禁止寫入任何檔案。
明細見 `references/deidentification-checklist.md`。

---

## Step 0 — 初始化

讀取 memory 取得 `$KB_ROOT`，解析 `setting/paths.yml` 路徑常數。
明細見 `references/step0-setup.md`。

---

## Step 0.5 — 選擇目標專案 KB

模式 A 全選所有 `_KBs`（排除 `common_KBs`）；模式 B 顯示選單由使用者選擇，結果記為 `$TARGET_KBs`。
明細見 `references/step0-setup.md`。

---

## Step 0.7 — 新 KB Scaffolding（自動偵測）

`MASTER_INDEX.md` 不存在時視為新 KB，自動初始化：格式規範自本 skill `templates/formats/` 正典複製、目錄結構與空白模板自 `demo_KBs`、排除示範內容後立即進入 Step 1。
明細見 `references/step0-setup.md`。

---

## Step 1 — 判斷啟動模式

模式 A：掃描各來源收集待更新清單，若多個 `$PROJECT_KB` 均有內容則同一 response 並行派發 Step 3。模式 B：詢問使用者 8 選項之一，等待輸入後進入 Step 2。
明細見 `references/step1-2-routing.md`。

---

## Step 2 — 判斷涉及的知識庫類型

依關鍵字判斷 PM / RD / SRE / 專案 ADR / 共用 ADR / 通用技術研究 / Review History / QA Records / KB_ROOT Meta，可多選；KB_ROOT Meta 不派子代理，由主流程直接處理。
明細見 `references/step1-2-routing.md`。

---

## Step 3 — 並行派發子代理

同一個 response 中同時對所有涉及 KB 類型發出 `Agent` tool call；依 Step 2 判定結果只讀取對應的單一模板檔，不得一次讀取全部模板。
明細（調度表、模板路徑、`subagent_type` / `model`）見 `references/step3-dispatch.md`。

---

## Step 4 — 彙整子代理結果，同步 Meta 檔案

等所有子代理完成後，同步以下四項；明細見 `references/step4-aggregation.md`。

### 4-1 同步各 PROJECT_KB 的 MASTER_INDEX.md
PM / Review History / QA Records 三類只維護指標段落（筆數 + 連結），不重複列出個別條目；RD / SRE 檢查路由關鍵字與文件清單是否有新增。

### 4-2 同步 setting/paths.yml
確認子代理建立的新文件是否需要新增對應 key。

### 4-3 同步 role-flows/
KB 結構或路由規則異動時，檢查對應 flow 文件（flow-pm / flow-backend / flow-qa / flow-reviewer / flow-sre）。

### 4-4 確認 README.md 是否需要更新
比對目錄結構、共用知識路徑、KB 類型清單，若不一致直接更新（中英文同步）。

### 4-5 執行 KB 格式漂移檢查
跑 `setting/check-kb-formats.ps1|.sh` 比對各 KB 格式檔複本與 `templates/formats/` 正典；
全 OK 不回報，有 WARN 列入 Step 6 摘要並附處理選項。

---

## Step 5 — 清理 Pending + 記錄 Log

對每個 `$PROJECT_KB` 執行以下兩項；log 範例全文見 `references/step5-pending-log.md`。

### 5-1 清理 pending
移除已成功處理的 ticket / 已整合的 pending 檔案，保留失敗或跳過的項目。

### 5-2 寫入更新 Log
建立或追加 `pending/logs/update-{YYYY-MM-DD}.md`；去識別化對照表禁止寫入 log 或任何檔案。

---

## Step 6 — 輸出摘要

向使用者輸出本次更新的最終摘要（格式同 Log），標注待補充位置；涉及 KB_ROOT Meta / 共用 ADR / 技術研究時的附加規則見明細。
明細見 `references/step6-summary-output.md`。
