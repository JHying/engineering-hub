---
date: 2026-07-02
keywords: Netty, Javax WebSocket, Tomcat, JMeter, 效能測試, EventLoop, 負載平衡, C10K, BIO
---

# Netty vs Javax WebSocket 效能實測比較

**日期**：2026-07-02
**關鍵字**：Netty, Javax WebSocket, Tomcat, JMeter, 效能測試, EventLoop, 負載平衡

## 問題背景

高併發 WebSocket 場景下，傳統 Javax WebSocket（阻塞 IO，每連線一條執行緒，運行於 Tomcat 之上）是否能滿足效能需求，或需改採 Netty（非阻塞 IO，Reactor 執行緒模型）。以 JMeter 模擬多用戶併發連線、連續收發訊息，量測兩者的吞吐量、延遲與資源消耗差異。

## 研究結論

### 一、測試情境與方法

- 測試工具：JMeter WebSocket 外掛
- **情境一**：模擬 3000 併發用戶，連續收發 100 則訊息並觀察每則延遲；5 秒內啟動至 3000 threads
- **情境二**：模擬 6000 併發用戶，10 msg/sec、持續 60 秒（每用戶總計 600 則訊息）；因單機無法負荷 1 秒內啟動 6000 threads，啟動延遲拉長為 30 秒

> 測試機為單台開發機，JMeter 本身即佔用大量 CPU/記憶體，故以下數據僅作方向性參考，非正式產能容量數據。

### 二、情境一結果（3000 併發，總計 100 則訊息/用戶）

| Label | 取樣數 | 平均延遲(ms) | 處理量(/sec) | 每秒千位元組 |
|-------|-------|-------------|-------------|-------------|
| Javax — WebSocket request-response | 300,000 | 202 | 11,399 | 55 |
| Javax — 總計 | 306,000 | 199 | 11,584 | 74 |
| Netty — WebSocket request-response | 300,000 | 0 | 28,347 | 1,328 |
| Netty — 總計 | 306,000 | 1 | 27,719 | 1,315 |

- Javax 端另發現瓶頸來自 `messageQueue` 消化速度（500 thread、每 200ms 消化一則訊息），第 100 則訊息延遲達 20,000ms；調整消化間隔為 50ms 後降至 5,000ms，顯示此情境下 Queue 門檻本身即掩蓋了真正的系統差異。

### 三、情境二結果（6000 併發，10 msg/sec，60 秒）

| Label | Javax 50ms queue | Javax 100ms queue | Netty |
|-------|-------------------|--------------------|-------|
| Open Connection 處理量(/sec) | 192.25 | 196.25 | 200.11 |
| Single Write Sampler 處理量(/sec) | 32,215.38 | 32,703.2 | 31,397.21 |
| Single Read Sampler 處理量(/sec) | 30,023.08 | 31,510.72 | 30,572.16 |
| Close 處理量(/sec) | 137.68 | 157.68 | 167.63 |

此情境下三者的 sampler 級處理量差異不大 —— 因 CPU 已用至極限，執行緒無空檔，加快 Queue 消化頻率也沒有多餘執行緒可用。

### 四、CPU / 記憶體消耗與訊息延遲比較（情境二）

| 系統 | 平均 CPU | 記憶體 | 平均訊息 delay(ms) |
|------|---------|--------|---------------------|
| Netty | 180% | 40% | 2,727 |
| Javax 50ms queue | 314% | 38.9% | 5,146 |
| Javax 100ms queue | 283% | 40% | 4,029 |

**關鍵觀察**：Netty 用**更低的 CPU 消耗**達成**更低的訊息延遲**；當用戶數遠大於可處理的執行緒數時，Javax 的 delay 會急遽惡化（實測中曾觀察到超過 90 秒未收斂），Netty 未出現此現象。另外，Javax 多用戶同時連入時曾因 TCP port 占用問題導致連線異常，需另行處理（見下節）。

### 五、Netty 側的實作與調校紀錄

- Netty 專案以 `ServletContextListener` 方式嵌入既有 Tomcat 應用啟動（而非取代整個 Web 容器）
- 透過 `SO_REUSEADDR` 處理 TCP port 占用問題
- Worker Thread（負責收發訊息）數量預設為 **CPU 核心數 × 2**；若擔心單一 Handler 處理耗時造成阻塞，Netty 本身可搭配 Queue 排程推送訊息以保證訊息有序性

### 六、Netty EventLoop 負載平衡機制（用於解釋吞吐差異的成因）

- **Channel**：單一用戶透過握手建立的連線
- **EventLoop**：永續執行的單執行緒迴圈；一個 Channel 只綁定一個 EventLoop，一個 EventLoop 可處理多個 Channel 的 I/O / 訊息請求，依接收序存入 queue；若某一事件耗時過長會阻塞同一 EventLoop 上其他 Channel 的事件
- **EventLoopGroup**：EventLoop 的執行緒池群組；預設實作為 NIO（Netty 預設）/ Epoll（Linux）/ Kqueue（FreeBSD/macOS），啟動時建立「CPU 核心數 × 2」條 EventLoop
- **分派策略**：用戶連線依序分配至 EventLoop（依連線序號對總執行緒數取餘數做平均分配），可透過自訂 `EventExecutorChooserFactory` 客製分派邏輯（見 `MultithreadEventExecutorGroup` / `DefaultSelectStrategyFactory`）
- 實測驗證：同一用戶初始連線與後續收到的訊息皆固定使用同一個 thread id；相對地，Javax WebSocket 的 `on message` 每次呼叫的 thread id 皆不同，代表每次初始化與訊息處理都會新建執行序 —— 這也是情境二中 Javax 需要大量新建 thread 處理 6000 用戶 × 100ms 頻率訊息、進而拖累延遲的直接原因

### 七、限制與後續建議

- 測試規模（3000～6000 併發）與硬體（單台開發機）皆為有限條件，實際生產環境差距可能更大（推測硬體越強，Netty 與 Javax 的差距會被放大）
- 測試方法與實際業務情境仍有落差（Queue 門檻掩蓋差異、JMeter 本身佔用大量資源）
- 後續可行的修改方向：拉長測試時間並採固定頻率發送、拔除 Javax 端 thread queue 以獨立量測延遲、測試更大用戶規模下單機 TCP port 占用情境

## 參考

- 來源：內部 JMeter WebSocket 壓測簡報（Netty vs Javax WebSocket）
- 相關 ADR：[ADR-0002 — Embedded web container for a WebSocket-heavy workload: Undertow vs Tomcat](../ADRs/06-api-web/0002-embedded-web-container-for-websocket-workload.md)
- 相關筆記：[Netty 執行緒模型與開發手冊](netty-reactor-thread-model.md)
