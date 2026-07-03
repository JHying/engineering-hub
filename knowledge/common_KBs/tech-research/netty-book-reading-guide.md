---
date: 2026-07-02
keywords: Netty, Netty in Action, Netty 权威指南, 書籍導覽, ByteBuf 原始碼, EventLoop 原始碼, 高性能之道, 可靠性, 安全性
---

# Netty 參考書籍導覽（章節地圖）

**日期**：2026-07-02
**關鍵字**：Netty, Netty in Action, Netty 权威指南, 書籍導覽, 原始碼分析, 高性能之道

## 問題背景

團隊資料夾內有兩本完整的 Netty 出版書籍（《Netty in Action》中譯本《Netty 实战》272 頁、李林鋒《Netty 权威指南 第2版》574 頁）。兩本書內容完整且屬版權著作，不適合整段複製進 KB；但團隊日後深入研究 Netty 特定主題（例如原始碼、可靠性設計）時，直接查書會比重新做研究更有效率。本篇只整理**章節地圖**與**各章涵蓋範圍摘要**，作為查閱索引，不重製書籍內文。原始檔案位置：使用者本機 Downloads/Telegram Desktop（未納入 repo）。

## 研究結論

### 一、《Netty 实战》（Netty in Action 中譯本，272 頁，4 大部分 + 附錄）

| 部分 | 涵蓋章節 | 摘要 |
|------|---------|------|
| 第一部分 概念及體系結構 | 第 1–9 章 | Netty 核心元件總覽（Channel / Future / ChannelHandler / EventLoop）、第一個 Echo 應用、傳輸層（NIO/Epoll/OIO/Local/Embedded）、`ByteBuf` API 與記憶體分配、`ChannelHandler` / `ChannelPipeline` / `ChannelHandlerContext` 深入、EventLoop 與執行緒模型、各種引導（Bootstrap）情境、EmbeddedChannel 單元測試 |
| 第二部分 編解碼器 | 第 10–11 章 | 編解碼器框架（`ByteToMessageDecoder` / `MessageToByteEncoder` 等抽象類別體系）、SSL/TLS、HTTP/HTTPS、WebSocket、分隔符/長度協議解碼、JDK 序列化 / JBoss Marshalling / Protocol Buffers 三種序列化方式比較 |
| 第三部分 網路協議 | 第 12–13 章 | WebSocket 應用實作、UDP 廣播應用 |
| 第四部分 案例研究 | 第 14–15 章 | 業界真實案例：Droplr（行動服務上傳體驗）、Firebase（即時資料同步、長輪詢）、Urban Airship（大量並發連線）、Facebook Nifty/Swift（Thrift over Netty）、Twitter Finagle（RPC 框架） |
| 附錄 | 附錄 A | Maven 使用介紹 |

**適合查閱情境**：想找「某個 Netty API 的正規用法／設計理由」（作者為 Netty 核心貢獻者，內容偏 API 設計思路）、想參考業界大型系統如何用 Netty 解決實際問題。

### 二、《Netty 权威指南 第2版》（李林鋒著，574 頁，6 大篇）

| 篇 | 涵蓋章節 | 摘要 |
|------|---------|------|
| 基礎篇：走進 Java NIO | 第 1–2 章 | I/O 模型基礎、Linux 網路 I/O、BIO/偽異步 IO/NIO/AIO 四種模型原始碼對比、選擇 Netty 的理由 |
| 入門篇：Netty NIO 開發指南 | 第 3–5 章 | 開發環境搭建、Netty 服務端/客戶端開發、**TCP 粘包/拆包問題完整案例**（含改造前後對照）、分隔符與定長解碼器應用 |
| 中級篇：Netty 編解碼開發指南 | 第 6–9 章 | 編解碼技術總論（Java 序列化缺點、業界主流框架）、MessagePack、**Google Protobuf**（含圖書訂購範例）、JBoss Marshalling |
| 高級篇：Netty 多協議開發和應用 | 第 10–14 章 | HTTP 協議開發、WebSocket 協議開發、**私有協議棧完整設計案例**（含握手、心跳檢測、斷線重連、可靠性/安全性設計）、服務端/客戶端建立原始碼分析 |
| 源碼分析篇：Netty 功能介紹和源碼分析 | 第 15–19 章 | **`ByteBuf` 原始碼**（含記憶體池 `PooledByteBuf` 原理）、`Channel` 與 `Unsafe` 原始碼、`ChannelPipeline` / `ChannelHandler` 原始碼、**`EventLoop` 與 `NioEventLoop` 原始碼**（含 Reactor 三種模型與 Netty 線程模型最佳實踐）、`Future` 與 `Promise` 原始碼 |
| 架構和行業應用篇：Netty 高級特性 | 第 20–25 章 | Netty 邏輯架構剖析、Java 多執行緒在 Netty 中的應用（JMM、CAS、讀寫鎖）、**高性能之道**（異步非阻塞、無鎖化串行設計、零拷貝、記憶體池、TCP 參數調校、主流 NIO 框架效能對比）、可靠性設計（鏈路檢測、Reactor 執行緒保護、流量整形）、安全性（SSL 雙向認證）、未來展望 |

**適合查閱情境**：需要**原始碼層級**細節（如 `PooledByteBuf` 記憶體池原理、`NioEventLoop` 內部設計）、需要一份完整的**私有協議 / 心跳 / 斷線重連**實作範本、想找「Netty 高性能 8 大手段」的系統化整理（第 22 章）。

### 三、與現有 KB 筆記的對應關係

以下主題本 KB 已有濃縮整理，非必要不需再翻書：

| 主題 | 已有筆記 |
|------|---------|
| BIO/NIO/AIO 比較、Netty 主從 Reactor 基本模型、開發設定 | [Netty 執行緒模型與開發手冊](netty-reactor-thread-model.md) |
| NIO Buffer / Channel / Selector 元件細節、零拷貝 | [Java NIO 核心元件：Buffer / Channel / Selector 與零拷貝](nio-buffer-channel-selector-zero-copy.md) |
| Reactor 模式三種變體比較 | [Reactor 模式三種實現方式比較](reactor-pattern-thread-models.md) |
| 編解碼器、TCP 粘包/拆包 | [Netty 編解碼器與 TCP 粘包/拆包解決方案](netty-codec-and-tcp-sticky-packet.md) |
| Netty vs Javax WebSocket 實測效能數據 | [Netty vs Javax WebSocket 效能實測比較](netty-vs-javax-websocket-performance.md) |

尚未整理、僅存在於書中的深度主題（如需要再評估是否整理）：`ByteBuf` 記憶體池原始碼、`NioEventLoop` 原始碼細節、私有協議完整案例（心跳/斷線重連/安全性設計）、Netty 高性能 8 大手段系統化整理、Facebook/Twitter 業界案例。

## 參考

- 《Netty in Action》/《Netty 实战》中譯本
- 李林鋒，《Netty 权威指南 第2版》
- 原始檔案：使用者本機 `Downloads/Telegram Desktop/`（未納入 repo，如需查閱請向擁有者索取）
