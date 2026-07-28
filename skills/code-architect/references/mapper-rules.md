## Mapper Rules

- Must be a `public interface` (MapStruct generates the impl).
- Must be `public` (top-level classes).
- One VO must NOT be referenced by more than 3 Mappers.

### `unmappedTargetPolicy = ReportingPolicy.IGNORE` 使用時機

只在 **source 是外部 toolbox / 第三方函式庫，且含有 computed getter**（例如 `getProduceKey()`、`getScore()`）導致 MapStruct 編譯期報錯時才加。source 是專案內部類別時不需要。

```java
@Mapper(componentModel = MappingConstants.ComponentModel.SPRING,
        unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface XxxMapper {
    XxxVO toVO(ExternalSource source);
}
```

### VO → Cache 轉換必須透過 Mapper

不可在 Manager 或其他類別中直接 `new Cache()` 並手動 set 欄位。應在對應的 `*Mapper` interface 中新增 `toCache(XxxVO vo)` 與 `toCacheList(List<XxxVO> voList)` 方法，由 MapStruct 自動生成實作。
