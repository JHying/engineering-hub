---
date: 2026-07-02
keywords: Java NIO, Buffer, Channel, Selector, SelectionKey, 零拷貝, mmap, sendFile, DMA, C10K
---

# Java NIO 核心元件：Buffer / Channel / Selector 與零拷貝

**日期**：2026-07-02
**關鍵字**：Java NIO, Buffer, Channel, Selector, SelectionKey, 零拷貝, mmap, sendFile, DMA

## 問題背景

Netty 本質上是對 Java 原生 NIO 的封裝，要理解 Netty 的執行緒模型與原始碼，需先掌握 NIO 三大核心元件（Buffer、Channel、Selector）的關係，以及高效能網路傳輸常提到的「零拷貝」機制。BIO/NIO/AIO 三種模型的整體比較已記錄於 [Netty 執行緒模型與開發手冊](netty-reactor-thread-model.md)，本篇聚焦 NIO 的元件細節。

## 研究結論

### 一、NIO 三大核心元件關係

- **Buffer（緩衝區）**：本質是可讀寫資料的記憶體塊（內含陣列），資料的讀寫都要經過 Buffer；與 BIO 的 stream 不同，Buffer 可雙向讀寫（需呼叫 `flip()` 切換讀/寫模式）
- **Channel（通道）**：雙向的資料傳輸通道，可同時讀寫、支援非同步；常用子類：`FileChannel`（本地檔案 I/O）、`DatagramChannel`（UDP）、`ServerSocketChannel` / `SocketChannel`（TCP，功能分別類似傳統的 `ServerSocket` / `Socket`）
- **Selector（選擇器）**：可同時監控多個註冊在其上的 Channel 是否有 I/O 事件發生（可讀、可寫、連線建立等），讓單一執行緒能高效管理多個連線，只有真正發生讀寫事件時才處理，大幅減少系統開銷與執行緒間 context switch 成本

> 關係：每個 Channel 對應一個 Buffer；一個 Selector 對應一個執行緒，可同時監聽多個 Channel；哪個 Channel 被處理由 Event 決定。

### 二、Buffer 四大屬性

```
// Invariants: mark <= position <= limit <= capacity
```

| 屬性 | 說明 |
|------|------|
| `capacity` | 容量，緩衝區可容納的最大資料量，建立時設定後不可變 |
| `limit` | 目前終點，不可對超過 limit 的位置做讀寫，limit 本身可修改 |
| `position` | 下一個要被讀/寫的元素索引，每次讀寫都會自動變動 |
| `mark` | 標記，可透過 `mark()` / `reset()` 回到標記位置 |

常用方法：`capacity()`、`position()` / `position(int)`、`limit()` / `limit(int)`、`mark()` / `reset()`、`clear()`（恢復初始狀態但不清除資料）、`flip()`（讀寫模式反轉）、`rewind()`、`remaining()` / `hasRemaining()`。JDK 1.6 起新增 `hasArray()` / `array()` 等取得底層陣列的方法。

最常用的子類是 `ByteBuffer`（對應 Netty 自己的 `ByteBuf`），提供 `allocate` / `allocateDirect` / `wrap` 建立緩衝區，以及 `get` / `put` 存取資料（存取後 `position` 自動 +1）。

### 三、Channel 常用子類與方法

`Channel` 是一個介面（`extends Closeable`）。`FileChannel` 常用方法：

| 方法 | 說明 |
|------|------|
| `read(ByteBuffer dst)` | 從通道讀取資料放入緩衝區 |
| `write(ByteBuffer src)` | 把緩衝區資料寫入通道 |
| `transferFrom(...)` | 從目標通道複製資料到當前通道 |
| `transferTo(...)` | 把資料從當前通道複製給目標通道（NIO 零拷貝的關鍵 API） |

### 四、Selector 與 SelectionKey

- `Selector` 為抽象類別，常用方法：`open()` 取得選擇器物件、`select(long timeout)` 監控所有註冊通道並回傳有 I/O 事件的 `SelectionKey` 集合、`selectedKeys()` 取得該集合；另有 `wakeup()`（喚醒 selector）、`selectNow()`（不阻塞立即返回）
- `SelectionKey` 表示 Selector 與某個 Channel 的註冊關係，四種事件旗標：

| 事件 | 說明 | 值 |
|------|------|-----|
| `OP_ACCEPT` | 有新連線可以 accept | 16 |
| `OP_CONNECT` | 連線已建立 | 8 |
| `OP_READ` | 可讀 | 1 |
| `OP_WRITE` | 可寫 | 4 |

- 註冊流程：客戶端連線 → `ServerSocketChannel` 產生 `SocketChannel` → 呼叫 `channel.register(selector, ops)` 註冊到 Selector 並取得對應的 `SelectionKey` → `selector.select()` 回傳有事件發生的 key 數量 → 透過 `SelectionKey.channel()` 反查回 Channel 進行實際的業務處理

> 此機制正是 Netty `NioEventLoop` 內部聚合 Selector、單一 I/O 執行緒可並發處理成百上千個客戶端連線（C10K 級別）的基礎：讀寫非阻塞、執行緒不會被單一連線的等待卡住，才能讓少量 I/O 執行緒撐起大量連線。

### 五、零拷貝（Zero-Copy）

零拷貝是網路程式效能優化的關鍵技術，核心目的是減少「核心緩衝區 ↔ 使用者緩衝區」之間不必要的資料複製與 context switch。

**傳統 IO 資料傳輸路徑**（以檔案讀取後透過 Socket 送出為例）：磁碟 → 核心緩衝區 → 使用者緩衝區（一次 CPU 拷貝）→ Socket 緩衝區（再一次 CPU 拷貝）→ 網卡，過程中發生多次 CPU 拷貝與使用者態/核心態的 context switch。

| 方式 | 原理 | Context Switch | 資料拷貝 | 適用場景 |
|------|------|----------------|---------|---------|
| `mmap`（記憶體映射） | 將檔案映射到核心緩衝區，使用者空間可直接共享核心空間資料，減少「核心→使用者」的拷貝次數 | 4 次 | 3 次 | 小資料量讀寫 |
| `sendFile`（Linux 2.1+） | 資料完全不經過使用者態，直接從核心緩衝區進入 Socket Buffer | 3 次 | 2 次（2.1 版本） | 大檔案傳輸 |
| `sendFile`（Linux 2.4+ 改進） | 進一步避免核心緩衝區拷貝到 Socket Buffer，直接拷貝到協定棧；僅剩的一次 CPU 拷貝只搬移 length/offset 等少量資訊，成本可忽略 | 3 次 | 最少 2 次（其中僅 1 次為極輕量的 CPU 拷貝） | 大檔案傳輸 |

- `DMA`（Direct Memory Access）：資料在磁碟與核心緩衝區之間搬移時，可不經過 CPU 直接完成拷貝；`sendFile` 能充分利用 DMA 減少 CPU 拷貝，`mmap` 則不能（必須從核心拷貝到 Socket 緩衝區）
- 「零拷貝」是從**作業系統角度**而言：核心緩衝區之間沒有重複資料（只有一份）。除了減少資料複製次數，還能帶來更少的 context switch、更少的 CPU cache 偽共享、免除 CPU 校驗和計算等效益
- NIO 對應 API：`FileChannel.transferTo(...)` 即為零拷貝方式傳輸大檔案，可與傳統 IO 方式（讀入 byte[] 再寫出）比較實測耗時差異

## 參考

- 韓順平（尚硅谷）Netty 核心技術教學課程
- Netty 官方文件
- 相關筆記：[Netty 執行緒模型與開發手冊](netty-reactor-thread-model.md)、[Netty vs Javax WebSocket 效能實測比較](netty-vs-javax-websocket-performance.md)
