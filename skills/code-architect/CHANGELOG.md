# Changelog — code-architect

所有版本異動依時間倒序排列。

---

## [2.4] — 2026-07-05

### Added
- **新增章節「Anti-Corruption Layer（外部型別隔離）規則」**：Domain 層（VO、DomainService）與其上層不得依賴外部系統原生型別（gRPC/proto 生成類、外部 API 的 request/response 型別、持久層 Entity/Document、訊息格式原始 payload 類）；轉換責任限定在 Manager（配合對應 `*Mapper`）完成，補上可 grep 的違規訊號與一組完整 ❌/✅ Java 範例
- **Quick Reference**：補充 ACL 違規範例（DomainService 方法簽名直接帶外部型別參數）

### Context
- 起因：通用 review 規範（REVIEW_GUIDE）已將 Anti-Corruption Layer 列為 DDD 審查點之一，但 code-architect 先前的規則集中沒有對應章節，屬已確認的職責內缺口；本次新增不影響既有規則內容
- 此規則目前僅由 Code Review 階段確認，尚無對應 ArchUnit 測試強制外部型別 import 檢查

---

## [2.3] — 2026-07-03

### Fixed / Clarified
- **AppService Rules**：明確允許注入 `*Mapper`（DTO↔VO 轉換用），修正先前規則字面只列 `*Service`+`ExecutorService` 例外、未含 Mapper 的疏漏
- **DomainService Rules**：同上，明確允許注入 `*Mapper`
- **InitAppService / InitService 規範**：依賴規則說明同步補上 Mapper

### Context
- 起因：某專案的 code review 中，`FooAppService` 注入 `BarRequestMapper` 被規則字面判定為違規；但掃描後發現 `BazAppService`、`QuxAppService` 等至少 3 個 AppService 都是同一 pattern，屬專案既有的 DTO↔VO 轉換慣例，確認後修訂規則文字承認此為合法依賴，而非要求既有程式碼配合改寫

---

## [2.2] — 2026-07-03

### Added
- **VO / DTO Rules**：新增欄位型別限制——不可為 `*Entity`、`*Cache`/`*CacheData` 或 `..infra..` 套件下型別，含作為 generic type argument 時（如 `List<FooEntity>`）。修補「頂層回傳型別是 VO 就判合規，但 VO 內部欄位偷塞 infra 物件」的漏洞
- **DomainService Rules**：回傳型別檢查註明需遞迴至 VO 內部欄位與 generic type argument，不可只看最外層 class 名稱（Manager 依既有規則引用套用相同檢查）
- **Manager Rules**：新增明確條列「Must NOT contain business logic」規則，與既有「Manager 職責定義」表格呼應，避免業務邏輯（手續費計算、餘額驗證等）誤寫入 Manager
- **Quick Reference**：補充「Manager 業務邏輯溢出」與「infra 物件包在 VO 欄位裡溢出到 service 層」兩則違規範例

### Context
- 起因：實際 review 中曾出現 infra 物件（Entity/Cache）溢出到 service 層、以及業務邏輯寫進 Manager 的分層錯誤，追查後發現舊版規則只檢查方法簽名「最外層型別」與「職責定義表格」，缺少欄位型別與語意判斷的明確 quick-reference 錨點

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
