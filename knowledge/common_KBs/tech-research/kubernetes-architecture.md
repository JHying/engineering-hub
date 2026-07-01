---
date: 2026-06-27
keywords: Kubernetes, K8s, Pod, Node, Master, Cluster, kubelet, kube-scheduler, etcd, kubectl
---

# Kubernetes 架構元件：Pod、Node、Master 與 Cluster

**日期**：2026-06-27
**關鍵字**：Kubernetes, K8s, Pod, Worker Node, Master Node, kubelet, kube-apiserver, etcd, kube-scheduler

## 問題背景

K8s 是容器編排的事實標準，理解其核心元件架構是進行 DevOps 工作、設定 GKE/EKS/AKS 或除錯 Pod 問題的基礎。

---

## 研究結論

### 一、四大核心元件

#### 1. Pod

K8s **運作的最小單位**，一個 Pod 對應一個應用服務。

- 每個 Pod 有一個 YAML 描述檔（身分證）
- 一個 Pod 通常只跑一個 Container（Sidecar 場景除外）
- 同一 Pod 內的 Container 共享網路和存儲，透過 localhost 互通

#### 2. Worker Node

K8s **運作的最小硬體單位**，對應一台機器（實體機或 VM）。

| 組件 | 說明 |
|------|------|
| **kubelet** | 該 Node 的管理員，管理所有 Pod 狀態並與 Master 溝通 |
| **kube-proxy** | 傳訊員，負責維護 Node 的 iptables 路由規則 |
| **Container Runtime** | 容器執行引擎（如 containerd、Docker Engine） |

#### 3. Master Node

K8s **指揮中心**，管理所有 Worker Node。

| 組件 | 說明 |
|------|------|
| **kube-apiserver** | 整個 K8s 的 API 接口，Node 間溝通橋樑 |
| **etcd** | 分散式 KV 資料庫，存放整個 Cluster 狀態備份 |
| **kube-controller-manager** | 確保實際狀態與期望狀態一致（如 Deployment 副本數） |
| **kube-scheduler** | Pod 調度員，根據資源評估最適合的 Node |

#### 4. Cluster

多個 Worker Node + Master Node 的集合。

---

### 二、Node / Pod / Container 三者關係

```
Cluster
  └─ Node（一台機器）
       └─ Pod（最小部署單位，一個應用服務）
            ├─ Container 1（主應用）
            └─ Container 2（Sidecar，如 Envoy）
```

---

### 三、建立 Pod 的流程

```
1. 使用者執行 kubectl apply -f pod.yaml
2. 指令透過身分驗證送到 Master 的 kube-apiserver
3. kube-apiserver 將 Pod 定義備份到 etcd
4. kube-scheduler 評估 Node 資源，選擇最適合的 Node
5. kube-controller-manager 協調確保 Pod 被建立
6. 目標 Node 的 kubelet 命令 Container Runtime 建立 Container
```

---

### 四、K8s 關鍵資源類型

| 資源 | 說明 |
|------|------|
| **Deployment** | 管理無狀態應用，定義副本數和更新策略 |
| **StatefulSet** | 管理有狀態應用（如 DB），Pod 有固定身份 |
| **Service** | 提供穩定的 IP/DNS 給 Pod，實現負載均衡 |
| **ConfigMap** | 非敏感設定注入 |
| **Secret** | 敏感資訊（密碼、Token）注入 |
| **PersistentVolume** | 持久化存儲 |
| **Ingress** | HTTP/HTTPS 流量入口，路由到不同 Service |
| **Namespace** | 邏輯隔離，同一 Cluster 內分割環境 |

---

### 五、Service 類型

| 類型 | 說明 | 用途 |
|------|------|------|
| **ClusterIP** | 只在 Cluster 內部可達（預設） | 服務間內部通訊 |
| **NodePort** | 在每個 Node 上開放固定 Port | 開發測試 |
| **LoadBalancer** | 雲端 Load Balancer（GKE/EKS 建立） | 對外暴露服務 |
| **ExternalName** | 映射到外部 DNS | 代理外部服務 |

---

### 六、DevOps 工具鏈

| 工具 | 說明 |
|------|------|
| `kubectl` | K8s CLI，操作 Cluster 的主要入口 |
| Helm | K8s 套件管理器，用 Chart 打包應用 |
| Minikube / K3s | 本地輕量 K8s，用於開發測試 |
| ArgoCD / Flux | GitOps 工具，從 Git 自動同步 K8s 狀態 |
| Istio / Envoy | Service Mesh，管理服務間流量和安全 |

---

## 參考

- 來源：Notion 開發學習筆記 — DevOps > Kubernetes 架構元件
