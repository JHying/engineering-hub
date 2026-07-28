## Manager Rules

- Must end with `Manager` and annotate with `@Component` (non-abstract classes).
- Must NOT use `@Service`.
- Inject ONLY from `..infra..`, `..mapper..`, `..vo..`, or `..entity..`.
- Must NOT depend on `..service..` or `..controller..`.
- Constructor dependencies ≤ 6.
- Public methods: same return type and parameter rules as DomainService. Exception: external framework types (non `com.example.project`) do not count toward parameter total.
- 查無資料的回傳方式：見下方跨層章節「查無資料的表達方式（null / Optional / 例外）」。**Manager 最常見的違規是把 Infra 回傳的 `Optional` 拆成 `null` 再往上丟**，等於抵銷 Infra 層的規則。**Manager 禁的是回 `null` 與拋業務例外**；對「必要資料查無」的必然系統故障，Manager `orElseThrow` 系統例外（`NoSuchElementException`/`IllegalStateException`）是允許的 fail-fast，非只能透傳 `Optional`（查無「有時正常」才透傳 Optional 讓 Domain Service 決定）。
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
