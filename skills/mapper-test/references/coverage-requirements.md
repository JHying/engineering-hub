# Coverage 要求

**JaCoCo methods covered ratio 必須達到 1.00**（每個 class 的每個方法都要被執行到）。

### 需要檢視的對象

生成測試後，必須讀取 `<MapperName>Impl.java`，確認以下兩類方法都有被覆蓋到：

#### 1. Interface 的 `default` 方法

`default` 方法的 bytecode 在 interface class 上，JaCoCo 直接量測 interface。若有未測試的 `default` 方法，interface 的 coverage ratio 將不足。

→ **每個 `default` 方法都必須有對應測試。**

#### 2. Impl 的 `protected` 輔助方法（MapStruct 自動生成的 nested 轉換）

當 Mapper 有巢狀物件型別轉換（如 `GameSettingVO ↔ GameSettingProto`），MapStruct 會在 Impl 生成 `protected` 方法。這些方法只有在 source 物件的對應欄位非 null（或 proto 的 `hasXxx()` 為 true）時才會被呼叫。

**常見陷阱：** 若 source 是 Protobuf，以 builder 手動建立時若漏設某個巢狀欄位，`hasXxx()` 會是 false，導致輔助方法永遠不執行。

```java
// ❌ 沒有設 gameSetting → hasGameSetting() = false → gameSettingProtoToGameSettingVO 不執行
GrpcAccountReq.newBuilder()
    .setUserId("testUser")
    .build();

// ✅ 設定巢狀物件 → 觸發 protected 輔助方法
GrpcAccountReq.newBuilder()
    .setUserId("testUser")
    .setGameSetting(GameSettingProto.newBuilder()
        .setSoundOn(true)
        .setLanguage("en")
        .build())
    .build();
```

→ **讀取 Impl 確認有哪些 `protected` 方法，並確保至少一個測試的 source 資料會觸發每個 `protected` 方法。**
