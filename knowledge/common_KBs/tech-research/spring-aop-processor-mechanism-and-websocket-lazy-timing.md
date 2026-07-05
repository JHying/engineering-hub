---
date: 2026-07-05
keywords: Spring AOP, BeanPostProcessor, BeanFactoryPostProcessor, JDK Dynamic Proxy, CGLIB, AspectJ, Compile-Time Weaving, Load-Time Weaving, Annotation Processing, Jakarta WebSocket, ServerEndpoint, SpringConfigurator, @Lazy, self-invocation
---

# Spring AOP 代理機制、Processor 體系與 WebSocket @OnOpen 時序陷阱

**日期**：2026-07-05
**關鍵字**：Spring AOP, JDK Dynamic Proxy, CGLIB, BeanPostProcessor, BeanFactoryPostProcessor, AnnotationAwareAspectJAutoProxyCreator, AspectJ, Compile-Time Weaving, Load-Time Weaving, Annotation Processing (APT), Jakarta WebSocket, @ServerEndpoint, SpringConfigurator, @Lazy, self-invocation

## 問題背景

`ioc-di-aop-patterns.md` 已建立 AOP 的基礎概念（Aspect / Pointcut / Advice / Join Point），但停留在「AOP 解決橫切關注點」的設計層次，沒有回答幾個更底層、更容易在實戰中踩坑的問題：

1. Spring AOP 的 advice 到底是「怎麼」被插進方法呼叫路徑的？是編譯期改了 bytecode，還是執行期做了什麼手腳？
2. Spring 框架裡常聽到的「processor」到底有幾種、分別作用在什麼時機？跟 AOP 的關係是什麼？
3. 一個實際踩過的坑：`@ServerEndpoint`（Jakarta WebSocket）搭配 Spring 整合時，`@OnOpen` 內注入的 `@Transactional`/`@Async` service 有時會整個 AOP 失效、且不報錯，改成 `@Lazy` 注入就正常了——原因是什麼？

這篇筆記把「代理是怎麼做出來的」「代理是什麼時候被做出來的」「什麼情境下會在代理做出來『之前』就把 bean 用掉」三件事串起來。

---

## 研究結論

### 一、Spring AOP：代理機制

Spring AOP 是**執行期（runtime）動態代理**，不是編譯期織入（weaving）。容器會依「目標物件是否實作介面」自動選擇兩種代理方式之一：

| 代理方式 | 觸發條件 | 實作原理 |
|---|---|---|
| **JDK Dynamic Proxy** | 目標類別有實作介面時的預設選擇 | 在執行期產生一個實作「同一組介面」的 Proxy class，所有介面方法呼叫都轉發給 `InvocationHandler`，由它決定何時呼叫 advice、何時呼叫原始方法 |
| **CGLIB** | 目標類別沒有實作介面，或設定 `proxyTargetClass=true` 強制指定 | 在執行期產生一個「繼承目標類別」的子類別，覆寫其 public/protected 方法，在覆寫的方法本體中插入 advice 邏輯再呼叫 `super.originalMethod()` |

兩者都是「額外包一層物件」的思路——重點是**額外**：容器裡真正被其他 bean 拿到、注入進去的，是這層包出來的代理物件，不是原始 class 的實例。

#### 共同副作用：self-invocation 問題

不管 JDK Proxy 還是 CGLIB，都只能攔截「從代理物件外部發起」的方法呼叫。類別內部呼叫 `this.otherMethod()` 時，`this` 指向的是**原始物件**本身，呼叫完全不會經過代理，因此掛在 `otherMethod()` 上的 `@Transactional`/`@Async`/`@Cacheable` 等註解會靜靜地失效：

```java
@Service
public class OrderService {

    public void placeOrder() {
        // this 是原始物件，不是代理 —— 以下呼叫不會觸發 @Transactional
        this.saveOrder();
    }

    @Transactional
    public void saveOrder() {
        // ...
    }
}
```

這不是 bug，是 proxy-based AOP 的結構性限制：代理只包在「入口」，物件內部的 `this` 從來沒有機會被換成代理引用。

---

### 二、Spring Processor 機制：執行期與編譯期

「processor」在 Spring 語境裡至少對應兩組完全不同層次的機制，很容易混淆。

#### 執行期：BeanFactoryPostProcessor / BeanPostProcessor

| Processor | 作用時機 | 作用對象 | 代表實作 |
|---|---|---|---|
| **BeanFactoryPostProcessor** | Bean **定義**註冊完成、但尚未被實例化之前 | `BeanDefinition`（描述 bean 的中繼資料，還不是物件） | `ConfigurationClassPostProcessor`：解析 `@Configuration`/`@ComponentScan`/`@Import`，把掃描結果轉成 BeanDefinition |
| **BeanPostProcessor** | 每個 bean **實例化**之後，掛在初始化前後兩個鉤子 | 已建立的 bean 實例 | `postProcessBeforeInitialization` / `postProcessAfterInitialization` |

**關鍵串接點**：Spring AOP 的代理，正是靠一個 `BeanPostProcessor` 做出來的——`AnnotationAwareAspectJAutoProxyCreator`（繼承 `AbstractAutoProxyCreator`）在 `postProcessAfterInitialization` 階段介入：

```
1. Instantiation（建構子建立原始物件）
2. Populate（DI 屬性注入）
3. Initialization
   ├─ @PostConstruct / afterPropertiesSet 執行完畢
   └─ postProcessAfterInitialization
        └─ AnnotationAwareAspectJAutoProxyCreator 檢查是否有切面命中
             ├─ 有命中 → 用 JDK Proxy / CGLIB 包一層代理，回傳代理物件
             └─ 沒命中 → 原樣回傳原始物件
4. 放進 singleton cache 的，是上一步回傳的物件
```

也就是說：屬性注入、`@PostConstruct` 都跑完之後，才輪到 AOP 決定要不要包代理；**放進 singleton cache 的「Spring bean」，如果有切面命中，早就不是原始 class 的實例，而是代理物件**。這個順序是後面 WebSocket 案例問題的根源。

#### 編譯期：兩種容易混淆但完全不同性質的 processor

**1. Java Annotation Processing（APT，JSR 269，`javax.annotation.processing.Processor`）**

在 `javac` 編譯階段執行，用途是**產生額外原始碼**，跟 AOP 沒有關係：
- Lombok：讀取 `@Data`/`@Getter` 等註解，生成 getter/setter/constructor 原始碼
- MapStruct：讀取 mapper 介面定義，生成實作類別
- `spring-boot-configuration-processor`：讀取 `@ConfigurationProperties`，產生 metadata 給 IDE 自動完成用

這一類是純粹的程式碼生成工具，不涉及攔截方法呼叫、不產生代理。

**2. AspectJ 的 Compile-Time Weaving（CTW）/ Load-Time Weaving（LTW）**

這才是跟 AOP 真正相關的編譯期機制，且是跟 Spring AOP **完全不同的實作路線**：

| | Spring AOP（Proxy-based） | AspectJ（Weaving-based） |
|---|---|---|
| 織入時機 | 執行期（runtime） | CTW：編譯期（`ajc` 編譯器）；LTW：class load 時（java agent） |
| 織入方式 | 額外包一層代理物件 | 直接改寫目標類別的 bytecode 本體 |
| 需要介面/繼承 | 需要（JDK Proxy 靠介面，CGLIB 靠繼承） | 不需要，advice 邏輯直接寫進原始類別 |
| self-invocation 問題 | 無法解決 | 可以解決 |

AspectJ 直接把 advice 邏輯**織進目標類別的 bytecode 本體**，不產生任何代理物件——這正是為什麼 AspectJ 織入可以解決 self-invocation 問題，而 Spring 的 proxy-based AOP（不管 JDK Dynamic Proxy 還是 CGLIB）永遠解決不了：self-invocation（`this.otherMethod()`）根本沒有經過代理物件這一層，只有真的改到目標類別本體的 bytecode，才能在「類別內部呼叫自己」這條路徑上也攔得到。

---

### 三、案例：Jakarta WebSocket `@OnOpen` 與 AOP 的時序衝突，以及 `@Lazy` 為何能解決

#### 衝突根因

`@ServerEndpoint` 標註的類別，其實例是由 **WebSocket container**（Tomcat 等 servlet 容器內建的 WS 實作）自己 `new` 出來的，並不走 Spring 的 bean 生命週期。WS container 呼叫的是 `ServerEndpointConfig.Configurator#getEndpointInstance()`，預設實作直接：

```java
endpointClass.getConstructor().newInstance();
```

要讓 `@Autowired` 生效，通常會換成 `SpringConfigurator`，做法是：

```java
Object instance = BeanUtils.instantiateClass(endpointClass);           // 產生一個新的原始物件（WS 端點是 per-connection，本來就不能是 singleton）
context.getAutowireCapableBeanFactory().autowireBean(instance);        // 用 autowireBean() 補齊 @Autowired 欄位
```

問題出在**時機**：WebSocket container 的啟動時機（通常掛在 `ServletContainerInitializer`，servlet context 初始化階段）跟 `Spring ApplicationContext.refresh()` 的完成時機，兩者之間**沒有先後順序保證**。

如果 `SpringConfigurator` 在 Spring 容器 `refresh()` 還沒跑完、`AnnotationAwareAspectJAutoProxyCreator` 這個 `BeanPostProcessor` 都還沒註冊好之前，就呼叫 `autowireBean()` 觸發某個 `@Transactional`/`@Async` service 的提前實例化——這個 bean 會在「AOP 代理創建者還沒生效」的狀態下就被建立並快取進 singleton pool，拿到的會是**沒有被代理包住的原始物件**。

之後全應用程式其他地方注入到的，都是這個已經快取住的原始版本——AOP 全部失效，而且不會報錯，只是靜靜地不生效，非常難抓。

#### 為什麼 `@Lazy` 能解決

`@Lazy` 加在注入點上，Spring 會塞一個**延遲解析代理（lazy-resolution proxy）**進去，不是直接注入目標 bean。這個 lazy proxy 把「真正呼叫 `getBean()` 取得目標」這件事，從「WebSocket container 早期 bootstrap 時」延後到「`@OnOpen`/`@OnMessage` 第一次真的被使用者連線觸發呼叫時」。

而使用者連線進來的時間點，一定是在整個 `ApplicationContext.refresh()` 完全跑完、所有 `BeanPostProcessor`（包含 AOP 的 auto-proxy creator）都已經註冊生效之後——所以 lazy proxy 第一次真正去 `getBean()` 解析目標時，容器狀態已經完整，拿到的必然是正確代理過的版本。

**一句話總結**：`@Lazy` 修的不是「代理型別不對」，而是「bean 被解析的時間點太早」——它把解析時機從 WebSocket container 不受控的 bootstrap 階段，挪到保證安全的「首次實際使用」階段。

---

## 參考

- 相關筆記：[ioc-di-aop-patterns.md](ioc-di-aop-patterns.md)（IoC、DI、AOP 基礎概念，含 Bean 生命週期、Bean Scope、Constructor vs Field 注入的 JMM 差異）——本篇是其延伸：聚焦「AOP 代理具體怎麼實作」與「一個因 Bean 生命週期時序而觸發的實戰陷阱案例」
- 相關筆記：[netty-vs-javax-websocket-performance.md](netty-vs-javax-websocket-performance.md)（Javax/Jakarta WebSocket 與 Netty 的效能比較，同樣涉及 WebSocket container 生命週期）
