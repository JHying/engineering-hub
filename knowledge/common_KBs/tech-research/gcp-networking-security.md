---
date: 2026-06-26
keywords: GCP, VPC, IAM, NEG, Instance Group, Load Balancer, Cloud Armor, WAF, IDS, DDoS, 網路安全, Serverless VPC Access
---

# GCP 網路與安全架構

## 問題背景

在 GCP 上部署多層服務時，需要妥善規劃網路隔離（VPC）、存取控制（IAM）、流量分配（Load Balancer、NEG）、與安全防護（Cloud Armor、Cloud IDS）。

---

## VPC 網路

Virtual Private Cloud (VPC) 是物理網路的虛擬版本，在 Google 的生產網路內部使用 **Andromeda** 實現。

### VPC 特性

- VPC 網路是**全球性資源**，與任何特定地區或區域均無關聯
- **子網屬於地區性資源**，每個子網定義一個 IPv4 地址範圍
- VPC 內的資源可使用內部 IPv4 地址互通
- 進出流量可透過網路防火牆規則控制

### VPC 功能

- 為 Compute Engine VM、GKE 叢集、App Engine 彈性環境提供連接
- 支援內部 HTTP(S) 負載平衡、TCP/UDP 負載平衡和代理系統
- 透過 Cloud VPN 通道和 Cloud Interconnect 連接本地網路

### Serverless VPC Access 連接器

讓 Serverless 服務（Cloud Run、App Engine 等）不走公共網路、直接連進 VPC。

> 每個 VPC 連接器需有自己的 /28 子網，此子網不得有除連接器以外的任何其他資源。

**建立步驟**：

1. 確保已為專案啟用 **Serverless VPC Access API**
2. 前往 Serverless VPC Access 概覽頁面
3. 點擊「建立連接器」
4. 輸入名稱（長度 ≤ 21 字元，連字號 `-` 計為 2 個字元）
5. 選擇地區（**必須與 Serverless 服務的地區相匹配**）
6. 選擇 VPC 網路
7. 子網設定（實際子網 or 自訂 IP 範圍，如 `10.8.0.0`）
8. 可選：設定擴縮選項（預設 2～10 個實例）
9. 點擊「建立」，完成後名稱旁出現綠色對勾

```bash
# 查看子網 purpose 是否為 PRIVATE
gcloud compute networks subnets describe SUBNET_NAME
```

---

## IAM 角色權限管理

### 角色類型

| 類型 | 說明 |
|------|------|
| **基本角色** | Owner / Editor / Viewer，對所有 GCP 服務有數千項權限（生產環境謹慎使用） |
| **預定義角色** | 針對特定服務的精細訪問權限，由 Google Cloud 管理 |
| **自定義角色** | 根據用戶指定的權限列表提供精細訪問權限 |

### 基本角色嵌套關係

```
Owner
  └── Editor 的全部權限
        └── Viewer 的全部權限
               └── 讀取權限
```

> ⚠️ 在生產環境中，除非沒有替代角色，否則請勿授予基本角色。應授予最受限制的預定義角色或自定義角色。

### 服務帳號 (Service Account)

命名格式：`SA_NAME@PROJECT_ID.iam.gserviceaccount.com`

- ID 必須介於 6 到 30 個字元
- 可包含小寫字母數字字元和短劃線
- **建立後無法更改名稱**

### 以 Cloud DNS 為例，設定服務帳號操作權限

1. 在 Cloud DNS 設定服務帳號，確保具有 DNS 權限（或設為 DNS 管理員）
2. 產生服務帳號的 JSON key
3. 其他環境可透過此 JSON key 進行身份驗證，進而操作 Cloud DNS

```bash
# 透過 key 開啟 gcloud 權限
gcloud config set account [SERVICE_ACCT_EMAIL]
gcloud auth activate-service-account [SERVICE_ACCT_EMAIL] --key-file=[KEY_FILE_NAME].json

# 整合 gcloud docker 權限
gcloud auth configure-docker [DOCKER_REGION].pkg.dev
# 範例
gcloud auth configure-docker asia-east1-docker.pkg.dev

# 查看當前 gcloud 已註冊的帳戶
gcloud auth list
```

---

## 網路端點群組 (Network Endpoint Group, NEG)

NEG 讓 Load Balancer 可將流量分配到更細粒度的端點（如 Pod level 而非 VM level）。

### NEG 類型

| 類型 | 用途 | NetworkEndpointType | 端點數量 |
|------|------|---------------------|---------|
| **區域性 NEG** | Compute Engine VM 或 GKE Pod 的內部 IP | `GCE_VM_IP` / `GCE_VM_IP_PORT` | 1 個以上 |
| **網際網路 NEG** | 託管在 GCP 外部的單一互聯網可路由端點 | `INTERNET_IP_PORT` / `INTERNET_FQDN_PORT` | 全球 1 / 區域 256 |
| **無伺服器 NEG** | App Engine / Cloud Functions / Cloud Run 的 FQDN | 服務 FQDN | 1 |
| **混合連接 NEG** | 混合連接場景 | — | — |
| **私人服務連接 NEG** | Private Service Connect | — | — |

> 無伺服器 NEG 不適用健康檢查。

---

## 執行個體群組 (Instance Group)

### 類型比較

| 類型 | 說明 |
|------|------|
| **MIG（託管型）** | 支援自動擴容、自動修復、滾動更新、多區域 |
| **Unmanaged（非託管型）** | 可包含異質個體，最多 2,000 個 VM，不提供自動化功能 |

### MIG 功能

| 功能 | MIG | Unmanaged |
|------|-----|-----------|
| 自動擴容 | ✅ | ❌ |
| 自動修復 | ✅ | ❌ |
| 滾動更新 | ✅ | ❌ |
| 多區域支援 | ✅ | ❌ |
| 負載平衡 | ✅ | ✅ |

**MIG 適合場景**：無狀態服務（Web 前端）、批次高效能計算、有狀態應用（資料庫）

> ℹ️ 使用 MIG 或 Unmanaged 均無額外收費，依群組使用的資源計費。

---

## Load Balancer（前後端導流轉送）

### 整體網路架構

```
使用者
  ↓ 訪問網域
Cloud DNS
  ↓ 導轉到 LB IP
Load Balancer  ← HTTPS 憑證設置於此
  ↓ 根據轉送規則
Instance Group / NEG
  ↓
Web Server / API Server
```

### 前置需求

1. 申請 Domain
2. 將 domain 設定到 Cloud DNS 代管
3. 透過 Let's Encrypt 申請 SSL 憑證（或選擇 Google 代管）
4. 建立執行個體群組 (Instance Group)

### 建立步驟

**步驟 1：建立執行個體群組**
- Group type 先選 **Unmanaged Instance Group**（不要自動擴充）
- Region 與 Zone 選擇與預計導流的 VM **相同地區**

**步驟 2：建立應用程式負載平衡器 (HTTP/S)**

前端配置（對外服務的 Port）：
- 選 HTTPS，放上預先申請的憑證
- 可同時開放 HTTP
- 建議使用 **Google 代管憑證**（免費 0～20 個，但不支援 wildcard）

> 強烈建議使用 Google 代管，就不用擔心憑證自動更新。LB 建好後要到 DNS 將該網域指向 LB IP，才會完成簽發。

後端服務設定：

| 類型 | 適用場景 |
|------|---------|
| 後端服務 | API 服務，支援 GCE、GAE、GCR |
| 後端值區 | 導流前端靜態資源（Cloud Storage） |

**健康檢查 (Health Check)**：

```
建立健康檢查：通訊協議 TCP + API 通訊埠

需開通防火牆給 LB Health Check，IP 共四組：
  35.191.0.0/16
  130.211.0.0/22
  209.85.152.0/22
  209.85.204.0/22
```

**步驟 3：設定網址轉送規則**
- 建立轉送規則，先將所有流量導到 backend
- 後端出現綠色勾勾即表示服務健康

**步驟 4：回到 Cloud DNS 設定 A Record**
- 新增 A Record，指向 Load Balancer IP
- 完成後憑證才會生效

> 建立 LB 後所有專案自動註冊 Cloud Armor 標準方案。LB 的防火牆政策要到 Cloud Armor 設定。

---

## Cloud Armor（DDoS 防護 + WAF）

### 架構

```
使用者
  ↓
Google Cloud CDN
  ↓ 經過 WAF 過濾檢查
Cloud Armor (Security Policy)
  - DDoS 防護
  - IP 白/黑名單
  - SQL Injection / XSS 防護
  - 地理位置限制
  ↓
Load Balancer
  ↓
後端服務（Instance Group / Cloud Run / GKE）
```

### 主要功能

- 依地理位置限制存取
- 預先配置的 WAF 規則阻擋 SQL Injection 和 XSS
- 自訂第 7 層 (L7) 程式碼過濾
- 與 Google Cloud SCC 整合
- 符合產業法規合規性要求

### Security Policy 類型

| 類型 | 適用範圍 |
|------|---------|
| **Backend Security Policy** | 過濾對後端服務（Instance Group、NEG）的請求 |
| **Edge Security Policy** | 為緩存內容設定過濾，適用後端服務與後端值區 |

### WAF 規則類型

| 規則 | 說明 |
|------|------|
| `CVE-Canary` | 檢查相關 CVE 漏洞 |
| `XSS-Stable` | 跨網站攻擊檢查 |
| `Sqli-stable` | SQL Injection 攻擊檢查 |
| `lfi-stable` | 本地文件漏洞檢查 |
| `Rfi` | 遠端文件漏洞檢查 |

> 白名單是最常被使用的防護機制，能防止不認識的 IP 存取應用服務。

---

## Cloud IDS（入侵偵測）

Cloud IDS 是**入侵偵測服務**，為網路上的入侵、惡意軟體、間諜軟體和命令控制攻擊提供威脅偵測。

### 運作原理

1. 使用**鏡像號 VM** 建立 Google 管理的對等網路
2. 對等網路中的流量經過鏡像
3. 由 **Palo Alto Networks 威脅防護技術**進行檢查
4. 提供進階威脅偵測

### 重要特性

- 提供南北向和東西向流量的完整可見性
- 可監控 VM 到 VM 通訊以偵測橫向移動
- 滿足 **PCI 11.4** 和 **HIPAA** 合規性要求
- ⚠️ **只偵測、發出警報，不採取措施防止攻擊**（需搭配 Cloud Armor）

### 建立步驟

1. GCP Console → IDS Endpoints → Create endpoint
2. 輸入 Endpoint 名稱
3. 選擇要檢查的 Network
4. 選擇 Region 和 Zone
5. Continue → 選擇服務檔案（警報級別）
6. Create（約需 10～15 分鐘）

**建立完成後，附加 Packet Mirroring 政策**：
1. 點擊 IDS Endpoints → 選擇剛建立的 endpoint → Attach
2. 輸入 Packet Mirroring 政策名稱
3. 選擇要鏡像的子網或實例（可多選）
4. 選擇鏡像方式：鏡像全部流量 or 依協議/IP/方向過濾
5. Submit

**查看威脅記錄**：IDS Threats 標籤 → 點擊威脅名稱 → View threat logs

---

## Compute Engine 網路與防火牆

### VPC 子網範例

```
us-east1
  ├── VM-A  (10.0.0.2)
  └── VM-B  (10.0.0.3)     ← 子網 10.0.0.0/24

asia-east1
  ├── VM-C  (10.140.0.2)
  └── VM-D  (10.140.0.3)   ← 子網 10.140.0.0/20
```

### 防火牆規則設定

| 設定項 | 說明 |
|--------|------|
| **目標標記** | 對應 VM 建立時設定的「網路標記」（Network Tag） |
| **來源範圍** | 指定 IP 或 CIDR；`0.0.0.0/0` 表示不限 |
| **通訊協定** | TCP / UDP / ICMP 等 |
| **連接埠** | 如 80、443、22、8080 |

> 💡 使用 **Network Tags** 而非直接指定 VM IP 管理防火牆，方便統一對一組 VM 套用規則。

### Compute Engine 連接 Cloud SQL（Private IP）

```bash
# 安裝 MySQL Client
sudo apt-get update && sudo apt-get install mysql-client

# 使用 Cloud SQL Private IP 連線（需同一 VPC）
mysql -h <CLOUD_SQL_PRIVATE_IP> -u <USER_NAME> -p
```

前置條件：Cloud SQL 執行個體須開啟 Private IP，且與 Compute Engine 在相同 VPC 網路下。

## 參考

- [GCP Load Balancing 文件](https://cloud.google.com/load-balancing/docs)
- [NEG 文件](https://cloud.google.com/load-balancing/docs/negs)
- [Cloud IDS 概述](https://cloud.google.com/intrusion-detection-system/docs/overview)
- [Compute Engine 防火牆規則](https://cloud.google.com/vpc/docs/firewalls)
