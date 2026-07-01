---
date: 2026-06-26
keywords: GCP, GKE, Kubernetes, K8s, Istio, Service Mesh, CI/CD, Cloud Build, Cloud Deploy, Artifact Registry, DevOps, PVC, RBAC, Cloud Run
---

# GKE 架構、DevOps 工具鏈與 Service Mesh

## 問題背景

在 GCP 上以 Kubernetes 管理容器化微服務時，需要了解 GKE 的選型（Standard vs Autopilot）、CI/CD 工具整合、Volume 持久化儲存策略，以及 Service Mesh（Istio）如何管理服務間網路流量。

---

## GKE 核心特色

GKE 是 GCP 代管的 Kubernetes，K8s 有更新時 GKE 通常在一週內跟進。

### 三大能力

**1. 資源調度**
- 依 CPU 與資源使用率等指標自動調度 Pod 資源與 Node 數量
- 垂直自動調度 Pod (Vertical Pod Autoscaling)
- 資源不足時可向上擴充至 **15,000 個 Node**

**2. 安全性**

| 類型 | 說明 |
|------|------|
| 身份識別 | IAM（專案層級）+ RBAC（Cluster 層級） |
| 網路安全 | VPC Firewall、Private Cluster Mode、Network Policy |
| 應用程式安全 | 映像檔弱點掃描、部署雙重認證、GKE SandBox |

**3. 軟硬體自動化**
- Node 健康狀態偵測，出問題即觸發自動修復
- Kubernetes 發布新版本，GKE 自動更新
- 預設使用 Container-Optimized OS

### GKE 模式選擇

| 模式 | 說明 | 建議 |
|------|------|------|
| **Standard** | 手動模式，一切自己設定 | 生產環境建議 |
| **Autopilot** | Google 代管一切，以 Pod 數量計價 | 謹慎評估成本 |

---

## GKE 叢集架構與建立

### 運作架構

```
master node（GCP 維護，僅提供 API）
     |
worker nodes（GCE 實例）
  |-- node-1  (asia-east1-a)
  |-- node-2  (asia-east1-b)
  |-- node-3  (asia-east1-c)
```

**正確做法**：建立 cluster + node pool → 將 workload define 好並 apply → container 就會被建立並跑在這座 cluster 上。

### 叢集建立設定（GKE Standard）

| 設定 | 說明 |
|------|------|
| **Zone** | 台灣選 `asia-east1-a/b/c`，假設 HA 可選多個區域 |
| **發布版本** | 會自動更新 |
| **自動改善** | **Prod 環境建議關閉自動升級**（避免半夜多個 node 同時離線） |

### 節點集區（Node Pool）設定

| 設定 | 說明 |
|------|------|
| 節點數 | 每個 zone 的 node 數；選 HA 三個 zone 各 1 = 共 3 |
| Image 類型 | Container-Optimized OS + Containerd（GKE 新版預設） |
| **注意** | **Node 數建議 > 3 台**，否則更新時三台可能同時離線 |

**其他設定**：
- 垂直自動調度 Pod 資源：自動分析並調整 CPU 和記憶體
- 節點自動佈建：依工作負載需求建立/刪除 Node Pool

---

## GKE DevOps 工具鏈

在 GKE 環境中，所有設定（機器、容器、服務、權限）都可用 **YAML 檔**進行操作，使部署框架統一且透明。

### GCP CI/CD 工具

| 工具 | 功能 |
|------|------|
| **Cloud Source Repository** | 原始碼管理庫，功能與 GitHub 相似 |
| **Cloud Build** | Serverless CI/CD，偵測變更自動建置 / 存儲 / 部署 Image |
| **Artifact Registry** | 儲存容器用的 Image |
| **Cloud Deploy** | 全代管式 CD，建立不同 Cluster 間的 CD Pipeline |

### 架構流程

```
Code Push
  ↓
Cloud Source Repository / GitHub
  ↓
Cloud Build（自動建置 Image）
  ↓
Artifact Registry
  ↓
Cloud Deploy
  ├── Test Cluster  → 驗證
  └── Production Cluster → 部署
```

### 維運監控工具（GKE 建立時自動啟用）

- **Cloud Monitoring**：客製化指標，可建立 Dashboard
- **Cloud Logging**：完整記錄所有 GKE 資源的日誌

---

## Artifact Registry — Image 管理

### 上傳 Image 流程

```bash
# 1. 設定 gcloud 服務帳號權限
gcloud config set account [SERVICE_ACCT_EMAIL]
gcloud auth activate-service-account [SERVICE_ACCT_EMAIL] --key-file=[KEY_FILE_NAME].json

# 2. 整合 gcloud docker 權限
gcloud auth configure-docker asia-east1-docker.pkg.dev

# 3. 建立 Docker Image
docker build -t my-app .

# 4. 確認 Image
docker images

# 5. 建立上傳 tag（格式：REGION-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG）
docker tag my-app:latest asia-east1-docker.pkg.dev/[PROJECT_ID]/[REPO_NAME]/my-app:v1

# 6. 推送 Image
docker push asia-east1-docker.pkg.dev/[PROJECT_ID]/[REPO_NAME]/my-app:v1
```

> 🔒 可在 Artifact Registry 設定中啟用**弱點掃描**，上傳 Image 時自動執行。

### 同步更新到 Cloud Run

```bash
# 從檔案載入 Image
docker load > [FILE_NAME]

# 打 tag
docker tag [LOCAL_IMAGE:TAG] [REGISTRY_PATH/IMAGE:TAG]

# 上傳
docker push [REGISTRY_PATH/IMAGE:TAG]

# 部署至 Cloud Run
gcloud run deploy [SERVICE_NAME] \
  --image [REGISTRY_PATH/IMAGE:TAG] \
  --region [REGION]
```

---

## Cloud Run 持續部署（CD）

```
GitHub 代碼提交（Push）
  ↓
Cloud Build（需啟用 Cloud Build API + Container Analysis API）
  - 自動建置 Docker Image
  - 推送到 Artifact Registry
  - 自動部署到 Cloud Run
  ↓
Cloud Run（新版本上線）
```

**前置需求**：
- 開啟 **Cloud Build API**
- 開啟 **Container Analysis API**
- 原始碼存放區連接 GitHub

---

## Cloud Run 連接 Cloud SQL

### 方式一：透過 Private IP（建議）

```
Cloud Run
  └──[Serverless VPC Access Connector]──> VPC ──> Cloud SQL（Private IP:3306）
```

**前置步驟**：
1. 確保 Cloud SQL 已設定私人 IP 網路
2. 在私人 IP 網路（如 default）開啟 Serverless VPC Access API
3. 到 Serverless VPC Access 建立連接器：
   - 區域必須與 Cloud Run 位於相同地區
   - IP 範圍不能與現有 IP 重疊（使用 `10.8.0.0` 通常可行）

**Cloud Run 設定**：
- Cloud Run → 該服務 → 修改和部署新的修訂版本 → 連接 → VPC 連接器 → 選擇剛建立的連接器 → 部署

### 方式二：透過 Public IP

需先設定 Cloud Run 服務帳號具有 **Cloud SQL Client** 角色。

**Java DataSource 範例**（使用環境變數，避免硬寫憑證）：

```java
@Bean
public DataSource cloudSQLDataSource() {
    HikariConfig config = new HikariConfig();
    config.setDriverClassName("com.mysql.cj.jdbc.Driver");
    config.setJdbcUrl(String.format("jdbc:mysql://google/%s", System.getenv("DB_NAME")));
    config.setUsername(System.getenv("DB_USER"));
    config.setPassword(System.getenv("DB_PASS"));
    config.addDataSourceProperty("socketFactory", "com.google.cloud.sql.mysql.SocketFactory");
    config.addDataSourceProperty("cloudSqlInstance", System.getenv("INSTANCE_CONNECTION_NAME"));
    // ipTypes=PRIVATE 強制使用私人 IP 連接
    config.addDataSourceProperty("ipTypes", "PUBLIC,PRIVATE");
    config.setMaximumPoolSize(5);
    config.setMinimumIdle(5);
    return new HikariDataSource(config);
}
```

**Maven 套件**：
```xml
<dependency>
    <groupId>com.google.cloud.sql</groupId>
    <artifactId>mysql-socket-factory-connector-j-8</artifactId>
    <version>1.4.3</version>
</dependency>
```

**環境變數**（在 Cloud Run 部署設定中配置）：
- `DB_NAME` — 資料庫名稱
- `DB_USER` — 使用者名稱
- `DB_PASS` — 密碼
- `INSTANCE_CONNECTION_NAME` — Cloud SQL 連線名稱

---

## GKE Workload 部署

**部署步驟**：
1. 將應用程式 Image 上傳至 Artifact Registry
2. GKE Console → Workload → 部署容器
3. 選擇映像檔
4. 設定 persistent volume（透過 Kubernetes Manifest）

**Deployment + Service YAML 範例**：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: asia-east1-docker.pkg.dev/[PROJECT]/[REPO]/my-app:v1
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
```

```bash
kubectl apply -f deployment.yaml
kubectl get pods
kubectl get services
```

---

## GKE 操作權限設定

> 如果直接使用 **Google Cloud Shell**，就不需要以下權限設定。

```bash
# 確認是否已有 cloud-sdk repository
grep -rhE ^deb /etc/apt/sources.list* | grep "cloud-sdk"

# 安裝 kubectl
sudo apt-get install -y kubectl
kubectl version --client

# 安裝 gke-gcloud-auth-plugin（Kubernetes 1.26+ 必須）
sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
gke-gcloud-auth-plugin --version

# 更新 kubectl 權限
gcloud container clusters get-credentials CLUSTER_NAME \
  --region=COMPUTE_REGION
```

**RBAC 設定範例**：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-pods-global
subjects:
- kind: User
  name: user@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## GKE Volumes 持久化儲存

### Stateless vs Stateful

| 類型 | 特徵 | 範例 |
|------|------|------|
| **Stateless** | 不依賴任何資料儲存 | Web Server、API、微服務 |
| **Stateful** | 需要對資料做持久化儲存 | 資料庫、File Server、Cache、Queue |

### PersistentVolume 存取模式

| 模式 | 說明 |
|------|------|
| `ReadWriteOnce` | 只能單一節點讀寫 |
| `ReadOnlyMany` | 多節點只讀 |
| `ReadWriteMany` | 多節點讀寫 |
| `ReadWriteOncePod` | 只能單一 Pod 讀寫 |

> ⚠️ GCE persistent disk 只支援 RWO 和 ROX。需要所有 nodes 都能讀寫，最好使用 **Filestore** 或 **Cloud Storage**。

### GKE Storage 選項比較

| 類型 | CSI Driver | StorageClass | 存取模式 | 費用 |
|------|-----------|-------------|---------|------|
| **GCE 硬碟** | `pd.csi.storage.gke.io` | standard / premium-rwo | RWO only | 中 |
| **Filestore** | `filestore.csi.storage.gke.io` | — | ReadWriteMany | 高（最低 1TB，NT$6,000+/月） |
| **Cloud Storage FUSE** | `gcsfuse.csi.storage.gke.io` | — | ReadWriteMany | 低 |

> GCE 硬碟因硬碟特性，只支援 ReadWriteOnce，代表只能允許一個硬碟掛載使用。

### PVC YAML 範例

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: env-share-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: premium-rwo
```

**使用步驟**：
1. 設定 PVC 指定到預設的 storageClass (GCE disk)
2. 於 deployment.yml 指定 PVC，會依 PVC 配置自動建立並綁定 PV
3. 到 pod 裡面，在 volume 的路徑中加入想永久保存的檔案
4. 只要都指定同一個 PVC，即可共享同樣的 PV

### 啟用 GCS FUSE CSI Driver

```bash
# 確認 GCS FUSE CSI 是否已啟用
gcloud container clusters describe <CLUSTER_NAME>
# 確認 gcsFuseCsiDriverConfig 是否為 true

# 啟用
gcloud container clusters update <CLUSTER_NAME> \
  --update-addons GcsFuseCsiDriver=ENABLED \
  --region=<ZONE>
```

### Debug Pod 掛載 Volume（存取驗證）

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: debug-pod-deploy
  labels:
    app: debug-pod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: debug-pod
  template:
    metadata:
      labels:
        app: debug-pod
      annotations:
        gke-gcsfuse/volumes: "true"   # GCS FUSE CSI 必須加此 annotation
    spec:
      restartPolicy: Always
      serviceAccountName: gke-service-account
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: debug-container
        image: gotechnies/alpine-ssh:latest
        command: ["sh", "-c", "ls /mnt/env && sleep 3600"]
        volumeMounts:
          - mountPath: /mnt/env
            name: env-share-vol
      volumes:
      - name: env-share-vol
        persistentVolumeClaim:
          claimName: env-share-pvc
```

```bash
# 進入 pod
kubectl exec -it debug-pod -- /bin/sh

# 列出 volume 內容
ls /mnt/env

# 操作完成後刪除 debug pod
kubectl delete pod debug-pod
```

> 若目錄下只有 `lost+found`，表示 volume 是新建的，裡面尚無資料。

---

## Service Mesh 與 Istio

### 什麼是 Service Mesh

使用 Container 的網路服務，背後有多個程式做支撐，且有大量存取行為：
- **多版本 Application**：A/B 測試
- **負載平衡構成的連線關係**：Cloud Native 底下許多服務支援自動擴展
- **身份驗證**：跨服務鏈設置 P2P 身份驗證

這些行為統稱為 **Service Mesh**。

### Service Mesh 精神

> **管理不應該留給服務本身**。最好的做法是服務和它們所訪問的網路之間有一個獨立的系統，把網路管理責任全部交給 **Istio**。

### 採用 Istio 的好處

- 服務本身不必處理網路流量 load balance、routing、retry 等細節
- 為管理員提供抽象層：可輕鬆在 cluster 策略控制、監控和日誌、服務發現
- 提升 container 安全性：透過 TLS 進行安全的服務間（docker-to-docker）通訊

### Istio 與 GKE 整合

```bash
# 安裝 Istio
istioctl install --set profile=default -y

# 給 namespace 加上標籤，自動注入 sidecar proxy
kubectl label namespace default istio-injection=enabled
```

## 參考

- [GKE 文件](https://cloud.google.com/kubernetes-engine/docs)
- [Cloud Deploy 文件](https://cloud.google.com/deploy/docs)
- [Istio 文件](https://istio.io/docs/)
- [Cloud Run + Cloud SQL 連線](https://cloud.google.com/sql/docs/mysql/connect-run)
- [GKE Volumes](https://cloud.google.com/kubernetes-engine/docs/concepts/storage-overview)
