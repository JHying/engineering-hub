# Changelog — code-architect

所有版本異動依時間倒序排列。

---

## [2.6] — 2026-07-23

### Added
- **新增跨層章節「查無資料的表達方式（null / Optional / 例外）」**：原本只寫在 Infra Rules 底下的 `Optional` 規則，提升為適用所有層的獨立章節。內容包含——
  - 三種表達方式的選擇表（正常業務 → `Optional`；系統異常 → 拋例外；集合 → 空集合；任何情境都不回 `null`）
  - 逐層檢查點表（Infra / Manager / Domain Service / **Utils 靜態查表** / Mapper），標注各層最容易犯的錯
  - 4 組違規範例（Infra 回 null、Manager 把 `Optional` 拆成 null、Utils 靜態查表回 null、查無屬異常卻回 `Optional`）
  - **空集合 /「部分存在」陷阱**：查到但內容為空 vs 完全查不到，語意相同卻常被寫成一個放行一個報錯，附 `.filter(...).orElseThrow(...)` 的合併寫法
  - **例外型別選擇**：業務例外 vs 系統例外的分型表與判準句「這是使用者做錯了，還是我們的資料壞了？」
- **Manager Rules / DomainService Rules / Utils Rules** 各補一行指向新章節，並標注該層最常見的違規樣態
- **Quick Reference** 補 3 組範例：Manager 拆 `Optional`、Utils 靜態查表回 null、服務端資料不完整誤拋業務例外

### Changed
- **Infra Rules**：原本的三行 `Optional` 規則收斂為一行指向新章節，避免規則分散在兩處各說一半

### Context
- 起因：某專案一次 code review 中，三個回傳 null 的方法全數通過本 skill 的檢查——`XxxManager`（Manager 層）、`XxxCategoryMapping`（Utils 靜態查表）、`XxxDomainService`（Domain Service），因為舊規則只寫在 Infra Rules 底下，這三層都不適用。最後是由使用者人工指出「有機會是 null 就丟 optional，不要讓上層猜」才被抓到
- 同一輪 review 還暴露第二個缺口：規則只講「該不該用 `Optional`」，沒講「決定拋例外之後該拋哪種」。該專案原先把「服務端設定資料不完整」包成業務例外回傳失敗訊息，導致使用者看到錯誤的失敗原因、故障混進業務失敗統計、監控上看起來一切正常——同樣由使用者指出「屬系統異常吧?」才修正
- 第三個缺口是「部分存在」：整份設定查無會拋例外，但查到卻是空 Map 時反而放行，兩者語意相同處置卻相反——由 reviewer 追問後才收斂為同一道守門
- 對應的通用規範 REVIEW_GUIDE 已同步新增 2-5 節（version 2026-07-23），兩份文件內容一致，本 skill 為執行面、REVIEW_GUIDE 為原則面
- 本規則目前無對應 ArchUnit 測試，屬 Code Review 階段檢查項

---

## [2.5] — 2026-07-07

### Fixed / Clarified
- **AppService Rules — `@Transactional` 位置規則**：修正先前「`@Transactional` 只能標注在 AppService 層」的絕對化表述，補上例外——橫跨多個 DataSource / `TransactionManager` 時，單一 `@Transactional` 無法涵蓋跨 DataSource 操作（Spring 宣告式交易的硬限制，非分層問題），此時交易邊界必須留在各自擁有該 DataSource 的 Manager 層，AppService 只依序呼叫。同時釐清「同一 DataSource 內多筆操作」與「跨 DataSource」是兩種不同情境：前者應把交易邊界收斂到單一批次呼叫（避免呼叫端迴圈呼叫產生 N 個獨立交易），後者才是本例外的適用範圍。補上 ✅/❌ 範例。

### Context
- 起因：某專案 code review 中，`MainDbManager`（Manager 層）標注 `@Transactional("transactionManager")`，`NotifyDbManager`（另一 Manager）標注 `@Transactional("notifyTransactionManager")`——兩者對應不同 DataSource。舊規則會將兩者都判為「Manager 不應使用 @Transactional」的違規，但使用者指出：即使把交易邊界拉高到共同呼叫兩者的 AppService 層，單一 `@Transactional` 也只能綁定一個 `TransactionManager`，無法讓兩個不同 DataSource 的操作同屬一個交易——規則對此情境的表述有誤，需修正而非要求程式碼配合改寫
- 同一輪 review 也發現一個真正的違規（同一個 DataSource 內，呼叫端迴圈呼叫 Manager 的單筆方法，產生 N 個獨立交易、喪失批次原子性），修法是把交易邊界收斂到 Manager 新增的批次方法內——這與「跨 DataSource 例外」是不同情境，本次一併在規則文字中釐清區別，避免未來誤用其中一種情境的結論套用到另一種

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
