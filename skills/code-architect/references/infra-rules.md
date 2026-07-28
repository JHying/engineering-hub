## Infra Rules

- Top-level non-abstract classes in `..infra..` (outside `..infra.data..`) must be annotated with `@Repository`, `@NoRepositoryBean`, or `@Component`.
- `@Component` infra classes must end with `Client`, `Producer`, `GrpcClient`, or `RedisClient`.
- `@Repository` classes must end with `Repository`.
- Must NOT depend on `..service..`, `..manager..`, or `..controller..`.
- Must NOT contain business logic — no conditional branching based on domain rules, no calculations, no transformations beyond data access. *（慣例；InfraArchitectureTest 未強制，由 Code Review 確認）*
- 查無資料的回傳方式：見下方跨層章節「查無資料的表達方式（null / Optional / 例外）」。

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
