# 流程圖 Metadata 格式

每個圖檔最頂部宣告（Mermaid block 之前）：

```markdown
<!-- synced: {commit-hash} -->
<!-- type: sequenceDiagram -->
<!-- covers:
  path/to/SourceFile1.java
  path/to/SourceFile2.java
-->
```

`type` 固定為 `sequenceDiagram` 或 `flowchart`，由生成時寫入，供 sync 判斷更新規則。
