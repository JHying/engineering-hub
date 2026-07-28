# Changelog — mapper-test

所有版本異動依時間倒序排列。

---

## [1.2] — 2026-07-28

### Changed
- SKILL.md 拆分為骨幹 + references/(progressive disclosure)，降低觸發時整份載入的 context 成本；主檔僅保留觸發條件、生成流程步驟骨幹（含 excludeFields 判斷規則等硬性約束）與注意事項，明細移至同目錄 references/：
  - `references/reading-mapper-interface.md` — 讀取 Mapper 介面與型別欄位解析明細
  - `references/test-method-templates.md` — 單一物件回傳、List 回傳測試程式碼範本
  - `references/instancio-enum-pitfall.md` — Instancio 與自訂 setter 的 enum 查找陷阱
  - `references/protobuf-handling.md` — Protobuf 型別建立方式與 assertAllFieldsMapped 方向規則
  - `references/multi-param-methods.md` — 方法有多個參數時的處理範例
  - `references/class-template.md` — 測試類別結構範本
  - `references/coverage-requirements.md` — Coverage 要求明細（default / protected 方法覆蓋）
  - `references/collection-mapping-pitfall.md` — Collection mapping 的 @Mapping 不套用至 element 陷阱

---

## [1.1] — 2026-04-16

### Added
- **MapStruct 陷阱**：Collection mapping 的 `@Mapping` 不套用至 element-level 轉換，需額外定義 element-level 方法

---

## [1.0] — 初版

### Added
- 根據 Mapper 介面生成符合專案慣例的 `MapperTest` 類別
- 每個方法對應一個 `_allFields_mappedCorrectly` 測試
- 使用 Instancio 建立 source 物件
- 以欄位映射完整性驗證工具方法確認所有欄位正確映射
- `@Mapping` expression / 改名欄位加入 `excludeFields` 並補 `assertEquals`
