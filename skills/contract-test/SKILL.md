---
name: contract-test
description: 根據指定的 Controller，生成符合本專案慣例的 Spring Cloud Contract Groovy DSL 契約檔與 ContractBase。契約用於 producer 自動化驗收測試，同時產生 consumer MockMVC stub。
version: "1.1"
---

根據指定的 Controller，生成 Spring Cloud Contract Groovy DSL 契約檔與對應的 ContractBase。

## 使用方式

```
/contract-test <ControllerName>
```

例：`/contract-test BalanceController`

---

## 生成步驟

### 1. 讀取 Controller 與 DTO

1. 找到 `<ControllerName>.java`，記錄每個 endpoint 的：
   - HTTP method、路徑、request body 型別
2. 找到對應的 request DTO（`ActionReqDTO<XxxMsgDTO>` 或其他），讀取每個欄位的 validation annotation：
   - `@NotBlank` / `@NotNull` → 必填
   - `@PositiveOrZero` / `@Positive` → 數值正數限制
   - 無 annotation → optional
3. 找到對應的 response DTO，記錄每個欄位型別（特別注意 `Timestamp` / `LocalDateTime` 等時間型別）
4. 找到 AppService，確認 service 層會拋哪些業務例外（如身份驗證失敗、無效 key 等），記錄各例外對應的錯誤訊息

### 2. 確認 400 / 401 的 error message

**400（MethodArgumentNotValidException）**

從 DTO 的 validation annotation 取得 message：
- `@NotBlank(message = "xxx")` → `"xxx"`
- `@NotBlank`（無 message） → `"must not be blank"`
- `@NotNull(message = "xxx")` → `"xxx"`
- `@PositiveOrZero(message = "xxx")` → `"xxx"`

**401（AuthenticationException）**

從 AppService 讀取業務驗證方法拋出的例外訊息（如 action 不符合預期、key 無效等），每個驗證方法對應的錯誤訊息即為合約中要測試的 error message。

Response body 格式（來自 `ServletGlobalExceptionHandler`）：
```json
{ "status": 400, "errors": ["MethodArgumentNotValidException", "<message>"], "payload": null }
{ "status": 401, "errors": ["AuthenticationException", "<message>"], "payload": null }
```

### 3. 產生契約檔

每個 endpoint 產生兩個檔案，放在 `src/test/resources/contracts/<featureName>/`：

#### `<endpoint>_valid.groovy`

單一 `Contract.make { ... }`。

**Request：** 依 validation annotation 決定 matcher：

| 欄位規則 | Request Matcher |
|---------|----------------|
| `@NotBlank` | `$(consumer(regex(nonBlank())), producer('value'))` |
| `@NotNull` + `@PositiveOrZero`（數值） | `$(consumer(regex('[0-9]+(\\.[0-9]+)?')), producer(value))` |
| Optional（無 annotation） | `$(consumer(optional(regex(nonBlank()))), producer('value'))` |

**Response：** 依欄位特性決定是否加 matcher：

| 欄位型別 | Response Matcher |
|---------|-----------------|
| `Timestamp` / `LocalDateTime` | `$(consumer('<fixedValue>'), producer(regex('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}[+-]\\d{2}:\\d{2}')))` |
| 其他固定值 | 直接寫值，不加 matcher |

> `Timestamp` 在 Spring Boot 3.x 預設序列化為 ISO 8601 字串（`WRITE_DATES_AS_TIMESTAMPS=false`）。
> ContractBase 對應的 fixedTs 使用 `new Timestamp(1000000000000L)`，字串為 `'2001-09-09T01:46:40.000+00:00'`。

#### `<endpoint>_invalid.groovy`

檔案頂部以行內註解列出所有異常情境，內容為 `[ Contract.make{...}, ... ]` list：

```groovy
// 異常情境：
// 1. xxx 為空白 → 400, "xxx can not be empty."
// 2. action 錯誤 → 401, "action does not match."
// 3. key 無效 → 401, "Invalid website key."
```

**場景分類**（依觸發層次排列）：

| 情境 | 觸發點 | HTTP Status |
|------|--------|-------------|
| `@NotBlank` 欄位為空白 | Spring `@Validated`（service 前） | 400 |
| `@NotNull` 欄位為 null | Spring `@Validated`（service 前） | 400 |
| `@PositiveOrZero` 欄位為負數 | Spring `@Validated`（service 前） | 400 |
| action 值錯誤（非空白但不符合預期） | service 層業務驗證方法 | 401 |
| key 值無效（非空白但不符合業務規則） | service 層業務驗證方法 | 401 |

null balance 與 negative balance **寫在同一個 invalid 檔案內**（共用 list）。

### 4. 產生 ContractBase

檔案路徑：`src/test/java/.../contract/<FeatureName>ContractBase.java`

```java
@WebMvcTest(<FeatureName>Controller.class)
@Import(ServletGlobalExceptionHandler.class)   // 必須：@WebMvcTest 不載入 global exception handler
@TestPropertySource(properties = {
    "spring.cloud.consul.enabled=false",
    "spring.cloud.consul.config.enabled=false"
})
public abstract class <FeatureName>ContractBase {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private <FeatureName>AppService <featureName>AppService;

    @BeforeEach
    void setup() {
        // 先 register any() (default)，再 register 特定 argThat（Mockito LIFO，後者優先匹配）

        when(<featureName>AppService.getXxx(any()))
            .thenReturn(<fixedValidResponse>);
        when(<featureName>AppService.getXxx(argThat(dto -> dto != null && !"expectedAction".equals(dto.getAction()))))
            .thenThrow(new AuthenticationException("action does not match."));
        when(<featureName>AppService.getXxx(argThat(dto -> dto != null && "BAD_KEY".equals(dto.getKey()))))
            .thenThrow(new AuthenticationException("Invalid key."));

        RestAssuredMockMvc.mockMvc(mockMvc);
    }
}
```

**Mock 設定規則：**

| 情境 | 是否需要 mock 設定 | 原因 |
|------|------------------|------|
| 400（blank/null/invalid format） | ❌ | Spring `@Validated` 攔截，service 不被呼叫 |
| 401 wrong action | ✅ `argThat` | action 通過 `@NotBlank`，進入 service 拋 exception |
| 401 invalid key | ✅ `argThat` | key 通過 `@NotBlank`，進入 service 拋 exception |

**Mockito LIFO 順序：**
- `any()` → 最後匹配（register 最先）
- `argThat(wrongAction)` → 優先於 `any()`（register 較晚）
- `argThat(badKey)` → 優先於 `any()`（register 最晚，最先被嘗試）

**常見錯誤：**
```java
// ❌ 錯誤：any() 不能放在 thenReturn 的物件建構子裡
.thenReturn(new XxxDTO(..., any(Timestamp.class), ...));

// ✅ 正確：用固定值
Timestamp fixedTs = new Timestamp(1000000000000L);
.thenReturn(new XxxDTO(..., fixedTs, ...));
```

---

## 檔案結構範本

```
src/test/resources/contracts/<feature>/
├── <endpoint>_valid.groovy
└── <endpoint>_invalid.groovy

src/test/java/.../contract/
└── <Feature>ContractBase.java
```

## 完整 groovy 範本

### `_valid.groovy`

```groovy
package contracts.<feature>

import org.springframework.cloud.contract.spec.Contract

Contract.make {
    description "POST /<path> - valid request returns 200"
    request {
        method POST()
        url '/<path>'
        headers {
            contentType(applicationJson())
        }
        body([
            key    : $(consumer(regex(nonBlank())), producer('SOME_KEY')),
            message: [
                action      : $(consumer(regex(nonBlank())), producer('expectedAction')),
                userId      : $(consumer(regex(nonBlank())), producer('user1')),
                optionalField: $(consumer(optional(regex(nonBlank()))), producer('value')),
                amount      : $(consumer(regex('[0-9]+(\\.[0-9]+)?')), producer(100.00))
            ]
        ])
    }
    response {
        status OK()
        headers {
            contentType(applicationJson())
        }
        body([
            status   : 200,
            amount   : 100.00,
            updatedTs: $(consumer('2001-09-09T01:46:40.000+00:00'), producer(regex('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}[+-]\\d{2}:\\d{2}')))
        ])
    }
}
```

### `_invalid.groovy`

```groovy
package contracts.<feature>

// 異常情境：
// 1. key 為空白 → 400, "key can not be empty."
// 2. action 為空白 → 400, "action can not be empty."
// 3. userId 為空白 → 400, "userId can not be empty."
// 4. amount 為 null → 400, "amount can not be empty."
// 5. amount 為負數 → 400, "amount should greater than 0."
// 6. action 錯誤 → 401, "action does not match."
// 7. key 無效 → 401, "Invalid website key."

import org.springframework.cloud.contract.spec.Contract

[
    Contract.make {
        description "POST /<path> - blank key returns 400"
        request { ... }
        response {
            status BAD_REQUEST()
            body([ status: 400, errors: ["MethodArgumentNotValidException", "key can not be empty."], payload: null ])
        }
    },

    // ... 其他 400 情境 ...

    Contract.make {
        description "POST /<path> - wrong action returns 401"
        request {
            body([ key: 'SOME_KEY', message: [ action: 'WRONG_ACTION', ... ] ])
        }
        response {
            status UNAUTHORIZED()
            body([ status: 401, errors: ["AuthenticationException", "action does not match."], payload: null ])
        }
    },

    Contract.make {
        description "POST /<path> - invalid key returns 401"
        request {
            body([ key: 'BAD_KEY', message: [ action: 'expectedAction', ... ] ])
        }
        response {
            status UNAUTHORIZED()
            body([ status: 401, errors: ["AuthenticationException", "Invalid website key."], payload: null ])
        }
    }
]
```

---

## 注意事項

- `BalanceControllerTest` 等 controller unit test 與 contract 高度重疊時，**刪除 controller test，以 contract 為唯一驗證來源**
- contracts 集中管理在別的 repo 時，`spring-cloud-contract-maven-plugin` 設定 `contractsRepositoryUrl` 指向該 Git repo
- `mvn clean test` 才會觸發 contract plugin 重新產生 `BalanceTest.java`；若只改 ContractBase，`mvn test` 可能因 incremental compile 跳過 contract test
