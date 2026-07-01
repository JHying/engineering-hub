# 環境清單 — 訂單平台【DEMO】

## 環境一覽

| 環境 | 用途 | 網域（示意） | 部署方式 |
|------|------|------------|---------|
| dev | 開發者本機整合測試 | localhost | Docker Compose |
| test | 功能測試 / QA 驗收 | test.internal.example.com | K8s（測試 cluster） |
| staging | 上線前完整驗收（mirror prod 設定） | staging.internal.example.com | K8s（staging cluster） |
| prod | 正式環境 | api.example.com | K8s（prod cluster）|

## 環境差異

| 項目 | dev | test | staging | prod |
|------|-----|------|---------|------|
| DB | H2 / local Oracle | 共用測試 Oracle | 獨立 Oracle（prod 快照） | 正式 Oracle |
| Kafka | 本機 Docker | 共用測試 Kafka | 獨立 Kafka | 正式 Kafka |
| Redis | 本機 Docker | 共用測試 Redis | 獨立 Redis | 正式 Redis（Sentinel） |
| Log 保留 | 3 天 | 7 天 | 14 天 | 90 天 |
| 副本數 | 1 | 1 | 2 | 3 |

## 部署架構圖（示意）

```
[User] → CDN → Load Balancer
                    ↓
              [api-gateway Pod × 3]
              ↙        ↘
   [order-service × 3]  [payment-service × 2]
          ↓                      ↓
      Oracle DB              Oracle DB
      Redis                  （共用）
      Kafka ──────────────► [notification-service × 2]
```

## 注意事項

- staging 環境的 Kafka topic 與 prod 完全隔離，無法跨環境消費
- prod 僅接受來自指定 IP 段的部署請求（透過 GitOps pipeline）
- prod 資料庫禁止直接 DML，所有 schema 異動須走 Migration SOP
