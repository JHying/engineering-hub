---
date: 2026-07-22
keywords: CSRF, Spring Security, SameSite, Bearer Token, XorCsrfTokenRequestAttributeHandler, Double Submit Cookie, Synchronizer Token, BREACH, 資安
---

# Spring Security CSRF 實作決策：憑證傳輸方式、SameSite 邊界與設定模式

**日期**：2026-07-22  
**關鍵字**：CSRF, Spring Security, SameSite, Bearer Token, XorCsrfTokenRequestAttributeHandler, Double Submit Cookie, Synchronizer Token, BREACH, 資安

## 問題背景

現有筆記（`frontend-web-security.md`、`web-security-attacks-overview.md`）停在「CSRF 有哪些防範手段」的概念層，缺少落到實作時真正需要判斷的三件事：什麼情況可以關掉 CSRF 防護、Spring Security 該怎麼設、以及 SameSite 能擋到什麼程度。本筆記補這一層。

---

## 研究結論

### 一、唯一的判斷準則：憑證是否為 ambient authority

CSRF 能成立的必要條件只有一個 —— **瀏覽器會在跨站請求中自動附帶憑證**（ambient authority，環境權限）。攻擊者無法讀取回應，只能「借用」這個自動附帶的行為。

屬於 ambient authority 的憑證：Cookie、HTTP Basic/Digest、TLS client certificate、Windows 整合認證。
**不屬於**的：`Authorization: Bearer <token>` —— 瀏覽器不會自動附帶，必須由 JavaScript 明確設定。

由此推出唯一需要記住的判斷式：

| 憑證放哪裡 | 需要 CSRF 防護？ |
|---|---|
| Cookie（Session ID 或 JWT 皆同） | **需要** |
| `Authorization` header，且伺服器**只**接受此來源 | 不需要 |
| 兩者都接受（常見於漸進遷移） | **需要** —— 攻擊者會選 Cookie 路徑 |

**關鍵陷阱**：判斷依據是「憑證的傳輸方式」，不是「Token 的格式」。把 JWT 放進 Cookie 一樣完整暴露於 CSRF；反之 Session ID 若透過 header 傳遞則不受影響。「我們用 JWT 所以不需要 CSRF」是錯誤推論，中間漏掉了「而且我們放在 Authorization header」這個真正的前提。

第二個陷阱是**同時存在兩條認證路徑**。例如 Spring Security 同時設定了 `formLogin()`（產生 session cookie）與 `oauth2ResourceServer()`（吃 bearer token），此時關閉 CSRF 等於對 cookie 路徑開洞——即使前端程式碼只使用 bearer。攻擊面取決於伺服器接受什麼，不是前端送出什麼。

---

### 二、Spring Security 實作

#### 2-1 預設行為（Spring Security 6.x / 7.x）

- **Token 儲存**：預設 `HttpSessionCsrfTokenRepository`（存 session，屬 synchronizer token pattern）
- **Token 處理**：預設 `XorCsrfTokenRequestAttributeHandler`。官方原文：「By default, the `XorCsrfTokenRequestAttributeHandler` is used for providing BREACH protection of the `CsrfToken`.」每次請求對 token 做隨機 XOR 編碼，使回應中的 token 值每次不同，避免 BREACH 這類壓縮側通道攻擊還原 token。

  > 常見混淆：API 文件說「The default implementation is `CsrfTokenRequestAttributeHandler`」，指的是 `CsrfFilter` 這個類別本身的預設值；但透過 `csrf()` DSL 設定時，`CsrfConfigurer` 會覆寫為 Xor 版本。以 DSL 為準。

- **延遲載入**：「By default, Spring Security defers loading of the `CsrfToken` until it is needed.」token 只在遇到不安全 HTTP 方法（POST 等）或有東西要把 token 寫進回應時才載入，避免每個請求都碰 session。

  這正是 SPA 最常見的災情來源：前端期待 GET 首頁時就拿到 `XSRF-TOKEN` cookie，但因為沒有任何東西「需要」token，Spring 根本沒產生它，cookie 也就沒被寫出，導致後續 POST 一律 403。

#### 2-2 SPA（前後端分離）—— Spring Security 7 用 `.spa()`

Spring Security 7 新增了專用捷徑，一行解決上述所有問題：

```java
@Bean
SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.csrf(csrf -> csrf.spa());
    return http.build();
}
```

`.spa()` 內含：`CookieCsrfTokenRepository.withHttpOnlyFalse()`（讓 JS 讀得到）、正確處理 Xor 編碼的 request handler、以及登入/登出後的 token 更新。**不需要**再手寫 `setCsrfRequestAttributeName(null)` 這類 workaround。

在 6.x 需要手動組裝等效設定（自訂 `CsrfTokenRequestHandler` 委派 + 一個強制解析 token 的 filter），樣板約 30 行。**若專案仍在 6.x 且有 SPA，這是升級 7.x 最直接的獲益點之一。**

前端對應行為：從 `XSRF-TOKEN` cookie 讀值，放進 `X-XSRF-TOKEN` header 送出（Axios 預設即此約定，多數情況零設定）。

#### 2-3 純無狀態 API —— 可以關，但要關對

官方立場：「Before disabling CSRF protection, consider whether it makes sense for your application.」「A backend application that _does not_ serve browser traffic may choose to disable CSRF.」

```java
http
    .csrf(csrf -> csrf.disable())
    .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
    .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
```

`disable()` 只有在**同時**滿足下列條件時才安全，缺一不可：

1. `SessionCreationPolicy.STATELESS` —— 確保不會產生 session cookie
2. 沒有 `formLogin()`、`httpBasic()`、`rememberMe()` 等任何以 cookie 或 ambient 憑證認證的機制
3. 沒有其他 filter 自行讀取 cookie 做認證

換言之，`csrf().disable()` 這行本身不是決策，它只是「我們已經沒有 ambient 憑證」這個事實的結果。單獨加上它而沒檢查 1–3，是實務上最常見的誤用。

#### 2-4 局部排除的風險

```java
http.csrf(csrf -> csrf.ignoringRequestMatchers("/webhooks/**"));
```

`ignoringRequestMatchers` 只在該路徑「不使用 cookie 認證」時才合理。典型正當用途是外部 webhook —— 對方無法取得 CSRF token，改以 **HMAC 簽章驗證 payload** 取代。

反例：對 `/api/**` 整段排除，但該 API 仍吃 session cookie —— 這等同於只在畫面路由上留著防護，把真正會改變狀態的端點全部裸露。

#### 2-5 Double-submit cookie 的隱含弱點

`CookieCsrfTokenRepository` 屬 double-submit cookie 模式（token 同時在 cookie 與 header，伺服器比對兩者）。它的已知弱點是 **cookie injection**：攻擊者若能寫入受害者的 cookie，就能讓兩邊一致而通過比對。可寫入的來源包括被接管的子網域、或任何同站的 XSS —— 因為 cookie 的作用域是 site 而非 origin。

Spring 的 Xor 編碼提高了偽造難度但不改變本質。若安全需求較高，優先選 session-based 的 `HttpSessionCsrfTokenRepository`（synchronizer token pattern，token 存在伺服器端，無法靠寫 cookie 偽造）。

**另外**：登入成功後必須更新 CSRF token，避免攻擊者預先取得未認證 token 再誘導受害者登入（類比 session fixation）。`.spa()` 與標準 `formLogin()` 流程已內建處理，自訂登入流程需自行確認。

---

### 三、SameSite Cookie 的實際邊界

SameSite 是有效的縱深防禦，但**不足以單獨取代 CSRF token**，原因有五：

| 限制 | 說明 |
|---|---|
| Lax 放行 top-level GET 導航 | 使用者點擊惡意連結跳轉時 cookie 仍會附帶。若有任何會改變狀態的 GET 端點（違反 REST 但實務常見，如 `/logout`、`/admin/delete?id=1`），仍可被攻擊 |
| 作用域是 site 不是 origin | 同一 eTLD+1 下的所有子網域視為同站。子網域的 XSS、或一個被接管的舊子網域，都能發出「同站」請求並帶著 cookie |
| Strict 破壞使用者體驗 | 從 email 或外部連結進站時不帶 cookie，看起來像未登入。常見緩解是雙 cookie（一個 Strict 用於敏感操作、一個 Lax 維持登入顯示），複雜度不低 |
| 需要 `Secure` 才能用 None | 跨站嵌入情境（iframe、第三方整合）必須 `SameSite=None; Secure`，此時 SameSite 完全不提供保護，CSRF token 成為唯一防線 |
| client 支援不一致 | 主流瀏覽器自 2020 起預設 Lax，但非瀏覽器 client、舊版 WebView、部分嵌入式環境行為不一 |

**結論**：SameSite 設 `Lax`（或敏感操作用 `Strict`）作為基線，CSRF token 作為主要防線，兩者並用。不要因為設了 SameSite 就關閉 CSRF token。

---

### 四、決策速查

| 情境 | CSRF token | SameSite | 備註 |
|---|---|---|---|
| 傳統 server-side render（Thymeleaf/JSP）+ session cookie | 必要（預設即有） | Lax | Spring 預設行為已正確，不要動 |
| SPA + cookie 認證 | 必要 | Lax | Spring Security 7 用 `csrf.spa()` |
| SPA + `Authorization: Bearer` | 不需要 | N/A | 前提：確認無任何 cookie 認證路徑 |
| 純機器對機器 API（無瀏覽器流量） | 不需要 | N/A | 官方明示可 disable |
| 外部 webhook 端點 | 排除 + HMAC 簽章 | N/A | 對方無法取得 token |
| 跨站 iframe 嵌入 | 必要（唯一防線） | None + Secure | SameSite 在此完全失效 |

---

## 待補充 / 後續

- 若專案需要把此決策定案，建議在 `common_KBs/ADRs/07-security/` 開一則 ADR，決策點為「認證憑證的傳輸方式」而非「是否啟用 CSRF」——後者只是前者的推論結果
- 本筆記未涵蓋：CORS 與 CSRF 的關係（常見誤解為 CORS 能防 CSRF，實際上 CORS 限制的是讀取回應，不阻止請求送達）、`Origin`/`Referer` header 驗證作為補充手段

## 參考來源

- Spring Security 官方文件 7.1.0：`docs/modules/ROOT/pages/servlet/exploits/csrf.adoc`（https://github.com/spring-projects/spring-security/blob/7.1.0/docs/modules/ROOT/pages/servlet/exploits/csrf.adoc）
- Spring Security Reference — Cross Site Request Forgery (CSRF) for Servlet Environments（https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html）
- `XorCsrfTokenRequestAttributeHandler` API doc, spring-security-docs 7.0.0（https://docs.spring.io/spring-security/site/docs/current/api/org/springframework/security/web/csrf/XorCsrfTokenRequestAttributeHandler.html）
- Baeldung — CSRF With Stateless REST API（https://www.baeldung.com/csrf-stateless-rest-api）
