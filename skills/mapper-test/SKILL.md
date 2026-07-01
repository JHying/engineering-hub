---
name: mapper-test
description: 根據指定的 Mapper 介面，生成符合本專案慣例的 MapperTest 類別。每個方法對應一個 _allFields_mappedCorrectly 測試，使用 Instancio 建立 source，以 MapperTestUtils.assertAllFieldsMapped 驗證欄位，@Mapping expression/改名欄位加入 excludeFields 並補 assertEquals。
version: "1.1"
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

1. 找到 `<MapperName>.java`（Mapper 介面）與 `<MapperName>Impl.java`（生成的實作）
2. 對每個 public 方法，記錄：
   - 方法名稱、參數型別、回傳型別
   - 讀取方法上所有 `@Mapping` 註解，特別注意：
      - `target` 欄位名稱
      - 有無 `source`、`expression`、`ignore = true`
3. **解析所有參考型別的實際欄位**：對 Mapper 中引用的每一個非 primitive 型別（VO、DTO、Proto 等），讀取該型別的欄位定義：
   - **POJO（VO / DTO / Entity）**：直接讀取 `.java` 原始碼取得欄位名稱與型別
   - **Protobuf 型別**：**不可**讀取本地 toolbox 原始碼（版本可能不同）。應從 `pom.xml` 取得實際依賴版本，再用 `javap` 反編譯 `.m2` 快取的 JAR：
     ```bash
     # 1. 從 pom.xml 確認版本，例如 GrpcUtils 0.0.9
     # 2. 解出 class 再 javap
     cd /tmp && jar xf ~/.m2/repository/com/example/project/GrpcUtils/<version>/GrpcUtils-<version>.jar \
       com/example/project/proto/auth/user/<ProtoClass>.class
     javap -p com/example/project/proto/auth/user/<ProtoClass>.class | grep "public.*get"
     ```
   - 以 `javap` 輸出的 getter 簽章為準，確認欄位名稱（BeanUtils property name）與回傳型別，再決定是否需要加入 excludeFields

### 2. 每個方法產生一個測試

命名規則：`<methodName>_allFields_mappedCorrectly`

#### 單一物件回傳

```java
@Test
void <methodName>_allFields_mappedCorrectly() {
    <SourceType> source = Instancio.create(<SourceType>.class);

    <ReturnType> result = mapper.<methodName>(source, ...);

    MapperTestUtils.assertAllFieldsMapped(source, target, result<excludeFields>);
    // 對每個 excludeField 補上 Assertions.assertEquals
}
```

#### List 回傳

```java
@Test
void <methodName>_list_mapsAllElements() {
    <SourceType> s1 = Instancio.create(<SourceType>.class);
    <SourceType> s2 = Instancio.create(<SourceType>.class);

    List<<ReturnElementType>> result = mapper.<methodName>(List.of(s1, s2));

    assertThat(result).hasSize(2);
    MapperTestUtils.assertAllFieldsMapped(result.get(0), s1, s1<excludeFields>);
   // 對每個 excludeField 補上 Assertions.assertEquals
    MapperTestUtils.assertAllFieldsMapped(result.get(1), s2, s2<excludeFields>);
   // 對每個 excludeField 補上 Assertions.assertEquals
}
```

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

**Instancio 使用反射直接設值**，會 bypass 自訂 setter。但 MapStruct 生成的 Impl 呼叫的是真實 setter。

**危險模式**：result 型別有如下自訂 setter：
```java
public void setCategoryId(Integer categoryId) {
    this.categoryId = categoryId;
    this.categoryType = CategoryType.get(categoryId); // 對未知值拋出 IllegalArgumentException
}
```

當 source 的對應整數欄位（`categoryId`、`typeCode`、`itemId` 等）由 Instancio 隨機生成時，mapper 呼叫 `result.setCategoryId(source.getCategoryId())` 會拋出例外。

**修正方式**：用 `Instancio.of().set(field(...), validValue)` 限制為合法 enum 值：

```java
import static org.instancio.Select.field;

// 在測試類別宣告常數
private static final Integer VALID_CATEGORY_ID = CategoryType.values()[0].getId();
private static final Integer VALID_ITEM_ID = ItemType.values()[0].getId();
private static final Integer VALID_TYPE = TypeCode.values()[0].getId();

// 建立 source 時限制問題欄位
CategoryItemRecord source = Instancio.of(CategoryItemRecord.class)
    .set(field(CategoryItemRecord.class, "categoryId"), VALID_CATEGORY_ID)
    .set(field(ItemRecord.class, "itemId"), VALID_ITEM_ID) // 巢狀型別也適用
    .create();
```

**判斷時機**：讀取 result 型別的 `.java` 原始碼，若發現 setter 內有 `XxxType.get(intValue)` 形式的呼叫，source 的對應整數欄位就必須限制。

> **注意**：Instancio 的 `field(ClassName.class, "fieldName")` selector 是型別層級的，會套用到物件圖中所有該型別的實例（包含 List 內的巢狀物件）。

**衍生 enum 欄位的 assertEquals**：這類 setter 同時設了兩個欄位（`categoryId` + `categoryType`），`categoryType` 不存在於 source 因此需要 exclude，並補：
```java
Assertions.assertEquals(CategoryType.get(source.getCategoryId()), result.getCategoryType());
```

### 5. Protobuf 型別（GrpcXxxReq 等）

Instancio **無法**建立 Protobuf 物件（私有建構子、final class）。凡 source 或 result 是 Protobuf 型別時，改用 builder 手動建立：

```java
// ❌ 不可用
GrpcLoginReq source = Instancio.create(GrpcLoginReq.class);

// ✅ 改用 builder
GrpcLoginReq source = GrpcLoginReq.newBuilder()
    .setUserId("testUser")
    .setWebsiteId(1)
    .setIp("127.0.0.1")
    .setUserAgent("Mozilla/5.0")
    .build();
```

List 測試中需要兩個不同的 proto 實例，直接分別 inline 建立即可（給不同欄位值）。

**`assertAllFieldsMapped` 方向規則（proto 同樣適用）：**

| 方法方向 | 呼叫方式 | 說明 |
|---|---|---|
| proto → POJO (`toVO`) | `assertAllFieldsMapped(proto, result)` | 迭代 POJO（欄位少）→ 在 proto 找對應名稱 |
| POJO → proto (`toTarget`) | `assertAllFieldsMapped(result, source)` | 反向：迭代 POJO source（欄位少）→ 在 proto result 找對應名稱，避免掃到 proto 內部欄位 |
| POJO → Entity（entity 有額外欄位如 `id`） | `assertAllFieldsMapped(result, source)` | 反向：迭代 VO source → 在 entity result 找，跳過 entity 額外欄位 |

### 6. 方法有多個參數（如 WebsiteType）

在測試類別頂端宣告常數：
```java
private static final CategoryType CATEGORY_TYPE = CategoryType.values()[0];
```
呼叫時帶入，並依 expression 推算期望值：
```java
// @Mapping(target = "compositeKey", expression = "java(new CompositeKey(dto.getOwnerId(), categoryType.getId()))")
Assertions.assertEquals(result.getCompositeKey(), new CompositeKey(dto.getOwnerId(), CATEGORY_TYPE.getId()));
```

---

## 類別結構範本

```java
package <same.package.as.mapper>;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.instancio.Instancio;
import org.instancio.junit.InstancioExtension;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.junit.jupiter.SpringExtension;

// ... 其他 import

@ExtendWith({SpringExtension.class, InstancioExtension.class})
@Import(<MapperName>Impl.class)
class <MapperName>Test {

    @Autowired
    private <MapperName> mapper;

    // 若方法有 enum 參數（例如 CategoryType）：
    private static final CategoryType CATEGORY_TYPE = CategoryType.values()[0];

    // ── <methodName> ──────────────────────────────────────────────

    @Test
    void <methodName>_allFields_mappedCorrectly() {
        <SourceType> source = Instancio.create(<SourceType>.class);

        <ReturnType> result = mapper.<methodName>(source);

        MapperTestUtils.assertAllFieldsMapped(source, result);
    }

    // ... 其餘方法
}
```

---

## Coverage 要求

**JaCoCo methods covered ratio 必須達到 1.00**（每個 class 的每個方法都要被執行到）。

### 需要檢視的對象

生成測試後，必須讀取 `<MapperName>Impl.java`，確認以下兩類方法都有被覆蓋到：

#### 1. Interface 的 `default` 方法

`default` 方法的 bytecode 在 interface class 上，JaCoCo 直接量測 interface。若有未測試的 `default` 方法，interface 的 coverage ratio 將不足。

→ **每個 `default` 方法都必須有對應測試。**

#### 2. Impl 的 `protected` 輔助方法（MapStruct 自動生成的 nested 轉換）

當 Mapper 有巢狀物件型別轉換（如 `GameSettingVO ↔ GameSettingProto`），MapStruct 會在 Impl 生成 `protected` 方法。這些方法只有在 source 物件的對應欄位非 null（或 proto 的 `hasXxx()` 為 true）時才會被呼叫。

**常見陷阱：** 若 source 是 Protobuf，以 builder 手動建立時若漏設某個巢狀欄位，`hasXxx()` 會是 false，導致輔助方法永遠不執行。

```java
// ❌ 沒有設 gameSetting → hasGameSetting() = false → gameSettingProtoToGameSettingVO 不執行
GrpcAccountReq.newBuilder()
    .setUserId("testUser")
    .build();

// ✅ 設定巢狀物件 → 觸發 protected 輔助方法
GrpcAccountReq.newBuilder()
    .setUserId("testUser")
    .setGameSetting(GameSettingProto.newBuilder()
        .setSoundOn(true)
        .setLanguage("en")
        .build())
    .build();
```

→ **讀取 Impl 確認有哪些 `protected` 方法，並確保至少一個測試的 source 資料會觸發每個 `protected` 方法。**

---

## 注意事項

- 測試類別放在與 Mapper 相同的 package（`src/test/java/...`）
- 用 `Instancio.create(...)` 建立 source，不手動 new 物件；**Protobuf 型別例外**，改用 builder（見第 4 節）
- 每個方法只寫一個 `_allFields_mappedCorrectly` 測試，不需要額外的 null / edge case 測試（除非 Mapper 有明顯的 null 處理邏輯）
- `MapperTestUtils` 的完整路徑依當前專案而定，請確認確切位置後 import

---

## MapStruct 陷阱：Collection mapping 的 `@Mapping` 不套用至 element

當 Mapper 方法回傳 `List<TargetVO>` 且 source 與 target 有欄位數量不對稱時，直接在 list 方法上標 `@Mapping(ignore = true)` **不會生效**，MapStruct 仍會產生 unmapped warning，且被 ignore 的欄位不會正確處理。

**原因**：MapStruct 不會將 collection-level 方法的 `@Mapping` 套用至自動生成的 element-level 轉換。

**修法**：額外定義一個 element-level 方法，並在該方法上標 `@Mapping`。MapStruct 會自動把它用在 list 轉換裡：

```java
/**
 * 此方法未直接使用。
 * MapStruct 不會將 Collection mapping 方法上的 @Mapping 套用至 element 轉換，
 * 須定義此 element-level 方法讓 toXxxList 自動套用 ignore 設定。
 */
@Mapping(target = "extraField1", ignore = true)
@Mapping(target = "extraField2", ignore = true)
TargetVO toTargetVO(SourceDTO dto);

List<TargetVO> toTargetVOList(Collection<SourceDTO> dtos);
```

> ⚠️ 常見錯誤：將 `@Mapping(ignore = true)` 標在 list 方法上無效，需改為定義 element-level 方法才能消除 unmapped warning。