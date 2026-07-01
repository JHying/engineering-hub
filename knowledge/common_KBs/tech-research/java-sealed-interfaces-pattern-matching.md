# Java Sealed Interfaces 與 Pattern Matching

**日期**：2026-06-29
**關鍵字**：Sealed Interface, Pattern Matching, switch expression, JDK 17, JDK 21, 多態回傳型別, 窮舉性

---

## 問題背景

當方法回傳「固定幾種可能結果」時（例如：成功 / 逾時 / 失敗），常見的建模方式有幾種：

| 方式 | 例子 | 問題 |
|------|------|------|
| boolean flag | `isSuccess`, `isTimeout` | 多個 flag 組合爆炸；無法強制「只能是其中一種」 |
| enum | `ResultStatus.SUCCESS` | 無法隨狀態帶不同 payload（成功帶資料、失敗帶錯誤碼） |
| Exception as control flow | 逾時 throw `TimeoutException` | 例外不應用於正常業務流程的分支 |
| Class hierarchy（開放） | `abstract Result` + 子類 | 無法保證窮舉；外部可以任意繼承 |
| **Sealed Interface**（封閉） | `sealed interface Result permits Success, Timeout, Failure` | 編譯器強制所有分支被處理，且類別層次封閉 |

---

## Sealed Interface 核心語法（JDK 17+）

```java
// 宣告封閉介面，只允許三個子類型
sealed interface BatchResult permits Success, Timeout, Failure {}

record Success(List<Long> ids) implements BatchResult {}
record Timeout(Duration elapsed) implements BatchResult {}
record Failure(String errorCode, String message) implements BatchResult {}
```

搭配 JDK 21 Pattern Matching for switch：

```java
String describe(BatchResult result) {
    return switch (result) {
        case Success s  -> "成功處理 " + s.ids().size() + " 筆";
        case Timeout t  -> "逾時（" + t.elapsed().toSeconds() + "s）";
        case Failure f  -> "失敗：" + f.errorCode();
        // 不需要 default — 編譯器已確認窮舉
    };
}
```

若漏寫任何一個 `permits` 子類型的分支，**編譯直接失敗**，不會是執行期 NPE 或 else 吃掉的靜默 bug。

---

## 與 enum 的比較

| 面向 | enum | sealed interface |
|------|------|-----------------|
| 每個狀態帶不同 payload | 不便（需要 field + 判斷） | 天然支援（record per state） |
| 編譯期窮舉 | JDK 21 `switch` 支援 | JDK 21 `switch` 支援 |
| 外部可繼承 / 擴展 | 不可繼承 | 封閉（`sealed` 限定 `permits`） |
| 狀態集固定程度 | enum 也難以中途增刪 | sealed 同樣是「封閉合約」 |
| 測試框架支援 | JUnit 4/5 均可 | JUnit 4 斷言不直覺；JUnit 5 + 型別推斷較自然 |

**結論：** enum 在狀態無額外 payload 時仍是首選；sealed interface 優勢在「每個狀態帶不同結構資料 + 需要編譯期窮舉」。

---

## 引入條件 Checklist

根據 [ADR-0043](../ADRs/02-coding-standards/0043-sealed-interface-adoption-conditions.md)，滿足以下三點才引入：

- [ ] 測試框架已升級至 **JUnit 5**（JUnit 4 的窮舉斷言需繁瑣 workaround）
- [ ] 團隊完成 sealed interface + pattern matching 的內部分享，reviewer 能有效把關
- [ ] **目標狀態集已穩定** — 連續兩個 sprint 無新增 / 拆分狀態的需求

條件未滿足時，維持用 `enum` 或 result wrapper class 建模即可。

---

## 常見誤用

**1. 狀態集不穩定就封閉**

```java
// ❌ 業務還在討論是否要加 Partial 狀態，就已 sealed
sealed interface OrderResult permits Approved, Rejected {}
// 之後加 PartialApproved → 所有 switch 都要改
```

**2. 把 Exception 包進 sealed 型別替代 Result**

```java
// ❌ 混淆「例外流程」與「正常業務分支」
sealed interface Result permits Success, BusinessException {}
// BusinessException 是 Exception → 應 throw，不應作為正常 return value
```

**3. 只有兩個狀態時引入**

```java
// ❌ 只有 Found / NotFound → Optional<T> 語意更清楚
sealed interface LookupResult permits Found, NotFound {}
```

**4. 在 JUnit 4 環境寫窮舉測試**

```java
// ❌ JUnit 4 沒有 instanceOf 型別推斷，需要強制轉型 + if-else
assertTrue(result instanceof Success);
assertEquals(3, ((Success) result).ids().size()); // 冗長且脆弱
```

---

## 研究結論

Sealed interface + pattern matching 是 JDK 21 對多態建模最完整的解答：**封閉合約 + 編譯期窮舉 + 每個狀態帶獨立 payload**。但引入時機比語法本身更重要：

- 狀態不穩定 → 封閉帶來的是維護負擔，不是安全感
- 團隊不熟悉 → reviewer 無法在 PR 中有效把關窮舉性
- JUnit 4 → 測試程式碼可讀性反而下降

引入時以**新功能邊界**為切入點，不建議 retrofit 既有的 enum 體系。

---

## 參考

- [JEP 409 — Sealed Classes（JDK 17）](https://openjdk.org/jeps/409)
- [JEP 441 — Pattern Matching for switch（JDK 21）](https://openjdk.org/jeps/441)
- [ADR-0043 — Defer sealed interfaces for multi-state return types](../ADRs/02-coding-standards/0043-sealed-interface-adoption-conditions.md)
