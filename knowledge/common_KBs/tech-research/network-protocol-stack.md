---
date: 2026-06-27
keywords: OSI, TCP/IP, DNS, CDN, TLS, HTTPS, 網路分層, 傳輸層, 應用層, DDoS
---

# 網路協議棧：DNS、CDN、OSI/TCP/IP 與 TLS

**日期**：2026-06-27
**關鍵字**：OSI, TCP/IP, DNS, CDN, TLS, HTTPS, 三次握手, 網路分層, DDoS

## 問題背景

理解網路請求從 URL 輸入到資料回傳的完整路徑，對系統架構設計（CDN 策略、HTTPS 配置、Load Balancer 選型）至關重要。

---

## 研究結論

### 一、DNS 概念

DNS（Domain Name System）將人類可讀的域名解析為 IP 位址。

- `briian.com` → 連到網站主機
- `blog.briian.com` → 連到部落格主機（子域名可指向不同機器）

**DNS 伺服器只做路由指引，不存放網頁內容本身。**

---

### 二、CDN 加速原理

**CDN（Content Delivery Network）** 在全球佈署節點，使用者請求就近的 CDN 節點而非源伺服器，縮短延遲。

#### CDN 快取流程

```
用戶 → DNS 解析 → CDN 節點 IP
用戶 → CDN 節點
  ├─ Cache Hit  → 直接回應（快速）
  └─ Cache Miss → 向源伺服器取得 → 快取 → 回應用戶
```

#### CDN 多地區架構

```
        源伺服器
        /   |   \
TW EDGE   HK EDGE   JP EDGE
台灣節點   香港節點   日本節點
   |          |          |
台灣用戶    香港用戶    日本用戶
```

#### CDN + DDoS 防護

CDN 隱藏源伺服器 IP，作為防 DDoS 的第一道防線：
1. **清洗中心**：偵測異常流量，轉移至清洗中心
2. **WAF 規則**：封鎖惡意請求
3. **乾淨流量**：只有過濾後的合法流量到達源站

---

### 三、網路分層架構

#### OSI 七層 vs TCP/IP 四層

```
OSI 七層                TCP/IP 四層
應用層 (Application) ─┐
表示層 (Presentation)  ├→ 應用層（HTTP, SMTP, FTP, SSH）
會話層 (Session)      ─┘
傳輸層 (Transport)    ───→ 傳輸層（TCP, UDP）
網路層 (Network)      ───→ 網路互連層（IP）
連路層 (Data Link)    ─┐
物理層 (Physical)     ─┘→ 網路存取層（乙太網、光纖）
```

> 實際應用 90% 以上遵守 TCP/IP 協定。

#### 各層說明

| 層 | TCP/IP | 說明 | 代表協議 |
|----|--------|------|---------|
| 應用層 | Application | 定義應用標準 | HTTP, SMTP, FTP, SSH |
| 傳輸層 | Transport | Port 概念，可靠性控制 | TCP, UDP |
| 網路層 | Internet | IP 位址，路由 | IP |
| 連結層 | Link | MAC 位址，實體傳輸 | Ethernet |

#### TCP vs UDP

| | TCP | UDP |
|-|-----|-----|
| 可靠性 | 高（三次握手，重傳機制） | 低（不保證送達） |
| 延遲 | 較高 | 低 |
| 適用 | HTTP, SMTP, DB 連線 | 串流, DNS, 遊戲 |

#### TCP 三次握手

```
Client         Server
  │── SYN ──────→ │
  │← SYN-ACK ────│
  │── ACK ──────→ │
  (連線建立)
```

#### 數據封裝流程

```
發送端（由上往下加頭部）：
應用層：產生 HTTP 數據
  ↓ + TCP 頭部（Port）
傳輸層
  ↓ + IP 頭部（IP 位址）
網路層
  ↓ + Ethernet 頭部（MAC 位址）
連結層 → 實體傳輸

接收端反向解析
```

---

### 四、TLS（傳輸層安全性協定）

TLS 在 TCP 之上加密，與應用層協定（HTTP, FTP, SMTP）無耦合，任何應用層都能使用。

**HTTPS = HTTP + TLS**

#### TLS 交握流程

```
1. 客戶端 → 伺服器：列出支援的密碼套件
2. 伺服器 → 客戶端：選定密碼套件 + 數位憑證（含公鑰）
3. 客戶端：驗證憑證有效性
4. 客戶端：用伺服器公鑰加密隨機金鑰送出
5. 雙方：利用隨機數生成對稱金鑰，後續通訊用對稱加密
```

#### TLS 三大作用

| 作用 | 說明 |
|------|------|
| **加密** | 隱藏傳輸資料，防竊聽 |
| **身份驗證** | 確認伺服器身份（數位憑證） |
| **完整性** | 驗證資料未被篡改 |

> **SSL vs TLS**：SSL 是舊版（Netscape 開發），TLS 是 SSL 3.1 的繼承者，現在說的 SSL 憑證實際上都是 TLS。

---

## 參考

- 來源：Notion 開發學習筆記 — 網路 > CDN / DNS / 網路分層架構 / TLS
