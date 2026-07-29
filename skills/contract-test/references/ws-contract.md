# WebSocket Controller 契約生成（明細）

適用：jakarta websocket（`@ServerEndpoint` + `@OnMessage`）的訊息式 endpoint。

> Spring Cloud Contract 原生不支援 WebSocket transport（僅 HTTP 與 messaging）。
> 本流程採 **messaging DSL + 自訂 MessageVerifier**：契約驗「收到什麼 action → 回什麼 payload/錯誤」的
> **訊息 payload 層級**，繞過 WS transport，直接驅動 controller 的訊息處理方法。

## 生成步驟

### 1. 讀取 WS Controller 結構

1. 找到 `@ServerEndpoint` 類別，記錄：`@OnMessage` 簽名（文字/二進位雙入口時以文字入口為契約基準）、訊息 envelope 類別
2. 解析 **envelope 結構**（常見為雙層）：
   - 外層：`{msgId, type(協定層 REQUEST/RESPONSE/ERROR/HEART_BEAT), payload, timestamp, status}`
   - 內層 payload：`{msgType(業務 action), msg(實際 DTO)}`
   - 契約的 action 判別欄位是**內層 `msgType`**，不是外層 `type`
3. 找 action 映射來源：若 message-type enum 上有標註（如 `@WsMessage(requestDto=..., responseDto=..., responseIsList=...)`），
   **直接以該標註為 action ↔ DTO 對照表**，不要自己從 switch 分支反推；無標註才讀 dispatch switch
4. 記錄回應發送路徑（如 `session.getAsyncRemote().sendText(json)` 或壓縮後 `sendBinary`）——
   ContractBase 的訊息擷取點以此為準
5. 確認 `@OnMessage` 是否丟執行緒池非同步處理：是 → ContractBase 需同步化（注入 same-thread executor，
   或依專案既有測試慣例直接呼叫內部 handler 方法）

### 2. 盤點驗證規則（雙軌）

JSR-356 不經 Spring argument resolver，`@Valid` 不會自動生效，驗證通常為以下兩軌並存，**逐 action 確認**：

| 驗證方式 | 判別 | invalid 情境的 error message 來源 |
|---------|------|-------------------------------|
| jakarta validation（controller 手動觸發 `validator.validate`） | DTO 欄位有 `@NotBlank`/`@NotNull`/`@Size`/`@Min`/`@Max` 等 | violation 串接格式（如 `"<propertyPath>: <message>"`，多筆以 `"; "` 串接——以專案實際串接邏輯為準） |
| controller 手動驗證 | DTO 無 annotation，controller 內 if 分支檢查 | 直接讀該 if 分支的錯誤字串 |

**錯誤 status 對應**：讀各 handler 的 catch 階梯建表（範例）：

| 例外 | status |
|------|--------|
| 驗證失敗（validation exception） | 400 |
| `IllegalArgumentException` | 400 |
| `AccessDeniedException` | 403 |
| 查無資料（NotFound 類） | 404 |
| 其他 `Exception`（含**未知 msgType 字串** → enum `valueOf` 拋 IAE 被外層 catch 吃掉的情況） | 500 |

**WS 錯誤 envelope 與 HTTP 不同構**，不要沿用 HTTP 的 `{status, errors[], payload}`：

```json
{ "msgId": "<原 msgId>", "type": "ERROR", "payload": { "msgType": "ERROR", "msg": "<單一錯誤字串>" }, "timestamp": 0, "status": 400 }
```

另注意：`@OnError` 通常只 log + 關閉 session、**不回訊息**，不入契約。

### 3. 一次性基礎建設（專案首次導入 WS 契約時）

1. `pom.xml` 加 `spring-cloud-contract-maven-plugin`（`testFramework=JUNIT5`），
   `baseClassMappings` 將 `contracts/ws/**` 對應到 WS ContractBase
2. 建自訂 MessageVerifier（SCC messaging 的 custom 整合）：
   - `MessageVerifierSender`：no-op（契約一律用 `triggeredBy`，不走 sender）
   - `MessageVerifierReceiver`：從 ContractBase 的 captured-message queue poll
     （ContractBase 以 `ArgumentCaptor` 攔截 `sendText` 內容後塞入 queue）
3. 以上僅第一次需要；skill 執行時先檢查專案是否已有此建設，已有則跳過

### 4. 產生契約檔

每個 action 產生兩個檔案，放在 `src/test/resources/contracts/ws/<action>/`：

#### `<action>_valid.groovy`

```groovy
package contracts.ws.<action>

import org.springframework.cloud.contract.spec.Contract

Contract.make {
    label '<action>_valid'
    description "WS <ACTION> - valid request returns RESPONSE"
    input {
        triggeredBy('sendValid<Action>Request()')   // ContractBase 內的方法
    }
    outputMessage {
        sentTo 'ws-out'
        body([
            msgId    : 'FIXED_MSG_ID',              // ContractBase 送出的固定 msgId，回應原樣帶回
            type     : 'RESPONSE',
            status   : 200,
            payload  : [
                msgType: '<ACTION>',
                msg    : [ /* response DTO 固定值，時間欄位用 matcher */ ]
            ],
            timestamp: $(consumer(1000000000000L), producer(regex('[0-9]+')))
        ])
    }
}
```

**Matcher 規則**：

| 欄位 | 規則 |
|------|------|
| `timestamp` | producer 端 `regex('[0-9]+')`（server 取當下時間，非決定性） |
| `msgId` | 固定值（由 ContractBase 的 trigger 方法控制，回應原樣帶回） |
| 時間類 response 欄位 | 比照 HTTP 規則（ISO 8601 regex） |
| 其他 | 固定值 |

#### `<action>_invalid.groovy`

檔案頂部行內註解列出所有異常情境，內容為 `[ Contract.make{...}, ... ]` list；
每個情境一個 `label` + `triggeredBy`（ContractBase 一個情境一個 trigger 方法），
`outputMessage` 為上述 ERROR envelope（`type: 'ERROR'`、`payload.msgType: 'ERROR'`、`payload.msg` 為錯誤字串、`status` 依對應表）。

### 5. 產生 WsContractBase

檔案路徑：`src/test/java/.../contract/<Feature>WsContractBase.java`

```java
@SpringBootTest(classes = WsContractTestConfig.class)   // 最小 context：controller bean + mocks + MessageVerifier
public abstract class <Feature>WsContractBase {

    @Autowired <Feature>WsController controller;
    @MockitoBean <Feature>AppService <feature>AppService;

    Session session;                    // mock(Session.class)
    RemoteEndpoint.Async asyncRemote;   // mock，ArgumentCaptor 攔 sendText

    @BeforeEach
    void setup() {
        session = mock(Session.class);
        asyncRemote = mock(RemoteEndpoint.Async.class);
        when(session.isOpen()).thenReturn(true);
        when(session.getUserProperties()).thenReturn(new HashMap<>());   // 讓發送走未壓縮 sendText 路徑
        when(session.getAsyncRemote()).thenReturn(asyncRemote);
        // 攔截 sendText → 塞入 MessageVerifierReceiver 的 queue
        doAnswer(inv -> { capturedQueue.add(inv.getArgument(0)); return null; })
            .when(asyncRemote).sendText(anyString());
        // AppService mock：比照 HTTP 版的 any() + argThat LIFO 規則
    }

    // 每個契約一個 trigger 方法：組 envelope JSON → 呼叫 controller 訊息入口（同步）
    public void sendValid<Action>Request() { ... }
    public void sendBlank<Field>Request() { ... }
}
```

**ContractBase 規則**：

- mock `Session` 最小三件套：`isOpen()`、`getUserProperties()`（回可變 Map）、`getAsyncRemote()`
- validator 用真實 instance（`Validation.buildDefaultValidatorFactory().getValidator()`），不 mock
- 驗證失敗情境（400）不需 AppService mock；業務例外情境需 `argThat` mock，LIFO 規則同 HTTP 版
- 非同步入口同步化：優先注入 same-thread executor；專案既有測試若以反射直呼內部 handler，沿用該慣例

### 6. 特殊回應形狀（逐 action 檢查，SCC 表達力邊界）

| 形狀 | 處理方式 |
|------|---------|
| 成功時**不回任何訊息**的 action | SCC messaging 無法表達「無 output」→ **不生契約**，改在 ContractBase 加一般 `@Test`（`verify(asyncRemote, never()).sendText(...)`），並在該 action 的 `_valid.groovy` 位置留註解說明 |
| 失敗但回 `status: 200` + 專用失敗 `msgType`（如 `*_FAILED`） | 契約照實寫 `status: 200`，`payload.msgType` 用失敗值——**不要**想當然改成 ERROR envelope |
| echo 型 action（回應即原 request DTO） | response body 直接複用 request DTO 欄位值 |
| server push only 的 msgType（不可作為 request） | 不生 request 契約；如需可另生 output-only 契約（僅 `outputMessage`） |

### 7. 序列化注意

- 內層 `msg` 欄位可能有兩種解析路徑（直接物件反序列化 vs 先轉 JSON 字串再解析）——
  trigger 方法組 envelope 時一律用**物件形式**，並跑一次實測確認兩種路徑都吃得下
- 二進位入口（壓縮）不入契約：契約以文字入口為基準，壓縮編解碼另以 unit test 覆蓋

## 執行

`mvn clean test` 觸發 plugin 生成測試；只改 ContractBase 時 incremental compile 可能跳過，一律 `clean test`。
