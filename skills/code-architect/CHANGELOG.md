# Changelog — code-architect

所有版本異動依時間倒序排列。

---

## [2.1] — 2026-04-24

### Added
- **Infra / MongoDB**：新增「禁止呼叫 `MongoTemplate.save()`」全域規則（ArchUnit 測試強制，執行期由 runtime 包裝類雙重保護）；請改用 `insert()` 或 `upsert()`
- **Quick Reference**：補充 `MongoTemplate.save()` 違規範例

### Fixed / Clarified（與 ArchUnit 實際規則對齊）
- **Package Structure**：明確標注 `..common..` 與 `..redis..` 排除於命名位置規則之外
- **Naming table**：Mapper 欄位補上 `public interface` 必要注解
- **Mapper Rules**：補充「Must be `public`」規則
- **AppService**：`ExecutorService` 明確列為注入例外；`@RequiredArgsConstructor`、AppService 互依、`@Transactional`、初始化 AppService `@EventListener` 標注為「慣例；ArchUnit 未強制」
- **DomainService**：`@RequiredArgsConstructor`、DomainService 互依標注為「慣例；ArchUnit 未強制」
- **Entity**：`@Data` 禁用標注為「慣例；Lombok 編譯期消失，ArchUnit 無法偵測」
- **Infra**：null 回傳禁止、業務邏輯禁止標注為「慣例；ArchUnit 未強制」
- **Utils**：`@UtilityClass` 規則標注為「軟規則；ArchUnit 僅 debug log，不產生違規」

---

## [2.0] — 2026-04-21

### Added
- **Controller**：DTO 信任邊界設計（每個 endpoint 獨立 DTO、`@Valid` 校驗、annotation 清單）
- **Controller**：WebSocket 訊息工具類呼叫必須集中在 Controller 層
- **Controller**：WebSocket `handleRequest` switch 純路由模式
- **AppService**：AppService 之間不可互相依賴
- **AppService**：`@Transactional` 只能在 AppService 層使用
- **AppService**：初始化 AppService / 初始化 Service 拆分規則
- **DomainService**：DomainService 之間不可互相依賴
- **Manager**：明確的職責邊界（資料層約束 vs 業務邏輯）
- **Infra**：儲存技術可替換性原則（MongoDB / Oracle / Redis 各自獨立堆疊）
- **Mapper**：`unmappedTargetPolicy = IGNORE` 使用時機
- **Mapper**：VO → Cache 轉換必須透過 Mapper
- **General**：新增欄位資料流追蹤規則（Entity → Mapper → VO → Cache）
- **General**：內部函式庫升版修改流程（版本號更新 + 彙整模組同步）

---

## [1.1] — 2026-04-16

### Added
- **Infra Rules**：新增「禁止包含業務邏輯」規則（no conditional branching based on domain rules、no calculations、no transformations beyond data access）
- **Infra Rules**：新增「禁止回傳 null」規則，可能缺值的方法必須回傳 `Optional<T>`
- **Quick Reference**：補充 Infra null 回傳與業務邏輯的違規範例

---

## [1.0] — 初版

### Added
- 完整 DDD 分層架構規則（Controller / AppService / DomainService / Manager / Infra / Mapper / VO / Entity / Cache / Constants / Config / Utils）
- 套件結構規範
- 層級依賴方向表
- Naming & Annotation 規則
- MongoDB / Oracle Entity 規則（含 UPPER_SNAKE_CASE、@Field、禁止 @Id）
- Common Violation Quick Reference
