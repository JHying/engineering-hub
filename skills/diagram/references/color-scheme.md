# 通用顏色規範（所有專案一致）

### sequenceDiagram init 區塊

```
%%{init: {'theme': 'base', 'themeVariables': {'loopLineColor': '#9673A6', 'signalColor': '#ffffff', 'signalTextColor': '#ffffff', 'labelTextColor': '#000000', 'loopTextColor': '#ffffff'}}}%%
```

| 變數 | 顏色 | 作用 |
|------|------|------|
| `loopLineColor` | `#9673A6`（紫色） | `loop` / `alt` 外框線與 `else` 分隔線 |
| `signalColor` | `#ffffff`（白色） | 箭頭線條本身（`->>` / `-->>`） |
| `signalTextColor` | `#ffffff`（白色） | 箭頭線上的訊息文字 |
| `labelTextColor` | `#000000`（黑色） | `alt` / `loop` / `else` 關鍵字標籤 |
| `loopTextColor` | `#ffffff`（白色） | `alt` / `loop` 標頭列的條件描述文字 |

> 注意：`alt` 外框為虛線，是 Mermaid 硬編碼規格，無法透過 themeVariables 改為實線。
