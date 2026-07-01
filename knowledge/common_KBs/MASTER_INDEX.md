# Common Knowledge Base — 通用知識庫索引

> 本 KB 收錄跨專案、跨語言、不含專案識別資訊的技術知識。
> 適用情境：技術探討、框架評估、架構研究、最佳實踐沈澱。

---

## 一、共用架構決策（ADRs）

路徑：`knowledge/common_KBs/ADRs/`

去識別化的 MADR 格式決策記錄，從專案 ADR 抽取後保留通用推理脈絡。

| 分類 | 路徑 | 主題 |
|------|------|------|
| 01 應用架構 | `ADRs/01-application-architecture/` | DDD 分層、服務拆分、微服務 vs 單體決策 |
| 02 程式設計標準 | `ADRs/02-coding-standards/` | Entity/DTO 邊界、MapStruct、靜態工具類、ArchUnit、TestContainers、Code Review 框架、sealed interface 引入時機 |
| 03 資料層 | `ADRs/03-data/` | Schema-as-code、跨服務資料邊界、本地快取策略、Redis Lua、多語言持久化 |
| 04 非同步訊息 | `ADRs/04-messaging/` | Kafka vs Redis pub/sub、Saga 模式、Save-then-Publish、冪等性、分散式排程、Protobuf 演進 |
| 05 基礎設施 | `ADRs/05-infrastructure/` | 服務發現與設定中心、Monorepo/Polyrepo、GitOps、Blue-Green 部署、容器化 |
| 06 API / Web | `ADRs/06-api-web/` | Undertow vs Tomcat、WebSocket session 跨 pod 管理、Stateless Session、Payload 壓縮 |
| 07 安全 | `ADRs/07-security/` | Vault Transit Engine（Token 簽章、Secret 管理）|
| 08 可觀測性 | `ADRs/08-observability/` | 可觀測性後端選型（OTel/Grafana/Loki/Tempo）、可觀測性策略 |

---

## 二、程式設計規範

路徑：`knowledge/common_KBs/guideline/`

| 文件 | 說明 |
|------|------|
| `guideline/REVIEW_GUIDE.md` | Code Review 標準（OOP、SOLID、Clean Code、DDD、效能、設計模式） |
| `guideline/LLM_CODING_GUIDE.md` | AI 輔助編碼行為準則（思考前置、最小修改、Fail Loud、token 預算） |

---

## 三、技術探討與研究筆記

路徑：`knowledge/common_KBs/tech-research/`

記錄技術選型評估、框架深入研究、跨專案可複用的技術發現。
每篇筆記獨立成檔，與 ADR 的差異在於：**非正式決策，而是研究過程與結論**。

索引：[tech-research/index.md](tech-research/index.md)

---

## 四、AI 文件路由規則

| 問題類型 | 優先讀取 |
|---------|---------|
| 架構選型（技術 A vs B） | `ADRs/` 對應分類 |
| 程式設計規範（命名、分層、Review） | `guideline/REVIEW_GUIDE.md` |
| AI 助理行為規範（如何思考、克制、透明） | `guideline/LLM_CODING_GUIDE.md` |
| AI Engineering / Playwright MCP / 原型頁面 → Spec KB 自動化 | `tech-research/playwright-mcp-spec-to-kb-workflow.md` |
| 框架使用細節、技術研究 | `tech-research/` |
| 找不到相關文件 | 回報「通用 KB 尚無對應內容，可考慮建立新筆記」 |

---

## 更新規則

- 每次技術探討有明確結論時，詢問是否寫入 `tech-research/`
- 結論升格為跨服務架構決策時，提議建立對應 ADR（放入 `ADRs/` 對應分類）
- 所有內容須去識別化：不含公司名稱、專案代號、系統名稱
