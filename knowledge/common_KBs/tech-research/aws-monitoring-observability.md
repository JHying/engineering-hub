---
date: 2026-06-26
keywords: AWS, CloudWatch, CloudTrail, Prometheus, Grafana, X-Ray, Observability, 監控, 稽核, AMP, App Mesh, Consul, SNS, CloudWatch Agent
---

# AWS 監控與可觀測性策略

## 問題背景

在 AWS 上運行容器化服務時，需要建立完整的可觀測性體系，包含指標收集（Metrics）、分散式追蹤（Tracing）、日誌（Logs）、以及告警機制。

---

## CloudWatch — AWS 原生監控服務

CloudWatch 為 AWS 推出的**監控服務**，能夠監控大多數的 AWS 服務，可統一查看所有軟硬體相關日誌。

| 監控類型 | 負責方 |
|---------|--------|
| **硬體監控** | AWS 透過 CloudWatch 幫你完成 |
| **軟體監控** | 你自己透過 CloudWatch Logs 蒐集 |

### Metrics（指標）視覺化

- **Metric（指標）**：CloudWatch 的基本概念，可以是要監控的變數。例如 EC2 Instance 的 CPU 用量就是 AWS 提供的指標之一。
- **Dimension（維度）**：Metric 的一部分，類似把資料做分類，可將維度連接到每個指標，用維度來篩選 CloudWatch 回傳的結果。

### Alarm 機制

- 為蒐集到的 Log 設定警示條件，當達到條件時發 Alarm
- 可搭配 **SNS** 服務對管理者進行 Email 或手機推播通知

### CloudWatch Agent

CloudWatch 預設**無法**監控機器內的**記憶體用量**與**硬碟內部用量**。

- 必須主動在 EC2 Instance 安裝 **CloudWatch Agent**
- 可將軟體的 Log 寫在指定的資料夾位置，再透過 Agent 蒐集回去

```
CloudWatch ←─[Log Stream]─ Agent（EC2）
                                |
                        多個 Log Streams
                                |
                        Log Group（統整管理）
```

### CloudWatch Event

- 由應用程式丟出或資源記錄的活動事件
- 可透過 CloudWatch Event 觸發其他 AWS 資源進行後續操作
- 可用來即時監視應用程式或 AWS 資源

---

## CloudTrail — 稽核記錄服務

CloudTrail 是 AWS 提供的**稽核記錄服務**，記錄所有 AWS 帳戶的 API 呼叫與事件。

- 記錄**誰**在**何時**對哪些資源做了什麼操作
- 適合：安全稽核、法規遵循、操作排障

---

## 全套可觀測性架構（K8s / EKS 環境）

### 工具分工

| 功能 | 方案 |
|------|------|
| Service Discovery & Config | Consul Helm (sidecar) |
| Mesh & Zero Trust | App Mesh (sidecar) |
| 分散式追蹤 (Trace) | X-Ray Daemon |
| Resource Metrics | AWS Managed Prometheus (AMP) |
| 可視化 | AWS Managed Grafana |
| 告警 | CloudWatch Alarm 或 Prometheus AlertManager |

### 資料流向

```
Pod 內 Envoy Proxy（App Mesh sidecar）
  ├── L7 Trace → X-Ray Daemon（透過 localhost）→ X-Ray
  └── Metrics（由 Prometheus scrape）

Node / Pod 資源指標
  └── Managed Prometheus (AMP)

Grafana Datasource：
  ├── AMP（資源監控 Dashboard）
  ├── X-Ray（分散式追蹤可視化）
  └── CloudWatch（AutoScaling / Load Balancer Metrics）
```

### 各工具說明

**App Mesh**
- 負責 Service-to-Service 流量管理（sidecar 模式）
- Envoy Proxy 內建可把 trace 送到 X-Ray Daemon

**Consul**
- 負責跨 Pod 的服務註冊、KV 配置
- 可選做健康檢查

**X-Ray**
- 負責 Envoy 內的 L7 請求鏈路追蹤
- 在 Pod 或 DaemonSet 中跑一個 X-Ray Daemon，Envoy Proxy 透過 localhost 傳 trace

```bash
# 給 Pod IAM Role 權限
AWSXRayDaemonWriteAccess
```

**Prometheus & Grafana**

```
Managed Prometheus 從 K8s 直接抓 kube-state-metrics & node-exporter

Managed Grafana 建立 Datasource：
  - Prometheus: 資源監控
  - X-Ray: 分散式追蹤可視化
  - CloudWatch: AutoScaling / Load Balancer Metrics
```

### IAM 設定（IRSA）

| 服務 | IAM 權限 |
|------|---------|
| Prometheus | AWSManagedPrometheusReadOnlyAccess |
| Grafana | AWSGrafanaReadOnlyAccess |
| X-Ray Daemon | AWSXRayDaemonWriteAccess |

---

## CloudWatch vs AWS Managed Prometheus（AMP）

| 項目 | CloudWatch | AMP |
|------|-----------|-----|
| **定位** | AWS 原生統一監控服務 | CNCF Prometheus 的完全託管版 |
| **支援資料類型** | 系統指標、自定義指標、AWS 服務 Metrics、Logs、Events | 主要收集 Prometheus 格式的 Metrics |
| **資料收集** | Agent（EC2、ECS）/ AWS 服務內建 | Prometheus scrape（Exporter、ServiceMonitor） |
| **查詢語言** | AWS 自定義 | **PromQL** |
| **適合場景** | AWS 原生服務監控、簡易告警 | K8s 環境、需要 PromQL 彈性查詢 |

**選擇建議**：
- 純 AWS 原生服務（EC2、RDS、Lambda）→ CloudWatch 即可
- K8s（EKS）環境、需要 PromQL / Grafana Dashboard → AMP + Managed Grafana
- 分散式追蹤 → X-Ray（已與 App Mesh / Envoy 整合）

---

## 大規模系統監控成本估算參考

> 以下為大規模系統（同時 1,000 萬人在線、每秒 100 萬並發請求）的監控成本參考，架構為微服務（Helm Consul + EKS + App Mesh + Fargate）。

### 監控架構成本概覽

| 功能 | 工具 | 粗估月成本 (USD) |
|------|------|----------------|
| Metrics | Managed Prometheus + CloudWatch | $10,000 ~ $20,000 |
| Trace | X-Ray | $20,000 ~ $40,000 |
| Logs | OpenSearch（ELK） | $15,000 ~ $30,000 |
| 可視化 | Managed Grafana | $300 ~ $1,000 |
| 告警 | AlertManager + CloudWatch Alarm | 包含在上面 |
| **小計** | — | **~$46,000 ~ $91,000** |

> 以上**只包含**監控/Trace/Log，**不包含** EKS Node + Auto Scaling EC2 成本（通常是最大宗）。

### 各項服務成本說明

**AWS Managed Prometheus**
- 計價依據：Ingested Metrics (DPM) + 儲存天數
- 1,000 萬人級別通常產生每秒 50~100 萬個 time series
- 粗估每月約 **$10,000 ~ $20,000 USD**

**CloudWatch**
- 收集基礎 AWS Infra Metrics（EKS、EC2、NLB）
- 僅 Metrics 每月約 **$1,000 ~ $2,000 USD**
- Logs 從輸出到 CloudWatch 費用偏高

**AWS Managed Grafana**
- 計價按 Active User / Workspace Hours
- SRE/PM/RD 10~20 人同時查看 Dashboard
- 每月約 **$300 ~ $1,000 USD**

**X-Ray**
- 計價依 Trace Segment 數量，每百萬個 Trace 約 $5 USD
- 100 萬 RPS，10% 取樣 = 100,000 RPS 被 trace
- 粗估每月約 **$20,000 ~ $40,000 USD**

**ELK（OpenSearch Service）**
- 1,000 萬用戶的 Chat/WSS 日誌量非常大，Log 吞吐量至少數 TB/天
- 通常需要至少 10~30 台 r6g.large.search 節點
- 粗估每月約 **$15,000 ~ $30,000 USD**

## 參考

- [CloudWatch 文件](https://docs.aws.amazon.com/cloudwatch/)
- [CloudTrail 文件](https://docs.aws.amazon.com/cloudtrail/)
- [AWS Managed Prometheus](https://docs.aws.amazon.com/prometheus/)
- [X-Ray 文件](https://docs.aws.amazon.com/xray/)
