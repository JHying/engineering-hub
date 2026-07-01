---
date: 2026-06-27
keywords: JVM, Stack, Heap, String Pool, Primitive Type, Reference Type, GC, Singleton, Thread, 記憶體管理, 垃圾回收
---

# JVM 記憶體模型：Stack、Heap、String Pool 與 Singleton

**日期**：2026-06-27  
**關鍵字**：JVM, Stack, Heap, String Constant Pool, Primitive Type, Reference Type, Garbage Collection, Singleton, Thread

## 問題背景

理解 JVM 記憶體分配是 Java 效能調優與物件生命週期管理的基礎。Stack 與 Heap 在 Java 中並非資料結構，而是 JVM 管理記憶體的兩個區域，兩者的分配邏輯、可見範圍與回收機制完全不同。

---

## 研究結論

### 一、Java 資料型態分類

| 分類 | 型態 | 說明 | 存放位置 |
|------|------|------|---------|
| **Primitive Type（基本型態）** | `int`, `short`, `long`, `byte`, `float`, `double`, `boolean`, `char` 共 8 種 | 宣告即有固定長度，生命週期可預知 | **Stack** |
| **Reference/Class Type（參考型態）** | `Integer`, `String`, `Long`，以及自訂類別 | 執行期動態建立，生命週期不可預知 | 實例放 **Heap**，參考位址放 Stack |

---

### 二、Stack（堆疊）

- **每個 Thread 擁有獨立的 Stack**，Thread 間不共享
- 採用 **FILO（後進先出）** 結構
- 存放內容：區域變數、函式參數、函式返回位址
- **生命週期規律**：函式執行完畢，其 Stack Frame 自動被系統回收，程式設計師無須介入
- 存取速度快、管理簡單

```
Thread 1 Stack         Thread 2 Stack
┌──────────────┐       ┌──────────────┐
│ method B()   │       │ method D()   │
│ method A()   │       │ method C()   │
└──────────────┘       └──────────────┘
（各 Thread 獨立，互不干擾）
```

---

### 三、Heap（堆積）

- 屬於 **Process 層級的共享記憶體**，同一 Process 下所有 Thread 都可存取
- 使用 `new` 建立的物件（Class Type Instance）存放於 Heap
- 物件建立流程：
  ```
  User user = new User("Mark");
  // 1. Heap 找一塊空間（如 0x1234），存放 User 實例的屬性資料
  // 2. Stack 中的變數 user 存放此記憶體位址（0x1234）
  // 3. 透過 user 這個「參考」存取 Heap 中的實際物件
  ```
- **GC（Garbage Collection）**：Java 的 GC 機制自動清理 Heap 中「已無任何參考指向」的物件
  - 程式設計師通常不應手動介入 GC，過度介入反而浪費資源

**Stack vs Heap 對比：**

| | Stack | Heap |
|-|-------|------|
| 可見範圍 | 當前 Thread（私有） | 整個 Process（共享） |
| 存放內容 | Primitive 值、Reference 位址、函式資訊 | Class 實例資料 |
| 管理方式 | 系統自動（FILO 規則） | GC 自動回收無參考物件 |
| 速度 | 快 | 相對較慢 |
| 生命週期 | 可預知（函式結束即回收） | 不可預知（GC 決定） |

---

### 四、String 常數池（String Constant Pool）

String 在 Java 中有特殊的記憶體行為：

#### 字面量賦值：`String s = "abc"`

```
1. 查找常數池是否存在 "abc"
2. 不存在 → 在常數池中建立 "abc"，s 引用指向常數池中的物件
3. 已存在 → s 直接引用現有常數池物件（不重複建立）
```

#### new 建立：`String s = new String("abc")`

```
1. 在 Heap 中建立一個新的 String 物件（始終建立）
2. 查找常數池是否存在 "abc"
3. 不存在 → 常數池建立 "abc"，並與 Heap 中物件關聯
4. 已存在 → 直接與常數池已有物件關聯
```

**面試題：`String s = new String("xyz")` 產生幾個物件？**
- 常數池**沒有** "xyz"：產生 **2 個**（Heap 1 個 + 常數池 1 個）
- 常數池**已有** "xyz"：產生 **1 個**（只在 Heap 建立）

#### `==` vs `equals()`

| 運算子 | 比較內容 |
|--------|---------|
| `==` | 比較兩個**引用（記憶體位址）**是否指向同一物件 |
| `equals()` | 比較兩個字串的**值**是否相等 |

```java
String a = "abc";
String b = "abc";
String c = new String("abc");

a == b       // true（同一個常數池物件）
a == c       // false（c 在 Heap，不同位址）
a.equals(c)  // true（值相同）
```

---

### 五、Singleton vs Static Class

| | Singleton（單例） | Static Class（靜態類別） |
|-|----------------|---------------------|
| **本質** | 類別的唯一實例（物件） | 僅含靜態方法與靜態變數的類別 |
| **狀態維護** | 可維護實例狀態 | 無物件狀態（只有類別變數） |
| **記憶體位置** | Heap | Stack（編譯時靜態綁定） |
| **載入時機** | 延遲載入（Lazy Loading）| JVM 載入類別時即載入（Eager） |
| **序列化** | 支援（可透過網路傳輸） | 不支援 |
| **Clone** | 可實作 | 無意義 |
| **執行速度** | 較慢（物件初始化開銷） | 較快（編譯時靜態綁定） |
| **多型** | 支援（OOP） | 不支援 |

**選用時機：**

```
選 Singleton：
  ✓ 需要維護狀態（如 DB Connection Pool、Config Manager）
  ✓ 需要延遲載入大型物件
  ✓ 需要 OOP 特性（繼承、多型）

選 Static Class：
  ✓ 純工具方法，不修改任何內部狀態（如 Math、StringUtils）
  ✓ 不需要多型或物件導向特性
```

> **Spring Bean 最佳實踐**：Spring Bean 預設 scope 即為 Singleton，由 IoC Container 管理唯一實例，並在需要時注入，不需要自行實作 Singleton 模式。

---

## 參考

- 來源：Java 面試考題筆記（Stack/Heap、String Pool、Singleton）
- 參考文章：blog.marklee.tw/java-interview-jvm-stack-heap/、ithelp.ithome.com.tw/articles/10283743
- 相關筆記：[ioc-di-aop-patterns.md](ioc-di-aop-patterns.md)（Spring Bean 與 IoC 容器）、[oop-solid-design-patterns.md](oop-solid-design-patterns.md)（OOP 設計原則）
