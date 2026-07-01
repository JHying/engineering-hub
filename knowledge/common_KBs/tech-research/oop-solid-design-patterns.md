---
date: 2026-06-27
keywords: OOP, SOLID, Design Pattern, Strategy, Clean Code, 封裝, 繼承, 多型, 低耦合, 高內聚
---

# OOP、SOLID 原則與設計模式概覽

**日期**：2026-06-27
**關鍵字**：OOP, 封裝, 繼承, 多型, SOLID, SRP, OCP, LSP, ISP, DIP, Strategy Pattern, Clean Code

## 問題背景

良好的物件導向設計需要遵循一套原則，避免程式碼耦合度過高、難以維護和擴展。SOLID 是最廣泛接受的 OOP 設計原則，設計模式則是針對常見問題的可複用解法。

---

## 研究結論

### 一、程式設計大原則

**目標三高：**

| 目標 | 說明 |
|------|------|
| **高可擴充性** | 新需求不需大幅修改原有程式碼 |
| **高維護性** | 新需求不影響其他功能的既有行為 |
| **高複用性** | 避免重複程式碼（DRY 原則） |

**設計準則：**
- **低耦合**：不同功能不互相依賴
- **抽象介面概念化**：保持簡單，不要寫太死
- **使用者單一原則**：類別職責清晰，不混用
- **Coding Style 統一**：團隊一致性

---

### 二、OOP 三大特性

#### 封裝（Encapsulation）

將屬性和方法包裝起來，外部無法直接存取內部細節。

```java
public class BankAccount {
    private double balance;  // private 封裝

    public double getBalance() { return balance; }
    public void deposit(double amount) { balance += amount; }
}
```

存取修飾詞：`public`（全開放）→ `protected`（子類別）→ `private`（僅本類別）

#### 繼承（Inheritance）

子類別繼承父類別的屬性和方法（除 private）。

- **Override（覆載）**：子類別改寫父類別同名方法
- **Overload（多載）**：同名方法但參數不同

```java
class Animal { void speak() { ... } }
class Dog extends Animal {
    @Override
    void speak() { System.out.println("Woof"); }
}
```

#### 多型（Polymorphism）

子類別可以有自己的方式實現父類別的功能。

```java
Animal a = new Dog();
a.speak();  // 呼叫 Dog 的 speak()，而非 Animal 的
```

---

### 三、SOLID 五大原則

#### S — Single Responsibility Principle（單一職責）

> 一個類別只負責一件事

```python
# 違反 SRP：ShoppingCart 同時處理邏輯和列印
class ShoppingCart:
    def add_item(self, item): ...
    def print_receipt(self): ...  # 應分離到 ReceiptPrinter

# 符合 SRP
class ShoppingCart:
    def add_item(self, item): ...

class ReceiptPrinter:
    def print(self, cart): ...
```

#### O — Open/Closed Principle（開放/封閉原則）

> 對擴充開放，對修改封閉

新增功能應繼承擴展，不修改現有程式碼。

```python
class Discount:
    def calculate(self, price): return price

class TenPercentDiscount(Discount):
    def calculate(self, price): return price * 0.9

class BlackFridayDiscount(Discount):
    def calculate(self, price): return price * 0.5
```

#### L — Liskov Substitution Principle（Liskov 替換）

> 子類別必須能替代父類別使用，不破壞程式正確性

子類別不應縮減父類別的功能，只能擴充。

#### I — Interface Segregation Principle（介面隔離）

> 把不相關的功能從介面中分離

```java
// 違反 ISP：不是所有機器都有 fax
interface Machine { void print(); void fax(); void scan(); }

// 符合 ISP
interface Printer { void print(); }
interface Scanner { void scan(); }
interface FaxMachine { void fax(); }
```

#### D — Dependency Inversion Principle（依賴反轉）

> 高階模組不依賴低階模組，兩者都依賴抽象

```java
// 違反：高階直接依賴低階具體類別
class OrderService {
    MySQLDB db = new MySQLDB();  // 綁定具體實作
}

// 符合：依賴介面
interface Database { void save(Order o); }
class OrderService {
    Database db;
    OrderService(Database db) { this.db = db; }  // 注入
}
```

---

### 四、Strategy Pattern（策略模式）

**目的**：將可互換的演算法封裝，讓行為可在執行期動態替換。

**三個元件：**
- **Context（環境類別）**：使用策略的物件
- **Strategy（策略介面）**：定義演算法介面
- **Concrete Strategy（具體策略）**：各種實作

```java
interface AttackStrategy {
    void attack(String target);
}

class NormalAttack implements AttackStrategy {
    public void attack(String target) { System.out.println("普通攻擊 " + target); }
}

class HeavyAttack implements AttackStrategy {
    public void attack(String target) { System.out.println("重擊 " + target); }
}

class Adventurer {
    private AttackStrategy strategy;

    public void setStrategy(AttackStrategy strategy) {
        this.strategy = strategy;  // 動態替換策略
    }

    public void attack(String target) { strategy.attack(target); }
}
```

| | 簡單工廠 | 策略模式 |
|-|---------|---------|
| 關注點 | 產生物件 | 策略本身 |
| 動態替換 | 否 | 是 |
| 符合 OCP | 否 | 是 |

---

### 五、Clean Code 實踐原則

> **閱讀程式碼 vs 撰寫程式碼 ≈ 10:1**

技術債的惡性循環：雜亂程式 → 維護前花時間理解 → 修改又花更多時間 → 再也無法更新

#### 命名原則

- 名稱代表意圖（避免縮寫和無意義單字）
- 布林值用 `is` / `has` 開頭：`isActive`, `hasPermission`
- 取值用 `get`，設值用 `set`
- 名稱能被搜尋（不用單字母變數）

#### 函式原則

- **一個函式只做一件事**（Single Responsibility）
- **降層原則**：由上而下閱讀，像在說故事
- 判斷函式是否只做一件事：能否從中再提取出新函式？若能，代表它做超過一件事

#### 程式碼健康標準

- 能通過所有測試
- 無重複程式碼（DRY）
- 隨時隨地保持整潔（童子軍規則：讓離開時比到達時更整潔）

---

## 參考

- 來源：Notion 開發學習筆記 — Design Pattern > 大原則 / OOP / SOLID / Strategy Pattern / Clean Code
