# 告警指標

> 以下告警指標需依專案實際基準調整後，填入 AlertManager rules。
> AlertManager 各環境獨立部署，需分別配置（dev 環境建議關閉 Critical 告警）。

## 告警指標定義

### 通用（所有服務）

| 指標 | 告警條件 | 嚴重度 | 說明 |
|------|---------|-------|------|
| HTTP 5xx Error Rate | > 1% 持續 5min（滾動視窗） | Critical | 立即介入 |
| HTTP Latency p99 | > 2s 持續 5min | Warning | 效能劣化 |
| Pod Restart Count | > 3 次 / 1hr | Critical | CrashLoopBackOff 風險 |
| JVM Heap Usage | > 85% 持續 3min | Warning | OOM 風險 |
| JVM GC Pause（STW） | > 500ms 單次 | Warning | 影響 latency |
| DB Connection Pool | usage > 90% 持續 2min | Warning | 可能排隊阻塞 |
| Redis Connection Errors | > 0 持續 1min | Critical | 快取失效風險 |
| CPU Usage | > 80% 持續 5min | Warning | 需評估是否擴容 |

### Kafka 相關

| 指標 | 告警條件 | 嚴重度 | 說明 |
|------|---------|-------|------|
| Consumer Lag | > 正常基準 3 倍持續 5min | Warning | Consumer 消費能力不足 |
| Consumer Lag（DLQ topic） | > 0 持續 10min | Warning | 有訊息消費失敗進 DLQ |
| Producer Send Error Rate | > 0.1% 持續 5min | Critical | Kafka 寫入失敗 |

### payment-service 專屬

| 指標 | 告警條件 | 嚴重度 | 說明 |
|------|---------|-------|------|
| Gateway Timeout Rate | > 10% 持續 3min | Critical | 第三方金流異常 |
| PAYMENT_IDEMPOTENCY Insert Fail Rate | > 0 持續 5min | Warning | 可能有重複付款風險 |
| Compensation Scheduler 執行延遲 | > 10min 未執行 | Warning | 逾時補償排程異常 |

### notification-service 專屬

| 指標 | 告警條件 | 嚴重度 | 說明 |
|------|---------|-------|------|
| Email Provider CircuitBreaker State | OPEN 持續 2min | Critical | 主要 Email Provider 熔斷 |
| SMS Provider CircuitBreaker State | OPEN 持續 2min | Warning | 主要 SMS Provider 熔斷 |
| Notification FAILED Rate | > 5% 持續 5min | Warning | 通知發送失敗率偏高 |

## AlertManager 配置方向

```yaml
route:
  group_by: [alertname, service]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
      receiver: pagerduty
      group_wait: 0s      # Critical 立即通知，不等聚合
    - match:
        severity: warning
      receiver: slack
      group_wait: 5m      # Warning 聚合後通知

receivers:
  - name: pagerduty
    pagerduty_configs: [...]
  - name: slack
    slack_configs: [...]
```

## 上線後觀察清單（前 30 分鐘）

- [ ] HTTP Error Rate（5xx）是否維持 < 0.1%
- [ ] Latency p99 是否在基準線以下
- [ ] Kafka consumer lag 是否正常消費
- [ ] payment-service Gateway 呼叫成功率
- [ ] Redis 命中率是否正常
- [ ] DB connection pool 使用率
- [ ] JVM heap / GC 是否穩定
- [ ] Pod restart count = 0
- [ ] notification-service CircuitBreaker 狀態為 CLOSED
