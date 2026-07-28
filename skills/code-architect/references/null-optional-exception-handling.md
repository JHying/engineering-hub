## 查無資料的表達方式（null / Optional / 例外）— 跨層規則

> **適用所有層**，不限 Infra。審查每一個對外提供查詢的方法時都要跑這一節。
> 核心原則：**不要讓呼叫端猜**。方法簽名必須讓「這裡可能沒有東西」與「沒有東西代表什麼」都是型別系統或例外型別可見的事實。

### 三種表達方式的選擇

| 情境 | 正確表達 | 理由 |
|------|---------|------|
| 查無資料屬**正常業務情境**（使用者可能沒設定、可選欄位、選填關聯） | `Optional<T>` | 呼叫端被強制顯式處理 |
| 查無資料屬**系統異常**（設定檔缺漏、必要主檔不存在、前置條件未滿足） | 拋例外 | 這不是「沒有」，是「壞了」。回 `Optional` 會誘導呼叫端寫防禦性 fallback，把故障掩蓋成正常流程 |
| 集合類查無 | 空集合（`List.of()` / `Set.of()`） | 空集合本身即完整語意，包 `Optional<List<T>>` 只是多一層無意義解包 |
| **任何情境** | ❌ `null` | 「查無」與「出錯」混在同一訊號，呼叫端無從區分也無從被提醒 |

### 逐層檢查點

| 層 | 檢查什麼 |
|----|---------|
| Infra（`*Repository` / `*Client` / `*RedisClient`） | 查詢方法回傳型別；是否有 `return null;` 或未包裝的可空表達式 |
| Manager | **是否把 Infra 回傳的 `Optional` 拆成 `null` 再往上丟**——這是最常見的違規，等於抵銷 Infra 層的規則。禁的是回 `null` 與拋業務例外；「必要資料查無」的必然系統故障可 `orElseThrow` 系統例外 fail-fast，非只能透傳 Optional |
| Domain Service | 對外查詢方法；「查無 → 拋例外」時的例外型別是否選對（見下方分型） |
| **Utils（靜態查表）** | `Map.get()` / `HELPER.get()` 的結果是否直接 return——**不在 Infra 層卻同樣回 null，最常被漏掉** |
| Mapper | source 為 null 時的輸出行為是否明確 |

### 違規範例

```java
// ❌ Infra 回 null
public FooEntity findById(String id) {
    return mongoTemplate.findById(id, FooEntity.class);   // may be null
}
// ✅
public Optional<FooEntity> findById(String id) {
    return Optional.ofNullable(mongoTemplate.findById(id, FooEntity.class));
}

// ❌ Manager 把 Optional 拆掉再往上丟 null——白做
public Map<String, Integer> getSettings(int id) {
    return repository.findById(id).map(FooEntity::getSettings).orElse(null);
}
// ✅ 透傳 Optional，讓 Domain Service 決定「沒有」代表什麼
public Optional<Map<String, Integer>> getSettings(int id) {
    return repository.findById(id).map(FooEntity::getSettings);
}

// ❌ 靜態查表回 null（Utils 層最常見的漏網之魚）
public static CategoryType findCategory(String key) {
    return CATEGORY_BY_KEY.get(key);
}
// ✅
public static Optional<CategoryType> findCategory(String key) {
    return Optional.ofNullable(CATEGORY_BY_KEY.get(key));
}

// ❌ 查無屬系統異常卻回 Optional，讓上層猜該怎麼辦
public Optional<FooSettingVO> getRequiredSetting(String key) { ... }
// ✅ 直接拋，語意明確
public FooSettingVO getRequiredSetting(String key) {
    return Optional.ofNullable(settingCache.get(key))
        .orElseThrow(() -> new NoSuchElementException("Setting not found: " + key));
}
```

### 空集合 / 空字串的「部分存在」陷阱

查到了資料但內容為空（空 Map、空 List、空字串），與完全查不到，**語意上往往是同一件事**，處置卻常被寫得不一致——一個放行、一個報錯：

```java
// ❌ 語意不一致：整份查無 → 拋例外；查到但內容為空 → 放行
Map<String, Integer> settings = manager.getSettings(id)
    .orElseThrow(() -> new NoSuchElementException("not found"));
if (settings.isEmpty()) {
    return false;                       // 為什麼這裡就可以放行？
}

// ✅ 同一道守門
Map<String, Integer> settings = manager.getSettings(id)
    .filter(found -> !found.isEmpty())
    .orElseThrow(() -> new NoSuchElementException("not found or empty"));
```

判準：問「這兩種狀態，呼叫端有理由做不同處置嗎？」沒有 → 合併；有 → 在程式碼中明確寫出差異理由。

### 例外型別的選擇（連帶檢查）

決定「查無 → 拋例外」之後還要選對型別。**業務例外與系統例外必須分開**——回應格式、可觀測管道、告警策略都不同：

| 例外類型 | 語意 | 典型處置 |
|---------|------|---------|
| 業務例外（自訂，如 `XxxInvalidException`） | 使用者的請求不合法 | 上層 catch → 可讀的失敗回應（2xx/4xx）；寫入業務失敗記錄 |
| 系統例外（`NoSuchElementException` / `IllegalStateException` 等） | 服務端資料或狀態不完整 | 不被業務 catch 攔截，冒至最外層 → 通用錯誤回應（5xx）；**不**混入業務失敗統計 |

**常見錯誤**：把服務端資料不完整包成業務例外回「您的請求失敗」。後果——① 使用者看到的原因是錯的；② 混進業務失敗統計，稀釋真實失敗率；③ 故障訊號被降級成一行 log，監控上看起來一切正常。

審查時對每個新增的 `throw` 追問：**這是使用者做錯了，還是我們的資料壞了？** 答案決定例外型別。

*（此規則對應 REVIEW_GUIDE 2-5；目前無對應 ArchUnit 測試，屬 Code Review 階段檢查項）*
