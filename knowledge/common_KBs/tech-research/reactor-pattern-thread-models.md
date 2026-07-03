---
date: 2026-07-02
keywords: Reactor 模式, 單 Reactor 單線程, 單 Reactor 多線程, 主從 Reactor 多線程, Dispatcher, I/O 多路複用, Netty, Nginx
---

# Reactor 模式三種實現方式比較

**日期**：2026-07-02
**關鍵字**：Reactor 模式, 單 Reactor 單線程, 單 Reactor 多線程, 主從 Reactor 多線程, Dispatcher, I/O 多路複用

## 問題背景

傳統阻塞 I/O 服務模型（每連線一條執行緒）在高併發下會建立大量執行緒、佔用大量系統資源，且連線閒置時執行緒仍會阻塞在 read 操作上、浪費執行緒資源。Reactor 模式是業界解決此問題的通用架構模式（不限於 Netty，Nginx、Memcached 等也採用其變體），依 Reactor 與工作執行緒池的數量組合，有三種典型實現方式。

## 研究結論

### 一、Reactor 模式核心概念

基於「I/O 多路複用 + 執行緒池複用」的設計思想：
- **I/O 多路複用**：多個連線共用一個阻塞物件，應用程式只需在單一阻塞物件上等待，不必為每個連線各自阻塞等待；當某連線有新資料時，作業系統通知應用程式，執行緒從阻塞狀態返回開始處理
- **執行緒池複用**：不必為每個連線建立執行緒，將連線的業務處理任務分派給執行緒池處理，一條執行緒可服務多個連線的業務

核心組成：
- **Reactor**：在獨立執行緒中運行，負責監聽並分發事件給對應的處理程式（類似總機接線生，負責接聽來電並轉接到正確的窗口）
- **Handler**：執行 I/O 事件的實際處理邏輯（類似客戶真正要洽談的窗口人員），以非阻塞方式執行

Reactor 模式又稱 Dispatcher 模式（反應器模式 / 分發者模式 / 通知者模式），透過 I/O 多路複用監聽事件、收到事件後分發給對應執行緒（或程序）處理，是網路伺服器支撐高併發的關鍵設計。

### 二、單 Reactor 單執行緒

**流程**：Reactor 透過 `Select` 監控所有客戶端請求事件 → 若是連線請求，由 `Acceptor` 處理並建立對應 `Handler` → 若非連線請求，則分發給對應連線的 `Handler` 執行「Read → 業務處理 → Send」的完整流程，全部在同一條執行緒中完成。

| 項目 | 說明 |
|------|------|
| 優點 | 模型簡單，無多執行緒、行程通訊、資源競爭問題 |
| 缺點（效能） | 單一執行緒無法發揮多核 CPU 效能；某連線業務處理耗時會卡住整個程序，容易成為效能瓶頸 |
| 缺點（可靠性） | 執行緒意外終止或進入死迴圈，會導致整個通訊模組不可用 |
| 適用場景 | 客戶端數量有限、業務處理非常快速（時間複雜度 O(1)），例如 Redis |

### 三、單 Reactor 多執行緒

**流程**：與單執行緒版相同由 Reactor 監控與分派連線事件，但 `Handler` 本身**只負責讀取資料、不做具體業務處理**——讀到資料後轉交給後方的 **Worker 執行緒池**中的某條執行緒處理業務，處理完成後結果交回 `Handler`，再由 `Handler` 透過 `send` 回傳給 client。

| 項目 | 說明 |
|------|------|
| 優點 | 可以充分利用多核 CPU 的處理能力 |
| 缺點 | 多執行緒間的資料共享與存取較複雜；所有事件的監聽與分派仍集中在單一 Reactor 執行緒，高併發場景下容易成為瓶頸 |

### 四、主從 Reactor 多執行緒

**流程**：將 Reactor 本身也拆成多執行緒，解決單 Reactor 多執行緒模型中「Reactor 監聽/分派仍是單點瓶頸」的問題。

- **MainReactor**（主執行緒）：透過 `select` 監聽連線事件，由 `Acceptor` 處理連線建立
- 連線建立後，MainReactor 將連線分配給某個 **SubReactor**（可對應多個子執行緒，一個 MainReactor 可關聯多個 SubReactor）
- SubReactor 將連線加入自己的監聽佇列，並為其建立 `Handler`
- 當該連線有新事件發生時，SubReactor 呼叫對應 `Handler`；`Handler` 讀取資料後同樣分派給後方 **Worker 執行緒池**做業務處理，處理完成後由 `Handler` 回傳結果給 client

| 項目 | 說明 |
|------|------|
| 優點 | 父執行緒（Main）與子執行緒（Sub）職責分明、資料交互簡單：父執行緒只負責接收新連線並轉交，子執行緒完成後續所有 I/O 與分派 |
| 缺點 | 程式設計複雜度較高 |
| 實際案例 | 廣泛用於各類高併發伺服器：Nginx 的主從 Reactor 多行程模型、Memcached 的主從多執行緒、以及 **Netty 的主從 Reactor 多執行緒模型**（見 [Netty 執行緒模型與開發手冊](netty-reactor-thread-model.md)） |

### 五、三種模式生活化比喻與總結

- **單 Reactor 單執行緒**：前台接待員與服務員是同一人，從頭到尾服務同一位顧客
- **單 Reactor 多執行緒**：1 位前台接待員 + 多位服務員，接待員只負責接待轉單
- **主從 Reactor 多執行緒**：多位前台接待員 + 多位服務員，接待與服務都可並行

Reactor 模式整體優點：
- 回應快，不必被單一同步操作阻塞（雖然 Reactor 本身的事件監聽仍是同步的）
- 避免複雜的多執行緒同步問題，同時避免了多執行緒/行程切換的開銷
- 擴充性好：可透過增加 Reactor（或 SubReactor）實例數量，充分利用 CPU 資源
- 複用性好：Reactor 模型本身與具體事件處理邏輯無關，複用性高

### 六、Netty 對主從 Reactor 模式的改進

Netty 主要基於主從 Reactor 多執行緒模型做了改進，抽象為 `BossGroup`（對應 MainReactor，只負責 Accept）與 `WorkerGroup`（對應 SubReactor + Worker，負責已建立連線的 I/O 讀寫與業務處理），並引入 `NioEventLoop` 內部的**串行化設計**（訊息的讀取 → 解碼 → 處理 → 編碼 → 發送，全程由同一條 `NioEventLoop` 負責，避免多執行緒切換 pipeline 處理階段的額外開銷）。詳細元件關係與程式範例見 [Netty 執行緒模型與開發手冊](netty-reactor-thread-model.md)。

## 參考

- 韓順平（尚硅谷）Netty 核心技術教學課程（Reactor 模式章節）
- 《Scalable IO in Java》（Doug Lea）— Multiple Reactors 原理圖解，為本主題的經典參考資料
- 相關筆記：[Netty 執行緒模型與開發手冊](netty-reactor-thread-model.md)、[Netty vs Javax WebSocket 效能實測比較](netty-vs-javax-websocket-performance.md)
