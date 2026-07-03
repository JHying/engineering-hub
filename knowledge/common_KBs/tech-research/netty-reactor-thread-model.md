---
date: 2026-07-02
keywords: Netty, BIO, NIO, AIO, Reactor 模型, BossGroup, WorkerGroup, EventLoop, ChannelPipeline, ByteBuf, IdleStateHandler
---

# Netty 執行緒模型與開發手冊

**日期**：2026-07-02
**關鍵字**：Netty, BIO, NIO, AIO, Reactor 模型, BossGroup, WorkerGroup, EventLoop, ChannelPipeline, ByteBuf, IdleStateHandler

## 問題背景

Netty 是非同步、事件驅動的網路應用框架，對原生 Java NIO 做了封裝與優化，可用於實作各種協定（FTP、SMTP、HTTP、WebSocket…）。本篇整理其底層執行緒模型（主從 Reactor）與團隊實際導入時常用的開發設定，作為建置 WebSocket / TCP 服務前的內部參考手冊。

## 研究結論

### 一、Java IO 模型比較（BIO / NIO / AIO）

| | BIO | NIO | AIO |
|---|-----|-----|-----|
| IO 模型 | 同步阻塞 | 同步非阻塞（多路複用） | 異步非阻塞 |
| 編程難度 | 簡單 | 複雜 | 複雜 |
| 可靠性 | 差 | 好 | 好 |
| 吞吐量 | 低 | 高 | 高 |

- **BIO**：一個連線一個執行緒，客戶端連線請求時需啟動一條執行緒處理，閒置連線仍占用執行緒資源
- **NIO**：一條執行緒處理多個連線，連線請求註冊到多路複用器（Selector），由其輪詢哪個連線有 I/O 請求再進行處理
- **AIO（NIO.2）**：導入異步通道概念（Proactor 模式），由作業系統完成 I/O 後才通知程式啟動執行緒處理；適合連線數多且連線時間長（重操作）的場景，JDK 7 起支援

> 比喻：BIO 如同在髮廊一直等到輪到自己理髮；NIO 如同抽號碼牌、先去做其他事、輪到時再回來；AIO 如同直接請理髮師上門服務，自己完全不用等待。

### 二、Javax WebSocket（傳統阻塞模型）的問題

- 採用阻塞 IO 模式取得輸入資料，每個連線都需要獨立執行緒完成資料輸入、業務處理、資料回傳
- 併發數大時會建立大量執行緒，占用大量系統資源
- 連線建立後若當前執行緒暫時無資料可讀，該執行緒會阻塞在 read 操作，造成執行緒資源浪費

### 三、Netty 主從 Reactor 多執行緒模型

Netty 在主從 Reactor 多執行緒模型基礎上做了改進，抽象出兩組執行緒池：

- **BossGroup**：只負責 Accept 事件，維護 Selector 監聽連線請求；接收到 Accept 事件後，取得對應的 `SocketChannel`，封裝為 `NioSocketChannel` 並註冊到某個 Worker 執行緒（EventLoop）
- **WorkerGroup**：負責已建立連線的 I/O 讀寫；當 Worker 的 Selector 監聽到通道發生感興趣的事件時，交由 Handler 處理

兩者型別皆為 `NioEventLoopGroup`：
- `NioEventLoopGroup` 相當於一個事件循環組，內含多個 `NioEventLoop`
- 每個 `NioEventLoop` 是一條不斷循環執行任務的執行緒，各自持有一個 `Selector`，用於監聽綁定其上的 socket 通訊
- `NioEventLoopGroup` 的執行緒數可於建立時指定，預設為 **CPU 核心數 × 2**

**每個 Boss NioEventLoop** 的循環步驟：輪詢 Accept 事件 → 處理 Accept I/O（與 client 建立連線、生成 `NioSocketChannel` 並註冊到某個 Worker 的 Selector）→ 處理任務佇列（`runAllTasks`）

**每個 Worker NioEventLoop** 的循環步驟：輪詢 Read/Write 事件 → 處理對應 `NioSocketChannel` 的 I/O 事件 → 處理任務佇列（`runAllTasks`）

Worker 處理業務時會經過 pipeline（管道），pipeline 中維護多個處理器（Handler），並可透過 pipeline 取得對應的 Channel。

### 四、Server 端基本設置範例

```java
public class MyServer {
    public static void main(String[] args) throws InterruptedException {
        EventLoopGroup bossGroup = new NioEventLoopGroup();
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        try {
            ServerBootstrap bootstrap = new ServerBootstrap();
            bootstrap.group(bossGroup, workerGroup)
                .channel(NioServerSocketChannel.class)
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 1000 * 60 * 10)
                .childHandler(new ChannelInitializer<SocketChannel>() {
                    @Override
                    protected void initChannel(SocketChannel ch) {
                        ChannelPipeline pipeline = ch.pipeline();
                        pipeline.addLast(new HttpServerCodec());
                        pipeline.addLast(new HttpObjectAggregator(8192));
                        pipeline.addLast(new WebSocketServerProtocolHandler("/hello"));
                        pipeline.addLast(new MyServerHandler());
                    }
                });
            ChannelFuture channelFuture = bootstrap.bind(1234).sync();
            channelFuture.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}
```

- `ServerBootstrap` 為 Netty 提供的建構器，簡化 Server 端設置流程
- `.channel(...)` 指定 Server 使用的通道類型（此例為 NIO Server Socket）
- Server 啟動後回傳非同步物件 `ChannelFuture`，供其他程式對其進行關閉等操作
- `option` 分為 `BossGroup` 的 option（握手連線等 Server 端設定）與 `workerGroup` 使用的 `childOption`（連線成功後註冊入的 Channel 設定）

### 五、ChannelOption 常用設定

| Option | 作用範圍 | 說明 |
|--------|---------|------|
| `SO_KEEPALIVE` | childOption | TCP 連線保活（心跳機制），預設關閉，預設心跳間隔 7200 秒 |
| `SO_REUSEADDR` | 通常用於 option→boss | 允許重複使用本地位址與埠號，常用於服務重啟後沿用原埠號、或多網卡/多程序共用同一埠 |
| `TCP_NODELAY` | — | 關閉 Nagle 演算法，要求高即時性時，有資料即馬上發送 |

### 六、ChannelPipeline 與 Handler

- 握手成功的連線會建立一個 Channel，每個 Channel 對應一個 Pipeline
- 事件分為 **Inbound**（進入事件，從 Pipeline 的 Head 依序觸發 Handler 到 Tail）與 **Outbound**（輸出事件，從 Tail 依序觸發 Handler 到 Head）
- Handler 實作範例（繼承 `SimpleChannelInboundHandler<TextWebSocketFrame>`）：

```java
public class MyServerHandler extends SimpleChannelInboundHandler<TextWebSocketFrame> {
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, TextWebSocketFrame msg) {
        ctx.writeAndFlush(new TextWebSocketFrame("echo: " + msg.text()));
    }

    @Override
    public void handlerAdded(ChannelHandlerContext ctx) { /* 連線成功初始化 Channel 時呼叫 */ }

    @Override
    public void handlerRemoved(ChannelHandlerContext ctx) { /* 用戶斷線時呼叫 */ }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        cause.printStackTrace();
        ctx.channel().close();
    }

    @Override
    public void userEventTriggered(ChannelHandlerContext ctx, Object evt) { /* 監聽前一個 Handler 觸發的自訂事件 */ }
}
```

- 必須實作 `channelRead0`（收到訊息時的處理邏輯）
- `ctx.channel()` 可取得是哪個用戶的連線發起
- `userEventTriggered` 可用於監聽前一個 Handler 是否有觸發自訂事件，依 eventType 做不同處理

### 七、Channel 分派到 EventLoop 的策略

- 分派邏輯元件預設為 `DefaultSelectStrategyFactory.INSTANCE`：依「使用者連入流水號 對 總執行緒量」取餘數，決定進入哪一條執行緒
- 可透過 `NioEventLoopGroup` 建構子自訂 `EventExecutorChooserFactory`，客製化分派邏輯

### 八、耗時 Handler 的執行緒隔離

EventLoop 為單執行緒，若 Handler 需執行耗時操作，應獨立安排執行緒池，避免阻擋其他請求：

- **作法一**：將長時間任務丟回同一 EventLoop 排程（`ctx.channel().eventLoop().execute(...)`）—— 代價是仍占用該 EventLoop
- **作法二**（建議）：另立一個共用的 `DefaultEventLoopGroup` 處理耗時任務，`pipeline.addLast(handlerWorkGroup, new NettyJobHandler())`，處理完成後轉交回原執行緒繼續後續流程

### 九、傳輸資料緩存（ByteBuf）與流量控制

- Netty 透過 `ByteBuf` 同時進行讀寫，緩存空間依使用量自動增減（預設長度 1024 bytes，最小不低於 64 bytes，最高不大於 65536 bytes）
- 可透過 `.childOption(ChannelOption.WRITE_BUFFER_WATER_MARK, new WriteBufferWaterMark(low, high))` 設定每個 Channel 輸出緩存的高低水位；緩存用量高於高水位時 `channel.isWritable()` 回傳 false，低於低水位後回傳 true，可在 `write` 前先檢查 `isWritable()` 做流量控制

### 十、閒置連線偵測

- `IdleStateHandler(readerIdleTime, writerIdleTime, allIdleTime, unit)` 可針對讀空閒、寫空閒或讀寫空閒分別設定監控時間（0 為不啟用）
- 偵測到用戶閒置超過設定時間會觸發 `IdleStateEvent`，由下一個 Handler 的 `userEventTriggered` 接手後續邏輯（`if (evt instanceof IdleStateEvent)`）

## 參考

- 韓順平（尚硅谷）Netty 核心技術教學課程
- Netty 官方文件
- 相關筆記：[Netty vs Javax WebSocket 效能實測比較](netty-vs-javax-websocket-performance.md)
