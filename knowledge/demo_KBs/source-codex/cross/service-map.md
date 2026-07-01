# Service Map

各服務 KB 同步狀態與基本資訊。

| 服務 | KB 路徑 | KB 狀態 | 最後同步 commit | 負責人 |
|------|---------|---------|----------------|--------|
| order-service | `source-codex/services/order-service/` | ✅ 已同步 | abc1234 | Team A |
| payment-service | `source-codex/services/payment-service/` | 🔲 待建立 | — | Team B |
| notification-service | `source-codex/services/notification-service/` | 🔲 待建立 | — | Team B |
| api-gateway | `source-codex/services/api-gateway/` | 🔲 待建立 | — | Team A |

## KB 狀態說明

| 符號 | 意義 |
|------|------|
| ✅ 已同步 | index.md + facts.md 均存在且與 code 一致 |
| ⚠️ 部分同步 | 文件存在但可能落後 N commits |
| 🔲 待建立 | 尚未建立 KB 文件 |
