# Step 3 — 解析路徑設定（明細）

### Step 3 — 解析路徑設定

讀取 `$KB_ROOT/setting/paths.yml`（此檔僅含 `@kb/` 相對路徑的 `regulations` 對照表，不含 `kb` root key——`$KB_ROOT` 一律以 Step 1 從 memory 解出的值為準）。

`@kb/` 前綴替換為 `$KB_ROOT/`，`{{key}}` 符號查找 `regulations` 區段對應路徑。

**動態路徑注入：**

- 通用 KB 主索引：`$KB_ROOT/knowledge/common_KBs/MASTER_INDEX.md`（先讀此檔，再按需讀取具體子目錄）
- 共用規範：`$KB_ROOT/knowledge/common_KBs/guideline/REVIEW_GUIDE.md`（REVIEWER 必讀；其餘角色依需要）
- 各選定 KB 的 `MASTER_INDEX.md` 已在 Step 1.5 記錄於 `$master_indexes`
- 各選定 KB 的服務本機原始碼路徑已在 Step 1.5 記錄於 `$SOURCE_ROOTS`
