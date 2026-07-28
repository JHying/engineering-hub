# 讀取 Mapper

1. 找到 `<MapperName>.java`（Mapper 介面）與 `<MapperName>Impl.java`（生成的實作）
2. 對每個 public 方法，記錄：
   - 方法名稱、參數型別、回傳型別
   - 讀取方法上所有 `@Mapping` 註解，特別注意：
      - `target` 欄位名稱
      - 有無 `source`、`expression`、`ignore = true`
3. **解析所有參考型別的實際欄位**：對 Mapper 中引用的每一個非 primitive 型別（VO、DTO、Proto 等），讀取該型別的欄位定義：
   - **POJO（VO / DTO / Entity）**：直接讀取 `.java` 原始碼取得欄位名稱與型別
   - **Protobuf 型別**：**不可**讀取本地 toolbox 原始碼（版本可能不同）。應從 `pom.xml` 取得實際依賴版本，再用 `javap` 反編譯 `.m2` 快取的 JAR：
     ```bash
     # 1. 從 pom.xml 確認版本，例如 GrpcUtils 0.0.9
     # 2. 解出 class 再 javap
     cd /tmp && jar xf ~/.m2/repository/com/example/project/GrpcUtils/<version>/GrpcUtils-<version>.jar \
       com/example/project/proto/auth/user/<ProtoClass>.class
     javap -p com/example/project/proto/auth/user/<ProtoClass>.class | grep "public.*get"
     ```
   - 以 `javap` 輸出的 getter 簽章為準，確認欄位名稱（BeanUtils property name）與回傳型別，再決定是否需要加入 excludeFields
