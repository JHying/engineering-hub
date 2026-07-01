---
date: 2026-06-30
keywords: XSS, CSRF, SQL Injection, DDoS, MITM, Phishing, Broken Authentication, Web Security, 資安
---

# 常見 Web 攻擊方式全覽

**日期**：2026-06-30  
**關鍵字**：XSS, CSRF, SQL Injection, DDoS, MITM, Phishing, Broken Authentication, Web Security, 資安

## 問題背景

Web 應用面臨的攻擊手法橫跨前端、後端、資料庫與網路傳輸層。理解各攻擊的原理、危害與防禦核心，有助於在系統設計與 Code Review 中識別風險點，並選擇對應的防禦機制。

> 本文為攻擊概覽，前端儲存安全（Cookie vs LocalStorage 選型、Token 儲存策略）請參考 [frontend-web-security.md](frontend-web-security.md)。

---

## 研究結論

### 一、XSS（Cross-Site Scripting）跨站腳本攻擊

**原理**：將惡意 JavaScript 注入網頁，受害者瀏覽時由瀏覽器自動執行。

**分類：**

| 類型 | 觸發方式 | 說明 |
|------|---------|------|
| Stored XSS | 每次頁面載入 | 惡意腳本存進資料庫（如留言板），任何人讀取該頁面即執行 |
| Reflected XSS | 點擊特製連結 | 惡意腳本藏在 URL 參數，伺服器直接反射回頁面 |
| DOM-based XSS | 純前端操作 | 惡意輸入透過 JS 操作 DOM 時注入，不經過伺服器 |

**危害**：竊取 Cookie / Token、偽造使用者操作、導向釣魚頁面。

**防範：**
- 輸出時做 HTML Encode（將 `<` `>` `"` 等字元轉義）
- 設定 `Content-Security-Policy`（CSP）Header，限制可執行的腳本來源
- 敏感 Cookie 設定 `HttpOnly`，使 JavaScript 無法讀取

---

### 二、CSRF（Cross-Site Request Forgery）跨站請求偽造

**原理**：誘使已登入用戶的瀏覽器，自動帶 Cookie 向目標網站發送惡意請求，伺服器無法區分是否為合法操作。

**危害**：轉帳、修改密碼、刪除資料（使用者本人不知情）。

**防範：**
- **CSRF Token**：每個表單 / 請求夾帶伺服器發行的隨機 Token，跨站無法取得
- **SameSite Cookie**：設定 `Strict` 或 `Lax`，限制跨站請求不自動帶 Cookie
- 敏感操作加入二次驗證（OTP、密碼確認）

> 與 XSS 的差異：XSS 是在用戶瀏覽器內執行惡意腳本；CSRF 是借用用戶的登入狀態發送請求。

---

### 三、SQL Injection

**原理**：在輸入欄位注入 SQL 語法，改變資料庫查詢邏輯。

**範例：**

```sql
-- 原始查詢
SELECT * FROM users WHERE username = '{input}' AND password = '{input}';

-- 惡意輸入：' OR '1'='1
-- 實際執行變成：
SELECT * FROM users WHERE username = '' OR '1'='1' AND password = '';
-- '1'='1' 永遠為真，繞過驗證
```

**危害**：繞過身分驗證、拖庫（傾倒所有資料）、刪除或竄改資料。

**防範：**
- **Prepared Statement / Parameterized Query**：參數與 SQL 語句分離，輸入永遠被視為值而非語法
- 使用 ORM 框架（自動處理參數化）
- 最小權限原則：DB 帳號只給必要的 CRUD 權限，不給 DROP / TRUNCATE

---

### 四、DDoS（Distributed Denial of Service）分散式阻斷服務攻擊

**原理**：控制大量殭屍機器（botnet）同時打流量至目標伺服器，耗盡資源導致正常用戶無法使用。

**分類：**

| 類型 | 攻擊層 | 手法 | 說明 |
|------|-------|------|------|
| Volume-based | 網路層 | UDP Flood | 塞爆頻寬 |
| Protocol-based | 傳輸層 | SYN Flood | 耗盡 TCP 連線資源（半開連線） |
| Application-layer | 應用層 | HTTP Flood | 偽裝正常 HTTP 請求，耗盡伺服器處理能力 |

**防範：**
- **CDN / WAF**（如 Cloudflare）：在邊緣節點吸收流量、過濾惡意請求
- **Rate Limiting**：限制單一 IP / 用戶的請求頻率
- 流量清洗服務（Traffic Scrubbing）

---

### 五、Man-in-the-Middle（MITM）中間人攻擊

**原理**：攻擊者秘密插入用戶與伺服器之間的通訊路徑，竊聽或篡改傳輸內容，雙方都不知情。

**常見場景：**
- 公共 Wi-Fi 中的 ARP 欺騙
- DNS 劫持（偽造 DNS 回應，導向惡意伺服器）
- SSL Stripping（將 HTTPS 降級為 HTTP）

**防範：**
- **HTTPS 全站加密**：確保傳輸內容被 TLS 保護
- **HSTS**（HTTP Strict Transport Security）：瀏覽器強制使用 HTTPS，防止降級攻擊
- **憑證 Pinning**：行動 App 預先綁定伺服器憑證指紋，防止偽造憑證

---

### 六、Phishing 釣魚攻擊

**原理**：以社交工程手段偽裝成合法網站或信件，誘騙用戶輸入帳號密碼或點擊惡意連結。

**常見手法：**
- 仿造知名網站的登入頁面（域名相似、視覺複製）
- 電子郵件偽裝成官方通知，引導點擊偽造連結

**防範：**
- **MFA 多因素驗證**：即使密碼外洩，攻擊者也無法完成登入
- 用戶安全意識教育（識別可疑 URL、不輕易點擊連結）
- 電子郵件 SPF / DKIM 驗證，防止偽造寄件人

---

### 七、Broken Authentication 身分驗證漏洞

**原理**：身分驗證或 Session 管理機制的設計缺陷，被攻擊者利用以取得其他用戶的存取權。

**常見問題：**
- 弱密碼政策（允許 `123456` 等常見密碼）
- Session Fixation（Session ID 未在登入後更換）
- Token 未設有效期或登出後未 Revoke
- 暴力破解（未限制失敗次數）

**防範：**
- 強制密碼複雜度，禁止常見弱密碼
- 登入後重新產生 Session ID
- Token 設定合理有效期（短期 Access Token + 長期 Refresh Token）
- 登出時 Revoke Token / 使 Session 失效
- 實作帳號鎖定（連續失敗 N 次後鎖定）

---

## 快速對照表

| 攻擊 | 主要目標 | 攻擊者需要 | 核心防禦 |
|------|---------|-----------|---------|
| XSS | 前端用戶（瀏覽器） | 可注入惡意 JS 的輸入點 | HTML Encode、CSP、HttpOnly |
| CSRF | 用戶的登入狀態 | 誘導已登入用戶點擊 | CSRF Token、SameSite Cookie |
| SQL Injection | 資料庫 | 未過濾的輸入欄位 | Prepared Statement、ORM |
| DDoS | 伺服器可用性 | 大量流量（botnet） | CDN、WAF、Rate Limiting |
| MITM | 傳輸中的資料 | 網路中間位置 | HTTPS、HSTS、憑證 Pinning |
| Phishing | 用戶帳號密碼 | 社交工程 | MFA、安全意識教育 |
| Broken Auth | 身分驗證系統 | 系統設計漏洞 | Token 有效期、Session 管理 |

---

## 攻擊層次對應

```
用戶（瀏覽器）   ←── Phishing、XSS
        ↕
  網路傳輸層     ←── MITM、DDoS（Volume / Protocol）
        ↕
  應用伺服器     ←── CSRF、Broken Authentication、DDoS（Layer 7）
        ↕
   資料庫層      ←── SQL Injection
```

---

## 參考

- OWASP Top 10：https://owasp.org/www-project-top-ten/
- 相關筆記：[frontend-web-security.md](frontend-web-security.md)（前端儲存安全 / Token 儲存策略）
- 相關筆記：[cryptography-digital-certificates.md](cryptography-digital-certificates.md)（TLS / 憑證原理）
- 相關筆記：[network-protocol-stack.md](network-protocol-stack.md)（HTTPS / DDoS 網路層基礎）
