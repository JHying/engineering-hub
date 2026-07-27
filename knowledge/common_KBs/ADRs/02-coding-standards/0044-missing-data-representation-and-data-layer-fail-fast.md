---
status: "accepted"
date: "2026-07-27"
decision-makers: "團隊架構慣例"
consulted: "Code Review 實務回饋"
---

# 查無資料的表達方式與資料層 fail-fast：業務缺漏用 Optional、系統缺漏在資料層直接 fail-fast 拋系統例外

## Context and Problem Statement

多層架構（Controller → AppService → DomainService → Manager → Infra）中，一個查詢方法「查不到資料」時該怎麼表達？回 `null`、回 `Optional`、還是拋例外？以及——當「查無」代表的是**系統故障**（必要主檔/設定缺漏）時，這個 fail-fast 應該發生在哪一層？若每一層都只透傳 `Optional`，每個業務層呼叫端都得自己 `orElseThrow` 同一種系統例外，是無意義的重複，且容易漏寫或用錯例外型別。

## Decision Drivers

* 呼叫端不需要靠讀實作、看註解、或試出 NPE 才知道「這裡可能沒東西」與「沒東西代表什麼」
* 業務失敗與系統故障的回應格式、可觀測管道、告警策略都不同，不可混為一談
* 避免同一種 fail-fast 在多個呼叫端重複撰寫（DRY、單一 fail-fast 點）

## Considered Options

* **A. 一律回 `Optional`，由呼叫端各自決定**（含 orElseThrow）
* **B. 依「查無語意」分流**：正常業務缺漏回 `Optional`；系統故障在資料層直接 fail-fast 拋系統例外
* **C. 回 `null`**

## Decision Outcome

**採選項 B。**

1. **查無屬正常業務情境**（使用者可能沒設定、選填欄位/關聯）→ 回 `Optional<T>`，強制呼叫端顯式處理。
2. **查無屬系統故障**（必要主檔/設定不存在、前置條件未滿足）→ **在資料層（Manager / Infra 邊界）直接 fail-fast 拋系統例外**（`NoSuchElementException` / `IllegalStateException`），呼叫端直接拿到值即可，不需各自 `orElseThrow`。
3. **集合類查無** → 回空集合（`List.of()`），不包 `Optional<List<T>>`。
4. **任何情境都不回 `null`**（「查無」與「出錯」混在同一訊號）。

**例外層邊界**：Manager **禁拋業務例外**（業務規則的「使用者請求不合法」歸 DomainService，如自訂 `XxxInvalidException`）；但**可**對「必然的系統故障」fail-fast 拋**系統**例外——`orElseThrow` 系統例外不是「回 null」也不是「業務例外」，不違反 Manager 職責。

**反面辨識（關鍵前提）**：只有當「查無」對**所有呼叫端**都是故障（永遠 fault）時，才在資料層 fail-fast。若不同呼叫端對「查無」有不同處置（有的當正常、有的當故障），代表這不是必然故障 → 該回 `Optional`，讓各 DomainService 自行決定；別為了 DRY 硬把有情境差異的判斷塞進資料層。

```java
// 業務缺漏：回 Optional，呼叫端決定語意
public Optional<XxxVO> findOptionalSetting(String key) { ... }

// 系統故障（必要資料、所有呼叫端一致）：資料層 fail-fast，呼叫端不重複 orElseThrow
public XxxVO getRequiredSetting(String key) {
    return repository.find(key)
        .orElseThrow(() -> new NoSuchElementException("Setting not found: " + key));
}

// 呼叫端分歧：保持 Optional（反面辨識）
//   consumerA：orElseThrow（當故障）；consumerB：orElse(null/default)（當正常）
```

### Consequences

* Good：業務失敗（可讀回應 / 業務失敗統計）與系統故障（通用 5xx / 告警，不進業務統計）清楚分離。
* Good：系統故障的 fail-fast 收斂到單一資料層點，呼叫端不重複、不漏寫、不用錯例外型別。
* Bad / 成本：需逐一判斷每個查詢「查無」的語意（正常 vs 故障、單一 vs 分歧呼叫端），無法純機械套用。
* Neutral：資料層方法簽名會出現「回 `Optional`」與「回具體型別 + 可能拋系統例外」兩種，須靠命名（`findXxx` vs `getRequiredXxx`）與 javadoc 表達。

### Confirmation

由 Code Review 確認（`guideline/REVIEW_GUIDE.md` 2-5「查無資料的表達方式」逐層檢查點與例外型別分型）；`/code-architect` skill 的 Manager Rules 與跨層「查無資料」章節載明「Manager 禁回 null 與業務例外、可 fail-fast 系統例外」；實作階段自審快篩（backend flow）納入「查無資料表達是否明確」一項。目前無 ArchUnit 強制（業務/系統例外分類屬語意判斷）。

## Pros and Cons of the Options

### A. 一律回 Optional

* Good：資料層最單純、呼叫端有最大彈性。
* Bad：必然故障也回 Optional，每個呼叫端重複 orElseThrow、易漏寫或例外型別不一致。

### B. 依語意分流（採用）

* Good：業務/系統分離、fail-fast 收斂單點、簽名即語意。
* Bad：需人工判斷語意，無法機械化。

### C. 回 null

* Bad：查無與出錯同訊號、呼叫端無從被提醒、NPE 風險。

## More Information

- 可執行檢查點版本：`guideline/REVIEW_GUIDE.md` 2-5。
- 何時重新檢視：若引入強型別 Result/Either 慣例，或 ArchUnit 能偵測例外分類時，重新評估。
