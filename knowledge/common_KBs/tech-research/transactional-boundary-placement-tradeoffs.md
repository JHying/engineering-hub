---
date: 2026-07-13
keywords: Spring, AOP, Transactional, 連線池, 交易邊界
---

# @Transactional 放置層級與連線池成本排序的決策脈絡

**日期**：2026-07-13
**關鍵字**：Spring, AOP, @Transactional, self-invocation, 連線池, 交易邊界, HikariCP, TransactionTemplate, AspectJ

## 問題背景

一個常見的下單服務結構：`XxxAppService.placeOrder()` 內部呼叫同類別的 `this.saveOrder()`（標了 `@Transactional`）。因為是 self-invocation，繞過了 Spring AOP proxy，交易完全沒生效，導致部分寫入沒有隨例外回滾。

機制成因（細節見 [ioc-di-aop-patterns.md](ioc-di-aop-patterns.md)、[spring-aop-processor-mechanism-and-websocket-lazy-timing.md](spring-aop-processor-mechanism-and-websocket-lazy-timing.md)）：Spring 對沒有實作 interface 的類別會用 CGLIB 產生子類別 proxy，在方法前後插入交易攔截邏輯；但類別內部的 `this` 指向的是被包住的原始 target instance，不是外部注入的 proxy，所以 self-invocation 繞過整條 interceptor chain。

這篇筆記不重複機制原理，聚焦「修法怎麼選、為什麼這樣排序」的決策脈絡——尤其是「把 `@Transactional` 移到外層方法」這個直覺解法背後隱藏的連線池代價，以及更根本的分層放置解法。

---

## 研究結論

### 一、修法選項與代價比較

| 選項 | 做法 | 代價 |
|---|---|---|
| self-injection | 注入自己的 proxy bean 呼叫自己 | 語意怪異（自己注入自己），常被視為 anti-pattern |
| `AopContext.currentProxy()` | 開 `exposeProxy=true`，方法內取得目前 proxy | 耦合到 AOP 內部 API |
| 拆分方法到另一個 bean | 交易方法從外部 bean 呼叫，不再是 self-invocation | 需要新增類別，但架構上最乾淨 |
| `TransactionTemplate` | 改用程式化交易，不依賴 proxy | 寫法較囉唆，失去宣告式交易的簡潔性 |
| AspectJ compile-time / load-time weaving | 直接在 bytecode 插入邏輯，非包一層 proxy，self-invocation 問題不存在 | 建置鏈與除錯複雜度上升 |
| 把 `@Transactional` 移到外層方法（如 `placeOrder`） | 外部呼叫一定經過 proxy，交易在最外層開好，內部 self-invocation 呼叫的方法仍能參與已綁定 thread 的交易（ThreadLocal 綁定，非靠自身 proxy） | **交易邊界擴大**：外層方法裡若混有非 DB 邏輯（呼叫外部 API、發通知等慢操作），會被意外拉進交易範圍，導致連線持有時間變長，高併發下增加連線池耗盡風險 |

### 二、更優解法——依架構分層放置 `@Transactional`

比起「把 `@Transactional` 移到外層方法」這種 workaround，更根本的解法是**依分層放置交易邊界**：

- 把 `@Transactional` 放在 domain/manager 層（與 appService 分開的獨立 bean），appService 層呼叫 domain/manager 是透過 DI 注入的參考（跨 bean 呼叫，非 `this`），因此會正確經過 proxy，交易生效。
- 好處：同時解決「self-invocation 導致失效」與「交易邊界過寬」兩個問題——appService 層的前置處理（非 DB 邏輯）完全不會被拉進交易範圍，因為交易邊界精準卡在 domain/manager 層。
- 這比「移到外層方法」策略更乾淨，因為它是把分層架構做對，而不是靠擴大交易範圍換取正確性。

### 三、效能瓶頸出現時的優先序（成本由低到高）

當壓測（以系統目標流量測試）顯示交易邊界擴大導致連線池吃緊時，處理優先序如下，越後面代價越高：

1. **拆分方法，消除 SRP 違反**：把不該進交易的前置邏輯（如外部請求、非 DB 操作）從交易方法中抽離。
2. **交易邊界收斂到 domain/manager 層**：如上節所述的分層調整，從架構面收斂交易範圍。
3. **Hibernate lazy connection acquisition**：調整連線取得策略（`DELAYED_ACQUISITION_AND_RELEASE_AFTER_STATEMENT`），只在真正觸及 DB 操作時才取得連線，降低連線持有時間，即使交易邊界仍偏寬也能緩解。
4. **加大連線池**（最後手段）：連線池擴大牽涉倍數 infra 成本（更多連線意味著 DB 端資源需求同步上升，可能需要升級 DB tier），應排在最後，只有前面手段都不夠時才考慮。

### 四、決策原則（一句話）

資料一致性問題的修復成本遠高於連線池調校成本——一致性只能靠程式修正，連線池可以透過多種維運手段調教；因此當兩者衝突時，優先保證正確性，再用壓測實測瓶頸、依上述優先序評估是否需要進一步優化，而非反過來為了怕連線池吃緊就犧牲交易正確性。

---

## 參考

- 相關筆記：[ioc-di-aop-patterns.md](ioc-di-aop-patterns.md)（IoC、DI、AOP 基礎概念）
- 相關筆記：[spring-aop-processor-mechanism-and-websocket-lazy-timing.md](spring-aop-processor-mechanism-and-websocket-lazy-timing.md)（Spring AOP proxy 機制、self-invocation 成因細節）
- 相關筆記：[spring-actuator-db-connection-health.md](spring-actuator-db-connection-health.md)（HikariCP 連線池健康監測）
- 來源：模擬面試對話 — self-invocation 導致 @Transactional 失效的修法推演與連線池成本排序
