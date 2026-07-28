## AppService Rules

- Must end with `AppService` or `InitService`.
- Inject ONLY `*Service` (DomainService) from `..service.domain..`, or `*Mapper` from `..mapper..`（DTO↔VO 轉換用）。`java.util.concurrent.ExecutorService` 例外。
- Must NOT inject `*Manager`, `*Repository`, or anything from `..infra..`.
- Must NOT use `@RequiredArgsConstructor` — write explicit constructors. *（慣例；Lombok 注解在編譯期消失，ArchUnit 無法偵測，由原始碼審查確認）*
- Constructor dependencies ≤ 6.
- **AppService 之間不可互相依賴。** 若多個 AppService 需要協作，由 Controller 各自注入並分別呼叫。*（慣例；ArchUnit 未強制）*
- `@Transactional` 預設應標注在 AppService 層，DomainService、Manager 及其他層不可使用，以避免事務嵌套。*（慣例；ArchUnit 未強制）*
- **例外：橫跨多個 DataSource / TransactionManager 時，交易邊界必須下放到各自擁有該 DataSource 的 Manager**。單一 `@Transactional` 只能綁定一個 `PlatformTransactionManager`；若同一個 AppService 方法邏輯上需要操作兩個不同 DataSource（例如主 DB 用 `transactionManager`、通知用 DB 用 `notifyTransactionManager`），AppService 層無法用一個 `@Transactional` 同時涵蓋兩者——這不是分層問題，是 Spring 宣告式交易的硬限制（真正跨 DataSource 的原子性需要 XA/分散式交易，非本規則涵蓋範圍）。此時應在各自的 Manager 方法上標注對應的 `@Transactional("xxxTransactionManager")`，AppService 僅依序呼叫，不強行用單一交易包住。
  ```java
  // ✅ 正確：AppService 依序呼叫，各 Manager 各自維持自己 DataSource 的交易邊界
  public class OrderAppService {
      public void settleOrder(OrderVO order) {
          mainDbManager.saveOrder(order);          // @Transactional("transactionManager") 標在 Manager 內
          notifyDbManager.saveNotification(order); // @Transactional("notifyTransactionManager") 標在另一個 Manager 內
      }
  }

  // ❌ 錯誤：試圖用單一 @Transactional 涵蓋跨 DataSource 呼叫——第二個 DataSource 的操作不在此交易範圍內，不會生效
  @Transactional("transactionManager")
  public void settleOrder(OrderVO order) {
      mainDbManager.saveOrder(order);
      notifyDbManager.saveNotification(order); // 用的是不同的 TransactionManager，這裡的宣告式交易涵蓋不到它
  }
  ```
  同一個 DataSource 內若有多筆邏輯上需要一起成功或失敗的操作（例如迴圈呼叫同一個 Manager 方法 N 次），則不屬於本例外——應將交易邊界收斂到單一呼叫（該 Manager 新增一個接受整批資料的方法，內部一次寫入），而不是讓呼叫端迴圈呼叫、產生 N 個獨立交易。

### InitAppService / InitService 規範

- `*InitAppService`：必須包含 `@EventListener` 方法作為啟動觸發入口，不可被 Controller 注入。*（慣例；ArchUnit 未強制）*
- `*InitService`：僅在啟動邏輯複雜、需要多步驟編排時建立；單一方法呼叫不需要此層。
- 兩者的依賴規則與 AppService 相同（只能注入 DomainService 或 Mapper）。
