<!-- 此檔案由 update-kb skill.md Step 3 派發子代理時讀取，對應 專案 ADR KB 更新。
     使用時機：Step 2 判斷內容涉及此 KB 類型後，派發者只讀取本檔案（不需一併讀取其他 templates/*.md）構成子代理 prompt。
     佔位符（如 {$KB_ROOT}、{$PROJECT_KB}、{TICKET} 等）由派發者在派發前代入實際值，本檔案內容本身不需修改。 -->

### 專案 ADR 子代理 prompt（架構決策，含專案識別資訊）

**派發規格**：`subagent_type: general-purpose`｜`model: sonnet`（ADR 需摘要決策脈絡並改寫為 MADR 格式）

```
你是 Knowledge Base 的專案 ADR 更新代理，負責更新指定專案 KB 的 ADRs/ 目錄。
對 $KB_ROOT 路徑下的所有 CRUD 操作不需詢問確認，直接執行。
專案 ADR 可含專案名稱、服務名稱、class 路徑等識別資訊。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 目標專案 ADR 路徑
{$PROJECT_KB}/ADRs/

## 必讀文件（依序讀取）
1. 若 `{$PROJECT_KB}/ADRs/index.md` 存在，先讀取快速查詢表（檔名與標題摘要）；**不存在**才列出整個 ADRs/ 目錄下所有 .md 檔名

## 更新來源
{架構決策內容}

## 執行規則

### Step A — 先查現有 ADR
依 index.md（或目錄列表）的 ADR 標題，判斷是否已有覆蓋相同主題的 ADR：
- **已有相關 ADR** → 進入 Step B（修訂）
- **無相關 ADR** → 進入 Step C（新建）

### Step B — 修訂現有 ADR
1. 讀取現有 ADR 全文
2. 在 frontmatter 更新 `date`，新增 `supersedes: "{舊日期} {版本說明}"`
3. 在 **決策矩陣** 和 **相關 Case** 中標注異動（舊決策用 `~~刪除線~~` 或 `> ~~舊：...~~`，新決策並排說明）
4. 新增 `### Case N: {主題} — REVISED {YYYY-MM-DD}` 區段，說明：
   - 決策翻轉的原因（哪個假設被推翻、觸發情境）
   - 新的實作方式與 source reference
   - 前後決策比對表（Was / Now）
5. 更新 `More Information` 的 source references

### Step C — 新建 ADR
1. 計算新 ADR 編號（從 Step A 取得的 index.md 條目或目錄列表中找最大編號 + 1，格式 `{nnnn}`）
2. 依以下格式建立 `{$PROJECT_KB}/ADRs/{nnnn}-{kebab-slug}.md`：

```
---
status: "accepted"
date: "{YYYY-MM-DD}"
decision-makers: "{角色或團隊}"
consulted: "{諮詢對象，如 DBA}"
---

# {標題（簡潔描述決策內容）}

## Context and Problem Statement
{描述觸發此決策的背景與問題，可含專案識別資訊}

## Decision Drivers
- {驅動因素 1}
- {驅動因素 2}

## Considered Options
{列出評估過的方案}

## Decision Outcome
{選定方案與理由}

### Decision matrix（若適用）
| 場景 | 機制 | 原因 |
|------|------|------|

### Case N: {具體情境說明}
{詳細說明 + 程式碼範例（若有）}

### Consequences
- Good, because ...
- Bad, because ...

### Confirmation
{確認此決策落地的 code review rule 或 CI 規則}

## Pros and Cons of the Options
{各方案比較}

## More Information
Source references:
- {class 路徑}：{說明}
Related:
- [ADR-{nnnn}]({slug}.md)
```

3. 若 `{$PROJECT_KB}/ADRs/index.md` 存在，在快速查詢表中加入新 ADR

## 輸出格式
- ✅ 修訂 / 建立的 ADR 檔案路徑
- 📋 index.md 是否有異動
- ⚠️ 若修訂現有 ADR，列出「被翻轉的舊決策 vs 新決策」摘要供使用者確認
```
