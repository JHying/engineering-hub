# MapStruct 陷阱：Collection mapping 的 `@Mapping` 不套用至 element

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