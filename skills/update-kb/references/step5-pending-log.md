<!-- 由 SKILL.md Step 5（含 5-1、5-2）連結，完整明細與 log 範例。 -->

## Step 5 — 清理 Pending + 記錄 Log

對每個 `$PROJECT_KB`：

### 5-1 清理 pending

| 來源 | 清理方式 |
|------|---------|
| `{$PROJECT_KB}/pending/jira.txt` | 移除已成功處理的 ticket ID 行，保留失敗或跳過的 |
| `{$PROJECT_KB}/pending/` 下的其他 `.md` 檔案 | 刪除已整合到 KB 的檔案 |

### 5-2 寫入更新 Log

> **禁止**將任何子代理輸出的「去識別化對照表」寫入此 log（或任何其他檔案）。Log 中的共用 ADR / 通用技術研究段落僅記錄檔案清單與「已確認去識別化」狀態，不含對照表內容。

建立或追加 `{$PROJECT_KB}/pending/logs/update-{YYYY-MM-DD}.md`：

```markdown
## {YYYY-MM-DD HH:MM} KB 更新記錄

### 觸發模式
{排程自啟動 / 使用者自啟動}

### 目標專案 KB
{$PROJECT_KB}

### 更新來源
{ticket ID 清單 / pending 檔案名稱 / 使用者描述}

### 更新結果

#### PM KB
- 建立：{檔案清單}
- 更新：{檔案清單}
- 待補充：{[待補充] 項目清單}

#### RD KB
- 建立：{檔案清單}
- 更新：{檔案清單}
- cross/ 異動：{項目清單}

#### SRE KB
- 建立：{檔案清單}
- 更新：{檔案清單}

#### 專案 ADR（{$PROJECT_KB}/ADRs/，若有更新）
- 建立：{ADR 檔案清單}
- 修訂：{ADR 檔案清單 + 翻轉決策摘要}

#### 共用 ADR（knowledge/common_KBs/ADRs/，若有更新）
- 建立：{ADR 檔案清單（已確認去識別化）}

#### 通用技術研究（knowledge/common_KBs/tech-research/，若有更新）
- 建立 / 更新：{tech-research 筆記清單（已確認去識別化）}

#### Review History KB（{$PROJECT_KB}/review-history/，若有更新）
- 建立：{review 記錄檔案清單}
- 更新：{追加審查段落的檔案清單}
- index.md：{有異動 / 無異動}

#### Meta 檔案
- MASTER_INDEX：{有異動 / 無異動}
- paths.yml：{有異動 / 無異動}
- flow 檔案：{有異動 / 無異動}
- README.md：{有異動 / 無異動}

### 清理 pending
- 已移除：{清單}
- 保留（失敗 / 跳過）：{清單}
```
