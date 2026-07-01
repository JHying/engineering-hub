---
date: 2026-06-27
keywords: Docker, Container, Image, Dockerfile, Docker Hub, VM, 容器化, 虛擬化, Bridge Network
---

# Docker 容器化基礎概念

**日期**：2026-06-27  
**關鍵字**：Docker, Container, Image, Dockerfile, Docker Hub, VM, 容器化, Bridge Network

## 問題背景

傳統虛擬機器（VM）資源消耗大、啟動慢；Docker 透過容器化提供更輕量的應用隔離與部署方式，廣泛用於開發環境一致性、微服務部署與 CI/CD 流水線。

---

## 研究結論

### 一、Docker 核心概念

**Docker** 是一種軟體平台，可快速建立、測試和部署應用程式或環境。

**主要特性：**
- 幾乎可在所有作業系統執行（只需 Docker Engine）
- 比 VM 更輕量：容器只虛擬化 OS 內核，不模擬硬體
- 每個容器獨立隔離、有獨立 IP（類似內網的獨立伺服器）
- 映像檔（Image）可從 Docker Hub 拉取，拉下即可執行

---

### 二、基本元件

| 元件 | 說明 |
|------|------|
| **Image 映像檔** | 應用程式、資料庫、服務的模板（唯讀） |
| **Container 容器** | 執行中的 Image 實例，可讀寫 |
| **Docker Hub** | 雲端映像檔倉庫（公/私有），類似 npm registry |
| **Dockerfile** | 建立自訂 Image 的建構腳本 |

```
Docker Hub（映像倉庫）
    │  docker pull
    ▼
Docker Engine（安裝在 OS 上）
  ┌──────────────────┐
  │  Container        │  ← Image 的執行實例
  │  [app / service]  │
  └──────────────────┘
```

---

### 三、Docker vs 虛擬機器（VM）

| 特性 | Docker Container | VM |
|------|-----------------|-----|
| 啟動速度 | 秒級 | 分鐘級 |
| 資源消耗 | 少（僅虛擬 OS 內核） | 多（含完整 OS） |
| 隔離性 | 程序級（共享 Host OS Kernel） | OS 級（獨立 Kernel） |
| 可移植性 | 高（Image 跨環境一致） | 較低（OS 依賴） |
| 適用場景 | 微服務、CI/CD、開發環境 | 需強隔離的應用 |

> Windows / macOS 上執行 Docker 仍需虛擬化層（如 Hyper-V、VirtualBox），因為 Docker Engine 需要 Linux Kernel。

---

### 四、Docker 網路架構

Docker 網路是 Host 主機中完全隔離的虛擬網路，透過 **IPv4 forward** 處理流量：

```
Host
│
├── eth0（對外網路）
│
├── alpine-net（自訂橋接網路）172.18.0.1/16
│   ├── Container A  172.18.0.2  ← 同網路可用 container name 互連
│   └── Container B  172.18.0.3
│
└── bridge docker0（預設橋接）172.17.0.1/16
    └── Container C  172.17.0.2
```

**重點：**
- 同一自訂橋接網路（Custom Bridge Network）內的容器可互相通訊，並以 **container name 作為 hostname**
- 若需從外界存取，需設定 port mapping（`-p 8080:80`）並確認防火牆 forwarding 設定
- 一個容器可加入多個網路（擁有多個 IP）

---

### 五、常用 Docker Compose 概念

Docker Compose 以 YAML 描述多容器應用的編排，常用指令：

```bash
docker compose up -d      # 建立並啟動所有服務（背景）
docker compose down       # 停止並移除容器
docker compose logs -f    # 追蹤所有服務 log
docker ps -a              # 查看所有容器狀態
```

---

## 參考

- 來源：Notion 開發學習筆記 — Docker > Docker 基礎概念
