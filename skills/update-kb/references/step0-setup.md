<!-- 由 SKILL.md Step 0 / Step 0.5 / Step 0.7 連結，完整明細。 -->

## Step 0 — 初始化

讀取 memory 的 `reference_knowledge_base.md` 取得 `$KB_ROOT`（knowledge-hub 根目錄）。

讀取 `$KB_ROOT/setting/paths.yml` 解析所有路徑常數（`@kb/` → `$KB_ROOT/`）。

---

## Step 0.5 — 選擇目標專案 KB

### 排程模式（Mode A）

掃描 `$KB_ROOT/knowledge/` 下所有名稱以 `_KBs` 結尾的子資料夾，**排除 `common_KBs`**（通用 KB 獨立處理），其餘**全部納入**更新範圍（以下稱 `$TARGET_KBs`）。

### 使用者模式（Mode B）

掃描 `$KB_ROOT/knowledge/` 下所有 `_KBs` 結尾子資料夾（**排除 `common_KBs`**），顯示選單：

```
請選擇要更新的專案知識庫（輸入編號，多個以逗號分隔，輸入 all 全選）：
  1. {project_name}_KBs
  2. demo_KBs
  ...
```

等待使用者選擇，記住選定清單（以下稱 `$TARGET_KBs`）。

每個 `$PROJECT_KB` 的根路徑格式為 `$KB_ROOT/knowledge/{project_name}/`。

---

## Step 0.7 — 新 KB Scaffolding（自動偵測）

對每個選定的 `$PROJECT_KB`，檢查 `{$PROJECT_KB}/MASTER_INDEX.md` 是否存在：

- **存在** → 正常進入 Step 1，不做任何 scaffolding。
- **不存在** → 視為新 KB，自動執行以下 scaffolding 後再進入 Step 1：

### Scaffolding 執行規則

1. 讀取 `$KB_ROOT/knowledge/demo_KBs/` 的完整目錄結構

2. 在 `{$PROJECT_KB}/` 下依以下分類規則處理每個檔案：

   **格式規範（從本 skill 的正典複製，不從 demo_KBs）：**
   - `specs/spec-format.md`、`specs/impls/impls-format.md`、`qa-records/qa-format.md`
     一律從 `skills/update-kb/templates/formats/` 複製（該目錄為格式**正典**；
     demo_KBs 與各專案 KB 內的同名檔皆為其複本）
   - KB 複本要客製化時：直接改該 KB 的複本，並在檔案 frontmatter 加 `customized: true`；
     `setting/check-kb-formats.ps1|.sh` 會比對各 KB 複本與正典的**章節結構**，
     結構不一致且未標 `customized` 即 WARN

   **直接複製（來自 demo_KBs 的空白模板）：**
   - `specs/README.md`
   - `specs/impls/README.md`
   - `site-reliability/index.md` 及 `site-reliability/` 下所有 `.md`
   - `source-codex/cross/index.md`、`source-codex/cross/service-map.md`
   - `ADRs/index.md`（`demo_KBs/ADRs/` 目前僅含 `index.md` 與示範 ADR `0001-service-communication-protocol.md`，後者屬示範內容、依下方「不複製」規則排除，不隨 index.md 一併複製）
   - `review-history/index.md`、`review-history/YYYY-MM-DD-TICKET-service-name.md`（模板檔）——**只複製表頭結構**（標題 + 欄位列），不含 `demo_KBs` 自身因執行煙霧測試累積的實際條目列
   - `qa-records/index.md`（同上，只複製表頭結構，不含 `demo_KBs` 自身的煙霧測試條目；若 `{$PROJECT_KB}/qa-records/` 目錄不存在，一併建立）
   - `specs/index.md`（同上，只複製表頭結構，不含 `demo_KBs` 自身的 DEMO-001／DEMO-002 條目）
   - `pending/README.md`、`pending/jira.txt`、`pending/logs/.gitkeep`

   **複製後清空示範資料（保留結構，替換內容）：**
   - `MASTER_INDEX.md`：複製結構，將服務清單、AI 路由規則、系統定位等示範文字改為 `[待補充]`；保留各章節標題與說明段落

   **不複製（demo 專屬內容）：**
   - `specs/DEMO-*.md`、`specs/impls/DEMO-*.md`（示範 ticket）
   - `source-codex/services/` 下所有子目錄（示範服務：order-service / payment-service / notification-service 等）
   - `ADRs/` 下編號 `0001` 以上的 `.md`（示範 ADR，非格式說明文件）

3. 完成後告知使用者：「已初始化 KB 結構（格式規範自 skill 正典複製、目錄結構自 demo_KBs，示範內容已排除），繼續更新流程。」

> **重要**：scaffolding 後立即繼續 Step 1，不等待使用者操作。
