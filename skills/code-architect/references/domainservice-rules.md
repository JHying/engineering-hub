## DomainService Rules

- Must end with `Service` (not AppService/InitService).
- Inject ONLY `*Manager` from `..manager..`, or `*Mapper` from `..mapper..`（DTO↔VO 轉換用）。
- Must NOT inject `*Repository` or anything from `..infra..`.
- Must NOT use `@RequiredArgsConstructor` — write explicit constructors. *（慣例；Lombok 注解在編譯期消失，ArchUnit 無法偵測，由原始碼審查確認）*
- Constructor dependencies ≤ 6.
- **DomainService 之間不可互相依賴。** 若有共用邏輯，應將其下沉至新的 Manager。*（慣例；ArchUnit 未強制）*
- Public methods MUST return `*VO` / a type from `..vo..`. Allowed exceptions: primitives, `java.*`, `org.springframework.data.domain.*`, `com.example.project.common.dto.*Key`.
- **此檢查需遞迴**：不只看回傳型別最外層是否為 `*VO`，VO 內部欄位與 generic type argument（如 `List<FooEntity>`、`PageVO<FooEntity>`）也不可挾帶 Entity/Cache 等 infra 型別，詳見 VO/DTO Rules 的欄位型別限制。Manager 套用相同規則（見 Manager Rules）。
- 查無資料的回傳方式、以及「查無 → 拋例外」時的例外型別選擇：見下方跨層章節「查無資料的表達方式（null / Optional / 例外）」。
- **Parameter rule**: count all parameters (VO, `*Key`, primitives, enums, `java.util.*`, `java.time.*`). Total count **> 3 (i.e., ≥ 4)** → must wrap in VO. Non-VO project-internal types (other than `*Key`) are forbidden regardless of count.
