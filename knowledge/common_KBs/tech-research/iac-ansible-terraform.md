---
date: 2026-06-27
keywords: IaC, Infrastructure as Code, Ansible, Terraform, Playbook, Provider, 宣告式, DevOps, 自動化
---

# IaC（Infrastructure as Code）：Ansible 與 Terraform

**日期**：2026-06-27
**關鍵字**：IaC, Ansible, Terraform, Playbook, Provider, 宣告式, 命令式, GitOps, 自動化

## 問題背景

手動建立和設定伺服器、網路、資料庫容易造成環境不一致和人為錯誤。IaC 將基礎設施定義為程式碼，解決可重複性、一致性和版本控制問題。

---

## 研究結論

### 一、IaC 核心概念

**Infrastructure as Code（IaC）** 是使用程式碼（而非手動程序）來佈署和管理遠端運算基礎設施的能力。

#### 優點

- **環境可複製**：相同的 IaC 可部署到不同環境（dev / staging / prod）
- **減少組態錯誤**：消除人工手動設定的不一致
- **版本控制**：基礎設施變更可 Git 追蹤，支援 Code Review

#### 兩種方法

| 方法 | 說明 | 代表工具 |
|------|------|---------|
| **命令式（Imperative）** | 明確指定每一個執行步驟 | Bash, Ansible（部分用法） |
| **宣告式（Declarative）** | 描述期望的最終狀態，工具自動計算如何達到 | Terraform, Kubernetes YAML |

> Declarative 是主流趨勢，更適合大規模管理。

---

### 二、Ansible：設定管理與應用部署

#### 定位

Ansible 是**設定管理工具**，解決「如何在多台已存在的機器上安裝軟體、設定環境」的問題。

- 無 Agent：被管理的機器只需 **SSH + Python**，不需要安裝任何 Agent
- 使用 YAML（Playbook）描述任務，接近自然語言

#### 架構

```
使用者
  ↓
Control Node（安裝 Ansible）
  ├─ Inventory   （主機清單，記錄所有 Managed Node 的 IP）
  ├─ Modules     （預建功能：安裝套件、啟動服務、複製檔案...）
  └─ Playbook    （YAML 任務腳本，組合多個 Module）
       ↓ SSH + Python
Managed Nodes（遠端機器）
  ├─ Host A
  ├─ Host B
  └─ ...
```

#### 範例 Playbook

```yaml
---
- name: Install and start Apache
  hosts: webservers
  become: yes
  tasks:
    - name: Install Apache
      apt:
        name: apache2
        state: present
    - name: Start Apache
      service:
        name: apache2
        state: started
```

#### 適用場景

- 批量設定伺服器環境（如安裝 JDK、Nginx）
- 應用部署（停服務 → 更新檔案 → 啟動）
- 網路設備設定（Cisco Switch 等）

---

### 三、Terraform：基礎設施佈署

#### 定位

Terraform 是**基礎設施佈署工具**，解決「如何在雲端建立 VPC、EC2、DB、Load Balancer 等資源」的問題。

> **Terraform vs Ansible 分工**：Terraform 建立基礎設施，Ansible 在建好的機器上安裝設定軟體。

#### 架構

```
Terraform Config（.tf 檔案）
    ↓
Terraform Core
  ├─ 讀取 State（基礎設施當前狀態）
  ├─ 比對 Config vs State（計算差異）
  └─ 透過 Provider 執行變更

Providers（雲端 API 橋接）
  ├─ AWS Provider
  ├─ GCP Provider
  ├─ Azure Provider
  └─ Kubernetes Provider
```

#### 基本工作流程

```bash
terraform init      # 初始化，下載 Provider plugins

terraform plan      # 預覽將建立/修改/刪除的資源（Dry Run）

terraform apply     # 執行，建立實際基礎設施

terraform destroy   # 刪除所有 Terraform 管理的資源
```

#### 範例：AWS EC2

```hcl
provider "aws" {
  region = "us-west-2"
}

resource "aws_instance" "app_server" {
  ami           = "ami-830c94e3"
  instance_type = "t2.micro"

  tags = {
    Name = "AppServerInstance"
  }
}
```

#### 適用場景

- 建立雲端網路架構（VPC、子網、安全組）
- 佈署 EC2 / GCE / AKS / GKE 叢集
- 管理 IAM 角色和權限
- 多環境基礎設施（dev/prod 共用同一套 config，參數化差異）

---

### 四、工具對比總覽

| | Ansible | Terraform |
|-|---------|-----------|
| 主要用途 | 設定管理、應用部署 | 基礎設施佈署 |
| 方法論 | 命令式為主 | 宣告式 |
| 狀態管理 | 無內建 State | 有 State 檔（.tfstate） |
| 雲端平台 | 多平台 Module | 多平台 Provider |
| 學習曲線 | 低（YAML） | 中（HCL 語法） |
| 典型組合 | Terraform 建環境 + Ansible 設定機器 | |

---

### 五、GitOps（補充）

**GitOps** 是 IaC 的進一步延伸：Git 作為唯一的真實來源（Source of Truth），CI/CD 工具（如 ArgoCD）自動將 Git 狀態同步到 Cluster。

```
開發者 push 到 Git → ArgoCD 偵測變更 → 自動部署到 K8s
```

---

## 參考

- 來源：Notion 開發學習筆記 — DevOps > IaC 簡介 / Ansible / Terraform
