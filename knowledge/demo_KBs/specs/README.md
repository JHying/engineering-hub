# Specs Knowledge Base

## 目的

記錄各 Jira ticket 的需求規格（spec）與實作知識（impl）。

## Spec vs Impl 分工

| 文件類型 | 建立時機 | 記錄內容 |
|---------|---------|---------|
| **Spec** (`{TICKET}.md`) | Story 建立 / 分析時 | **要做什麼**：功能目標、驗收條件、資料流、影響範圍、特殊限制 |
| **Impl** (`impls/{TICKET}-impls.md`) | 實作完成後 | **做了什麼**：AC 與 class 對應、系統流程、測試方式、SA 規格（Redis key / Kafka topic / DB schema） |

## AI 路由規則

| 條件 | 讀取文件 |
|------|---------|
| Story / AC 出現 ticket 單號 | `{TICKET}.md`（spec，若存在）+ `impls/{TICKET}-impls.md`（impl，若存在）|
| 撰寫新 spec | `spec-format.md` |
| 撰寫新 impl | `impls/impls-format.md` |
