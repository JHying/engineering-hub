# 方法有多個參數（如 WebsiteType）

在測試類別頂端宣告常數：
```java
private static final CategoryType CATEGORY_TYPE = CategoryType.values()[0];
```
呼叫時帶入，並依 expression 推算期望值：
```java
// @Mapping(target = "compositeKey", expression = "java(new CompositeKey(dto.getOwnerId(), categoryType.getId()))")
Assertions.assertEquals(result.getCompositeKey(), new CompositeKey(dto.getOwnerId(), CATEGORY_TYPE.getId()));
```
