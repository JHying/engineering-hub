---
date: 2026-07-03
keywords: Spring Boot, JSP, Servlet, Quartz, log4j2, Spring Data JPA, 分層架構重構, SpringBootServletInitializer, Connection Pool, Transactional
---

# JSP/Servlet + Quartz + 傳統 JDBC Web 應用遷移至 Spring Boot

**日期**：2026-07-03
**關鍵字**：Spring Boot, JSP, Servlet, Quartz, log4j2, Spring Data JPA, 分層架構重構, SpringBootServletInitializer, Connection Pool, Transactional

## 問題背景

許多維運多年的 Web 應用仍停留在「JSP + Servlet + Quartz + 傳統 JDBC」的架構：Servlet 直接用 `getParameter()` 收參數、手動組 Connection 做 CRUD、用 jGenerator 手刻 JSON、Quartz 用原生 `quartz.properties` 排程。這類架構的痛點：
- Servlet 一個類別身兼「驗證、業務邏輯、DB 存取、組 JSON」多重職責，難以測試與重用
- DTO 同時承擔「DB 物件」與「邏輯物件」兩種角色，職責不清
- 沒有依賴注入，物件多為手動 `new` 或靜態方法呼叫

本篇記錄將這類應用遷移到 Spring Boot + Spring Data JPA 的步驟，並附上遷移前後的分層架構對比與 Servlet 重構的 9 步驟流程。本篇的應用**有 Web 層**（Servlet/Controller 接外部請求）。

---

## 遷移步驟

### 一、目標分層架構對比

#### 現行架構：Servlet / DTO / BO / DAO（四層）

```
Servlet ←→ DTO ←→ BO ←→ DAO
  ↑                        │
  └────────────────────────┘
```

| 層 | 職責 |
|----|------|
| **Servlet** | 驗證資料、業務邏輯、request（`getParameter`）、response（jGenerator 組 JSON） |
| **DTO** | DB 物件、邏輯物件、Cache、組 JSON（jGenerator）、業務邏輯 |
| **BO** | 建 connection、業務邏輯、組 JSON（jGenerator）、組 DTO |
| **DAO** | CRUD、組 DTO、組 JSON（jGenerator）、業務邏輯 |

**問題**：四層之間的職責高度重疊——DTO、BO、DAO 都在「組 JSON」與「業務邏輯」，DTO 同時是 DB 物件又是邏輯物件，導致改動一處要追蹤多層。

#### 新版架構：Controller / Service BO / DTO / BO / DAO / Entity（六層）

```
Controller ←→ Service BO      DTO ┄┄ BO ←→ DAO ┄┄ Entity
```

| 層 | 職責 |
|----|------|
| **Controller** | `@RequestBody`（json → dto）、`@ResponseBody`（json response）、系統流程 |
| **Service BO** | 業務邏輯、驗證資料 |
| **DTO** | 邏輯物件、Cache |
| **BO** | 組 DTO、其他邏輯／物件運算 |
| **DAO** | CRUD、Spring repository |
| **Entity** | DB ORM 對映（取代原本 DAO 手動組的 DB 物件） |

**改善重點**：
- Controller 只做「收請求、綁物件、回應」，不碰業務邏輯
- 業務邏輯集中到 Service BO，可單元測試
- DTO 與 Entity 分離：DTO 是邏輯層的物件，Entity 才是 DB 對映（ORM），避免 DTO 職責混雜
- DAO 全面改用 Spring Data JPA Repository，不再手動組 SQL / 組 DTO

---

### 二、Servlet 重構流程說明（9 步驟）

實際重構一支 Servlet 時，依下列順序處理，避免一次性大改導致難以驗證：

1. **DAO**：CRUD 以外的邏輯移到 BO（DAO 只留資料存取）
2. **Servlet**：request 進來先綁定物件，不要分散寫多次 `getParameter()`
3. **Servlet**：response 改用 DTO 轉 JSON，讓回應格式明確（取代手刻 jGenerator）
4. **Servlet**：邏輯移到 Service BO（先不拆分細節，變數改丟 request DTO 傳遞）
5. **DTO**：套用介面隔離原則
   - a. 按照應用場景拆分不同物件（從名稱可大致了解用途）
   - b. interface 慎用 `default` 方法
   - c. DTO 盡量單純（POJO 概念，getter/setter 用 Lombok 註解）
6. **Service / BO**：依單一職責原則細拆方法
7. **Service / BO**：建立 interface（介面隔離原則）
8. **工廠模式**：不同業務類型改用工廠模式實例化對應的 BO，移除重複邏輯
9. **其他 JGenerator**：改成「組 DTO → 轉 JSON」的統一模式，不再手刻 JSON 字串

#### Interface 與 Abstract 使用時機

| 情境 | 選用 |
|------|------|
| 多個子類有**相同的實作方法及屬性**，只有部分邏輯不同 | **Abstract class**：共用邏輯寫在父類，不同的部分定義為 abstract method 由子類實作 |
| 子類之間**只共享方法簽名**，實作完全不同 | **Interface**：僅定義方法，由子類各自實作 |

> 兩者都能搭配 Factory Pattern 使用：Factory 依條件（如業務類型）決定要 `new` 出哪個子類實例，呼叫端只依賴 Interface / Abstract 型別，不關心具體子類。

---

### 三、專案骨架搬遷步驟

1. **建立新的 Spring Boot 專案骨架**：沿用原本的 `pom.xml`，額外加入 Spring Boot 與 Spring Data JPA 的依賴
2. **依新專案結構搬遷舊檔案**：
   - `properties` 移到 `src/main/resources`
   - 靜態資源與頁面移到 `src/main/webapp`
   - 業務獨立的資料夾（如排程 job、util、connection manager 等）整包搬移
3. **原生 Quartz 改用 `spring-boot-starter-quartz`**，以支援註解與 Spring 化的 properties 管理
4. 其餘 `properties` 內容與原本設定大同小異，先保留不動，等骨架搭好後再逐步重構

---

### 四、JSP 相容性設定

Spring Boot 預設**不支援 JSP**（內建的 embedded servlet container 假設回傳 JSON/模板引擎），需額外設定：

1. Application 類別繼承 `SpringBootServletInitializer`（支援 war 包裝與 JSP 解析）：

```java
@SpringBootApplication
public class WebApplication extends SpringBootServletInitializer {
    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(WebApplication.class);
    }
}
```

2. `context.xml` → `application-web.properties`：原本容器層級的設定（如 JSP servlet mapping、welcome file）改寫成 Spring Boot 的 web 相關 properties

> 所有宣告為 Spring Bean 的物件，預設都是 **singleton instance**——這也是為什麼原本的 static instance（如 Manager 類別）要改用 Spring Bean 宣告，才能透過依賴注入運用，而不是繼續用靜態欄位持有單例。

**checklist**：
- [ ] `SpringBootServletInitializer` 已繼承，war 包裝可正常啟動
- [ ] `context.xml` 內容已對應搬到 `application-web.properties`
- [ ] 原本用 static instance 持有的單例物件，已改為 `@Component` + 建構子注入

---

### 五、Quartz 遷移

1. 依賴改用 `spring-boot-starter-quartz`
2. 原本的 `quartz.properties` 改名為 `application-quartz.properties`
   - Spring Boot 只會自動讀取以 `application-` 開頭的設定檔
3. 在主設定檔 `application.properties` 加入對應的 include/引用設定，讓 `application-quartz.properties` 被載入
4. Job 內部邏輯基本不用大改，排程觸發機制改用 Spring 管理的 Scheduler Bean

**checklist**：
- [ ] `quartz.properties` 已更名為 `application-quartz.properties` 並被主設定檔引用
- [ ] Job 類別可由 Spring 注入依賴（不再需要自行 `new` DAO / Service）
- [ ] 排程觸發驗證：至少一個 Job 在新架構下能準時觸發並執行

---

### 六、log4j2 遷移

沿用原生 log4j2 設定，改用 `spring-boot-starter-log4j2` 依賴：
- 排除 Spring Boot 預設的 logback（見無 Web 層服務遷移筆記的 pom.xml 設定，作法相同）
- `log4j2.xml` 的 appender / logger 設定可直接沿用，路徑改放到 `src/main/resources`

---

### 七、分層重構：Controller → Service BO → Repo

1. **修改 Servlet → Spring Controller 風格**：`doGet`/`doPost` 改為 `@GetMapping`/`@PostMapping`，`request.getParameter()` 改為 `@RequestBody` 綁定 DTO
2. **修改 JDBC style → Spring Data JPA style**：手動組 SQL 的 DAO 改為繼承 `JpaRepository` 的 interface
3. **DTO → Entity 分工**：原本「資料表物件」直接用 DTO 承擔，改用 ORM Entity 對映資料表，DTO 只負責跨層傳輸
4. **重構 Controller / BO / Repo**：
   - 業務邏輯方法都移到 BO（Service 層）
   - 資料庫操作全部移到 Repo（Repository 層）
   - Controller 保持薄——只做參數綁定、呼叫 Service BO、包裝回應

---

### 八、DB 連線層設定對照表

| 原生架構 | Spring Boot 架構 |
|---------|------------------|
| 自行管理的 DB Connection Pool | Tomcat JDBC Connection Pool（`spring-boot-starter-jdbc` 內建） |
| 全域連線池設定散落在程式碼 | 統一寫在 `application-db.properties` |
| 手動管理多個 DB 節點 | Spring 多 `DataSource` Bean（帳密等敏感設定從加密檔讀取，作法與無 Web 層服務遷移筆記一致） |
| 自建 DB Monitor（輪詢比對時間、可用性） | DB Health Check（可用原生 Monitor 邏輯，或改接 Spring Boot Actuator health indicator） |
| 手動 `conn.rollback()` / `conn.commit()` | `@Transactional` 宣告式事務 |
| Oracle DB 手動建 Entity/DTO 對照 | Entity 可用工具從既有資料表自動產生（auto generated），再手動調整型別與關聯 |

**checklist**：
- [ ] Connection Pool 設定已全部集中到 `application-db.properties`
- [ ] 多 DataSource 場景已比照無 Web 層服務遷移筆記的 `@Primary` / `@Qualifier` 規則設定
- [ ] DB Health Check 機制已驗證（斷線後能偵測並記錄）
- [ ] 原本手動 commit/rollback 的程式碼已全部改為 `@Transactional`，且事務邊界涵蓋原本手動控制的範圍
- [ ] Entity 欄位型別、複合鍵、關聯（`@OneToMany` 等）已與原資料表結構核對一致

---

## 參考

- 相關筆記：[enterprise-object-layer-patterns.md](enterprise-object-layer-patterns.md)（POJO / DTO / VO / DAO / BO 分層定義）、[orm-jpa-spring-data.md](orm-jpa-spring-data.md)（JPA / Spring Data 基礎）、[oop-solid-design-patterns.md](oop-solid-design-patterns.md)（SOLID 原則、Strategy Pattern）
