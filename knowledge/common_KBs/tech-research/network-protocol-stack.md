---
date: 2026-06-27
keywords: OSI, TCP/IP, DNS, CDN, TLS, HTTPS, 網路分層, 傳輸層, 應用層, DDoS, VIP, ClusterIP, kube-proxy, iptables, IPVS, L4, L7, Load Balancer, WebSocket, STOMP, Subprotocol, Jakarta WebSocket
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

### 五、Kubernetes VIP 與 L4/L7 分流（2026-07-12 追加）

> 本節屬一般技術知識整理，**未逐項查證官方文件**。

#### 1. Kubernetes 的 VIP（Virtual IP）

- ClusterIP Service 的 IP 是從叢集 service CIDR 配發的「虛擬 IP」：沒有任何實體網卡或 pod
  綁定這個 IP，它只存在於每個節點上 kube-proxy 寫入的轉譯規則（iptables DNAT 或 IPVS）中。
- 封包送往 `VIP:port` 時，在節點上被 DNAT 改寫成某個後端 `pod IP:port`——「選哪個 pod」就
  發生在這一步。
- 因為只是規則而非真實網路端點，VIP 本身通常 ping 不到，這是「virtual」的由來。

#### 2. L4 分流是什麼

- kube-proxy 的分流決策只看 L3/L4 資訊（來源/目的 IP、port、協定），發生在 **TCP 連線建立
  時**：每條新連線挑一個後端，之後該連線的所有封包都固定走同一個 pod。
- 它完全看不懂 HTTP 內容：無法做 per-request 分流、無法依 path/header 路由、無法重試。
- 推論：對 keep-alive / 長連線而言，L4 分流只在「重新建線」時才有再平衡機會——pod 死掉會
  斷 TCP，client 重連時 DNAT 就會挑到健康 pod。這正是 Consul 事故中 ClusterIP 解法生效的
  機制層面解釋。
- 對照：headless service 連這層 L4 DNAT 都沒有，選 pod 完全交給 client 的 DNS 解析。

#### 3. L7 分流對照

L7（應用層）分流由 proxy 實作（Envoy/Istio、NGINX Ingress、HAProxy 等）：看得懂 HTTP/gRPC，
能做 per-request 路由、依 path/header/version 分流、重試、熔斷、金絲雀。

| 面向 | L4 分流 | L7 分流 |
|------|---------|---------|
| 決策依據 | IP:port（連線層資訊） | HTTP/gRPC 內容（path、header、method） |
| 分流粒度 | per-connection（每條連線固定一個後端） | per-request（每個請求可獨立路由） |
| 代表實作 | kube-proxy（iptables/IPVS）、雲端 NLB | Envoy/Istio、NGINX Ingress、HAProxy、雲端 ALB |
| 成本 | 核心層轉發，低開銷 | 需終結連線、解析協定，開銷較高 |

Istio 屬 L7，但它的路由建立在 Service/VIP 模型之上——這也呼應
[consul-headless-service-istio-routing-gap.md](consul-headless-service-istio-routing-gap.md)
中「headless 流量 Istio 不介入」的根因。

---

### 六、WebSocket 與 Subprotocol 分層：STOMP 與自訂協議（2026-07-12 追加）

> 本節屬一般技術知識整理，**未逐項查證官方文件**。

#### 1. OSI 在 L7 之上沒有編號，但協議會繼續往上疊

OSI 模型到 L7 為止，但現代協議常見「L7 疊 L7」：gRPC 疊在 HTTP/2 上、STOMP 疊在 WebSocket
上、WebSocket 本身以 HTTP/1.1 Upgrade 握手起始。嚴格分層編號在 L4 以上已不太適用，重點是
「誰提供傳輸、誰提供語意」。

#### 2. WebSocket（RFC 6455）是刻意設計成「笨管道」的 L7 協議

- 握手階段藉 HTTP Upgrade 完成，之後轉為 TCP 上的雙向 frame 協議，提供有序的 text/binary
  message pipe。
- 它不定義任何訊息語意：沒有主題（topic）、沒有訂閱、沒有 request/response 對應、沒有
  ack、沒有錯誤格式——這些全部留給上層。

#### 3. STOMP 是 WebSocket 的 subprotocol（訊息語意層）

- STOMP 定義 frame 格式（COMMAND + headers + body，長得像文字版 HTTP）、destination
  （topic/queue）、SUBSCRIBE/SEND/ACK、receipt、ERROR frame、heart-beat。
- 類比：WebSocket 之於 STOMP ≈ TCP 之於 HTTP——下層給可靠雙向管道，上層給語意。

分層堆疊：

```
自訂 API 規格 / STOMP / MQTT   ← 訊息語意（subprotocol）
WebSocket (RFC 6455)           ← 雙向 message pipe
HTTP/1.1 Upgrade 握手          ← 僅建線時使用
TLS                            ← 加密
TCP                            ← L4
```

- 補充：WebSocket 握手時可用 `Sec-WebSocket-Protocol` header 協商 subprotocol（如
  `stomp`、`mqtt`），自訂協議也可利用此機制宣告。

#### 4. Jakarta WebSocket + 自訂協議 = 自寫 subprotocol

Jakarta WebSocket（JSR 356）是 WebSocket 那一層的 Java API；在其上自訂 API 規格（例如 JSON
envelope 含 type/action/payload/correlationId），就是在 STOMP 的同一層自己定義語意協議。

| 面向 | STOMP | 自訂協議 |
|------|-------|---------|
| 標準化 | 公開標準，跨團隊互通 | 僅限自家系統 |
| 框架整合 | Spring 有 `@MessageMapping` 與 broker relay（RabbitMQ/ActiveMQ）整合 | 無框架包袱，也無現成整合 |
| Client 生態 | 現成 client library | client 需自行實作 |
| 彈性 | 受限於 STOMP 語意 | 格式完全貼合領域需求 |
| 維護成本 | 低（語意由標準定義） | 訂閱語意、ack、錯誤格式、版本協商、心跳等都要自己設計維護 |

**心跳的分層細節**：WebSocket 自身有 ping/pong control frame（管道層存活偵測），STOMP 另有
自己的 heart-beat 機制（語意層）；自訂協議通常需擇一或自行定義。

---

> 訊息協議家族（MQTT/STOMP/AMQP）、Kafka 與 Redis Pub/Sub 的比較與選型已拆分至
> [messaging-protocols-vs-platforms.md](messaging-protocols-vs-platforms.md)（2026-07-12）。

---

## 參考

- 來源：Notion 開發學習筆記 — 網路 > CDN / DNS / 網路分層架構 / TLS
