---
date: 2026-07-04
keywords: WebSocket, OpenTelemetry, OTEL, Baggage, Istio, 版本路由, Canary, Spring AOP, Distributed Tracing, Trace Context
---

# WebSocket 使用 OTEL Baggage 傳遞版本號並整合 Istio 版本路由

## 問題背景

系統已透過 OTEL Java Agent（以 sidecar 形式隨每個 pod 佈署）建立分散式追蹤能力，並對 HTTP、Kafka、gRPC 提供自動注入（auto-instrumentation）。但存在兩個缺口：

1. **WebSocket 連線與非同步流程（Thread Pool / `@Scheduled` 排程）未被涵蓋在追蹤鏈中**，導致 trace 斷裂、難以還原完整呼叫路徑。
2. **需要讓「版本號（version）」可透過 OTEL Baggage 一路傳遞**，使 Istio 能依版本號做流量導流——例如同時佈署新舊版本的 pod，並將特定測試流量導向指定版本，以支援灰度發布（canary release）驗證。

需要研究：現有 OTEL 自動注入機制的邊界在哪裡、缺口如何補齊、版本號要透過哪個管道傳遞、以及 Istio 端如何依版本號路由。

## 研究結論

### 一、現有 OTEL 自動注入的限制

OTEL Java Agent 內建 extension SDK 與 auto-instrumentation，JVM 啟動時自動注入，目前涵蓋 HTTP、Kafka、gRPC。應用層若需手動 instrumentation，僅需引入 OTEL API（Baggage、Context、Span）即可擴充。

實測後發現兩個自動注入無法涵蓋的場景：

- **WebSocket**：Agent 能擷取 HTTP Upgrade 階段的 header，但後續 `@OnOpen` / `@OnMessage` 生命週期中無法再取得原始的 `traceparent` header（WebSocket frame 本身不攜帶該 header），導致追蹤鏈在 handshake 完成後斷裂。
- **`@Scheduled` 排程**：Agent 會自動建立 span（`code.function` / `code.namespace`），但排程觸發本身沒有 inbound request，因此無法從中推導出 version baggage。

**結論**：WebSocket 與自啟動排程都必須透過 OTEL API 手動 instrumentation 補齊，無法單靠 Agent 自動注入解決。

### 二、解法：自建 AOP 工具寫入 Baggage

透過一個啟用類註解（範例：`@EnableTraced`）引入三個 Spring Bean，分工如下：

| Bean | 職責 |
|------|------|
| **方法層 Aspect**（標註 `@WithTraced` 於關鍵方法） | 實作 WebSocket 的 OTEL context 接力機制：Upgrade 階段將 context 寫入 `EndpointConfig` → `@OnOpen` 從 `EndpointConfig` 復原並寫入 session → `@OnMessage` 從 session 復原並注入 baggage，藉此讓 handshake 之後的訊息仍能延續原始 trace/baggage。 |
| **Bean 後處理器**（偵測 `@Bean` 上的 `@WithTraced`） | 自動為指定 Bean（主要是 Thread Pool）注入 OTEL context（含 baggage），解決非同步執行緒切換導致的追蹤鏈斷裂。 |
| **排程 Aspect** | 服務啟動時從版本設定（環境變數）解析一次版本號，之後每次 `@Scheduled` 執行前自動注入 version baggage，讓排程觸發的下游呼叫也能攜帶版本資訊。 |

### 三、版本號傳遞管道：header 與 query param 雙軌支援

實測從 request query param 與 header 兩種管道傳入 version，皆可成功路由到指定版本，且能觀察到完整的 tracing chain（涵蓋 REST → gRPC → WebSocket 連線 → 後續 REST 呼叫的多段呼叫鏈）。

確立規則：

- 若 query param 與 header 同時攜帶 version，**以 header 為主**。
- API Gateway 統一將 client 傳入的 `?version` query param 轉換為 `version` header 再繼續轉發：因為 OTEL context 的傳遞依賴 header，追蹤框架（如 Micrometer Tracing）需要對應的 header 才能將版本值橋接進 baggage，讓後續請求依原始版本號路由到指定 pod。

### 四、Istio 流量導流設定

Istio `VirtualService` 同時支援 header 與 queryParam 兩種 match 規則，導向對應版本的 subset（兩者同時存在時以 header 為主）：

```yaml
hosts:
- api-gateway.example.internal
http:
- match:
  - headers:
      version:
        exact: canary-test-v1
  - queryParams:
      version:
        exact: canary-test-v1
  route:
  - destination:
      host: api-gateway.namespace.svc.cluster.local
      port:
        number: 80
      subset: canary-test-v1
```

CI/CD 流程針對指定版本部署時，會自動同步加上對應的 `queryParams` 路由設定，避免手動維護造成 header/queryParam 規則不一致。

### 五、落地與工具化

- 共用工具包新增啟用類與方法層兩個 Spring AOP 註解（範例：`@EnableTraced` / `@WithTraced`），涵蓋自啟動排程的 Baggage 注入，並補齊對應單元測試，測試通過。
- 至少一個業務服務已引用該共用工具包新版本，在關鍵方法加上註解後完成整合測試，測試通過。

### 六、額外修正：自訂 RestClient 工具導致 OTEL 失效

若使用自訂建構子建立 RestClient 工具類別、且未繼承框架提供的預設 RestClient 設定類別，會導致 OTEL 自動注入失效——因為預設設定類別本身承載了 tracing 相關的攔截器（interceptor）設定。已同步調整共用工具包內的 RestClient 工具類別（版本升級）修正此問題，未繼承預設設定的自訂建構方式需特別留意此陷阱。

### 七、追蹤雜訊排除

Tracing 排除了服務探索設定查詢（如 config server 拉取設定）與 K8s health check 探測的採樣，避免產生大量無意義的 trace 資料，降低追蹤系統負擔與雜訊。

### 八、決策摘要

| 決策點 | 結果 |
|---|---|
| WebSocket / 排程追蹤方式 | OTEL Agent 自動注入無法涵蓋，改用自建 Spring AOP 工具（啟用類 + 方法層註解）手動 instrumentation |
| 版本號傳遞管道 | 同時支援 header 與 query param，兩者衝突時 header 優先 |
| Gateway 角色 | 統一把 query param 版本轉成 header，確保追蹤框架與 Istio 都能吃到一致的版本資訊 |
| Istio 路由 | VirtualService 同時支援 header/queryParam match 規則，導向對應版本 subset |
| 追蹤雜訊處理 | 排除服務探索設定查詢與 K8s health check 探測的採樣 |
| 落地狀態 | 共用工具包已發版並整合進至少一個業務服務，驗證通過；RestClient 相容性問題已修復 |

## 參考

- OpenTelemetry Java Agent：https://github.com/open-telemetry/opentelemetry-java-instrumentation
- OpenTelemetry Baggage API：https://opentelemetry.io/docs/concepts/signals/baggage/
- Istio VirtualService（Header/QueryParam 路由）：https://istio.io/latest/docs/reference/config/networking/virtual-service/
