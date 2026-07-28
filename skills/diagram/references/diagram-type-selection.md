# 圖表類型選擇

使用者指定時以指定為準；自動判斷時依下表：

| 情境 | 類型 |
|------|------|
| 跨元件 / 服務的訊息傳遞、資料流（Controller → Infra） | `sequenceDiagram` |
| 排程觸發的完整流程（含外部系統互動） | `sequenceDiagram` |
| 特定方法內的條件分支、狀態機、演算法邏輯（不限層級，可為 DomainService / Manager / 任意方法） | `flowchart TD` |
