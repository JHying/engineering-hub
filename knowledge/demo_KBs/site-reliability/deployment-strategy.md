# 部署策略

## 策略選擇指引

| 策略 | 適用場景 | 風險等級 | 環境支援 |
|------|---------|---------|---------|
| **Blue-Green** | 大多數變更，需要即時切換能力 | 中 | staging、prod（預設）|
| **Canary** | 高風險功能，需要漸進流量切換 | 低 | 需調整 Argo Rollouts patch-strategy |
| **Istio Mirror** | 新版本驗證，不影響真實流量 | 最低 | 需額外 VirtualService 設定 |
| **Feature Flag** | 程式碼已部署但功能尚未對外開放 | 最低 | 應用層控制，與部署策略無關 |
| **直接部署** | dev 環境 / 緊急 hotfix | 高 | dev（Deployment，非 Rollout）|

## Blue-Green 操作流程

```
1. CD pipeline 推新 image tag → ArgoCD 更新 preview（新版）Pod 啟動
2. SRE 觀察 preview Pod 健康狀態（readinessProbe + Grafana Error Rate）
3. 確認正常後手動 promote：
   kubectl argo rollouts promote {service} -n {namespace}
   # 或 ArgoCD UI → Rollout → Promote
4. Istio VirtualService 自動切換 100% 流量到新版
5. 舊版（blue）保留一段時間，可快速 Rollback
```

`patch-strategy.yml` 關鍵設定：
```yaml
strategy:
  blueGreen:
    activeService: {service}
    previewService: {service}-preview
    autoPromotionEnabled: false   # 必須手動 promote，禁止自動
    scaleDownDelaySeconds: 300    # 舊版 5 分鐘後縮容
```

## Canary 操作流程

修改 `patch-strategy.yml` 為 canary 策略：
```yaml
strategy:
  canary:
    steps:
    - setWeight: 10      # 先導 10% 流量
    - pause: {}          # 暫停，等待人工確認（無逾時）
    - setWeight: 50
    - pause:
        duration: 5m     # 自動等待 5 分鐘
    - setWeight: 100
```

監控期間觀察：Error Rate、Latency p99、Kafka consumer lag。

## Istio Mirror（流量鏡像）

在 VirtualService 加入 mirror 設定，新版本接收鏡像流量但不影響使用者回應：
```yaml
mirror:
  host: {service}-canary
  port:
    number: 8080
mirrorPercentage:
  value: 100
```

適用場景：驗證新版邏輯是否正確，但不承擔線上流量風險。

## Rollback 操作

```bash
# 方式一：Argo Rollouts（推薦，秒級）
kubectl argo rollouts undo {service} -n {namespace}

# 方式二：ArgoCD UI → Rollback to previous revision

# 方式三：手動更新 GitOps repo image tag，ArgoCD 自動同步
git revert HEAD && git push
```

**Rollback 觸發條件（建議）：**
- HTTP 5xx Error Rate > 1%（5 分鐘滾動視窗）
- Latency p99 > 2s 持續 5 分鐘
- Kafka consumer lag > 正常基準 3 倍持續 5 分鐘
- readinessProbe 連續失敗（Pod 進入 CrashLoopBackOff）
- 付款 Gateway 連線逾時 > 30% 持續 3 分鐘

## DB Migration 與部署順序

當 DB 變更為 **BREAKING** 時，部署順序必須嚴格遵守：

```
1. 執行 DB migration（DDL / DML）
2. 確認 DB schema 正確 → DBA 核可
3. 觸發 CD 部署新版應用程式
4. 禁止步驟 3 先於步驟 2（程式先上、migration 後執行會導致 prod 故障）
```

**BREAKING 判斷標準：**
- 刪除欄位 / 表格
- 修改欄位型態（縮短長度、改型別）
- 新增 NOT NULL 欄位且無 DEFAULT 值
- 修改 Kafka topic partition 數量

非 BREAKING（可 rolling deploy）：
- 新增欄位（允許 NULL 或有 DEFAULT）
- 新增 INDEX
- 新增 TABLE
