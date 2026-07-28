# sequenceDiagram 規範

### 結構慣例

- 排程觸發：`Note over SVC: @Scheduled fixedDelay=Xms`
- 迴圈：`loop for each <類型>`
- 條件分支：`alt <條件描述>` / `else <條件描述>` / `end`
- 例外拋出：`Note over SVC: throw XxxException（...）`
- 成功結尾：`Note over SVC: ✅ ...`
- 失敗結尾：`Note over SVC: ❌ ...`
- 交排程重試：`Note over SVC,CACHE: 🔁 下次排程重試`
- 非同步：`Note over SVC: CompletableFuture async → ...`
- 中文描述，步驟前加編號（`1.` `2a.` `2b.`）

### 步驟編號規則

- 主線：`1.` `2.` `3.` ...
- 分支內：`2a.` `2b.`、`3a.` `3b.`（alt/else 各自從父步驟 + 字母開始）

### 常見語法陷阱

`;` 是 Mermaid 語句結尾符，箭頭訊息文字內不可使用：

- ❌ `CACHE ->> SVC: INCR key; DEL if 0`
- ✅ `CACHE ->> SVC: INCR key<br/>DEL if 0`
