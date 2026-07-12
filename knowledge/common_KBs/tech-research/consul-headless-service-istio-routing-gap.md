---
date: 2026-07-12
keywords: Consul, Helm, Headless Service, StatefulSet, Istio, Envoy, PassthroughCluster, Service Discovery, Kubernetes, DNS, Failover
---

# Consul Headless Service 與 Istio 不導流的節點故障事故

## 問題背景

應用程式以 Kubernetes service name 連線由官方 Consul Helm chart 部署的 consul-server。當單一
Consul server pod 掛掉後，client 持續連向已死掉的 pod IP，未自動切換到其他健康的 Consul server
實例。環境中已導入 Istio 作為 service mesh，但觀察到 Istio 並未把流量導向健康實例，故障未被
mesh 層自動處理，需要釐清背後機制與可行對策。

> 事故現象（client 黏著死亡 pod IP、Istio 未介入導流）為第一手維運觀察；以下根因分析屬一般
> 技術知識整理，**尚未逐項查證官方文件**，後續若查證 Consul / Istio 官方文件可再補充更新。

## 研究結論

### 根因分析

1. **StatefulSet + Headless Service 是官方 chart 的預設拓樸**：consul-server 以 StatefulSet
   部署，搭配 headless Service（`clusterIP: None`）。StatefulSet 需要 headless service 提供
   per-pod 穩定 DNS，供 Raft peer 之間互相定址（例如 `consul-server-0.consul-server.<ns>.svc`）。

2. **Headless Service 沒有 L4 VIP 分流層**：一般 ClusterIP Service 會由 kube-proxy 建立 VIP 並
   做連線層負載平衡；headless service 沒有 ClusterIP，DNS 查詢會直接回傳**全部 pod IP 的 A
   records**，由 client 自行從中挑選連線目標。也就是說，「該連哪個 pod」的決定權從 Kubernetes
   下放給了 client。

3. **Client 端會黏著（sticky）已選定的 pod IP**：DNS 解析結果通常會被 client（如 JVM DNS
   cache）快取，加上 HTTP keep-alive / 長連線的特性，一旦建立連線就傾向持續使用同一個 IP。pod
   掛掉後，failover 的責任完全落在 client 身上（重新解析 DNS + 重建連線），但多數 client
   library 預設不會主動做這件事，導致故障後仍持續嘗試連向已死亡的 IP。

4. **Istio 對 headless service 走 original destination passthrough，設計上不介入**：因為
   headless service 沒有 VIP，Envoy 無法（也不會）在多個 endpoint 之間做負載平衡或 outlier
   ejection，而是直接尊重 client 已經解析並選定的目的地 pod IP，讓流量原樣穿透
   （passthrough）。這類流量在遙測（telemetry）上通常顯示為 `PassthroughCluster` 或
   `unknown`，因為它沒有經過 Envoy 的服務發現與路由決策路徑。這解釋了為何 Istio 明明存在，卻
   沒有把故障 pod 的流量導向健康實例——不是 bug，而是 headless service 語意下的預期行為。

5. **副作用：passthrough 流量以明文（plaintext）方式發起**。若目標 pod 的 sidecar 設定為
   STRICT mTLS，這類 passthrough 連線會直接被拒絕，是排查此類問題時容易被忽略的另一個面向。

### 對策

- **應用端改走有 ClusterIP 的 Service 連 Consul API**（✅ 本事故**實際採用並驗證有效**的解法，
  第一手經驗）：另建一個 ClusterIP Service，selector 對到 consul server pods，並將應用服務設定
  中的 Consul 位址改指向該 ClusterIP service；Helm chart 原本的 headless service 保留不動
  （StatefulSet / Raft peer 定址仍需要它）。readiness probe 失敗即會把該 pod 從 endpoints
  移除，新連線會自動導向健康 pod，把 failover 責任交還給 Kubernetes 的 service layer，而不是
  依賴 client 自行處理。
- **改採 DaemonSet client agent 模式**（其他可行方向，本事故未實際採用）：應用程式改連本機
  hostIP 上的 local Consul agent，由該 agent 負責與 server cluster 之間的通訊與 failover，
  應用端不直接面對 server cluster 的拓樸變化。
- **Client 端補強**（其他可行方向，本事故未實際採用；屬輔助手段，非取代上述架構調整）：
  調低 DNS TTL、實作斷線後重連並重新解析 DNS，降低黏著死亡 IP 的時間窗口。

### 補充：常見性、命名澄清與方案比較（2026-07-12 追加）

> 本節屬一般技術知識整理，**未逐項查證官方文件**。

**1. 雙 Service 模式是常見做法**

headless Service 供 StatefulSet 成員互相定址（peer discovery）、另建 ClusterIP Service 供
外部 client 存取，是 Kubernetes 上 stateful 叢集的慣用模式。許多官方 Helm chart 本身就同時
建立兩個 Service——例如 Kafka（broker headless + client service）、Redis、Elasticsearch 等
皆採此結構。本事故的解法（另建 ClusterIP Service）實際上就是把 Consul server 補齊成這個
慣用結構。

**2. 命名澄清：ClusterIP 的「cluster」是指什麼**

「ClusterIP」的 cluster 指的是 **Kubernetes cluster 內部可路由**——從 service CIDR 配發的
虛擬 IP（VIP），僅叢集內可達，與 NodePort / LoadBalancer / ExternalName 這些對外曝露的類型
相對；與「給 headless cluster 用」無關。ClusterIP 是 Service 的預設類型；headless service
其實正是 `type: ClusterIP` 搭配 `clusterIP: None` 的特例。

**3. ClusterIP Service vs DaemonSet client agent 比較**

| 面向 | ClusterIP Service | DaemonSet client agent |
|------|-------------------|------------------------|
| 架構複雜度 | 最簡單，零新增元件 | 多一層元件要維運（升級、資源、版本相容） |
| Failover 機制 | 交給 endpoints / readiness probe，Kubernetes 原生處理 | 應用連本節點 agent；節點死掉時應用 pod 也一起死，天然不存在黏著死 IP 問題 |
| Istio / mesh 整合 | 流量有 VIP 之後，Istio 可正常套用路由、遙測、mTLS | hostIP 連線不經 mesh 政策 |
| Server 負載 | 所有 client 請求直接打到 server cluster：無本地快取，blocking query / watch 負載全上 server | 本地快取、聚合 blocking query、就地健康檢查，可大幅降低 server 負載 |
| Client agent 功能 | 用不到本地健康檢查等 client agent 功能 | Consul 傳統架構（每節點一個 agent），功能完整 |
| 適用場景 | 中小規模、主要用 KV config 的場景 | 大規模、重度使用 service discovery / 健康檢查的場景 |

**補充趨勢**：HashiCorp 在 Kubernetes 上已改推 agentless 的 Consul Dataplane 模式
（consul-k8s 1.0 / Consul 1.14 起），DaemonSet client agent 不再是 K8s 上的預設建議——
此點同樣**未查證**，需以官方文件為準。

## 參考

- 呼應共用 ADR：[knowledge/common_KBs/ADRs/05-infrastructure/0001-service-discovery-and-config-backbone.md](../ADRs/05-infrastructure/0001-service-discovery-and-config-backbone.md) —
  「routing 交給 Kubernetes DNS、Consul 只當 config backbone」的決策，本事故是該決策的實證
  rationale 之一：headless service 語意下 Consul server 本身的 service discovery 並不適合直接
  承擔可路由性（routability）的角色。
