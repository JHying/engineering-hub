---
date: 2026-06-26
keywords: GCP, AWS, Cloud DNS, Route 53, CloudFront, CDN, ALB, ELB, 多CDN, CORS, DNS routing, Geolocation, Latency
---

# GCP / AWS DNS、CDN 與流量路由策略

## 問題背景

多種場景需要選擇 DNS 服務、CDN 加速方案，以及處理多 CDN 供應商共用同一 Domain 的 CORS 與 SSL 問題。

---

## GCP Cloud DNS

### 建立流程

**步驟 1：購買網域**
- 可在 GoDaddy 或 Google Domains 購買
- 也有免費網域可供測試使用（有到期限制）

**步驟 2：建立 Cloud DNS 可用區**
- **私人**：僅在 GCP project 內部使用
- **公開**：不限使用位址

建立完成後，Cloud DNS 設定會顯示 NS（Name Server）和 SOA（Start of Authority）類型記錄。

**步驟 3：設定 DNS 記錄**
- **A record**：將 DNS 名稱指向 Load Balancer 或 VM 的 IP
- **CNAME**：將子域名指向另一個域名

### DNS 記錄類型

| 記錄類型 | 用途 | 範例 |
|---------|------|------|
| **A** | 域名 → IPv4 | `example.com → 123.45.67.89` |
| **AAAA** | 域名 → IPv6 | `example.com → IPv6 address` |
| **CNAME** | 域名 → 另一個域名 | `sub.example.com → main.example.com` |
| **NS** | Name Server 設定 | 由 Cloud DNS 自動產生 |
| **SOA** | Start of Authority | 由 Cloud DNS 自動產生 |

---

## AWS Route 53

AWS 提供的 DNS 服務，可透過 Route 53 購買網域，將網域與指定伺服器綁定。

### A Record / CNAME / Alias 比較

| 類型 | 說明 | 特點 |
|------|------|------|
| **A Record** | 直接把網域名稱指向伺服器 IP | 最直接 |
| **CNAME** | 把網域名稱轉換成另一個域名 | 適合子域名 |
| **Alias** | 指派 AWS 服務，底層是 A Record | 減少轉發延遲（10～50ms） |

### Route 53 導流策略

Route 53 擁有 **Health Check** 功能，可確認對應 Server 是否存活。基於此機制，可把同一個 DNS 指向到多個伺服器。

| 策略 | 說明 |
|------|------|
| **Failover** | 指向主要與備用位置，主要位置失效時自動切換 |
| **Latency** | 依對 Client 端最少連線延遲，轉發流量到不同伺服器 |
| **Geolocation** | 依據 Client 的地理位置進行流量分發 |
| **Simple** | 所有用戶端收到相同的回應 |
| **Weighted** | 指定移至每個資源的流量比例 |
| **Multivalue** | 隨機回傳最多 8 個正常記錄來回應 DNS 查詢 |

---

## AWS CloudFront（CDN）

CloudFront 是 AWS 提供的 CDN 服務，利用最靠近使用者的節點，將緩存的靜態內容（HTML）或影音檔案（RTMP）以低延遲傳遞給使用者。

> 📌 **2026-06 更新**：CloudFront 現有 **600+ Edge Locations，遍佈 50+ 國家**（舊資料為 275+）

### 主要概念

**Edge Location（邊緣節點）**
- AWS 在世界各地遍布的連接點，緩存 Origins 的內容或 DNS
- 可自訂緩存的類型與時間

**Origins（原始位置）**
- 通常是 **S3**，也可以是 EC2 或 ALB
- 可將網站交由 S3 託管，禁止其他來源直接訪問 S3，僅透過 CloudFront，達到增加效能與監控流量的目的

### 存取控制機制

| 方式 | 適用時機 |
|------|---------|
| **Signed URLs** | RTMP、個別檔案限制、不支援 cookies 的客戶端 |
| **Signed Cookies** | 多個限制檔案，如頻道會員專屬 |
| **Georestrictions** | 依地理位置封鎖，只允許特定地區存取 |
| **AWS WAF Web ACL** | 針對特定 IP 限制存取 |
| **SNI Custom SSL** | 支援 SSL certificates 搭配 Server Name Indication |

---

## 多 CDN + ALB 統一架構（解決 CORS 問題）

### 問題情境

多個 CDN 節點（CloudFront、其他 CDN）分別處理不同靜態資源的 Cache，且前後端分離。

**目標**：所有靜態資源與 Server 能共用一個 SSL 及 Domain，避免不同資源產生 CORS 問題。

**解決方式**：透過 **ALB 導流**解決。

### 整體架構

**DNS 智慧解析（多 CDN 地理導流）**

使用 Route 53 Geo-location 或 Latency-based Policy：

```
example.com  →  CloudFront    （美國）
example.com  →  其他 CDN      （台灣）
example.com  →  其他 CDN      （日本）
```

所有 CDN 的 Origin 都指向同一個 ALB，使用者體感上沒有差別。

**ALB Path Routing 規則**

| 路徑 | Target Group | 備註 |
|------|-------------|------|
| `/api/*` | 後端服務 Target Group | 提供後端 API |
| `/assets/*` | EC2/S3 Proxy Group | nginx 反 proxy 到 S3 bucket |
| 其他 | 其他靜態資源 | proxy 到對應來源 |

### SSL 憑證設置在 ALB 的原因

| 原因 | 說明 |
|------|------|
| 統一憑證管理 | 所有來源都走同一個 Domain，ALB 掛一次憑證即可 |
| 降低後端負載 | SSL Termination 發生在 ALB，後端只需處理 HTTP |
| 相容 CDN 設計 | 各大 CDN 預設支援 HTTPS 串接 Origin |
| 可接 WAF | ALB 可掛 AWS WAF 提供 Web 攻擊保護 |
| 跨 CDN 無 CORS | ALB 負責導流，CDN 都導向同一 entry point |

### ALB SSL 憑證設定建議

| 項目 | 建議做法 |
|------|---------|
| 憑證來源 | **AWS ACM**（免費 + 自動續期） |
| 憑證綁定 | 綁在 ALB 的 HTTPS Listener (port 443) |
| Domain 驗證 | 透過 Route 53 DNS 自動驗證，或手動加 TXT 記錄 |
| 支援 SNI | AWS ALB 原生支援 SNI，可掛多個憑證 |

### CORS 完全避免條件

| 條件 | 是否符合 |
|------|---------|
| 所有請求來自同一個 Domain | ✅ |
| 所有 CDN 只轉送，Host header 不修改 | ✅ |
| ALB 不轉向外網，而是 proxy internal | ✅ |
| Response header 沒有被額外添加跨域限制 | ✅ |

## 參考

- [AWS CloudFront Features](https://aws.amazon.com/cloudfront/features/)
- [Route 53 Routing Policies 文件](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html)
- [CloudFront Edge Locations](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/LocationsOfEdgeServers.html)
