# Instancio 與自訂 setter 的 enum 查找陷阱

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
