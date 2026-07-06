# REVIEW_GUIDE.md
# Code Review 統一規範

version: 2026-07-06（新增 Redis Cluster Cross-Slot 檢查點，來源：多 key Lua Script 實務案例）
目標：確保系統的「維護性」、「擴展性」、「可靠性」

---

## 審查輸出格式（每次 Review 必須依序列出以下三區塊）

```
### 品質問題（Quality Issues）
- [ ] <ClassName / 方法> — <違規原則> — <發現> — <修正方向>

### 效能瓶頸 / 資料原子性（Performance & Atomicity Issues）
- [ ] <ClassName / 方法> — <問題類型> — <發現> — <修正方向>

### 設計模式（Design Pattern Review）
- 已使用：<模式名稱> @ <位置> — <評語：合適 / 誤用>
- 過度設計：<位置> — <說明>
- 建議引入：<模式名稱> — <理由>
```

---

## 一、技術棧分類表

> 新增技術棧時，在對應類別補一列即可。

### 1-1 應用框架

| 技術 | 版本 / 說明 | 審查重點 |
|------|------------|---------|
| Spring Boot | 3.x | Auto-configuration 副作用、Bean 生命週期 |
| Spring Cloud | 2025 | 服務發現、Config Server、Gateway 路由 |
| Spring Cloud Stream | Kafka binder | Binding 設定、Consumer Group、DLQ |
| Spring MVC | Spring Boot 內建 | Controller 分層、@Transactional 邊界 |
| Spring WebFlux | Spring Boot 內建 | Reactive pipeline、blocking call 混用 |

### 1-2 持久層

| 技術 | 版本 / 說明 | 審查重點 |
|------|------------|---------|
| Spring Data JPA | Hibernate 6 | N+1、FetchType、@Transactional 邊界 |
| Spring Data MongoDB | Spring Boot 3 內建 | Partial Update、Index 使用、TTL |
| Oracle | OJDBC8 | 序列、批次 INSERT、悲觀鎖 vs 樂觀鎖 |
| JDBC | Pure Java | Connection 洩漏、PreparedStatement 重用 |

### 1-3 快取

| 技術 | 版本 / 說明 | 審查重點 |
|------|------------|---------|
| Redis | Lettuce client | Key 設計、TTL、Pipeline vs 單命令、Lua Script 原子性 |
| Caffeine | Local Cache | 跨 Pod 同步問題、容量設定、統計監控 |

### 1-4 訊息佇列

| 技術 | 版本 / 說明 | 審查重點 |
|------|------------|---------|
| Apache Kafka | Spring Cloud Stream / KafkaTemplate | 冪等性、Consumer Group、Partition Key、重試策略、DLQ |

### 1-5 遠端通訊

| 技術 | 版本 / 說明 | 審查重點 |
|------|------------|---------|
| gRPC | spring-grpc | Timeout 設定、Channel 重用、錯誤碼映射 |
| HTTP | Spring RestClient / WebClient | 連線池、Timeout 三層（connect / read / write）、重試冪等性 |
| Jakarta WebSocket | JSR-356 | Session 管理、廣播效率、心跳機制 |

### 1-6 容器 / 部署

| 技術 | 版本 / 說明 | 審查重點 |
|------|------------|---------|
| Undertow | Spring Boot 預設替換 Tomcat | IO Thread vs Worker Thread 比例、XNIO 參數 |
| Tomcat | Spring Boot 預設 | Max Thread、Connector、keepAliveTimeout |
| JAR | Spring Boot Fat JAR | 啟動時間、classpath 順序 |
| WAR | 傳統部署 | Servlet Container 相容性、JNDI DataSource |
| Pure Java Servlet | Javax / Jakarta | Filter 順序、ServletContext 共享狀態 |
| JSP | Jakarta Pages | 避免在 JSP 寫業務邏輯，確保 View 純展示 |

### 1-7 前端

| 技術 | 版本 / 說明 | 審查重點 |
|------|------------|---------|
| Vue | 3.x | API 呼叫錯誤處理、WebSocket reconnect 邏輯 |

---

## 二、品質審查標準（Quality）

> 原則：**不過度設計**——介面、抽象、Pattern 只在有多個實作或明確擴展需求時引入。

### 2-1 OOP 原則

| 原則 | 說明 | 常見違規 |
|------|------|---------|
| 封裝（Encapsulation） | 狀態由擁有者控管，不對外暴露可變內部 | getter 回傳可變集合、public field |
| 繼承 vs 組合 | 優先組合，繼承只用於真正 is-a 關係 | 只為複用而繼承（has-a 用 delegate） |
| Tell Don't Ask | 讓物件自己做決定，不要從外部抓資料再判斷 | `if (obj.getStatus() == X) obj.setStatus(Y)` |
| Law of Demeter | 只和直接朋友說話 | `a.getB().getC().doSomething()` |
| 多型取代 if-else | 行為隨型別變化時用多型，不用 instanceof chain | `if (type == A) ... else if (type == B)` |

### 2-2 Clean Code

| 面向 | 標準 |
|------|------|
| 命名 | 方法名動詞開頭、布林命名 is/has/can、常數全大寫底線 |
| 方法長度 | 單一方法不超過 30 行（超過考慮拆分） |
| 參數數量 | 超過 3 個考慮封裝成 DTO / ValueObject |
| 魔術數字 | 所有 literal 數字提取為具名常數 |
| 註解 | 只寫「為什麼」，不寫「做什麼」（程式碼自解釋） |
| 例外處理 | 不吞異常、不用 Exception 做流程控制、分層邊界轉譯 |

> **Infra 層空值處理**：Infra 層方法查無資料時禁止直接回傳 `null`，必須回傳 `Optional<T>`（集合類則回傳空 List）。原因：直接回傳 null 讓「查無資料」與「例外狀況」混在同一種訊號裡，呼叫端容易漏判導致 NPE；統一用 `Optional` 讓「找不到」成為型別系統可見、強制呼叫端顯式處理的狀態。審查時檢查 Infra 方法簽名回傳型別，以及是否有 `return null;` 或未包裝的可空表達式。完整判準與範例見 `/code-architect` skill（Infra Rules）。

### 2-3 SOLID

| 原則 | 說明 | 違規警示 |
|------|------|---------|
| SRP（單一職責） | 一個類別只有一個改變的理由 | Service 同時處理業務邏輯 + 格式轉換 + 持久化 |
| OCP（開放封閉） | 對擴展開放、對修改封閉 | 新增功能必須修改既有 if-else |
| LSP（里氏替換） | 子型別可完全替代父型別 | Override 後行為改變或丟出父類未宣告的例外 |
| ISP（介面隔離） | 不強迫實作不需要的方法 | 一個介面包含無關的方法群 |
| DIP（依賴反轉） | 高層模組不依賴低層實作，依賴抽象 | Service 直接 `new` 實作類別 |

> ⚠️ 注意：ISP / DIP 引入介面有成本。**若只有一個實作且未來不會擴展，不需要抽介面。**

### 2-4 DDD 概念

| 概念 | 說明 | 審查重點 |
|------|------|---------|
| Entity | 有唯一識別符、生命週期跨越多操作 | ID 欄位明確、相等性以 ID 比較 |
| Value Object | 無識別符、以值相等、不可變 | 確認 immutable，不應有 setter |
| Aggregate | 一致性邊界，只透過 Aggregate Root 修改內部狀態 | 外部不應直接操作 Aggregate 內部 Entity |
| Domain Service | 跨多個 Aggregate 的業務邏輯，無狀態 | 不應含持久化操作（交給 Repository） |
| Manager | 包裝 Infra 操作、回傳技術結果（boolean / Optional / 數值） | **不應拋業務例外、不做業務判斷**；業務規則解讀屬 Domain Service 職責 |
| — | Manager 職責的完整判準與 ✅/❌ 範例以 `/code-architect` skill 為準，本表僅作概念摘要 | — |
| Repository | 持久化抽象，Domain 層不知道 DB 實作 | 不在 Domain Service 直接呼叫 JPA/Mongo API |
| Anti-Corruption Layer | 外部系統整合邊界轉譯 | 外部 DTO 不應滲透到 Domain 內部 |
| 欄位新增資料流追蹤 | 新增欄位需追蹤完整鏈路（Entity/Proto → Mapper → VO → Mapper → Cache → Redis），不能只確認到 VO 與 Mapper 就停止 | Cache 類別最容易被漏加：MapStruct 對缺漏欄位採 `ReportingPolicy.IGNORE` 靜默不報錯，導致該欄位存進 Redis 後恆為 null |
| — | 完整資料流圖示與範例以 `/code-architect` skill 為準，本表僅作概念摘要 | — |

---

## 三、效能瓶頸 / 資料原子性審查標準（Performance & Atomicity）

### 3-1 系統規格基準

> 系統規格因專案而異，不在此處定義固定數值。
> Review 時請從對應**專案 KB 的 MASTER_INDEX → 系統規格基準**取得門檻值。

| 門檻類型 | 使用規則 |
|---------|---------|
| 系統現狀（強制） | 現有 QPS / TPS，不達標須在 Review 結果中標注風險 |
| 資料量現狀（強制） | 各資料集筆數，影響 Index / Cache 策略判斷 |
| 系統期望目標（參考） | 未來優化方向，標注建議但非強制 |

### 3-2 資料庫 / 持久層

| 問題類型 | 審查項目 |
|---------|---------|
| N+1 查詢 | JPA 關聯未設 Fetch Join、迴圈內查詢 |
| 大量全表掃描 | 缺少 Index、LIKE '%xxx' 無法走索引 |
| 長事務 | @Transactional 方法內含 HTTP call / Kafka send |
| 批次處理 | 單筆迴圈 INSERT 應改 batch INSERT |
| 悲觀鎖範圍 | FOR UPDATE 鎖住過多列、持鎖時間過長 |
| 樂觀鎖衝突 | 高並發下 @Version 衝突率、重試策略 |
| MongoDB `save()` 誤用 | `save()` 具 upsert 語意，帶 `_id` 時會整份文件覆蓋，可能造成非預期資料遺失；審查是否應改用 `insert()`（新增）或 `upsert()`（條件更新） |

> MongoDB `save()` 禁令的完整判準、正確替代寫法與程式碼範例見 `/code-architect` skill（Infra Rules → MongoDB 操作限制）。

### 3-3 Redis

| 問題類型 | 審查項目 |
|---------|---------|
| 原子性 | 非原子的 GET-CHECK-SET 應改 Lua Script 或 SET NX |
| Cluster Cross-Slot | Redis Cluster 環境下，Lua Script／MULTI／`DEL`(多 key) 等指令若涉及 2 個以上 key，需確認這些 key 是否保證落在同一 slot；由不同來源值（如不同業務欄位各自組字串）組成的 key 幾乎必然落在不同 slot，執行時會拋 `CROSSSLOT Keys in request don't hash to the same slot`。Lua Script／MULTI 無法像 `MGET`/`DEL` 那樣被 client 端自動依 slot 拆分執行，是硬性限制而非效能問題。審查時檢查：① 是否為 Redis Cluster 部署（非 standalone/Sentinel）② Script 是否有 2 個以上 key ③ 這些 key 是否用 hash tag（`{tag}`）強制同 slot，或整個資料模型改為單一 key（如用 HASH 的多個 field 取代多個獨立 key）避免跨 key 依賴 |
| 熱 Key | 單一 Key 寫入頻率過高，考慮分片或 Local Cache 前置 |
| 大 Key | Value 過大（> 1MB）影響序列化與網路 |
| Pipeline | 多個獨立命令應合併為 Pipeline，減少 RTT |
| 過期策略 | TTL 缺失導致 Key 堆積、TTL 設定不合理 |
| 快取穿透（Penetration） | 查詢不存在的 key 是否有防護（空值快取 + 短 TTL、布隆過濾器），避免每次繞過快取直打 DB |
| 快取雪崩（Avalanche） | 大量 Key 是否使用相同 / 相近 TTL 未加隨機偏移，同時集體過期造成流量瞬間全打 DB |
| 快取擊穿（Breakdown） | 熱點 Key 過期瞬間是否有互斥鎖（Mutex Lock）或邏輯過期（Logical TTL）防止重建風暴 |

> 判斷「熱點 Key」「合理 TTL」需依專案實際流量與資料特性：Review 時請從對應**專案 KB 的系統規格基準**（`MASTER_INDEX.md`）或 `source-codex/cross/redis-keymap.md`（若專案有維護）取得實際 Key 設計與 TTL 依據，不套用通用門檻。
> 三種異常情境的成因分析與解法範例，見 `common_KBs/tech-research/redis-cache-failure-patterns.md`。

### 3-4 Kafka

| 問題類型 | 審查項目 |
|---------|---------|
| 冪等性 | Consumer 重複消費是否有 deduplicate 機制 |
| 訊息順序 | 同一實體須用相同 Partition Key 保證順序 |
| 重試策略 | 無限重試可能造成 Consumer Lag 堆積，應有 DLQ |
| 事務邊界 | DB 寫入 + Kafka produce 須考慮兩階段提交或 Outbox Pattern |
| Consumer Group | 多 Pod 消費時 Partition 分配是否均勻 |

### 3-5 HTTP / gRPC 對外呼叫

| 問題類型 | 審查項目 |
|---------|---------|
| Timeout 三層 | connect / read / write timeout 全部設定 |
| 連線池 | 每次請求 `new` Client 或未設定連線池上限 |
| 同步阻塞 | @Transactional 方法內含同步 HTTP call，持鎖等待 |
| 重試冪等 | 非冪等操作（建立資源）不應自動重試 |
| 熔斷 | 下游異常是否有 Fallback / Circuit Breaker |

### 3-6 並行 / 跨 Pod 同步

| 問題類型 | 審查項目 |
|---------|---------|
| Caffeine 跨 Pod | Local Cache 更新後其他 Pod 仍持有舊值，需 Kafka/Redis 廣播失效 |
| Singleton 共享狀態 | Spring Bean（default singleton）持有可變欄位，多執行緒競爭 |
| CompletableFuture | exception 分層處理、timeout 設定、避免 join() 阻塞 IO Thread |
| 分散式鎖 | Redis SETNX / Redisson，確認鎖釋放（finally）與 TTL |
| 水平擴展 | Session / 狀態不應存在 JVM 記憶體，應外移 Redis |
| 定時任務 | 多 Pod 同時觸發，應使用 ShedLock 或 JobRunr 保證單次執行 |

### 3-7 WebSocket / 長連線

| 問題類型 | 審查項目 |
|---------|---------|
| Session 存放 | Session Map 存 JVM 記憶體 → 水平擴展後找不到 session |
| 廣播效率 | 逐一 send 改為批次廣播，避免 O(N) blocking |
| 心跳 / 重連 | 無 heartbeat 機制，連線靜默斷開無法感知 |
| 執行緒模型 | Undertow：IO Thread 不可 blocking，必須切換 Worker Thread |

---

## 四、設計模式審查標準（Design Patterns）

### 4-1 已定義模式

| 模式 | 適用場景 | 誤用警示 |
|------|---------|---------|
| **Singleton**（單例） | 無狀態的工具 / Service，全程只需一個實例 | 持有可變狀態 → 並行問題；Spring Bean 預設即 Singleton，不需再手工實作 DCL |
| **Spring Bean Lifecycle**（預設說明） | `@Component` / `@Service` / `@Repository` 預設 scope=singleton；`@RequestScope` / `@SessionScope` / `@Prototype` 用於有狀態場景 | 在 singleton bean 注入 prototype bean 時未使用 `ApplicationContext.getBean()` 或 `ObjectProvider` |
| **Factory Method**（工廠方法） | 由子類決定建立哪種物件，隱藏建立細節 | 只有一種產品卻引入抽象工廠 |
| **Abstract Factory**（抽象工廠） | 建立一族相關物件（如多 DB 環境、多廠商策略） | 產品族只有一個 → 用簡單工廠即可 |
| **Aggregator Pattern**（自定義） | 聚合多個下游資料來源，統一回傳結構 | 各 source 強依賴順序 → 應改為並行 + 合併 |
| **Spring Aggregator Pattern** | Spring Integration Aggregator：收集多個訊息後合併為一個 | 只有一個輸入訊息卻使用 Aggregator → 過殺 |
| **Sealed Interface + Pattern Matching**（JDK 17+） | 封閉、窮舉的多態結果集（3+ 狀態，如 Success / Timeout / Failure）；編譯器強制所有分支都被處理 | 狀態集尚未穩定就封閉 → 每次新增狀態都要改所有 switch；JUnit 4 環境窮舉斷言不直覺；團隊不熟 pattern matching 時 reviewer 無法有效把關。**引入前需滿足三個條件（見 ADR-0043）**：① 已升級 JUnit 5、② 團隊完成 sealed interface 教育訓練、③ 狀態集穩定兩個 sprint 以上 |

### 4-2 Review 輸出規則（設計模式區塊）

每次 Review 必須回答以下三個子項：

1. **已使用**：列出程式碼中識別到的模式，說明是否合適
2. **過度設計**：介面/抽象/模式引入但無實際效益的地方
3. **建議引入**：明確說明引入後解決什麼問題、不引入的代價

> 若三個子項均無內容，明確寫「無」，不得省略。

---

## 五、CI 覆蓋確認（曾為「審查不涵蓋範圍」，2026-07-03 移除排除清單）

以下項目過去假設「由 CI 工具強制，Review 不重複檢查」。此假設不可靜默沿用——**Review 開始前必須先確認對應專案的 CI 設定（`.gitlab-ci.yml` 等）是否真的涵蓋這些項目**；只要有一項未被 CI 實際涵蓋，Review 階段就必須自行檢查，不得因為「理論上該由誰把關」而略過：

| 項目 | 原本假設的把關方 | Review 時的處理 |
|------|----------------|-----------------|
| Package 命名與邊界、分層依賴方向 | ArchUnit（CI） | 呼叫 skill: `/code-architect` 逐檔審查，結果併入本次 Review 的品質問題區塊，不得略過 |
| 測試覆蓋率 | SonarQube | 檢查本次異動是否有對應的單元 / 整合測試覆蓋；缺漏視為 Review 發現項 |
| DB Schema 命名規則 | db-object-rules skill | 涉及 DB Object 異動時，呼叫 skill: `/db-object-rules` 審查，結果併入本次 Review |

**判斷是否可略過的唯一依據**：實際檢視該專案的 CI 設定檔，確認對應 stage 存在且會執行。無法確認時，一律視為未涵蓋，Review 階段自行把關。

若上述項目在 Review 階段被判定為未涵蓋而發現問題，其嚴重度與待遇比照第二節「品質問題」——列入審查輸出格式的品質問題區塊，計入摘要計數，不得因為「本非 Review 職責」而降級或省略。

---

## 六、修改本文件指引

| 需求 | 修改位置 |
|------|---------|
| 新增技術棧 | 第一節對應類別表格補一列 |
| 調整品質原則 | 第二節對應子章節 |
| 調整效能基準值 | 第三節 3-1 系統規格基準 |
| 新增效能審查項目 | 第三節對應子章節 |
| 新增設計模式 | 第四節 4-1 表格補一列 |
| 調整輸出格式 | 本文件頂部「審查輸出格式」區塊 |
