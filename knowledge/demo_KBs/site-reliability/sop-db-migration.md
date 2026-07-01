# SOP：DB Migration（Database-as-Code）

## 概念

統一管理 DB 的 DDL / DML 腳本，確保符合規範，建立 DB Schema 的唯一事實來源。
每一次異動都有 ticket 可追蹤，腳本同時作為 TestContainers 整合測試初始化腳本。

## 檔案位置與命名

- 位置：各 service repo 的 `docs/db/`
- Oracle DDL / DML：`{TICKET}.sql`
- MongoDB DDL：`{TICKET}.js`

## 檔案 Header 格式

**Oracle SQL：**
```sql
-- TAG: {TICKET}
-- SCHEMA: {schema名稱}
-- TYPE: DDL | DML
-- TABLES: {影響的 table，多個以逗號分隔}
-- DESCRIPTION: {說明}
-- BREAKING: Y | N
```

**MongoDB JS：**
```js
// TAG: {TICKET}
// SCHEMA: {db名稱}
// TYPE: DDL | DML
// COLLECTIONS: {影響的 collection}
// DESCRIPTION: {說明}
// BREAKING: Y | N
```

## 寫入規則

- **DDL**（建表 / 改表 / 欄位異動）：**必寫**，包含 CREATE、ALTER、DROP、INDEX
- **DML**：只寫「系統啟動一定要存在的資料（seed data）」，不寫測試資料
- **BREAKING** 判斷（見下方）

## BREAKING 判斷標準

| 操作 | BREAKING | 理由 |
|------|---------|------|
| 新增欄位（有 DEFAULT 或允許 NULL） | N | rolling deploy 期間舊版不會讀新欄位 |
| 新增欄位（NOT NULL 且無 DEFAULT） | **Y** | 舊版 INSERT 會失敗 |
| 刪除欄位 | **Y** | 舊版程式仍引用該欄位 |
| 修改欄位型態 / 縮短長度 | **Y** | 可能造成資料截斷或型態不符 |
| 新增 INDEX | N | 僅影響效能，不影響功能 |
| 新增 TABLE | N | 舊版不引用，安全 |
| 刪除 TABLE | **Y** | 舊版可能仍引用 |
| MongoDB 新增欄位 | N | Schema-less，舊文件無此欄位不影響讀取 |
| MongoDB 刪除欄位（程式有引用） | **Y** | 舊版程式讀取會得 null 或報錯 |

## 上線流程

```
1. 開發人員在 PR 中提交 docs/db/{TICKET}.sql（或 .js）
2. CI pipeline 自動執行 DB Lint（sqlfluff / JS 格式驗證）
3. DBA / Tech Lead Review：
   - BREAKING: N → 可 rolling deploy，通知 SRE 準備執行腳本
   - BREAKING: Y → 排停機視窗，DBA 確認後排程
4. SRE 在目標環境執行 SQL / JS：
   - 測試環境：SRE 執行 + 確認
   - Prod：DBA 執行（SRE 旁觀確認）
5. 執行完成確認 table / collection 結構正確
6. 觸發 CD 部署新版應用程式
```

> ⚠️ BREAKING: Y 時，**step 4 必須在 step 6 之前完成**，禁止應用程式先上。

## TestContainers 整合

DB 腳本同時作為 TestContainers 初始化腳本，在 CI 驗證三個面向：
1. Entity mapping 正確性（欄位名稱、型別、長度符合）
2. SQL 語法與 DBA 規範一致
3. 在與 prod 相同 DB 版本下程式執行無誤

## SRE 職責邊界

- **負責**：確認 BREAKING 影響範圍、協調停機視窗、監控執行過程
- **不負責**：撰寫 SQL 腳本、決定 Schema 設計、DB 日常維運
- **可建議**：腳本執行順序、Rollback 計畫、影響評估

## 緊急 Rollback（DDL Rollback）

```
DDL Rollback 腳本需在原腳本提交時一起附上（docs/db/{TICKET}-rollback.sql）
欄位新增 Rollback：ALTER TABLE ... DROP COLUMN ...
Table 建立 Rollback：DROP TABLE IF EXISTS ...
```
