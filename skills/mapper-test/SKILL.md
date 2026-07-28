---
name: mapper-test
description: 根據指定的 Mapper 介面，生成符合本專案慣例的 MapperTest 類別。每個方法對應一個 _allFields_mappedCorrectly 測試，使用 Instancio 建立 source，以 MapperTestUtils.assertAllFieldsMapped 驗證欄位，@Mapping expression/改名欄位加入 excludeFields 並補 assertEquals。
version: "1.2"
---

根據指定的 Mapper 介面，生成符合本專案慣例的 MapperTest 類別。

## 使用方式

```
/mapper-test <MapperInterfaceName>
```

例：`/mapper-test MockBalanceMapper`

---

## 生成步驟

### 1. 讀取 Mapper

找到 Mapper 介面與其生成的 Impl，記錄每個方法的簽章與 `@Mapping` 註解（target/source/expression/ignore）。解析每個引用型別的實際欄位：POJO（VO/DTO/Entity）直接讀原始碼；Protobuf 型別不可讀本地原始碼，改用 `javap` 反編譯 `.m2` 快取的 JAR（版本以 `pom.xml` 為準）。

明細見 `references/reading-mapper-interface.md`。

### 2. 每個方法產生一個測試

命名規則：`<methodName>_allFields_mappedCorrectly`。單一物件回傳與 List 回傳各有對應的程式碼範本。

完整範本見 `references/test-method-templates.md`。

### 3. excludeFields 判斷規則

| 情況 | 加入 excludeFields？ | 補 assertEquals？ | assertEquals 內容 |
|---|---|---|---|
| `expression = "java(...)"` | ✅ | ✅ | 依 expression 邏輯組出期望值 |
| target 與 source 欄位名稱不同 | ✅ | ✅ | 依 `@Mapping(target=..., source=...)` 邏輯撰寫比對 |
| `ignore = true` | ✅ | ❌ | — |
| 欄位同名、無特殊設定 | ❌ | ❌ | 由 assertAllFieldsMapped 自動驗證 |
| **VO 自訂 setter 衍生欄位**（不存在於 source） | ✅ | ✅ | `XxxType.get(source.getXxxId())` |
| **同名 List 但元素型別不同**（如 `List<AVO>` vs `List<ADTO>`） | ✅ | ✅ | 手動驗證 size 與各元素關鍵欄位 |

excludeFields 帶入第三個參數，**每個 excludeField 前方必須加上行內註解說明排除原因**：

```java
// userKey: @Mapping(target="userKey", expression="java(...)")，由 expression 組合
// updateDate: @Mapping(target="updateDate", ignore=true)，update 不可修改
MapperTestUtils.assertAllFieldsMapped(source, result, "userKey", "updateDate");
```

常見排除原因範本：

| 情況 | 註解範本 |
|---|---|
| `expression = "java(...)"` | `// <field>: @Mapping expression 組合，見下方 assertEquals` |
| `ignore = true`（update 不可修改） | `// <field>: @Mapping(target="<field>", ignore=true)，update 不可修改` |
| target/source 欄位改名 | `// <field>: @Mapping(target="<field>", source="<src>")，欄位改名` |
| Entity 的 DB 管理欄位（不存在於 DTO/VO） | `// <field>: Entity 的 DB 管理欄位，不存在於 <DTO/VO>` |
| VO 自訂 setter 衍生欄位 | `// <field>: VO 欄位不存在於 <Source>，由 VO.set<XxxId>() 自動推算` |
| 同名 List 元素型別不同 | `// <field>: 元素型別不同（<TypeA> → <TypeB>），需手動驗證` |

### 4. Instancio 與自訂 setter 的 enum 查找陷阱

Instancio 用反射直接設值會 bypass 自訂 setter，但 MapStruct 生成的 Impl 呼叫真實 setter；若 setter 內有 `XxxType.get(intValue)` 這類查表邏輯，source 對應整數欄位的隨機值可能查無對應 enum 而拋例外，須用 `Instancio.of().set(field(...), validValue)` 限制為合法值。

明細與範例見 `references/instancio-enum-pitfall.md`。

### 5. Protobuf 型別（GrpcXxxReq 等）

Instancio 無法建立 Protobuf 物件（私有建構子、final class），source/result 為 Protobuf 時一律改用 builder 手動建立。`assertAllFieldsMapped` 呼叫方向依轉換方向（proto→POJO / POJO→proto / POJO→Entity）而不同。

明細與方向規則表見 `references/protobuf-handling.md`。

### 6. 方法有多個參數（如 WebsiteType）

在測試類別頂端宣告常數代表額外參數，呼叫時帶入，並依 `@Mapping expression` 邏輯推算期望值。

範例見 `references/multi-param-methods.md`。

---

## 類別結構範本

完整範本見 `references/class-template.md`。

---

## Coverage 要求

**JaCoCo methods covered ratio 必須達到 1.00**：需確認 interface 的 `default` 方法、以及 Impl 中 MapStruct 自動生成的 `protected` 巢狀轉換輔助方法，都有測試觸發到（後者需 source 的巢狀欄位非 null，或 proto 的 `hasXxx()` 為 true）。

明細與範例見 `references/coverage-requirements.md`。

---

## 注意事項

- 測試類別放在與 Mapper 相同的 package（`src/test/java/...`）
- 用 `Instancio.create(...)` 建立 source，不手動 new 物件；**Protobuf 型別例外**，改用 builder（見第 4 節）
- 每個方法只寫一個 `_allFields_mappedCorrectly` 測試，不需要額外的 null / edge case 測試（除非 Mapper 有明顯的 null 處理邏輯）
- `MapperTestUtils` 的完整路徑依當前專案而定，請確認確切位置後 import

---

## MapStruct 陷阱：Collection mapping 的 `@Mapping` 不套用至 element

當 Mapper 方法回傳 `List<TargetVO>` 且 source 與 target 有欄位數量不對稱時，直接在 list 方法上標 `@Mapping(ignore = true)` 不會生效，需改為額外定義 element-level 方法並在該方法標註 `@Mapping`。

明細與範例見 `references/collection-mapping-pitfall.md`。
