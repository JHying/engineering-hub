---
date: 2026-06-27
keywords: ORM, JPA, Hibernate, Spring Data JPA, Entity, Repository, CrudRepository, 物件關聯對映, 持久層
---

# ORM、JPA 與 Spring Data JPA：持久層技術棧

**日期**：2026-06-27  
**關鍵字**：ORM, JPA, Hibernate, Spring Data JPA, Entity, Repository, CrudRepository, 持久層, 物件關聯對映

## 問題背景

直接撰寫 SQL 與資料庫溝通有以下問題：SQL 散落在程式碼各處難以維護、不同資料庫方言不兼容、手動映射 ResultSet 到物件繁瑣且容易出錯。ORM 透過物件與資料表的映射關係，讓開發者用物件導向方式操作資料庫，解決上述問題。

---

## 研究結論

### 一、ORM（Object Relational Mapping，物件關聯對映）

**定位**：位於「資料庫」與「Model 物件」之間的中介層。

```
應用程式程式碼（Java / Python / Ruby 物件）
          ↕  自動轉換
        ORM 框架
          ↕  SQL 查詢
        關聯式資料庫（MySQL / PostgreSQL / Oracle）
```

**核心能力：**
- 用程式語言語法操作資料庫，不需手寫 SQL
- 自動將物件屬性映射到資料表欄位
- 防止 SQL Injection（參數化查詢）
- 跨資料庫方言兼容（切換資料庫只需改設定）

---

### 二、JPA（Java Persistence API）

**定位**：Java 官方 ORM **規範**（不是實作），定義了 ORM 的標準介面與 Annotation。

**常用 Annotation：**

| Annotation | 說明 |
|-----------|------|
| `@Entity` | 宣告此類別對應資料庫的一張表 |
| `@Table(name = "...")` | 指定對應的表名（預設用類別名） |
| `@Id` | 標記主鍵欄位 |
| `@GeneratedValue` | 設定主鍵自動生成策略（AUTO / IDENTITY / SEQUENCE） |
| `@Column(name = "...")` | 對應欄位名稱與約束 |
| `@Transient` | 標記不需持久化的屬性（不對應欄位） |
| `@OneToMany` / `@ManyToOne` | 關聯關係映射 |

**Entity 範例：**

```java
import javax.persistence.*;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_name", nullable = false)
    private String name;

    @Transient
    private String tempToken;  // 不儲存到資料庫

    // getters / setters
}
```

---

### 三、Hibernate

**定位**：最主流的 JPA **實作（Provider）**，也可以單獨使用（不透過 JPA 規範）。

**JPA Provider 選項：**

| Provider | 說明 |
|---------|------|
| **Hibernate** | 最廣泛使用，功能最豐富 |
| **EclipseLink** | JPA 參考實作（Reference Implementation） |
| **OpenJPA** | Apache 開源實作 |

**Hibernate 核心功能：**
- 將 Java 物件轉換成資料庫表格資料（Object → Row）
- 將資料庫表格資料轉換成 Java 物件（Row → Object）
- 提供 HQL（Hibernate Query Language）作為物件導向查詢語言
- 一階快取（Session 級）與二階快取（應用程式級）

---

### 四、Spring Data JPA

**定位**：Spring 在 JPA 規範（底層 Hibernate）之上再封裝的應用框架，進一步簡化持久層程式碼。

**技術棧層次：**

```
Spring Data JPA（Spring 封裝層）
     ↓ 使用
JPA 規範（javax.persistence）
     ↓ 實作
Hibernate（JPA Provider）
     ↓ 操作
資料庫
```

#### Repository 介面繼承體系

```
Repository（頂層介面，標記用）
  └─ CrudRepository（提供 CRUD 基本方法）
       └─ PagingAndSortingRepository（新增分頁 + 排序）
            └─ JpaRepository（新增 JPA 特定方法，最常用）
```

| 介面 | 新增功能 |
|------|---------|
| `Repository` | 標記介面，無方法 |
| `CrudRepository` | `save()`, `findById()`, `findAll()`, `delete()`, `count()` |
| `PagingAndSortingRepository` | `findAll(Pageable)`, `findAll(Sort)` |
| `JpaRepository` | `flush()`, `saveAndFlush()`, `deleteInBatch()`, `getOne()` |

**使用方式：**

```java
// 繼承 JpaRepository，自動獲得 CRUD + 分頁 + 批次操作
public interface UserRepository extends JpaRepository<User, Long> {

    // 方法名稱命名查詢（Spring Data 自動生成 SQL）
    List<User> findByName(String name);
    List<User> findByNameAndStatus(String name, String status);

    // 自訂 JPQL 查詢
    @Query("SELECT u FROM User u WHERE u.name = :name")
    List<User> searchByName(@Param("name") String name);
}
```

**與傳統 JDBC / 純 JPA 的差異：**

| 方式 | 程式碼量 | 彈性 | 推薦場景 |
|------|---------|------|---------|
| 純 JDBC | 最多 | 最高 | 複雜 SQL、效能調優 |
| 純 JPA（EntityManager） | 中 | 高 | 需要精細控制 |
| Spring Data JPA | 最少 | 中（可搭配 @Query） | 一般 CRUD 業務 |

---

## 參考

- 來源：Notion 開發學習筆記 — Java Spring 基礎概念
- 相關筆記：[ioc-di-aop-patterns.md](ioc-di-aop-patterns.md)（IoC / DI / AOP）、[enterprise-object-layer-patterns.md](enterprise-object-layer-patterns.md)（PO / DTO / VO / DAO 分層）
