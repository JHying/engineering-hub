---
date: 2026-06-27
keywords: POJO, JavaBean, PO, DTO, VO, DAO, BO, 分層架構, 物件轉換, 持久層, 業務層
---

# 企業分層架構物件模式：POJO / DTO / VO / DAO / BO

**日期**：2026-06-27  
**關鍵字**：POJO, JavaBean, PO, DTO, VO, DAO, BO, 分層架構, 物件轉換, 持久層, 業務層

## 問題背景

企業應用分層架構中（Controller → Service → DAO → DB），各層之間傳遞的物件有不同職責與命名慣例，容易混淆。這些概念在 Java 生態最為常見，但分層設計思路適用於多數後端框架。

---

## 研究結論

### 一、物件型態速覽表

| 縮寫 | 全名 | 所在層 | 核心職責 |
|------|------|--------|---------|
| **POJO** | Plain Old Java Object | 通用 | 最基礎的 Java 類，不繼承框架類、不實作框架介面 |
| **JavaBean** | — | 通用 | 遵循規範的可重用組件（無參構造、getter/setter、Serializable） |
| **PO** | Persistent Object | 持久層 | 對應資料庫表的一條記錄，用於 ORM（Hibernate / JPA） |
| **DTO** | Data Transfer Object | 傳輸層 | 跨進程 / 遠程傳輸的數據容器，不含業務邏輯 |
| **VO** | Value/View Object | 業務 / 表示層 | 業務值對象或頁面顯示對象，可為 PO 的子集或多 PO 的組合 |
| **DAO** | Data Access Object | 持久層 | 封裝所有 DB 存取邏輯（CRUD），對業務層提供抽象介面 |
| **BO** | Business Object | 業務層 | 封裝業務邏輯，可包含一個或多個 PO / VO |

---

### 二、各物件詳細說明

#### POJO（Plain Old Java Object）

由 Martin Fowler 等人於 2000 年提出，強調「不被框架侵入的普通類別」。

POJO **不應**：
- 繼承框架基類（如 `HttpServlet`）
- 實作框架介面（如 `EntityBean`）
- 使用框架專屬 annotation（如 `@javax.ejb.Entity`）

**轉化路徑**：
- POJO + 持久化 → **PO**
- POJO + 序列化 / 傳輸 → **DTO**
- POJO + 頁面展示 → **VO**

#### PO（Persistent Object）

- 屬性與資料庫表欄位一一對應
- 不包含資料庫操作邏輯（交給 DAO）
- 一個 PO = 資料庫一條記錄

#### DTO（Data Transfer Object）

- 跨層、跨服務傳輸資料
- 不包含業務邏輯
- 常見用途：API Request/Response、RPC 呼叫

> **為何需要 DTO？** 若 DB 表有 100 個欄位，但 API 只需返回 10 個，直接用 PO 會暴露不必要的資料結構。DTO 隔離了 DB 模型與 API 合約。

#### VO（Value Object / View Object）

- **Value Object**：業務層的業務值物件，根據當前業務邏輯決定屬性
- **View Object**：前端展示所需的物件，可對應頁面結構
- 可以是 PO 的部分、多個 PO 的組合，或與 PO 完全對應

#### DAO（Data Access Object）

- 夾在業務邏輯層與資料庫之間
- 提供 CRUD 介面讓業務層呼叫，不暴露 DB 實作細節
- 透過 DAO 可將 POJO 持久化為 PO，或用 PO 組裝 VO/DTO

#### BO（Business Object）

- 封裝業務邏輯，包含一組相關 PO
- 範例：「履歷 BO」= 教育經歷 PO + 工作經歷 PO + 社會關係 PO
- 通常需轉換為 PO 才能持久化

---

### 三、分層流向示意

```
Client Request
      ↓
Controller（接收 DTO / Request VO）
      ↓
Service（操作 BO，呼叫業務邏輯）
      ↓
DAO（存取 DB，使用 PO 對應表格）
      ↓
Database

回程：PO → BO → DTO → Response VO → Client
```

---

### 四、JavaBean vs EJB

| | JavaBean | EJB (Enterprise JavaBean) |
|-|---------|--------------------------|
| 用途 | 一般可重用組件 | J2EE 企業應用（業務邏輯、ORM） |
| 規範 | 無參構造、getter/setter、Serializable | 需繼承特定介面，有 Session/Entity/MessageDriven Bean |
| 現況 | 廣泛使用 | 已基本被 Spring 取代 |

---

## 參考

- 來源：Notion 開發學習筆記 — 後端開發(Java) > Java - 物件型態說明
