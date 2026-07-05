# Changelog — contract-test

所有版本異動依時間倒序排列。

---

## [1.1] — 2026-07-05

### Added
- frontmatter 補上 `version` 欄位

---

## [1.0] — 初版

### Added
- 根據指定 Controller 自動生成 Spring Cloud Contract Groovy DSL 契約檔
- 讀取 Controller endpoint、request / response DTO 及 validation annotation，推導契約內容
- 生成 `_valid.groovy`：單一合法請求情境，依欄位規則自動選擇 consumer/producer matcher
- 生成 `_invalid.groovy`：涵蓋 400（`@NotBlank` / `@NotNull` / `@PositiveOrZero` 欄位違規）與 401（service 層 AuthenticationException）異常情境清單
- 生成對應的 `ContractBase.java`：含 `@WebMvcTest`、`@MockitoBean`、Mockito LIFO mock 設定規則
- `Timestamp` / `LocalDateTime` 欄位自動套用 ISO 8601 regex matcher
- `MethodArgumentNotValidException` / `AuthenticationException` 統一 response body 格式支援
