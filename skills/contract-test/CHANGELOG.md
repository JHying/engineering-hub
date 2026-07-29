# Changelog — contract-test

所有版本異動依時間倒序排列。

---

## [1.2] — 2026-07-29

### Added
- WebSocket Controller 支援（jakarta websocket `@ServerEndpoint`）：SCC 原生不支援 WS transport，改走 messaging DSL 驗訊息 payload 層級契約
  - 依類別註解自動分流 HTTP / WS 流程，兩者皆非或並存時停下詢問
  - WS 流程：解析雙層 envelope（外層協定欄位 + 內層 msgType/msg）、action↔DTO 映射優先讀 message-type enum 標註、驗證雙軌盤點（jakarta validation 手動觸發 + controller 手驗）、錯誤 status catch 階梯對照表
  - 每個 action 生 `_valid`/`_invalid` 契約（`triggeredBy` + `outputMessage`）+ mock Session 的 WsContractBase（同步化非同步入口、ArgumentCaptor 攔截發送）
  - 專案首次導入附一次性基礎建設範本（maven plugin baseClassMappings + 自訂 MessageVerifierSender/Receiver）
  - 特殊回應形狀規則：成功無回應（不生契約、base 補 verify never 測試）、status 200 回失敗 msgType、echo 型回原 request DTO、server push only 不生 request 契約

### Changed
- `SKILL.md` 拆分為骨幹 + `references/`（progressive disclosure，比照 sdlc-agent 2.20 拆檔模式）：
  - `references/http-contract.md` — 原 HTTP 生成步驟、注意事項逐字搬移
  - `references/http-contract-templates.md` — 原 HTTP groovy 完整範本（因單檔超過 250 行門檻再拆一層）
  - `references/ws-contract.md` — 新增之 WS 生成明細
- description 更新為涵蓋 HTTP 與 WebSocket 兩種 Controller

### Context
- 起因：原 skill 僅支援 HTTP Controller；使用者需求為丟任何 Controller（含 WS）皆可生成契約測試。WS 端經實際專案原始碼分析後定案 payload 契約路線（SCC WS transport 支援為官方開放需求，尚未實作）

---

## [1.1] — 2026-07-05

### Added
- frontmatter 補上 `version` 欄位

---

## [1.0] — 初版

### Added
- 根據指定 Controller 自動生成 Spring Cloud Contract Groovy DSL 契約檔
- 讀取 Controller endpoint、request / response DTO 及 validation annotation，推導契約內容
- 生成 `_valid.groovy`：單一合法請求情境，依欄位規則自動選擇 consumer/producer matcher
- 生成 `_invalid.groovy`：涵蓋 400（`@NotBlank` / `@NotNull` / `@PositiveOrZero` 欄位違規）與 401（service 層 AuthenticationException）異常情境清單
- 生成對應的 `ContractBase.java`：含 `@WebMvcTest`、`@MockitoBean`、Mockito LIFO mock 設定規則
- `Timestamp` / `LocalDateTime` 欄位自動套用 ISO 8601 regex matcher
- `MethodArgumentNotValidException` / `AuthenticationException` 統一 response body 格式支援
