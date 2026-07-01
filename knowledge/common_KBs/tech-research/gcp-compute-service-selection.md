---
date: 2026-06-26
keywords: GCP, Serverless, Cloud Functions, App Engine, Cloud Run, Compute Engine, GKE, IaaS, PaaS, CaaS, gcloud, CLI
---

# GCP 計算服務選擇指南

## 問題背景

將應用程式部署至 GCP 時，面臨多種計算服務可選擇（Cloud Functions、App Engine、Cloud Run、GKE、Compute Engine），需要依據應用類型、控制需求與擴展策略選出最適合的服務。

---

## Serverless 概念

Serverless（無伺服器架構）是全託管計算服務，讓開發者只需準備好應用程式本體，基礎架構（負載平衡、擴容、部署）由雲端平台負責。

> 💡 只要寫好 Code，剩下的部署問題通通不用煩惱。

---

## GCP 計算服務對應表

| 準備內容 | 服務 | 說明 |
|---------|------|------|
| 只有程式碼 | **Cloud Functions** | 事件驅動的無伺服器函數 |
| Node.js、Java web 專案 | **App Engine** | 適用 web project，自動擴容 |
| Container Image | **Cloud Run** | 容器化應用的部署 |
| Container 群組（大規模） | **GKE** | 代管 Kubernetes |
| 需要完整 OS 控制 | **Compute Engine** | IaaS 虛擬機器 |

---

## 如何選擇合適的 GCP 計算服務

```
我的應用是否需要容器？
       |
  No ←━━━→ Yes
  |              |
  |           是否需要完整控制機器？
  |              |
  |        No ←━━→ Yes
  |        |         |
  |     Cloud Run   Compute Engine
  |     (Container)   (VM)
  |
  是否只有函數程式碼？
       |
  Yes ←━→ No
   |         |
Cloud     是 web 專案 (Node.js/Java)？
Functions    |
         Yes ←→ No
          |       |
       App     其他選擇
       Engine
```

### 服務比較表

| 服務 | 內容類型 | 自動擴容 | 控制度 | 適合場景 |
|------|---------|---------|--------|---------|
| **Cloud Functions** | 函數程式碼 | ✅ | 最低 | 事件驅動、輕量工作 |
| **App Engine** | Web 專案 (Node.js, Java) | ✅ | 低 | 傳統 Web App |
| **Cloud Run** | Container Image | ✅ | 中 | 容器化微服務 |
| **GKE** | Container 群組 | ✅ (HPA) | 高 | 大規模 K8s 工作負載 |
| **Compute Engine** | VM | ❌ (手動) | 最高 | 需要完整 OS 控制 |

---

## 安裝 Google Cloud CLI

### Windows

- 安裝檔：https://cloud.google.com/sdk/docs/install
- 壓縮檔：https://cloud.google.com/sdk/docs/downloads-versioned-archives

下載後執行 `GoogleCloudSDKInstaller.exe`，一路按下一步。

> ⚠️ 支援 Python 版本：**3.10 – 3.14**（Windows 版本內建 Python 3）（2026-06 更新）

安裝後執行 `gcloud init`，完成帳戶 / default project / Region 設定，完成後輸入 `gcloud version` 出現版本代表成功。

#### 問題排除：SSL 驗證失敗

```bash
# 關閉 SSL 驗證並更新
gcloud config set auth/disable_ssl_validation True
gcloud components update
```

### Linux (Debian/Ubuntu)

```bash
# 1. 更新套件
apt-get update

# 2. 安裝相依套件
apt-get install apt-transport-https ca-certificates gnupg curl

# 3. 匯入 Google Cloud 公開密鑰 (Debian 9+ / Ubuntu 18.04+)
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
  gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# 4. 新增 gcloud CLI distribution URI 為套件來源
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
  https://packages.cloud.google.com/apt cloud-sdk main" | \
  tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# 5. 更新並安裝 gcloud CLI
apt-get update && apt-get install google-cloud-cli
```

**Docker 內安裝（單一 RUN 步驟）**：

```dockerfile
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
    https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update -y && apt-get install google-cloud-sdk -y
```

---

## 常用 gcloud 指令

```bash
# 辨識與帳戶
gcloud auth list                          # 確認帳戶資訊
gcloud config set account `ACCOUNT`       # 重新設定登入帳戶
gcloud config list project                # 確認目前 project ID

# App Engine
gcloud app create --region asia-east1     # 建立 App Engine（asia-east1 = 台灣彰化）
gcloud app browse                         # 測試 App Engine 部署狀態
gcloud app logs read                      # 觀看 logs

# Cloud SQL
gcloud sql instances describe [執行個體ID]   # 查看 Cloud SQL 資訊

# GKE
gcloud container clusters create [cluster name] \
  --num-nodes 2 \
  --machine-type n1-standard-1 \
  --region asia-east1               # 建立 cluster（asia-east1 各地區各放 2 node）

gcloud container clusters get-credentials CLUSTER_NAME \
  --region=COMPUTE_REGION           # 取得特定 cluster 的 credentials
```

---

## App Engine 部署（Java Spring Boot）

1. 設定為 Java 並安裝 Cloud SDK 至本機
2. 啟用 Cloud Build API
3. 在 Spring Boot 專案更新 `pom.xml`，新增 App Engine plugin（需要 Java 11+）
4. 新增 App Engine 設定檔（`src/main/appengine/app.yaml`）
5. 執行 Maven build 並部署：

```bash
mvn appengine:deploy
```

6. 測試：

```bash
gcloud app browse
# 或直接訪問
http://<project-id>.de.r.appspot.com

# 查看 logs
gcloud app logs read
```

---

## Cloud Run 部署步驟

> ⚠️ 開始前需先將 Image 存放在 **Artifact Registry**。

1. GCP Console → 無伺服器 → Cloud Run → 建立服務
2. 選取容器映像檔（從 Artifact Registry 選取）
3. 填寫服務名稱、Region
4. 進階設定 → 設定容器通訊埠
5. Ingress 設定：
   - 允許所有流量（公開對外）
   - 內部 + 允許 LB 傳出流量（透過 LB 代管）
6. 驗證：允許未經驗證的叫用
7. 建立完成後點擊 URL 測試

**與自訂網域整合**：服務建立後可「新增整合作業」，Google 自動產生 Load Balancer。

## 參考

- [Google Cloud SDK 安裝文件](https://cloud.google.com/sdk/docs/install)
- [App Engine 文件](https://cloud.google.com/appengine/docs)
- [Cloud Run 文件](https://cloud.google.com/run/docs)
