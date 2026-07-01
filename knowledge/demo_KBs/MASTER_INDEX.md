# 【DEMO】訂單平台 — 系統總覽 & Knowledge Base Index
version: demo

> ⚠️ 此為示範用知識庫，說明各目錄的用途與文件格式。
> 建立新專案 KB 時，複製此資料夾並以實際專案內容取代所有 `【DEMO】` 標記。

---

## 系統定位

這是一個**多服務訂單處理平台**，核心功能為商品下單、付款驗證與狀態通知。

---

## 系統技術棧

| 分類 | 技術 |
|------|------|
| 應用框架 | Spring Boot 3.x、Spring Cloud |
| 設定中心 | （依專案填寫，例如：Consul / Apollo） |
| 持久層 | Spring Data JPA、Oracle / PostgreSQL |
| 快取 | Redis |
| 訊息佇列 | Apache Kafka |
| 服務間 RPC | gRPC / REST（依服務填寫） |
| 容器 / 部署 | Docker、Kubernetes、ArgoCD |
| 可觀測性 | Grafana + OTEL + Prometheus + Loki |
| CI/CD | GitOps + Jenkins + Harbor |

---

## RD Knowledge Base（source-codex）

> 根目錄：`source-codex/`
> 涵蓋範圍：微服務清單、服務間通訊、Cross-Service Resources、AI 文件路由規則。

### 微服務清單

| 服務 | 職責 |
|------|------|
| **order-service** | 核心服務。接收下單請求、庫存鎖定、管理訂單生命週期（PENDING → PAID → SHIPPED → DONE） |
| **payment-service** | 付款流程核心。消費 order-created、呼叫第三方 Gateway、管理付款狀態機（INITIATED → SUCCESS / FAILED），發布 payment-result |
| **notification-service** | 訂單通知。消費 payment-result，依使用者偏好透過 Email / SMS 發送通知；Provider 熔斷降級 |
| **api-gateway** | 統一入口，路由與認證過濾 |

---

### 服務間通訊

```
前端 (HTTP)
       ↓
  api-gateway
       ↓
  order-service ──Kafka (order-created)──► payment-service
                                                 │
                                          Kafka (payment-result)
                                                 ↓
                                        notification-service
```

- **REST**：外部請求進入 api-gateway → order-service
- **Kafka**：`order-created`（order → payment）、`payment-result`（payment → notification）
- **Redis**：訂單狀態熱快取（TTL = 30m）

---

### Services（文件索引）

文件根目錄：`source-codex/services/`

### order-service
- 職責：接收下單、驗證庫存、管理訂單狀態機（PENDING → PAID → SHIPPED → DONE）
- 技術：Spring Boot 3.x, JPA（Oracle）, Kafka producer, Redis
- 溝通：REST inbound（api-gateway）/ Kafka outbound（order-created）/ Redis 讀寫
- 文件：
  - `source-codex/services/order-service/index.md`（wiki entry，含摘要、資料結構、業務邏輯）
  - `source-codex/services/order-service/facts.md`（機械抽取業務邏輯事實）
  - `source-codex/services/order-service/meta.yml`（服務 metadata）

---

### Cross-Service Resources（跨服務資源索引）

- `source-codex/cross/index.md`（索引總覽）
- `source-codex/cross/service-map.md`（各服務 sync 狀態、路徑）

---

### AI 文件路由規則

| Story 關鍵字 | 讀取文件（依序） |
|---|---|
| 下單 / 訂單 / 狀態機 | `source-codex/services/order-service/index.md` → `facts.md` |
| 付款 / 金流 / payment | `source-codex/services/payment-service/index.md` → `facts.md` |
| 通知 / Email / SMS / push | `source-codex/services/notification-service/index.md` → `facts.md` |
| 路由 / 認證 / gateway | `source-codex/services/api-gateway/index.md` → `facts.md` |

跨多 service 的 Story → 各自對應文件全部讀取，再整合產出。

---

## Architecture Decision Records（ADRs）

> 根目錄：`ADRs/`
> 入口索引：`ADRs/index.md`

涵蓋本專案重要架構決策，主題包含：

| 主題分類 | 相關 ADR |
|---------|---------|
| 服務間通訊 | 0001 |
| （依實際狀況補充） | ... |

---

## SRE Knowledge Base

SRE 知識庫路由索引：`site-reliability/index.md`

| 文件 | 說明 |
|------|------|
| `site-reliability/environments.md` | 環境清單（dev / test / staging / prod）、部署架構 |
| `site-reliability/cicd-pipeline.md` | Jenkins CI/CD 流程、Branch → 環境對應、Shared Libs |
| `site-reliability/deployment-strategy.md` | Blue-Green / Canary / Mirror / Rollback 操作 |
| `site-reliability/alert-metrics.md` | 告警指標、AlertManager 配置、上線觀察清單 |
| `site-reliability/sop-db-migration.md` | DB Migration SOP（BREAKING 判斷、TestContainers 整合）|
| `site-reliability/sop-kafka.md` | Kafka topic 異動、Consumer Lag、DLQ 管理 |
| `site-reliability/operations-boundary.md` | SRE 職責邊界、On-call 規則、緊急聯絡分工 |

---

## Review History（code-review 記錄）

> 根目錄：`review-history/`
> 入口索引：`review-history/index.md`
> 說明：每次 Code Review 後的結構化記錄（品質問題、效能問題、設計模式建議、修改清單、相關 ADR）。
> 命名規則：`{YYYY-MM-DD}-{ticket-or-topic}-{service}.md`
> 模板檔：`review-history/YYYY-MM-DD-TICKET-service-name.md`（複製後改名使用）

| 日期 | Ticket / 主題 | 服務 | 模式 | 檔案 |
|------|-------------|------|------|------|
| （尚無）| | | | |

---

## pending/ 目錄說明

AI 待整理清單，新內容進 KB 前先放此處。

| 子目錄 | 說明 |
|--------|------|
| `pending/jira.txt` | 等待整理成 spec 的 ticket 清單 |
| `pending/logs/` | KB 更新紀錄 |

---

## PM Knowledge Base（specs）

> 根目錄：`specs/`
> 入口：`specs/README.md`

| 文件類型 | 路徑格式 | 說明 |
|---------|---------|------|
| Spec 格式規範 | `specs/spec-format.md` | 撰寫 spec 的標準格式 |
| Impl 格式規範 | `specs/impls/impls-format.md` | 撰寫 impl 的標準格式 |
| Spec（需求） | `specs/{TICKET}.md` | 各 ticket 初始需求（要做什麼） |
| Impl（實作） | `specs/impls/{TICKET}-impls.md` | 各 ticket 實作知識（做了什麼，實作後建立） |

### 已建立 Spec

| Ticket | 標題 | 檔案 |
|--------|------|------|
| DEMO-001 | 訂單建立功能 | `specs/DEMO-001.md` |
| DEMO-002 | 採購申請驗證（多步驟驗證 + 批次核准） | `specs/DEMO-002.md` |

### 已建立 Impl

| Ticket | 說明 | 檔案 |
|--------|------|------|
| DEMO-001 | 訂單建立 | `specs/impls/DEMO-001-impls.md` |
| DEMO-002 | 採購申請多步驟驗證 + 批次核准（Playwright MCP workflow 示範） | `specs/impls/DEMO-002-impls.md` |
