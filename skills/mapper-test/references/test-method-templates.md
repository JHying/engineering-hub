# 每個方法產生一個測試：程式碼範本

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
