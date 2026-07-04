---
date: 2026-07-04
keywords: WebSocket, API 文件生成, AsyncAPI, Springwolf, STOMP, Jakarta WebSocket, Swagger, 自定義 Annotation, API Gateway
---

# WebSocket API 文件自動生成 — 選型與架構決策

## 問題背景

WebSocket 不像 REST 有 Swagger / OpenAPI 這類事實標準的文件生成方案。當一個系統中有多個 service 各自維護 WebSocket 端點時，缺乏文件會讓跨團隊串接、測試變得困難。需要研究一套能夠：

1. 自動產生 WebSocket API 文件（無須完全手寫）
2. 供多個 service 共用、統一維護方式
3. 能整合成一個跨 service 的測試入口

的做法，並評估現成工具生態系是否可直接採用，或需要自建方案。

## 研究結論

### 1. 現成工具比較

| 工具 / 方案 | 支援程度 | 適用場景 |
|---|---|---|
| Swagger / OpenAPI | 不支援 WebSocket | 只能做 REST API |
| Smart-Doc | 不支援 WebSocket | 只能做 REST API、Dubbo、gRPC |
| AsyncAPI + Springwolf | 部分支援，仍需手動寫配置 | 只支援 STOMP、Kafka、RabbitMQ |
| Postman | 手動建檔並測試 | 適合手動測試和分享，WebSocket 類型仍在 beta（見 Postman 官方 GitHub issue tracker，WebSocket 支援長期停留在 beta 階段） |
| 自定義 Annotation 生成 | 半自動化 | 需自訂 annotation，可於編譯期自動生成文件 |

排除理由：

- **Postman**：WebSocket 支援仍為 beta 狀態，無法完全文件化。
- **AsyncAPI 單獨使用**：需手寫 YAML + 額外建置外掛，CI 環境需額外引入文件產生工具鏈，影響範圍含建置設定、YAML、CI 環境，導入成本偏高。
- **AsyncAPI + Springwolf**：僅支援 STOMP / AMQP / MQTT / Kafka 等訊息協議；若專案採 Jakarta WebSocket + 自訂協議（非標準訊息協議），則不適用。
- 曾嘗試以 AI 輔助生成 API 物件規格，正確率高、速度快，但 header 與 request 參數仍需人工校正，尚無法完全免人工。

**結論**：選擇「自定義 annotation + 自動掃描生成文件」路線，捨棄現成的 AsyncAPI 生態系，改為編譯期自動產文件。

### 2. 協議選型比較：Jakarta WebSocket + 自訂協議 vs Spring WebSocket + STOMP

> 以下為概略估算比較（未實測，僅供參考），估算基準約 6000 QPS 情境。

| 面向 | Jakarta WebSocket + 自訂協議 | Spring WebSocket + STOMP | 差異說明 |
|---|---|---|---|
| 連接開銷 | 低 | 中 | STOMP 需額外握手 |
| 訊息開銷 | 低 | 中高 | STOMP 有協議頭 |
| CPU 使用 | 低 | 中 | STOMP 需解析協議 |
| 記憶體 | 低 | 中高 | STOMP 需維護訂閱表 |
| 延遲 | 約 1ms | 約 2-3ms | 協議解析開銷 |
| 吞吐量 | 高 | 中高 | 視實作品質而定 |
| 開發效率 | 低 | 高 | 自行實作 vs 框架內建 |
| 可維護性 | 低 | 高 | 自訂協議 vs 標準協議 |

粗估：在約 6000 QPS 情境下，STOMP 相較自訂協議，頻寬 +53%、延遲 +100%、CPU +50%、記憶體 +50%。

**決策**：延遲敏感、訊息體積小、團隊具備自行維護協議能力的場景，維持 Jakarta WebSocket + 自訂協議；STOMP 雖能搭配現成工具自動產文件，但改動成本高、對本情境無明顯效益優勢，暫不採用，僅留紀錄供未來參考。

**STOMP 較適用的情境**（供日後選型參考）：需快速開發、團隊規模小、需與外部系統標準化對接、效能要求非極致、吞吐量落在中低區間（約數千 QPS 以下）的場景。

### 3. 最終架構

由 API Gateway 提供統一的測試入口，各 service 各自維護自己的 WebSocket 設定（ws-config），架構如下（服務名稱以通用代稱表示）：

```
API Gateway
 ├─ Static: websocket-test.html, ws-config-common
 ├─ GET /api/ws-services → [服務清單]
 └─ fetch 各服務 config
      ├─ /service-a/ws-config → service-a (Endpoint: /ws-config)
      ├─ /service-b/ws-config → service-b (Endpoint: /ws-config)
      └─ /service-c/ws-config → service-c (Endpoint: /ws-config)
```

原則：

- 各 service 的文件由引用共用工具包並完成配置後自動生成，具備跨 service 通用性。
- API Gateway 手動維護或自動發現各服務，整合成統一對外測試頁面（概念類似 Swagger UI 的整合方式）。
- 共用工具包需提供「是否啟用測試頁面」的開關與對應配置說明，避免非預期環境誤開啟。

### 4. 測試整合方案

- 由 API Gateway 維護整合測試介面；各 service 配置 ws-config 產生工具後自動產生文件；API Gateway 自動註冊具備測試文件的服務，於整合測試介面提供服務選單（概念類似 Swagger 整合，可直接操作測試）。
- Production 環境非必要不開放此功能。
- 待優化項目：API Gateway 與容器編排平台（如 Kubernetes）整合，改為服務全自動發現（routes list、WebSocket endpoint、文件 endpoint 自動探測），目前仍為手動註冊階段。
- 落地驗證：已於本地完成兩個 service（API Gateway 與其中一個業務 service）的工具包配置測試，驗證可行。

### 5. 最終成果

落地工具：一個共用工具包內建的 WebSocket Session 管理元件。各 service 完成配置後，會在編譯階段自動生成類 Swagger 的文件，無須手動維護文件內容。

### 6. 決策摘要

| 決策點 | 結果 |
|---|---|
| 文件生成方式 | 自定義 annotation + 自動掃描 → 編譯期生成；不採用 AsyncAPI / Springwolf |
| 協議 | 維持 Jakarta WebSocket + 自訂協議；STOMP 方案僅留參考，未採用 |
| 管理架構 | API Gateway 統一整合各 service 的 ws-config，具跨 service 通用性 |
| 測試方式 | API Gateway 提供類 Swagger UI 整合測試頁，正式環境預設關閉 |
| 落地狀態 | 共用工具包已可用，兩個 service 本地驗證通過；服務自動發現（容器編排整合）待後續優化 |

## 參考

- 無外部連結（原始內部文件連結因含內部網域資訊已排除）
