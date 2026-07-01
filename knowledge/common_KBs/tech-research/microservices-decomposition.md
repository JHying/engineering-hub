---
date: 2026-06-27
keywords: 微服務, 拆分原則, DDD, 限界上下文, 康威定律, Gateway Pattern, 12-Factor, Strangler Pattern, Spring Cloud, Eureka, Hystrix, Feign, 服務治理, 挑戰
---

# 微服務架構：拆分原則與聚合模式

**日期**：2026-06-27
**關鍵字**：微服務, DDD, Bounded Context, 康威定律, Gateway Pattern, Edge Pattern, 12-Factor, Strangler Pattern

## 問題背景

從單體系統切換到微服務，或初期設計微服務時，最困難的決策是「服務如何拆分」。拆太細維護成本高，拆太粗失去獨立擴展的好處。

---

## 研究結論

### 一、服務拆分五大原則

#### 1. 單一職責（Single Responsibility）

每個服務只完成自己職責範圍的任務，不越界處理其他服務的邏輯。

#### 2. 粒度先粗後細

初期服務粒度拆粗一些，隨著團隊對業務和微服務理解加深，再逐步細化，避免過早過度拆分。

#### 3. 不影響日常迭代

拆分過程應平行於功能迭代，採用 **Strangler Pattern（扼殺者模式）**：逐步從單體中把功能切出來，不影響現有功能。

#### 4. API 參數封裝類設計

服務間以 HTTP/gRPC 通訊，API 參數應使用封裝物件（DTO），方便日後新增欄位而不破壞介面相容性。

#### 5. 服務自治

每個服務是獨立業務單元，不互相依賴。可參考：
- **Domain-based**：依領域拆分
- **Business process-based**：依業務流程拆分
- **Atomic transaction-based**：依事務邊界拆分

---

### 二、拆分依據

**推薦以「業務功能」為核心拆分**，而非以「資料類型」或「技術層」拆分。

| 拆分方式 | 優點 | 缺點 |
|---------|------|------|
| 依業務功能 | 高內聚、低耦合，易獨立擴展 | 各服務需遵守共用契約 |
| 依資料類型 | 邏輯隔離清楚 | 重複業務邏輯、維護複雜 |

**參考方法論：**
- **DDD 限界上下文（Bounded Context）**：以領域邊界劃分服務範圍
- **康威定律（Conway's Law）**：系統設計反映組織溝通結構，拆分時考量團隊配置

---

### 三、常見服務清單（通用業務功能）

| 服務 | 職責 |
|------|------|
| Account Service | 帳號、錢包管理 |
| Auth Service | 登入/登出、Token 簽發驗證 |
| Config Service | 系統設定、參數管理 |
| Betting / Transaction Service | 核心交易行為 |
| Settlement / Calculate Service | 結算、派彩 |
| Report Service | 統計報表 |
| Notification Service | 推播、Email 通知 |
| Log Service | 日誌（ELK） |
| Risk Analytic Service | 風險分析 |

---

### 四、Gateway 聚合模式

#### Gateway Pattern（基本）

提供統一入口給 Client，路由到各服務。

#### Process Aggregator Pattern

將共用邏輯（驗證、權限）整合在 Gateway，避免各服務重複實作。

#### Edge Pattern（最常用）

針對不同 Client 建置不同的聚合服務（Edge Service）。

```
Mobile Client → Mobile Edge Service → [Services...]
Web Client   → Web Edge Service    → [Services...]
```

- **優點**：針對性擴展，不影響整體 Gateway
- **缺點**：維護多個 Edge Service

---

### 五、Sidecar Pattern

透過可重複使用的 Sidecar 模組（如 Istio Envoy）處理跨切面需求（Log、Auth、Monitor），降低服務間重複程式碼。

---

### 六、十二要素應用程式（12-Factor App）

雲端原生微服務的設計準則：

| 因素 | 說明 |
|------|------|
| 1. 程式碼庫 | 一個 Repo，多次部署 |
| 2. 依賴關係 | 明確聲明並隔離依賴 |
| 3. 配置 | 配置存在環境變數，不硬寫在程式碼 |
| 4. 支援服務 | 把 DB / MQ 視為附加資源 |
| 5. 建置/發布/運行 | 嚴格分離三階段 |
| 6. 無狀態進程 | 應用作為無狀態進程執行 |
| 7. 連接埠綁定 | 服務透過 Port 對外暴露 |
| 8. 並發 | 透過進程模型水平擴展 |
| 9. 可處置性 | 快速啟動、優雅關閉 |
| 10. 開發/生產一致 | Dev / Staging / Prod 環境盡量相同 |
| 11. 日誌 | 視日誌為事件流，不管理日誌檔案 |
| 12. 管理流程 | 管理任務（migration）作為一次性進程 |

---

### 七、微服務的挑戰與潛在缺點

採用微服務架構前需評估以下風險：

| 挑戰 | 說明 |
|------|------|
| **資料完整性** | 各服務各自維護持久化資料，跨服務的資料一致性難以保證 |
| **跨服務關聯管理** | 在不同服務間建立關聯紀錄（如 join 查詢）非常困難 |
| **版本控制** | 服務更新不得打斷依賴它的其他服務，API 向後相容要求高 |
| **技能門檻** | 微服務是高度分散式系統，團隊需有容錯、分散式事務等經驗才能成功落地 |
| **重複工作** | 多服務共用相同功能但不值得獨立成服務 → 各自實作造成重複代碼；若獨立成 Library 則跨語言不適用 |
| **介面調整成本** | 若多個服務依賴同一介面，單一介面變更需同步調整所有消費方 |

---

### 八、微服務所需技術能力

| 技術能力 | 說明 |
|---------|------|
| **負載均衡 / Gateway 路由** | 高可用叢集部署、請求轉發、驗證、服務整合 |
| **服務治理** | 服務註冊（Registration）與發現（Discovery），讓服務間能動態找到彼此 |
| **容錯** | 熔斷器（Circuit Breaker）等機制，防止單一服務故障引發雪崩效應 |
| **監控與追蹤** | 資源利用率、服務響應時間、容器資源監控（Metrics + Tracing） |
| **訊息匯流排** | 訊息佇列（Message Queue）+ 非同步通訊，解耦服務間直接呼叫 |
| **配置管理** | 集中式配置中心，統一管理各服務的環境設定 |
| **自動化部署** | CI/CD Pipeline 全自動構建、測試、部署 |

---

### 九、Spring Cloud 技術棧

**Spring Cloud** 是目前最主流的 Java 微服務框架生態，並非單一技術，而是集合多個開源項目的技術棧：

```
Spring Cloud（技術棧總稱）
  ├─ Eureka          → 服務註冊與發現（Service Registry）
  ├─ Hystrix         → 熔斷器（Circuit Breaker），防止雪崩
  ├─ Feign           → 宣告式 HTTP Client，簡化服務間呼叫
  ├─ Ribbon          → 客戶端負載均衡
  ├─ Zuul / Gateway  → API Gateway，路由、過濾、限流
  ├─ Config Server   → 集中式配置管理
  └─ Sleuth + Zipkin → 分散式追蹤（Distributed Tracing）
```

| 元件 | 對應「技術能力」 |
|------|---------------|
| Eureka | 服務治理（Service Discovery） |
| Hystrix | 容錯（Circuit Breaker） |
| Feign + Ribbon | 服務間通訊 + 負載均衡 |
| Zuul / Spring Cloud Gateway | Gateway 路由 |
| Config Server | 配置管理 |
| Sleuth + Zipkin | 監控與追蹤 |

> Spring Cloud 各元件與「八大技術能力需求」一一對應，可作為選型 checklist 使用。

---

## 參考

- 來源：Notion 開發學習筆記 — 架構框架 > 微服務架構、Spring Cloud 第 242-243 頁
- 參考文章：rickbsr.medium.com（網站架構演進）
- [12factor.net](https://12factor.net/)
- 相關筆記：[message-broker-comparison.md](message-broker-comparison.md)（訊息匯流排選型）、[gcp-kubernetes-devops.md](gcp-kubernetes-devops.md)（K8s + Istio Service Mesh）
