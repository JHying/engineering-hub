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

// ❌ Manager 把 Infra 的 Optional 拆成 null 再往上丟（抵銷 Infra 層規則）
public Map<String, Integer> getSettings(int id) {
    return repository.findById(id).map(FooEntity::getSettings).orElse(null);
}
// → public Optional<Map<String, Integer>> getSettings(int id) {
//        return repository.findById(id).map(FooEntity::getSettings);
//    }

// ❌ Utils 靜態查表回 null（不在 Infra 層，最常被漏掉）
public static CategoryType findCategory(String key) {
    return CATEGORY_BY_KEY.get(key);
}
// → public static Optional<CategoryType> findCategory(String key) {
//        return Optional.ofNullable(CATEGORY_BY_KEY.get(key));
//    }

// ❌ 服務端資料不完整卻拋業務例外（使用者看到錯誤原因、污染業務失敗統計）
if (settings.get(key) == null) {
    throw new FooInvalidException("request rejected: " + requestId);
}
// → throw new NoSuchElementException("Setting miss: " + key);   // 系統例外，走 5xx，不進業務失敗記錄

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

// ❌ ACL 違規：DomainService 直接依賴外部型別（proto / 持久層 Entity 滲透進 Domain 層）
public InvoiceStatusVO checkStatus(InvoiceProto.InvoiceInfo invoice, InvoiceEntity entity)
// → public InvoiceStatusVO checkStatus(String invoiceId)
//    // 呼叫 InvoiceManager.getInvoice(invoiceId) 取得已轉換的 InvoiceVO，proto/Entity 止步於 Manager
```
