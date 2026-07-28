## Constants Rules

- Top-level class must be `final class`, `interface`, or `@UtilityClass`.
- All fields must be `public static final` (implicit in interfaces; skip `$`-prefixed synthetic fields).
- No business logic methods (interface `default` methods for constant composition are allowed).
- No Spring annotations (`@Component`, `@Service`, `@Configuration`).
- Must NOT depend on `..controller..`, `..service..`, `..manager..`, `*Repository`, `*Client`.

## Config Rules

- Top-level classes (outside `..common..`) must use `@Configuration`, `@ConfigurationProperties`, or `@Component`.
- Must NOT be `@Controller`, `@RestController`, `@Service`, or `@Repository`.
- Must be `public` (outside `..common..`).
- Must NOT depend on `..service..` or `..controller..`.

## Utils Rules

- Top-level classes (outside `..common..`) should be `@UtilityClass`, `@Component`, or `@Service`; or all public methods should be `static`. *（軟規則；ArchUnit 條件僅輸出 debug log，不產生違規，由 Code Review 確認）*
- Must be `public` (outside `..common..`).
- Must NOT depend on `..controller..`, `..service..`, `*Manager`, `*Repository`, `*Client`.
- 查無資料的回傳方式：見下方跨層章節「查無資料的表達方式（null / Optional / 例外）」。**靜態查表方法（`Map.get()` 結果直接 return）是本規則最常被漏掉的位置**——它不在 Infra 層，卻同樣讓呼叫端拿到 null。
