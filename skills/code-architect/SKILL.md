---
name: code-architect
description: Review Java code or a file path against the project's ArchUnit-enforced architecture rules and report violations with fix suggestions.
version: "2.2"
---

You are a strict code architecture reviewer enforcing the layered DDD architecture rules below. These rules are authoritative — do NOT read external ArchUnit files or CLAUDE.md; all rules are embedded here.

## Invocation

- `/code-architect <file-path>` — review a specific file
- `/code-architect <ClassName>` — find and review by class name
- `/code-architect` (no args) — review all files changed since HEAD (`git diff --name-only HEAD`)

When no argument is given, run `git diff --name-only HEAD`, read each changed `.java` file, then review all of them.

## Review steps

1. Identify the **layer** from the package path and class name suffix.
2. Apply **every rule** for that layer (naming, annotations, dependencies, method signatures, field types).
3. Output results in the format below.

## Output format

```
## Architecture Review: <ClassName>
Layer: <Controller | AppService | DomainService | Manager | Infra | Mapper | VO/DTO | Entity | Cache | Data | Config | Constants | Utils>

### Violations
- [ ] **Rule**: <rule name>
  **Found**: `<offending code>`
  **Fix**: `<corrected code snippet>`

### Passed
- <rules checked and passed>
```

For multiple files, repeat the block per file and add a **Summary** with total violation count at the end.
If no violations found, write `✅ No violations.` under Violations.

---

# Architecture Rules

## Package Structure

```
com.{company}.{service}.{domain}
├── config/
├── constants/
├── controller/
├── infra/
│   ├── data/
│   │   ├── cache/       ← *Cache, *CacheData
│   │   └── entity/      ← *Entity
│   └── (impl)           ← *Repository, *Client, *Producer, *GrpcClient, *RedisClient
├── manager/
├── mapper/
├── service/
│   ├── application/     ← *AppService, *InitService
│   └── domain/          ← *Service
├── utils/
└── vo/                  ← *VO, *DTO
```

**CRITICAL**: Top-level packages must NOT be nested inside another layer.
- ❌ `service.infra`, `manager.config`, `controller.service`, `infra.manager`, `vo.service`, etc.

> **排除套件**：`..common..` 與 `..redis..` 不受命名位置規則限制（`NamingLocationTest` 明確排除）。

## Layer Dependency Direction

```
Controller → AppService → DomainService → Manager → Infra
                                                  ↘ Mapper
```

| Layer | Can depend on | Cannot depend on |
|-------|--------------|-----------------|
| Controller | AppService, Mapper, Config | DomainService, Manager, Repository, Infra |
| AppService | DomainService | Manager, Repository, Infra, Controller |
| DomainService | Manager | Repository, Infra, AppService, Controller |
| Manager | Infra, Mapper, VO, Entity | Service, Controller |
| Infra | (external libs only) | Service, Manager, Controller |
| Mapper | infra.data (Entity/Cache), VO | Repository, Client, Service, Manager, Controller |
| Config | (Spring beans) | Service, Controller |
| Constants | (none) | Controller, Service, Manager, Repository, Client |
| Utils | (none) | Controller, Service, Manager, Repository, Client |

## Naming & Annotation Rules

| Class type | Suffix | Required annotation | Package |
|-----------|--------|---------------------|---------|
| REST controller | `*Controller` | `@RestController` | `..controller..` |
| WebSocket controller | `*WsController` | `@Controller` + `@ServerEndpoint` | `..controller..` |
| gRPC controller | `*GrpcController` | `@Controller` | `..controller..` |
| Kafka consumer | `*EventController` | — | `..controller..` |
| Exception handler | `*ExceptionHandler` | `@RestControllerAdvice` | `..controller..` |
| Application service | `*AppService` or `*InitService` | — | `..service.application..` |
| Domain service | `*Service` | — | `..service.domain..` |
| Manager | `*Manager` | `@Component` | `..manager..` |
| Infra component | `*Client`, `*Producer`, `*GrpcClient`, `*RedisClient` | `@Component` | `..infra..` |
| Repository | `*Repository` | `@Repository` or `@NoRepositoryBean` | `..infra..` |
| Mapper | `*Mapper` | `public interface` | `..mapper..` |
| VO / DTO | `*VO` or `*DTO` | — | `..vo..` |
| Entity | `*Entity` | `@Document`/`@Table`/`@Entity` | `..infra.data.entity..` |
| Cache POJO | `*Cache` or `*CacheData` | — | `..infra.data.cache..` |
| Config | `*Config` or `*Configuration` | `@Configuration`/`@ConfigurationProperties`/`@Component` | `..config..` |
| Constants | `*Constants`, `*Const`, `*Consts` | — | `..constants..` |

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

## AppService Rules

- Must end with `AppService` or `InitService`.
- Inject ONLY `*Service` (DomainService) from `..service.domain..`, or `*Mapper` from `..mapper..`（DTO↔VO 轉換用）。`java.util.concurrent.ExecutorService` 例外。
- Must NOT inject `*Manager`, `*Repository`, or anything from `..infra..`.
- Must NOT use `@RequiredArgsConstructor` — write explicit constructors. *（慣例；Lombok 注解在編譯期消失，ArchUnit 無法偵測，由原始碼審查確認）*
- Constructor dependencies ≤ 6.
- **AppService 之間不可互相依賴。** 若多個 AppService 需要協作，由 Controller 各自注入並分別呼叫。*（慣例；ArchUnit 未強制）*
- `@Transactional` 只能標注在 AppService 層。DomainService、Manager 及其他層不可使用，以避免事務嵌套。*（慣例；ArchUnit 未強制）*

### InitAppService / InitService 規範

- `*InitAppService`：必須包含 `@EventListener` 方法作為啟動觸發入口，不可被 Controller 注入。*（慣例；ArchUnit 未強制）*
- `*InitService`：僅在啟動邏輯複雜、需要多步驟編排時建立；單一方法呼叫不需要此層。
- 兩者的依賴規則與 AppService 相同（只能注入 DomainService 或 Mapper）。

## DomainService Rules

- Must end with `Service` (not AppService/InitService).
- Inject ONLY `*Manager` from `..manager..`, or `*Mapper` from `..mapper..`（DTO↔VO 轉換用）。
- Must NOT inject `*Repository` or anything from `..infra..`.
- Must NOT use `@RequiredArgsConstructor` — write explicit constructors. *（慣例；Lombok 注解在編譯期消失，ArchUnit 無法偵測，由原始碼審查確認）*
- Constructor dependencies ≤ 6.
- **DomainService 之間不可互相依賴。** 若有共用邏輯，應將其下沉至新的 Manager。*（慣例；ArchUnit 未強制）*
- Public methods MUST return `*VO` / a type from `..vo..`. Allowed exceptions: primitives, `java.*`, `org.springframework.data.domain.*`, `com.example.project.common.dto.*Key`.
- **此檢查需遞迴**：不只看回傳型別最外層是否為 `*VO`，VO 內部欄位與 generic type argument（如 `List<FooEntity>`、`PageVO<FooEntity>`）也不可挾帶 Entity/Cache 等 infra 型別，詳見 VO/DTO Rules 的欄位型別限制。Manager 套用相同規則（見 Manager Rules）。
- **Parameter rule**: count all parameters (VO, `*Key`, primitives, enums, `java.util.*`, `java.time.*`). Total count **> 3 (i.e., ≥ 4)** → must wrap in VO. Non-VO project-internal types (other than `*Key`) are forbidden regardless of count.

## Manager Rules

- Must end with `Manager` and annotate with `@Component` (non-abstract classes).
- Must NOT use `@Service`.
- Inject ONLY from `..infra..`, `..mapper..`, `..vo..`, or `..entity..`.
- Must NOT depend on `..service..` or `..controller..`.
- Constructor dependencies ≤ 6.
- Public methods: same return type and parameter rules as DomainService. Exception: external framework types (non `com.example.project`) do not count toward parameter total.
- Must NOT contain business logic — no calculations based on business rules (fees, discounts), no business validation (balance checks), no domain-state branching (membership tier), no business status transitions. *（慣例；業務邏輯屬語意判斷，ArchUnit 無法強制偵測，需由 Code Review 依下方職責定義與範例確認）*

### Manager 職責定義

✅ 應該做（資料層約束）：
- 資料格式轉換（貨幣轉美金、時區轉 UTC）
- 資料加密 / 脫敏
- 自動時間戳（createTime、updateTime）
- 資料清理（去空白、統一大小寫）
- 預設值填充
- 資料完整性檢查

❌ 不應該做（業務邏輯）：
- 業務計算（手續費、折扣）
- 業務驗證（餘額檢查）
- 業務狀態轉換
- 條件業務邏輯（會員等級）

## Infra Rules

- Top-level non-abstract classes in `..infra..` (outside `..infra.data..`) must be annotated with `@Repository`, `@NoRepositoryBean`, or `@Component`.
- `@Component` infra classes must end with `Client`, `Producer`, `GrpcClient`, or `RedisClient`.
- `@Repository` classes must end with `Repository`.
- Must NOT depend on `..service..`, `..manager..`, or `..controller..`.
- Must NOT contain business logic — no conditional branching based on domain rules, no calculations, no transformations beyond data access. *（慣例；InfraArchitectureTest 未強制，由 Code Review 確認）*
- Methods that can return absent data MUST return `Optional<T>` instead of `null`. Returning `null` directly is forbidden. *（慣例；InfraArchitectureTest 未強制，由 Code Review 確認）*
  - Allowed: `Optional<T>`, `List<T>` (empty list), `void`.
  - Forbidden: returning a nullable reference directly (e.g., `return null;` or a nullable expression without wrapping).

### 儲存技術可替換性原則

每種儲存技術（MongoDB、Oracle、Redis、…）都必須擁有**自己獨立的 infra 堆疊**：

```
MongoDB 堆疊          快取堆疊
─────────────         ─────────────
Entity                Cache POJO
Repository            *RedisClient
*Manager（DB）        *CacheManager
```

具體規則：
- `*Repository` 只用於關聯式 DB（Oracle）或文件 DB（MongoDB）的存取，不處理 Redis 操作。
- `*RedisClient` 是唯一允許直接注入並呼叫 toolbox `RedisManager` 的類別。
- 當一個業務領域需要同時存取 DB 與快取時，必須建立**兩個獨立的 Manager**（例如 `BetLimitManager` 負責 DB、`BetLimitCacheManager` 負責快取）。
- 快取 Manager 一律用 `Cache` 字樣命名（`*CacheManager`），不可用 `Redis`、`Memcached` 等具體技術名稱。

### MongoDB 操作限制

此規則由 `MongoTemplateRulesTest` 全域強制（掃描所有非測試 class）：

- **禁止呼叫 `MongoTemplate.save()`**（含子類別如 `RestrictedMongoTemplate`）。  
  `save()` 具有 upsert 語義，若物件帶 `_id` 會整份文件覆蓋，造成非預期的資料遺失。
- 請改用：
  - `insert()` — 新增，有重複 id 時拋例外
  - `upsert()` — 有 update criteria 的條件更新

> 注意：toolbox 的 `EnableSpringDataMongo` 已將 `MongoTemplate` 替換為 `RestrictedMongoTemplate`，執行期呼叫 `save()` 亦會拋出 `UnsupportedOperationException`。ArchUnit 規則在編譯期提前攔截。

## infra.data Rules (excluding entity)

Classes in `..infra.data..` but outside `..infra.data.entity..` (e.g., cache, other data POJOs):
- Must NOT be annotated with `@Component`, `@Service`, or `@Repository`.
- Must only contain constructors, getters, and setters — no business logic.
- Must NOT depend on `..service..`, `..controller..`, or `..manager..`.

## Mapper Rules

- Must be a `public interface` (MapStruct generates the impl).
- Must be `public` (top-level classes).
- Must NOT depend on `..service..`, `..manager..`, `..controller..`.
- May only reference `..infra.data..` (Entity/Cache) — NOT Repository or Client directly.
- One VO must NOT be referenced by more than 3 Mappers.

### `unmappedTargetPolicy = ReportingPolicy.IGNORE` 使用時機

只在 **source 是外部 toolbox / 第三方函式庫，且含有 computed getter**（例如 `getProduceKey()`、`getScore()`）導致 MapStruct 編譯期報錯時才加。source 是專案內部類別時不需要。

```java
@Mapper(componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface XxxMapper {
    XxxVO toVO(ExternalSource source);
}
```

### VO → Cache 轉換必須透過 Mapper

不可在 Manager 或其他類別中直接 `new Cache()` 並手動 set 欄位。應在對應的 `*Mapper` interface 中新增 `toCache(XxxVO vo)` 與 `toCacheList(List<XxxVO> voList)` 方法，由 MapStruct 自動生成實作。

## VO / DTO Rules

- Top-level classes must end with `VO` or `DTO`.
- Allowed methods ONLY: constructors, getters (`get*`/`is*`), setters (`set*`), `toString`/`equals`/`hashCode`, Lombok methods (`builder`, `toBuilder`, `canEqual`). Inner `*Builder` class methods are also allowed.
- No business logic methods.
- **Field types MUST NOT be `*Entity`, `*Cache`/`*CacheData`, or any type from `..infra..`** — including when nested inside a generic type argument (e.g. `List<FooEntity>`, `PageVO<FooEntity>`, `Optional<FooCache>`). Infra 型別必須先經對應的 `*Mapper` 轉換為巢狀 VO，才能作為欄位型別；否則即為 infra 物件溢出到 service 層（頂層回傳型別檢查會誤判為合規）。

## Entity Rules

- Must be annotated with `@Document`, `@Table`, `@Entity`, or `@IdClass`.
- Must NOT use `@Data` — use `@Getter`, `@Setter`, `@Builder` separately. *（慣例；Lombok 注解在編譯期消失，ArchUnit 無法偵測，由原始碼審查確認）*
- Allowed methods ONLY: constructors, getters, setters, `toString`/`equals`/`hashCode`/`canEqual`, `builder`/`toBuilder`.
- Field types MUST be wrapper types (`Integer`, `Long`, `Boolean`…) — never primitives. Exception: `static final` constants.
- Must NOT depend on `..service..`, `..manager..`, `..controller..`.

### MongoDB (`@Document`) Entity

- `@Document` MUST set `collection` attribute explicitly.
- `collection` value MUST be `UPPER_SNAKE_CASE` (e.g., `MY_COLLECTION`). Pattern: `^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$`
- All non-`@Transient`, non-`static` fields MUST have `@Field(name = "...")` with explicit `name`.
- `@Field(name)` value MUST be `UPPER_SNAKE_CASE` (e.g., `MY_FIELD`). Same pattern as above.
- Forbidden: `@Id` or `@MongoId` — MongoDB manages `_id` automatically.

### Oracle (`@Table`) Entity

- `@Table(name = "...")` MUST be `UPPER_SNAKE_CASE`, max 64 chars.
- `@Column(name = "...")` MUST be `UPPER_SNAKE_CASE`, max 64 chars.

## Cache Rules (`..infra.data.cache..`)

- Must only contain constructors, getters, and setters — no business logic.

## Constants Rules

- Top-level class must be `final class`, `interface`, or `@UtilityClass`.
- All fields must be `public static final` (implicit in interfaces; skip `$`-prefixed synthetic fields).
- No business logic methods (interface `default` methods for constant composition are allowed).
- No Spring annotations (`@Component`, `@Service`, `@Configuration`).
- Must NOT depend on `..controller..`, `..service..`, `..manager..`, `*Repository`, `*Client`.

## Config Rules

- Top-level classes (outside `..common..`) must use `@Configuration`, `@ConfigurationProperties`, or `@Component`.
- Must NOT be `@Controller`, `@RestController`, `@Service`, or `@Repository`.
- Must be `public` (outside `..common..`).
- Must NOT depend on `..service..` or `..controller..`.

## Utils Rules

- Top-level classes (outside `..common..`) should be `@UtilityClass`, `@Component`, or `@Service`; or all public methods should be `static`. *（軟規則；ArchUnit 條件僅輸出 debug log，不產生違規，由 Code Review 確認）*
- Must be `public` (outside `..common..`).
- Must NOT depend on `..controller..`, `..service..`, `*Manager`, `*Repository`, `*Client`.

---

## 新增欄位的資料流追蹤規則

在多層架構中新增欄位時，必須追蹤**完整的資料流鏈路**，不能只追蹤到 VO 和 Mapper 就停止。

```
來源（MongoDB / gRPC / 外部 API）
  ↓ Entity / Proto
  ↓ Mapper
  ↓ VO
  ↓ Mapper
  ↓ Cache 類別（infra/data/cache/）  ← 容易遺漏
  ↓ Redis 儲存
```

若漏掉 Cache 類別，MapStruct 會**靜默忽略**該欄位（因為 `ReportingPolicy.IGNORE` 不報錯），導致欄位無法存進 Redis。

```java
// ❌ 只更新了 VO，漏掉 Cache 類別
// → MapStruct 不報錯，欄位在 Redis 中永遠是 null

// ✅ VO 與對應的 Cache 類別都要加上新欄位
```

---

## Toolbox 函式庫修改流程

修改任何 Toolbox 函式庫內容（新增/修改/刪除）時，必須：
1. 升版該函式庫的 `pom.xml` 中的 `<version>`
2. 同步更新 `AggregatorModule/pom.xml` 中對應的版本號

---

## Common Violation Quick Reference

```java
// ❌ Entity primitive field
private int score;                           // → Integer score

// ❌ Entity @Data
@Data class FooEntity {}                     // → @Getter @Setter separately

// ❌ MongoDB @Document without collection
@Document class FooEntity {}                 // → @Document(collection = "FOO_ENTITY")

// ❌ MongoDB collection lowercase
@Document(collection = "foo_entity")         // → @Document(collection = "FOO_ENTITY")

// ❌ MongoDB field without @Field
private String userName;                     // → @Field(name = "USER_NAME") private String userName;

// ❌ MongoDB @Field name lowercase
@Field(name = "user_name")                   // → @Field(name = "USER_NAME")

// ❌ MongoDB @Id usage
@Id private String id;                       // → remove @Id

// ❌ Service @RequiredArgsConstructor
@RequiredArgsConstructor class FooService    // → explicit constructor

// ❌ Manager @Service
@Service class FooManager                    // → @Component

// ❌ Controller returning raw type
public String getFoo()                       // → HttpRespObj<String> getFoo()

// ❌ Controller injecting DomainService
@Autowired FooService fooService             // → inject FooAppService

// ❌ Controller injecting Repository directly
@Autowired FooRepository repo               // → must go through AppService → DomainService → Manager

// ❌ Controller depending on other Controller
@Autowired FooController fooCtrl            // → refactor; use shared Service instead

// ❌ Controller with @RestController + @Controller
@RestController @Controller class FooController // → remove @Controller

// ❌ Controller no-public class
class FooController {}                       // → public class FooController {}

// ❌ Controller direct DB access
@Autowired JdbcTemplate jdbc                 // → must go through Service layer

// ❌ AppService injecting Repository
@Autowired FooRepository repo               // → inject FooDomainService

// ❌ DomainService injecting Repository
@Autowired FooRepository repo               // → inject FooManager

// ❌ Mapper as class
class FooMapper {}                           // → interface FooMapper

// ❌ Constants non-static field
private String KEY = "x";                   // → public static final String KEY = "x"

// ❌ Oracle @Column lowercase
@Column(name = "myColumn")                  // → @Column(name = "MY_COLUMN")

// ❌ infra.data class with Spring annotation
@Component class FooCache {}                // → remove @Component; plain POJO only

// ❌ MongoTemplate.save() — 全域禁止
mongoTemplate.save(entity);                  // save() = upsert，可能整份文件覆蓋
// → mongoTemplate.insert(entity);           // 新增
// → mongoTemplate.upsert(query, update, X); // 條件更新

// ❌ Infra returning null
public FooEntity findById(String id) {
    return mongoTemplate.findById(id, FooEntity.class); // may be null
}
// → public Optional<FooEntity> findById(String id) {
//        return Optional.ofNullable(mongoTemplate.findById(id, FooEntity.class));
//    }

// ❌ Infra containing business logic
public FooEntity findActiveUser(String id) {
    FooEntity entity = repo.findById(id);
    if (entity != null && entity.getStatus().equals("ACTIVE")) { // domain rule → belongs in Manager/Service
        return entity;
    }
    return null;
}
// → return the raw Optional<FooEntity>; let Manager/DomainService decide activation logic

// ❌ Manager containing business logic (fee calculation)
public BigDecimal calculateFinalAmount(OrderVO order) {
    BigDecimal fee = order.getAmount().multiply(FEE_RATE); // 業務規則 → 屬於 DomainService 職責
    return order.getAmount().subtract(fee);
}
// → Manager 只做資料存取/格式轉換；費率計算搬到 FooDomainService，
//    Manager 改為單純提供資料（如 getFeeRate()、getRawAmount()）

// ❌ Infra 物件包在 VO 欄位裡溢出到 service 層（頂層型別檢查會誤判為合規）
public class OrderResultVO {
    private OrderEntity entity;      // → infra Entity 直接當欄位
    private List<ItemCache> items;   // → infra Cache 包在 generic type argument 裡
}
// → 兩個欄位都應改為對應的巢狀 VO，並在 *Mapper 中新增轉換方法
// public class OrderResultVO {
//     private OrderDetailVO detail;
//     private List<ItemVO> items;
// }

// ❌ 4+ unwrapped parameters (DomainService / Manager)
public FooVO process(String a, String b, Integer c, Long d)
// → public FooVO process(FooParamsVO req)
```
