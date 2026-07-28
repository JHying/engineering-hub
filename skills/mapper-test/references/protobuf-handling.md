# Protobuf 型別（GrpcXxxReq 等）

Instancio **無法**建立 Protobuf 物件（私有建構子、final class）。凡 source 或 result 是 Protobuf 型別時，改用 builder 手動建立：

```java
// ❌ 不可用
GrpcLoginReq source = Instancio.create(GrpcLoginReq.class);

// ✅ 改用 builder
GrpcLoginReq source = GrpcLoginReq.newBuilder()
    .setUserId("testUser")
    .setWebsiteId(1)
    .setIp("127.0.0.1")
    .setUserAgent("Mozilla/5.0")
    .build();
```

List 測試中需要兩個不同的 proto 實例，直接分別 inline 建立即可（給不同欄位值）。

**`assertAllFieldsMapped` 方向規則（proto 同樣適用）：**

| 方法方向 | 呼叫方式 | 說明 |
|---|---|---|
| proto → POJO (`toVO`) | `assertAllFieldsMapped(proto, result)` | 迭代 POJO（欄位少）→ 在 proto 找對應名稱 |
| POJO → proto (`toTarget`) | `assertAllFieldsMapped(result, source)` | 反向：迭代 POJO source（欄位少）→ 在 proto result 找對應名稱，避免掃到 proto 內部欄位 |
| POJO → Entity（entity 有額外欄位如 `id`） | `assertAllFieldsMapped(result, source)` | 反向：迭代 VO source → 在 entity result 找，跳過 entity 額外欄位 |
