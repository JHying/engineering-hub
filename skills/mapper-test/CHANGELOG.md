# Changelog — mapper-test

所有版本異動依時間倒序排列。

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
