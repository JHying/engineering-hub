---
date: 2026-06-27
keywords: Java, Thread, Process, Concurrency, Parallelism, Thread Safety, synchronized, Collections, ConcurrentHashMap, Thread Pool, ExecutorService, Executor, IO-bound, CPU-bound
---

# Java 併發與執行緒安全：Thread、Thread Pool 與 Executor 體系

**日期**：2026-06-27  
**關鍵字**：Thread, Process, Concurrency, Parallelism, Thread Safety, synchronized, java.util.concurrent, Thread Pool, Executor, ExecutorService

## 問題背景

多執行緒程式設計讓同一個應用程式能同時處理多個任務（IO 等待、CPU 密集運算、排程），但引入執行緒間的資料共享問題。Java 提供多層工具：`synchronized` 關鍵字、`Collections.synchronizedXXX()`、`java.util.concurrent` 套件，以及 Executor / Thread Pool 框架。

---

## 研究結論

### 一、Thread vs Process

| | Thread（執行緒） | Process（進程） |
|-|--------------|---------------|
| **定址空間** | 同一個 Process 的 Address Space（共享記憶體） | 各自獨立的 Address Space |
| **隔離性** | 低（共享 Heap） | 高（完全隔離） |
| **溝通成本** | 低（直接共享物件） | 高（需 IPC：Socket / Pipe / 共享記憶體） |
| **重量** | 輕量（Lightweight Process） | 重量 |
| **建立開銷** | 較小 | 較大 |

> Thread 允許在同一個 Address Space 中撰寫 **Concurrency（併發）** 與 **Parallelism（並行）** 程式。

---

### 二、多執行緒使用時機

| 時機 | 說明 | 典型場景 |
|------|------|---------|
| **IO-bound Task** | 等待 IO 時不阻塞主執行緒，允許其他任務繼續 | 同時讀多個檔案、大量 Socket 連線 |
| **CPU-bound Task** | 利用多核 CPU，單執行緒只能用一個 Core | 影像處理、大量計算 |
| **非同步執行** | 開新 Thread 執行耗時任務，完成後回傳結果給主程式 | 背景上傳、API 呼叫 |
| **排程（Scheduling）** | delay（N 秒後執行）、週期性（每 N 秒）、指定時間點 | 定時備份、清理任務（底層用 `Timer` 或 `ScheduledThreadPoolExecutor`） |
| **Daemon / Service** | 專門等待事件，持續監聽 | Server 監聽 Port、Message Queue Consumer |

---

### 三、執行緒安全（Thread Safety）

Java 容器（`ArrayList`, `HashMap` 等）**預設不是 Thread-safe**，多執行緒同時存取可能導致資料損毀。

#### 方法 1：手動 synchronized 區塊

```java
// 鎖住對特定物件的操作
synchronized(arrayList) {
    arrayList.add(new SomeClass());
}
```

#### 方法 2：Collections.synchronizedXXX()

```java
// 傳回一個同步化的 List 包裝器
List list = Collections.synchronizedList(new ArrayList());
```

> **注意**：`synchronizedList` 的 `iterator()` 返回的 Iterator **並不保證 Thread-safe**，遍訪時仍須手動同步：

```java
List list = Collections.synchronizedList(new ArrayList());

synchronized(list) {           // 必須在 synchronized 內使用 Iterator
    Iterator i = list.iterator();
    while (i.hasNext()) {
        foo(i.next());
    }
}
```

#### 方法 3：java.util.concurrent 套件（推薦，Java 5+）

`java.util.concurrent` 提供高效能的 Thread-safe 集合，依各自特性選擇最佳同步實作：

| 類別 | 對應傳統容器 | 同步特性 |
|------|------------|---------|
| `ConcurrentHashMap` | `HashMap` | 分段鎖（Segment Lock），高並發讀寫效能優異 |
| `CopyOnWriteArrayList` | `ArrayList` | 寫時複製，讀多寫少場景最佳 |
| `CopyOnWriteArraySet` | `HashSet` | 同 CopyOnWriteArrayList，Set 版本 |

```java
// 直接使用，無需額外同步
ConcurrentHashMap<String, Integer> map = new ConcurrentHashMap<>();
CopyOnWriteArrayList<String> list = new CopyOnWriteArrayList<>();
```

---

### 四、Thread Pool（執行緒池）

#### 為何需要 Thread Pool？

| 問題 | Thread Pool 解法 |
|------|----------------|
| 執行緒建立 / 銷毀開銷大 | 執行緒重複利用，降低系統資源消耗 |
| 執行緒數量過多導致 Context Switch 開銷大 | 設定最大執行緒數上限，避免 CPU 效率下降 |
| 執行緒難以管理（放任野跑） | 統一管理生命週期與結果收集 |

#### 核心概念

Thread Pool 的核心邏輯是**生產者-消費者模式（Producer-Consumer）**：

```
提交任務（生產者）
    ↓
Task Queue（有界佇列，控制最大等待量）
    ↓
Thread Pool（固定數量的 Worker Thread，消費者）
    ↓
執行結果回傳
```

> **類比**：與 DB Connection Pool 概念相同——預先建立固定數量的連線（執行緒），任務排隊等待可用的執行緒，完成後執行緒回歸 Pool 供下一個任務使用。

#### Semaphore 概念

在框架介面設計時，可借助 **Semaphore（信號量）** 概念——釋出（release）與索取（acquire）許可，控制同時進入臨界區的執行緒數量。

---

### 五、Executor 類家族體系

```
Executor（介面）
  └─ ExecutorService（介面）
       └─ AbstractExecutorService（抽象類）
            ├─ ThreadPoolExecutor（主要實作，可直接使用）
            │    └─ ScheduledThreadPoolExecutor（支援延遲 / 週期排程）
            └─ ForkJoinPool（Fork/Join 框架，大任務分解）
```

| 類 / 介面 | 說明 |
|---------|------|
| **`Executor`** | 頂層介面，只定義 `execute(Runnable command)` 一個方法 |
| **`ExecutorService`** | 繼承 Executor，新增完整 Thread Pool 操作：`submit()`, `shutdown()`, `invokeAll()`, `Future` 結果取得 |
| **`ThreadPoolExecutor`** | 原生執行緒池實作，可自訂 corePoolSize / maxPoolSize / Queue 類型 |
| **`ScheduledThreadPoolExecutor`** | 支援 delay（延遲執行）、scheduleAtFixedRate（固定週期）、scheduleWithFixedDelay（固定延遲間隔） |

**核心設計原則**：Executor 框架將 **Task（任務）** 與 **Thread（執行）** 解耦——任務只管描述「要做什麼」，執行緒池負責「何時 / 用哪個執行緒做」。

```java
// 建立固定大小的 Thread Pool
ExecutorService executor = Executors.newFixedThreadPool(4);

// 提交任務（不阻塞）
Future<String> future = executor.submit(() -> {
    // 耗時任務
    return "result";
});

// 取得結果（此處會等待任務完成）
String result = future.get();

executor.shutdown();  // 不再接受新任務，等現有任務完成
```

---

### 六、synchronized 鎖定範圍詳解

`synchronized` 的鎖定對象決定了互斥範圍：

```java
// 1. 鎖定任意物件
synchronized(myResource) {
    // myResource 被鎖定期間，其他想 lock 同一物件的 thread 會等待
}

// 2. 同步化 Instance Method → 等同 synchronized(this)
public synchronized void myMethod() { ... }
// 等同於：
public void myMethod() {
    synchronized(this) { ... }
}

// 3. 同步化 Static Method → 等同 synchronized(MyClass.class)
public static synchronized void myStaticMethod() { ... }
// 等同於：
public static void myStaticMethod() {
    synchronized(MyClass.class) { ... }
}
```

> `synchronized(this)` 鎖定的是 **實例物件**；`synchronized(MyClass.class)` 鎖定的是 **Class 本身**（全域），兩者互不干擾。

---

### 七、Deadlock（死結）

當 Thread A 持有 Lock-A 並等待 Lock-B，同時 Thread B 持有 Lock-B 並等待 Lock-A，雙方互等 → **Deadlock**。

```
Thread 1: lock A → 等待 B
Thread 2: lock B → 等待 A  ← 互相等待，永遠卡住
```

**預防原則：**
1. **統一取鎖順序**：所有 Thread 一律以「先取 A 再取 B」的順序，不允許反向
2. **減少鎖的粒度**：思考是否真的需要分別鎖 A 和 B，若能統一取一個鎖，Deadlock 風險歸零

---

### 八、Race Condition（競態條件）

Race Condition 發生在沒有正確保護共享資源的情況下：

```java
// 有問題的程式碼：i++ 在 JVM 是「讀取 → 遞增 → 寫回」三步，非原子操作
public class MyClass {
    private int i;
    public int getAndIncr() {
        return i++;
    }
}

// 兩個 Thread 同時呼叫時可能發生：
// Thread 1: get value = 100
// Thread 2: get value = 100  ← 讀到同一個值
// Thread 2: incr + set = 101
// Thread 1: incr + set = 101  ← 應為 102，結果遺失了一次遞增
```

**解法：加 synchronized**

```java
public synchronized int getAndIncr() {
    return i++;
}
```

> 或使用 `java.util.concurrent.atomic.AtomicInteger`，提供 `getAndIncrement()` 原子操作，效能優於 `synchronized`。

---

### 九、Thread Safe 的設計取捨

**定義**：一個 class / method 在 multi-thread 環境下不會發生 Race Condition，即為 Thread-safe。

| 特性 | 說明 |
|------|------|
| 使用者可放心多 Thread 呼叫 | 不需要在外部再加 `synchronized` |
| 有效能代價 | `synchronized` 本身有 overhead，在 single-thread 環境下是浪費 |
| 非強制責任 | 讓 Library 使用者決定 `synchronized` 的顆粒度，往往更靈活 |

**Java Collection Library 的策略**：預設不是 Thread-safe，需要時透過包裝器升級：

```java
Collection syncedCol = Collections.synchronizedCollection(myCol);
List      syncedList = Collections.synchronizedList(myList);
Set       syncedSet  = Collections.synchronizedSet(mySet);
Map       syncedMap  = Collections.synchronizedMap(myMap);
```

---

### 十、Immutable Object（不可變物件）

Immutable 是另一種避免 Resource Sharing 問題的策略：**只要物件不可被修改，任意多個 Thread 同時讀取都不需要鎖**。

| | Mutable（可變）| Immutable（不可變）|
|-|--------------|-----------------|
| 共享需要 | 加 synchronized | 無需鎖 |
| 修改方式 | 直接改原物件 | 產生新物件（以產生取代修改） |
| 並行效能 | 受鎖限制 | 最大化並行度 |

**Java 經典範例：String**

```java
String str = "hello";
String newStr = str + " world";
// str 與 newStr 是兩個完全獨立的物件
// str 本身從未被修改
```

> 其他常見 Immutable 類別：`Integer`, `Long` 等包裝類別（Wrapper classes）、`LocalDate`、`BigDecimal`。

---

### 十一、Flow Control：wait / notify

Thread 間除了資料共享，還需要**流程同步**（協作順序）。Java 提供最底層的 `Object#wait()` 與 `Object#notify()`：

- `wait()`：呼叫的 Thread 暫停執行，釋放持有的鎖，等待被 notify
- `notify()`：喚醒一個正在 wait 此物件的 Thread

```java
public class FlowControl {
    private final Object lock = new Object();
    private String message = null;

    public void produce(String msg) {
        synchronized(lock) {
            this.message = msg;
            lock.notify();          // 喚醒等待中的 consumer
        }
    }

    public void consume() throws InterruptedException {
        synchronized(lock) {
            lock.wait();            // 釋放 lock，暫停等待
            System.out.println("consumed: " + message);
        }
    }
}
```

> `wait()` / `notify()` 是幾乎所有 Java 流程控制機制（`BlockingQueue`, `CountDownLatch`, `Semaphore`）的底層實作基礎。

---

### 十二、Thread.join()（Fork / Join 模式）

**Fork**：將工作發包給新 Thread 開始執行  
**Join**：等待另一個 Thread 完成，再繼續當前 Thread 的後續流程

```java
Thread worker = new Thread(() -> {
    System.out.println("worker start");
    Thread.sleep(1000);
    System.out.println("worker complete");
});

worker.start();                    // Fork：發包給 worker
System.out.println("master wait");
worker.join();                     // Join：main thread 在此等待 worker 結束
System.out.println("master complete");

// 執行順序：
// master wait → worker start → worker complete → master complete
```

---

### 十三、Message Passing 與 Pipeline 模式

**Message Passing**：一個 Thread 將資料傳遞給另一個 Thread 處理的高階概念。

**Pipeline（生產線）模式**：

```
Thread A（Producer）
    ↓  放入 message
  Queue（管道 / Pipe）← 解耦 Producer 與 Consumer，處理速率差異
    ↓  取出 message
Thread B（Consumer）
    ↓
Thread C（Consumer）
```

- **Queue 的角色**：生產與消費速率不同時，Queue 作為緩衝
- **Queue 滿**：Producer 被 blocked，直到有空位
- **Queue 空**：Consumer 被 blocked，直到有新 message

> `java.util.concurrent.BlockingQueue` 是實作 Message Passing 最常用的工具，`LinkedBlockingQueue`（無界）與 `ArrayBlockingQueue`（有界）最常見。

---

## 參考

- 來源：Notion 開發學習筆記 — Java 多執行緒
- 參考文章：popcornylu.gitbooks.io/java_multithread/、hackmd.io/@no4sms04/H10xNAs7q、hackmd.io/@KaiChen/HyJwzDqxu
- 相關筆記：[jvm-memory-model.md](jvm-memory-model.md)（Stack / Heap / Thread 可見範圍）、[high-concurrency-design.md](high-concurrency-design.md)（高併發設計：鎖機制、分散式鎖）
