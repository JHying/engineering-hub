---
name: contract-test
description: >
  根據指定的 Controller 生成符合本專案慣例的 Spring Cloud Contract 契約檔與 ContractBase。
  支援 HTTP Controller（Groovy DSL + MockMVC stub）與 jakarta websocket Controller
  （messaging DSL + 自訂 MessageVerifier，驗訊息 payload 層級契約）。
  契約用於 producer 自動化驗收測試，HTTP 同時產生 consumer MockMVC stub。
version: "1.2"
---

根據指定的 Controller，生成 Spring Cloud Contract 契約檔與對應的 ContractBase。

## 使用方式

```
/contract-test <ControllerName>
```

例：`/contract-test BalanceController`、`/contract-test <Feature>WsController`

## 型別偵測與分流

讀取 `<ControllerName>.java` 的類別註解，自動分流：

| Controller 型別 | 判別 | 流程明細 |
|----------------|------|---------|
| HTTP | `@RestController`，或 `@Controller` + `@RequestMapping` | `references/http-contract.md`（groovy 完整範本另見 `references/http-contract-templates.md`） |
| WebSocket | `@ServerEndpoint`（jakarta websocket） | `references/ws-contract.md` |

兩者皆非（或同時存在）→ 停下詢問使用者。

## 流程摘要

**HTTP**：讀 Controller + DTO validation annotation + AppService 業務例外 →
每個 endpoint 生 `_valid.groovy` / `_invalid.groovy`（400/401 情境）+ `@WebMvcTest` ContractBase。

**WebSocket**：SCC 不支援 WS transport，改走 messaging DSL 驗 payload 契約——
讀 envelope 結構與 action↔DTO 映射（優先用 message-type enum 標註）→
每個 action 生 `_valid.groovy` / `_invalid.groovy`（`triggeredBy` + `outputMessage`）+
mock Session 的 WsContractBase；專案首次導入時附一次性基礎建設（pom plugin + 自訂 MessageVerifier）。
特殊回應形狀（無回應、status 200 回失敗、echo 型、server push only）處理規則見明細檔第 6 節。

## 共通規則

- 生成前先確認專案既有 contract 慣例（目錄結構、base class 命名），有既有檔案就對齊
- Controller unit test 與 contract 高度重疊時，刪除 controller test，以 contract 為唯一驗證來源
- 生成後以 `mvn clean test` 驗證（incremental compile 會跳過 contract 重新生成，一律 `clean`）
- error message 一律從原始碼讀取（annotation message、controller 手驗字串、AppService 例外），不憑推測編寫
