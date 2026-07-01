---
date: 2026-06-27
keywords: CSRF, XSS, Cookie, LocalStorage, SessionStorage, Same-origin, JWT, Bearer Token, async/await, Promise
---

# 前端資安與非同步處理基礎

**日期**：2026-06-27  
**關鍵字**：CSRF, XSS, Cookie, LocalStorage, SessionStorage, Same-origin, HttpOnly, Bearer Token, async/await, Promise

## 問題背景

前端應用需要儲存認證 Token 以維持登入狀態，但不同儲存方式各有 CSRF / XSS 風險差異。同時，非同步 API 呼叫是前端開發的核心，理解 Promise 與 async/await 的等價性有助於正確使用。

---

## 研究結論

### 一、CSRF 攻擊（Cross-Site Request Forgery）

**定義**：攻擊者誘使已登入用戶的瀏覽器，向目標網站發送惡意請求。

**達成 CSRF 的三要素：**
1. 存在可觸發惡意操作的動作
2. 只以單一條件驗證身份（如僅驗 Cookie）
3. 驗證參數可被預測（固定 Cookie 或 Token）

**防範方式：**
- **CSRF Token**：在 form 或 custom header 中放一個伺服器發行的隨機 token，每次請求夾帶，無法被跨站腳本偽造
- 增加敏感操作的二次驗證（如金流、個資提交）
- SameSite Cookie 屬性設為 `Strict` 或 `Lax`

---

### 二、前端儲存方式比較

| 特性 | Cookie | LocalStorage | SessionStorage |
|------|--------|-------------|----------------|
| 大小限制 | 4KB | 5MB | 5MB |
| 生命週期 | 設定的過期時間 | 永久（除非手動清除） | 關閉分頁即清除 |
| 跨域存取 | 可設定 | 否（Same-origin） | 否（Same-origin） |
| 自動帶入 Request | 是 | 否（需手動取出） | 否（需手動取出） |
| JavaScript 可讀取 | 非 HttpOnly 才可 | 是 | 是 |
| CSRF 風險 | 較高 | 低 | 低 |
| XSS 風險 | HttpOnly Cookie 較安全 | 較高（JS 可直接讀取） | 較高（JS 可直接讀取） |
| 跨分頁共享 | 是 | 是 | 否 |

**同源策略（Same-origin policy）**：瀏覽器限制只有相同來源（協議 + 域名 + 埠）的頁面才能存取同一個 LocalStorage / SessionStorage。

---

### 三、Token 儲存安全建議

**CSRF vs XSS 風險取捨：**
- Cookie（HttpOnly） → 防 XSS，但 CSRF 風險較高 → 需搭配 CSRF Token 或 SameSite
- LocalStorage → 防 CSRF，但 XSS 可直接讀取 → 需確保對 XSS 有完整防護

**推薦做法：**
- 敏感 Token（如 JWT）存在 **HttpOnly Cookie**，JavaScript 無法直接讀取，防 XSS 竊取
- 若使用 LocalStorage 存 Token，改用 `Authorization` Header 傳遞（不讓瀏覽器自動帶 Cookie）：

```
Authorization: Bearer <token>
```

- 一律使用 **HTTPS** 傳輸所有資料

---

### 四、JavaScript 非同步：Promise 與 async/await

**async/await 是 Promise 的語法糖**，兩者等價但可讀性不同。

判斷可以用 async/await 的情境：
1. 函式說明它會回傳 Promise
2. 範例使用 `.then()` 寫法

**寫法對比：**

```javascript
// Promise 寫法
fetch('/api/data')
  .then(response => response.json())
  .then(data => console.log(data))
  .catch(err => console.error(err));

// async/await 等價寫法（較易閱讀）
async function getData() {
  try {
    const response = await fetch('/api/data');
    const data = await response.json();
    console.log(data);
  } catch (err) {
    console.error(err);
  }
}
```

**並行請求（Promise.all）：**

```javascript
// 同時發出多個請求，等全部完成才繼續
const [user, posts] = await Promise.all([
  fetch('/api/user').then(r => r.json()),
  fetch('/api/posts').then(r => r.json())
]);
```

> 使用 `Promise.all` 而非逐一 await，可避免不必要的串行等待，提升效能。

---

## 參考

- 來源：Notion 開發學習筆記 — 前端開發 > 前端資料儲存 - 資安、JavaScript - Promise 處理
