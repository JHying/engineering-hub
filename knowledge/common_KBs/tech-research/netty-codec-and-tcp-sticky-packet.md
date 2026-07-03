---
date: 2026-07-02
keywords: Netty, Codec, ByteToMessageDecoder, ReplayingDecoder, LengthFieldBasedFrameDecoder, TCP 粘包, TCP 拆包, Protobuf, 序列化
---

# Netty 編解碼器與 TCP 粘包/拆包解決方案

**日期**：2026-07-02
**關鍵字**：Netty, Codec, Encoder, Decoder, ByteToMessageDecoder, ReplayingDecoder, TCP 粘包, TCP 拆包, Protobuf

## 問題背景

網路傳輸的資料都是二進位位元組，發送前需編碼、接收後需解碼；而 TCP 是面向流、無消息保護邊界的協定，若不處理消息邊界問題，會產生「粘包」「拆包」導致資料誤讀。本篇整理 Netty 的編解碼器機制、與原生 Java 序列化相比 Protobuf 的優勢，以及 TCP 粘包/拆包的成因與解法。

## 研究結論

### 一、編解碼器基本概念

- `encoder`（編碼器）：負責把業務資料轉換成位元組資料（出站方向）
- `decoder`（解碼器）：負責把位元組資料轉換成業務資料（入站方向）
- Netty 提供的編解碼器皆實作 `ChannelInboundHandler` 或 `ChannelOutboundHandler`：入站方向時，每次從 Channel 讀到訊息會呼叫 `channelRead`，內部再呼叫解碼器的 `decode()` 完成解碼，並將結果轉發給 pipeline 中下一個 `ChannelInboundHandler`

### 二、Java 原生序列化 vs Protobuf

Netty 內建 `ObjectEncoder` / `ObjectDecoder` 可直接對 POJO 做編解碼，但底層仍是 Java 原生序列化技術，存在三個問題：

| 問題 | 說明 |
|------|------|
| 無法跨語言 | 序列化格式綁定 Java，無法與其他語言的服務互通 |
| 序列化後體積大 | 約為對應二進位編碼的 5 倍以上 |
| 序列化效能低 | 相較專用的結構化資料格式，效能明顯較差 |

**Google Protobuf**（Protocol Buffers）是為此設計的替代方案：以 `.proto` 檔描述訊息（message）結構，透過 `protoc` 編譯器自動產生對應語言的程式碼；支援跨平台、跨語言（C++、C#、Java、Python 等），高效能、高可靠性，適合作為 RPC 的資料交換格式（對應 Netty 提供的 `ProtobufEncoder` / `ProtobufDecoder`）。多語言互通場景常見組合為 `HTTP + JSON`（人類可讀、除錯方便）或 `TCP + Protobuf`（效能優先）。

### 三、Netty 常用解碼器

| 解碼器 | 說明 |
|--------|------|
| `ByteToMessageDecoder` | 解碼器基底類別；因無法保證遠端一次性送達完整訊息（TCP 粘包/拆包問題），此類別會緩衝入站資料直到內容「準備好」才觸發解碼邏輯。實作時需自行判斷 `ByteBuf` 是否已有足夠資料（如 `in.readableBytes() >= 4`）才讀取，避免結果與預期不一致 |
| `ReplayingDecoder` | 繼承 `ByteToMessageDecoder`，使用者不需自行呼叫 `readableBytes()` 判斷資料是否足夠，撰寫較簡便；限制：並非所有 `ByteBuf` 操作都支援（呼叫不支援的方法會丟出 `UnsupportedOperationException`），且在網路慢、訊息格式複雜（被拆成多個碎片）時效能可能略低於 `ByteToMessageDecoder` |
| `LineBasedFrameDecoder` | 以行尾控制字元（`\n` 或 `\r\n`）作為訊息分隔符解析資料 |
| `DelimiterBasedFrameDecoder` | 以自訂特殊字元作為訊息分隔符 |
| `LengthFieldBasedFrameDecoder` | 透過訊息中的長度欄位標識整包訊息長度，可自動處理粘包與半包問題 |
| `HttpObjectDecoder` | HTTP 資料的解碼器 |

> Handler 調用機制的關鍵限制：不論編碼器或解碼器 Handler，其宣告的泛型訊息型別必須與實際待處理的訊息型別一致，否則該 Handler 不會被執行。

### 四、TCP 粘包/拆包問題

**成因**：TCP 是面向連接、面向流、提供高可靠性服務的協定；發送端為提高效率會用 Nagle 演算法將多次間隔小、資料量小的封包合併成一個大資料塊再送出。這提升了效率，但接收端因此難以分辨出原本各自獨立的訊息邊界（TCP 本身無消息保護邊界）。

假設客戶端依序送出兩個資料包 D1、D2，接收端一次讀取到的位元組數不確定，可能發生以下情況：

| 情況 | 說明 |
|------|------|
| 正常 | 分兩次讀到完整且獨立的 D1、D2，無粘包拆包 |
| 粘包（sticky packet） | 一次讀到 D1 + D2 黏在一起的完整資料 |
| 拆包（half packet，第一種） | 第一次讀到「完整 D1 + 部分 D2」，第二次讀到「D2 剩餘部分」 |
| 拆包（half packet，第二種） | 第一次讀到「D1 部分內容」，第二次讀到「D1 剩餘內容 + 完整 D2」 |

若 Netty 程式未做任何處理，實際運行時就會出現上述粘包/拆包現象，導致收到的資料與預期的訊息邊界不一致。

**解決策略**：核心是解決「伺服器端每次應讀取多少長度資料」的問題，一旦确定每次讀取的資料邊界，就不會再多讀或少讀。常見做法：

1. **自訂協議 + 編解碼器**：在訊息中明確定義長度欄位或分隔符，讓接收端能準確切出單一完整訊息（對應 `LengthFieldBasedFrameDecoder` / `DelimiterBasedFrameDecoder`）
2. 範例場景：客戶端連續送出 5 個 Message 物件，若無邊界處理機制，伺服器端可能讀到粘連或截斷的資料；加入長度前綴或分隔符後，伺服器可穩定地分 5 次正確解碼，每收到一個完整 Message 即可回應一個 Message 給客戶端

## 參考

- 韓順平（尚硅谷）Netty 核心技術教學課程（編解碼器、Google Protobuf、TCP 粘包拆包章節）
- Netty 官方文件
- 相關筆記：[Netty 執行緒模型與開發手冊](netty-reactor-thread-model.md)
