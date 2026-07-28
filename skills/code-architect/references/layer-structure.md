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

| Layer         | Can depend on                      | Cannot depend on                                 |
| ------------- | ----------------------------------- | ------------------------------------------------ |
| Controller    | AppService, Config, DTO            | DomainService, Manager, Repository, Infra        |
| AppService    | DomainService, DTO, VO             | Manager, Repository, Infra, Controller           |
| DomainService | Manager, VO                        | Repository, Infra, AppService, Controller        |
| Manager       | Infra, Mapper, VO, Entity          | Service, Controller                              |
| Infra         | (external libs only)               | Service, Manager, Controller                     |
| Mapper        | infra.data (Entity/Cache), VO, DTO | Repository, Client, Service, Manager, Controller |
| Config        | (Spring beans)                     | Service, Controller                              |
| Constants     | (none)                             | Controller, Service, Manager, Repository, Client |
| Utils         | (none)                             | Controller, Service, Manager, Repository, Client |

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
