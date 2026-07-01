---
name: sre
description: >
  SRE 工作流程。收到 Jira Story 後評估上線風險，產出部署策略選擇，再依選擇產出完整上線 Checklist。
---

# SRE 工作流程

角色定義見 `{{role_sre}}`

---

## Step 1 — 詢問 Jira 單號

```
請輸入要分析的 Jira 單號（例：PROJ-123），或直接貼上 Story 內容：
```

- 若輸入單號格式 → 嘗試用 Jira MCP 拉取 issue 內容
- 若 Jira MCP 不可用或失敗 → 請使用者直接貼上 Story 文字
- 若使用者直接貼文字 → 直接使用

---

## Step 2 — 載入 System Context

依序讀取：
1. `{{master_index}}` — 服務清單與路由規則
2. `{{sre_index}}` — SRE 知識庫路由索引（文件清單 + 關鍵字路由規則）

---

## Step 3 — 分析 Story，讀取相關文件

### 3a — SRE 知識庫（按需載入）

參照 `{{sre_index}}` 的「路由規則」，依 Story 關鍵字判斷需要讀取哪些 SRE 文件。

每次只讀取與本次 Story 相關的文件，不全部預載。

### 3b — 服務文件

參照 `{{master_index}}` 的「AI 文件路由規則」判斷哪些 service 受影響。

每個涉及的 service，依序讀取：
1. `knowledge/source-codex/services/{service}/index.md` — 了解流量路徑與架構
2. `knowledge/source-codex/services/{service}/facts.md` — 業務邏輯事實（若涉及）

---

## Step 4 — 產出 Phase 1（部署策略選擇）

```
## 方案 A：{部署策略標題}
- 做法：（直接部署 / Blue-Green / Canary / Feature Flag）
- 優點：
- 缺點：
- 風險等級：低 / 中 / 高
- 適合當：

## 方案 B：{部署策略標題}
- 做法：
- 優點：
- 缺點：
- 風險等級：
- 適合當：

---
請問您選擇方案 A 還是方案 B？
```

---

## Step 5 — 等待選擇，產出 Phase 2（完整上線 Checklist）

### 影響範圍分析
| Service | 影響程度 | 說明 |
|---------|---------|------|

### 流量路徑變化
（文字說明或 ASCII 圖）

### 上線前檢查項目
- [ ] DB migration 腳本已審核
- [ ] Config 變更已推送到 Config 管理分支（依專案約定，確認部署前已同步）
- [ ] Kafka topic 是否需要新增（留意 consumer group offset）
- [ ] gRPC proto 是否向後相容
- [ ] Redis key 格式是否有異動（需清快取？）

### 監控告警設定
| 指標 | 告警條件 | 通知管道 |
|------|---------|---------|

### Rollback 條件與步驟
- Rollback 觸發條件：（例如 error rate > 1%，latency p99 > 2s）
- Rollback 步驟：
  1.
  2.

### 上線後觀察清單（前 30 分鐘）
- [ ] Error rate
- [ ] Kafka consumer lag
- [ ] Redis 命中率
- [ ] DB slow query

---

## 關注重點
- Config 變更需 push 至 Config 管理分支（依專案約定），部署前確認
- Kafka topic 新增不影響現有 consumer，但 partition 數量要確認
- gRPC proto 異動的向後相容性
- MongoDB / Oracle DDL 是否需要停機視窗
