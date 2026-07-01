# pending/ 目錄說明

## 用途

存放「尚未整理進正式 KB」的內容，作為暫存區。

## 子目錄

| 子目錄 / 檔案 | 說明 |
|-------------|------|
| `jira.txt` | 等待整理成 spec 的 Jira ticket 單號清單 |
| `logs/` | KB 更新紀錄（`update-YYYY-MM-DD.md`） |

## 處理流程

```
新 Jira ticket
      ↓
  pending/jira.txt（加入單號）
      ↓
  /update-kb（觸發 AI 整理）
      ↓
  specs/{TICKET}.md 建立完成
      ↓
  pending/jira.txt 移除該單號
  pending/logs/update-{date}.md 記錄本次異動
```

## 注意

- `logs/` 目錄保留所有更新紀錄，不定期清理
- pending 內容不作為 AI 回答的知識來源，整理完成後才算正式進 KB
