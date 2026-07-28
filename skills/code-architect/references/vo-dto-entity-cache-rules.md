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
