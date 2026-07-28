## Controller Rules

### Basic rules
- All top-level classes in `controller` must end with `Controller` or `ExceptionHandler`.
- Controller classes must be `public`.
- `@RestController` public non-void methods MUST return `HttpRespObj<?>`.
- `@RestController` classes must NOT also be annotated with `@Controller`.
- `@RequestBody` parameters MUST be named `*DTO` and the DTO class must be in `..vo..`.
- Inject ONLY `*AppService`, `*Mapper`, `*Config` (WsController may also inject `ExecutorService`).
- Must NOT use setter injection (`@Autowired` on setter methods).
- Must NOT have `public static` methods.

### Dependency rules
- Must NOT inject `*Repository`, DomainService (`..service.domain..`), or any Infra.
- All injected `*Service` must come from `..service.application..`.
- Must NOT depend on other Controllers.
- Must NOT directly access database: do NOT inject `JdbcTemplate`, `EntityManager`, or `SessionFactory`.
- Methods must NOT use Entity types directly as parameters or receive Entity return values from non-Mapper calls.

### DTO 設計與信任邊界

- 每個 API endpoint 對應一個專屬 DTO，不與其他 API 共用。
- 校驗邏輯必須宣告在 DTO 欄位的 annotation 上（`@NotBlank`、`@NotNull`、`@Positive`、`@Min`/`@Max`、`@Size`、`@Email`、`@Pattern` 等），不在 Controller 方法內寫 if 判斷。
- Controller 方法參數加 `@Valid`，違規由 `*ExceptionHandler` 統一攔截。
- `WsMsgUtils` 的呼叫（`sendResponse`、`sendError`、`sendMessage` 等）必須集中在 Controller 層，AppService 不可直接呼叫。

### WebSocket `handleRequest` 模式

`handleRequest` 的 switch 必須作為純路由使用。每個 `case` 呼叫專屬的 `handleXxx` 方法（由該方法自行負責 send 邏輯），或直接呼叫 `WsMsgUtils`。不可在 switch 外集中判斷 null。

```java
// ✅ 正確模式
switch (eventMsgType) {
    case GET_SYMBOL -> handleGetSymbolRequest(session, msg.getMsgId(), meta);
    case TEST       -> WsMsgUtils.sendResponse(session, msg.getMsgId(), handleTestMessage(...));
}
```

### Special controller types
- gRPC controllers must extend `**Grpc.**ImplBase` and use `@Controller`.
- WebSocket controllers must use `@ServerEndpoint` + `@Controller`; send messages via `WsMsgObj` or `WsMsgUtils`.
- Classes with `@KafkaListener` methods must end with `EventController`.
