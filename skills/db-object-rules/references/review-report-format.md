# 審查報告格式（VII. Step 3 明細）

報告格式如下：

```
## DB Object 審查報告
檔案：<檔名>
類型：Oracle DDL / MongoDB DML / ...
審查時間：<日期>

### 命名與語法
✅ 檔名格式正確
❌ [第5條] 語句中有空白行 — 第 12 行與第 13 行之間有空行，請移除
⚠️ [建議] 第 3 欄位 COL3 未設定 DEFAULT Value，請確認是否需要

### Table
✅ Table Comment 已建立
❌ COL4 缺少 Column Comment

### Index
✅ 命名符合規則
⚠️ IDX_USERID 與 IDX_USERID_NAME 存在欄位包含關係，建議評估是否移除 IDX_USERID

### DML
❌ UPDATE 語句後缺少 COMMIT

### 申請流程提醒（請人工確認）
ℹ️ 本次為正式環境異動，請確認已在 2 天前通知 DBA
ℹ️ 若為新系統上線，請確認已在 2 週前通知 DBA
```
