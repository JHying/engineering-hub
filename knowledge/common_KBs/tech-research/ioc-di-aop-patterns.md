---
date: 2026-06-27
keywords: IoC, DI, AOP, Inversion of Control, Dependency Injection, Aspect-Oriented Programming, Bean, Bean Lifecycle, Bean Scope, 控制反轉, 依賴注入, 切面, Singleton, Prototype
---

# IoC、DI 與 AOP：框架核心設計概念

**日期**：2026-06-27  
**關鍵字**：IoC, DI, AOP, Inversion of Control, Dependency Injection, Bean, 控制反轉, 依賴注入, Aspect, Pointcut

## 問題背景

傳統物件導向程式使用 `new` 直接建立依賴物件，導致類別間高度耦合，難以測試與替換。IoC / DI 解決物件建立與依賴管理問題；AOP 則解決橫切關注點（logging、transaction、security）散落各處的問題。這三者是主流框架（Spring、Angular、NestJS、.NET）的設計基礎。

---

## 研究結論

### 一、IoC（Inversion of Control，控制反轉）

**定義**：將「建立物件的控制權」從呼叫方轉移給第三方容器（IoC Container）。

**問題根源：**

```java
// 傳統寫法：OrderService 直接 new 依賴 → 高耦合
class OrderService {
    private PaymentService payment = new PaymentService();  // 綁死具體實作
}
```

**IoC 解法：**

```java
// IoC：由容器管理 PaymentService 的生命週期，OrderService 不主動建立
class OrderService {
    private PaymentService payment;  // 由容器注入，不知道也不管具體實作
}
```

**IoC Container 的職責：**
1. 掃描並建立所有宣告的物件（Bean）
2. 管理物件的生命週期（Singleton / Prototype）
3. 在需要時將物件注入到指定位置

**四大優點：**

| 優點 | 說明 |
|------|------|
| **鬆散耦合** | 物件不依賴具體實作，容易替換 |
| **可測試性** | 可輕鬆 Mock 依賴，利於單元測試與整合測試 |
| **模組化** | 鼓勵將應用拆分為獨立模組，透過容器組合 |
| **配置分離** | 依賴關係透過設定檔或 annotation 管理，可在不改程式碼的情況下調整行為 |

---

### 二、DI（Dependency Injection，依賴注入）

**定義**：DI 是 IoC 概念的具體實作方式，由容器在執行期間動態地將依賴物件「注入」到需要的地方。

**三種注入方式：**

```java
// 1. 建構子注入（推薦：明確依賴、易於測試）
@Service
class OrderService {
    private final PaymentService payment;

    @Autowired
    OrderService(PaymentService payment) {
        this.payment = payment;
    }
}

// 2. Setter 注入（可選依賴時使用）
@Service
class OrderService {
    private PaymentService payment;

    @Autowired
    public void setPayment(PaymentService payment) {
        this.payment = payment;
    }
}

// 3. Field 注入（簡潔但不推薦：難以測試、隱藏依賴）
@Service
class OrderService {
    @Autowired
    private PaymentService payment;
}
```

**IoC vs DI 的關係：**

```
IoC（概念）
  └─ DI（實作方式之一）
       ├─ 建構子注入
       ├─ Setter 注入
       └─ Field 注入
```

> IoC 也可以透過 Service Locator 模式實作，DI 是更推薦的方式。

---

### 三、AOP（Aspect-Oriented Programming，切面導向程式設計）

**定義**：將應用程式中橫跨多個模組的「橫切關注點」（cross-cutting concerns）抽取出來，模組化為獨立的切面，不污染業務邏輯。

**常見橫切關注點：**
- Logging（每個方法都要記錄執行日誌）
- Transaction 管理（每個 DB 操作都需要 begin/commit/rollback）
- Security 驗證（每個 API 都需要身份驗證）
- 效能監控（每個方法的執行時間）

#### AOP 四大核心概念

| 概念 | 英文 | 說明 |
|------|------|------|
| **切面** | Aspect | 定義「何處」和「何時」應用橫切邏輯，包含通知 + 切點 |
| **通知** | Advice | 切面中的具體操作，定義「執行什麼」 |
| **切點** | Pointcut | 表達式，定義「在哪些方法/類上」應用通知 |
| **連接點** | Join Point | 程式執行中可插入通知的實際位置（如方法呼叫、例外拋出） |

#### 通知（Advice）類型

| 類型 | 說明 | 範例 |
|------|------|------|
| **Before（前置）** | 方法執行前 | 驗證輸入、記錄開始 |
| **After（後置）** | 方法執行後（無論成功或失敗） | 釋放資源 |
| **AfterReturning** | 方法成功返回後 | 記錄回傳值 |
| **AfterThrowing** | 方法拋出例外後 | 記錄錯誤 |
| **Around（環繞）** | 包圍方法執行前後 | 效能計時、事務管理 |

#### AOP 範例：效能監控

```java
@Aspect
@Component
public class PerformanceAspect {

    @Around("execution(* com.example.service.*.*(..))")  // 切點：所有 service 方法
    public Object measureTime(ProceedingJoinPoint joinPoint) throws Throwable {
        long start = System.currentTimeMillis();

        Object result = joinPoint.proceed();  // 執行原始方法

        long elapsed = System.currentTimeMillis() - start;
        System.out.println(joinPoint.getSignature() + " 耗時 " + elapsed + "ms");

        return result;
    }
}
```

---

### 四、Bean 生命週期（Bean Lifecycle）

Spring IoC 容器管理的物件稱為 **Bean**，完整生命週期如下：

```
1. Instantiation（實例化）
   └─ 容器呼叫建構子，為 Bean 分配記憶體空間

2. Populate（屬性賦值）
   └─ 透過 Setter 方法注入依賴（DI 在此階段執行）

3. Initialization（初始化）
   ├─ 執行 @PostConstruct 標記的方法（前置初始化）
   ├─ 執行自定義 initMethod
   └─ 執行初始化後回調（如 BeanPostProcessor）

4. In Use（使用中）
   └─ Bean 執行業務邏輯，與其他 Bean 協作

5. Destruction（銷毀）
   ├─ 應用程式關閉時觸發
   ├─ 執行 @PreDestroy 標記的方法
   └─ 釋放資源（關閉連線、釋放檔案等）
```

**對應方法：**

| 生命週期階段 | 對應方法/Annotation |
|------------|-------------------|
| Instantiation | 建構子 Constructor |
| Populate | Getter / Setter（DI 注入） |
| Initialization | `initMethod`、`@PostConstruct` |
| Destruction | `destroyMethod`、`@PreDestroy` |

---

### 五、Bean Scope（作用域）

| Scope | 說明 | 適用情境 |
|-------|------|---------|
| **Singleton**（預設） | 容器只建立一個實例，全應用共享 | 無狀態服務（Service、Repository） |
| **Prototype** | 每次請求 Bean 時建立新實例 | 有狀態、每次需獨立的物件 |
| **Request** | 每個 HTTP Request 建立一個新實例 | Web 應用：Request 層級資料 |
| **Session** | 每個 HTTP Session 建立一個新實例 | Web 應用：Session 層級資料（購物車） |
| **Global Session** | 全局 Session 範圍（分散式 Web / 集群） | Portal 應用的全局 Session |
| **Application** | 整個 Web 應用程式共享一個實例 | 應用層級全局配置 |
| **WebSocket** | WebSocket 連線範圍內共享 | WebSocket 應用 |

> **Singleton vs Prototype 選擇原則：**
> - 無狀態（Stateless）Bean → Singleton（效能好，預設值）
> - 有狀態（Stateful）Bean → Prototype（每次獨立，避免狀態污染）

---

### 六、三者關係

```
IoC（概念）
  └─ 容器管理物件生命週期與依賴
       ├─ DI（實作）：注入物件依賴
       └─ AOP（延伸）：注入橫切行為
```

| | IoC | DI | AOP |
|-|-----|-----|-----|
| 解決的問題 | 物件建立的控制權 | 物件依賴的注入方式 | 橫切關注點的模組化 |
| 層面 | 概念 / 設計原則 | IoC 的實作 | 獨立的程式設計範式 |
| 關鍵詞 | Container, Bean | @Autowired, @Inject | @Aspect, Pointcut, Advice |

---

### 七、Constructor 注入 vs Field 注入：JVM 記憶體模型差異

#### 最終 Heap 佈局相同

不管哪種注入方式，Singleton bean 的物件實例都活在 heap，注入的 field 都是 heap 裡 object 的一部分，存的是指向另一個 bean 的 reference。

#### 建構過程的短暫差異

```
Constructor 注入：
  stack frame → 參數 payment, inventory（暫存在 stack）
              → 賦值給 this.payment, this.inventory（寫入 heap）
  constructor 結束 → stack frame 彈出

Field 注入：
  Spring 用 reflection → field.set(object, value)
  直接寫入 heap，沒有經過 constructor 參數的 stack
```

#### final field 的 Java Memory Model（JMM）保證

Constructor 注入允許宣告 `final`，而 Field 注入不允許：

```java
// Constructor 注入：可宣告 final
private final PaymentService payment;

// Field 注入：不能宣告 final（Spring 在 constructor 後才注入）
@Autowired
private PaymentService payment;  // ✗ 無法加 final
```

Java Memory Model 對 `final` field 有特殊的 **happens-before** 保證：
- Constructor 完成後，所有 thread 看到的 `final` field 值一定是初始化後的值
- 不需要額外的同步（`synchronized` / `volatile`）
- Field 注入因為是 constructor 之後才由 Spring 反射寫入，沒有這個 JMM 保證

#### 比較表

| | Field 注入 | Constructor 注入 |
|---|---|---|
| 最終 heap 佈局 | 相同 | 相同 |
| 能宣告 final | ✗ | ✓ |
| JMM final happens-before 保證 | ✗ | ✓ |
| 注入路徑 | reflection 直寫 heap | stack 參數 → heap field |
| 多執行緒可見性風險 | 理論上存在（Singleton 共享）| 無（final 保證） |

> **實務補充**：Singleton bean 通常在應用啟動階段完成注入，多執行緒可見性問題在實務上不常踩到，但 Constructor 注入的 `final` 語意仍是更嚴謹的設計。

---

## 參考

- 來源：Notion 開發學習筆記 — Spring 相關概念
- 相關筆記：[oop-solid-design-patterns.md](oop-solid-design-patterns.md)（OOP 三大特性、SOLID 五大原則）
