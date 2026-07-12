---
date: 2026-07-07
keywords: ThreadPoolExecutor, Bulkhead, RejectedExecutionException, AbortPolicy, CallerRunsPolicy, HTTP 503, HTTP 429, HTTP 502, Istio, Envoy, Outlier Detection, Resilience4j, Circuit Breaker, Hystrix
---

# 服務過載時的拒絕策略、HTTP 狀態碼語意與熔斷責任分層

**日期**：2026-07-07
**關鍵字**：ThreadPoolExecutor, Bulkhead, RejectedExecutionException, AbortPolicy, CallerRunsPolicy, HTTP 503, HTTP 429, HTTP 502, Istio, Envoy, Outlier Detection, Resilience4j, Circuit Breaker, Hystrix

## 問題背景

高流量同步 API 服務中，隔離下游呼叫的執行緒池（Bulkhead）滿載時該如何拒絕請求、回什麼 HTTP 狀態碼；以及熔斷機制應該放在應用層（Resilience4j）還是基礎設施層（Istio/Envoy service mesh）。

## 研究結論

### 一、ThreadPoolExecutor 拒絕行為的前提機制

- 提交順序：core 滿 → 進佇列 → 佇列滿才長到 max → max 也滿才觸發拒絕策略。
- 無界佇列（如 `Executors.newFixedThreadPool` 預設的 `LinkedBlockingQueue`）會讓 max 參數永遠不生效：尖峰時請求堆積於佇列，延遲飆升、最終 OOM。
- 同步呼叫端自帶 timeout：請求在佇列中排隊超過呼叫端 timeout 後才被處理，即為「殭屍工作」——呼叫端已放棄，處理只是浪費下游容量。故同步 API 場景佇列應有界且小（小 `ArrayBlockingQueue` 僅吸收毫秒級抖動，或 `SynchronousQueue` 不排隊）。

### 二、拒絕策略選擇（同步 request-serving 場景）

- **AbortPolicy（fail fast）**→ 捕捉 `RejectedExecutionException` 轉為 429/503 + fallback，讓上游重試/熔斷機制接手。為 request-serving 場景首選。
- **CallerRunsPolicy** 是天然背壓，但在 request-serving 場景會讓提交者（容器 worker thread，如 Tomcat worker）親自執行慢任務 → worker 池耗盡 → 不相關的 endpoint 一併變慢 → 故障往上游逐層擴散。等於在 Bulkhead 艙壁上開洞，使下游故障漫入共用 serving 資源。CallerRuns 適合 batch / 內部 pipeline（提交者變慢正是期望的背壓效果）。

### 三、過載時的 HTTP 狀態碼語意（503 vs 429 vs 502）

- **503 Service Unavailable**：「我自己暫時處理不了」（過載/維護）。池滿拒絕屬自身容量問題，503 為語意正確選擇，可附 `Retry-After`。
- **429 Too Many Requests**：「你這個呼叫端打太多」。可歸因到特定 client 超額（rate limit/quota）時使用；整體過載回 503。
- **502 Bad Gateway**：gateway/proxy 專用語意——「我身後的 upstream 回了無效回應或連線失敗」（如 Envoy 連不上 pod、連線被 reset）。
- 應用過載回 502 的兩個實害：
  1. 誤導排障——把矛頭指向下游，triage 方向錯誤。
  2. 破壞網格層自動化——Istio retry policy（retryOn / retriable-status-codes）與 outlier detection 按狀態碼分類行為，503+`Retry-After` 是「暫時過載、可重試其他 pod」的標準訊號，502 常被歸類為「endpoint 壞了」。

### 四、熔斷責任分層（mesh vs in-process）

架構立場「resilience 下沉到基礎設施（Istio），業務服務不關注熔斷」是主流且合理的預設，但有三個沉不下去的邊界：

1. **Envoy 看不見 process 內部**：outlier detection 依賴 pod 已開始回 5xx/變慢的網路層訊號；「池滿快速回 503」發生在 process 內，Envoy 只能轉發、無法代為拒絕。應用仍須保留有界池 + timeout，目的不是做熔斷，而是在過載時快速產生誠實的失敗訊號供 mesh 消費。
2. **Mesh 只保護經過 sidecar 的 HTTP/gRPC 流量**：JDBC 連線池耗盡、Redis 變慢、Kafka producer 堆積等 raw TCP 依賴，Envoy 無狀態碼可判斷健康度、保護能力極有限，須靠 client library 的 pool 上限與 timeout 或 in-process 手段。
3. **Istio 能「斷」不能「降級」**：Envoy 熔斷觸發只會回 503（flag UO），無業務語意，做不出 fallback（如回快取的降級內容）。降級邏輯天生是業務邏輯，沉不下去；判斷準則：下游掛掉時要的是「請求失敗」（mesh 全包）還是「功能降級」（應用層必寫 fallback，Resilience4j 只是整潔的載體、屬實作細節）。

分層總結表：

| 層 | 負責 | 沉不下去的原因 |
|---|---|---|
| Istio | 東西向 HTTP/gRPC 的熔斷、重試、outlier ejection | — |
| 應用（不可免） | 有界池 + timeout + 過載時回 503 | mesh 看不見 process 內部，訊號源必須在這 |
| 應用（視需求） | 業務降級 fallback、非 HTTP 依賴（DB/Redis/MQ）的自保 | 業務語意與非 mesh 流量，mesh 構不到 |

補充：Hystrix 自 2018 年進入維護模式（EOL），Spring Cloud 現行方案為 Resilience4j（經 spring-cloud-circuitbreaker 整合）；Resilience4j 的 `ThreadPoolBulkhead` 即「帶正確拒絕行為的隔離池」。

## 參考

（無外部文件連結；本篇為技術討論整理）
