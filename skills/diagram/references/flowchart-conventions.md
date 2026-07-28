# flowchart 規範

### 結構慣例

- 排程起點：`START(["@Scheduled fixedDelay=Xms\n方法名稱()"])`
- 迴圈：`subgraph LOOP1["for each <類型>"]` ... `end`（可巢狀）
- 決策菱形：`{條件描述}`
- 例外：`[/"throw XxxException\n'...'"/]`
- 正常動作：`["動作描述"]`
- 終點成功：`(["✅ 完成描述"])`
- 終點失敗：`(["❌ 失敗描述"])`
- 相同職責節點用 `subgraph` 分組（Controller、AppService、Manager 等）
- 外部系統用 `(["..."])` 或 `[("...")]`
- 流程步驟順序標示用 `[1][2][3]...`
