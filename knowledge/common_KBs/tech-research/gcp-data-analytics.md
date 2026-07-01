---
date: 2026-06-26
keywords: GCP, Cloud Storage, Cloud SQL, BigQuery, OLTP, OLAP, 資料倉儲, MySQL, 物件儲存, ACID
---

# GCP 資料儲存與分析服務

## 問題背景

GCP 提供多種資料儲存服務，需依據使用場景選擇：物件儲存（Cloud Storage）、關聯式資料庫（Cloud SQL）、資料倉儲（BigQuery）。

---

## OLTP vs OLAP 選擇原則

| 項目 | OLTP (Database) | OLAP (Data Warehouse) |
|------|-----------------|----------------------|
| **目的** | 支援應用程式當前資料 | 分析歷史資料、獲取洞見 |
| **操作** | 讀 + 寫 | 主要讀取 |
| **資料結構** | 正規化 | 高度結構化 |
| **使用者** | 應用程式、使用者 | 商業分析師、資料科學家 |
| **GCP 對應** | Cloud SQL、Cloud Spanner | **BigQuery** |
| **常見場景** | 銀行系統、電商訂單 | 商業分析、報表生成 |

### ACID 四大特性（OLTP 核心）

| 特性 | 說明 |
|------|------|
| **A**tomicity 原子性 | 事務全部完成或全部不完成，不會停在中間 |
| **C**onsistency 一致性 | 事務前後資料庫完整性不被破壞 |
| **I**solation 隔離性 | 允許多個並發事務同時讀寫而互不干擾 |
| **D**urability 持久性 | 事務完成後修改永久生效 |

### 事務隔離級別

| 級別 | 說明 |
|------|------|
| Read Uncommitted | 可讀取尚未提交的資料 |
| Read Committed | 只能讀取已提交的資料 |
| Repeatable Read | 同一事務內多次讀取相同資料結果一致 |
| Serializable | 最高級別，完全串行化 |

---

## Cloud Storage（物件儲存）

### Bucket Location Type

| 類型 | 可用性 | 成本 |
|------|--------|------|
| `multi-region` | 最高（SLA 99.95%） | 最高 |
| `dual-region` | 中 | 中 |
| `region` | 普通 | 最低 |

### Storage Class

| Class | 適用場景 |
|-------|---------|
| **Standard** | 經常存取的資料（網站、應用） |
| **Nearline** | 每月不超過一次存取 |
| **Coldline** | 每季不超過一次存取 |
| **Archive** | 每年不超過一次存取 |

### 靜態網站部署步驟

**步驟 1：建立 Bucket**
- Location type 依需求選擇
- Storage class 選 **Standard**
- Access Control：
  - 不勾選 `Enforce public access prevention on this bucket`
  - Access control 選 `Uniform`

**步驟 2：授予 allUsers 存取權限**
- Cloud Storage → 右方三個點點 → 編輯存取權 → 新增 `allUsers`

**步驟 3：指定靜態網站首頁**
- 右方三個點點 → 編輯網站設定 → 輸入首頁檔案名（如 `index.html`）

### 前後端統一給 Load Balancer 轉送

1. 負載平衡器新增「後端值區（Backend Bucket）」
2. 選擇 Cloud Storage Bucket
3. 設定轉送規則：

```
domain/api/*  → 後端服務
domain/*      → 前端靜態網站（Cloud Storage Bucket）
```

---

## Cloud SQL（全託管關聯式資料庫）

支援 MySQL、PostgreSQL、SQL Server。

> Cloud SQL manages your database instance. You manage your data.

### 建立執行個體

1. **必須先啟用 Compute Engine API**
2. GCP Console → Cloud SQL → 建立執行個體
3. 選擇 MySQL 8
4. 填寫設定（實例 ID、Region、機器規格等）
5. 建立後：點擊總覽查看狀態
6. 建立使用者帳戶

### 連線設定

> Cloud SQL 預設**不允許任何人連接**。

**方式一：私人 IP 連線（建議）**

```
選擇 default 網路 → 建立私人 IP

該網路下的全部資源都可使用 Private IP 連接 Cloud SQL：
- 所有使用 default 網路介面的 VM (Compute Engine)
- 所有 Serverless 服務，透過建立 VPC 通道
```

**方式二：公共 IP 連線**

1. Cloud SQL 實例頁面 → 點擊實例名稱
2. SQL 導覽選單 → 連線
3. 勾選「公共 IP」
4. 點擊「新增網路」
5. 輸入允許連接的 IP 或 CIDR（如 `203.0.113.0/24`）
6. 完成 → 儲存

---

## BigQuery（Serverless 資料倉儲）

BigQuery 是 **無伺服器的資料倉儲 (Serverless data warehouse)**，可想像成放在雲端的 Database，但不需要自己架設，在 GCP 上開啟服務即可建立資料集和資料表。

> Google 搜尋引擎和 Gmail 等服務，背後就和 BigQuery 息息相關。

### 核心優勢

| 優勢 | 說明 |
|------|------|
| ✅ 速度快 | 查詢或分析 TB/PB 等級資料最快可達秒級 |
| ✅ 費用省 | 省去維運硬體成本；每月有免費額度；依使用情形提供折扣 |
| ✅ 應用多 | 支援各種 BI 工具（Looker、Data Studio 等） |
| ✅ 彈性大 | 無需先定義使用空間；支援多種語法；多元存取方式 |

### BigQuery vs 傳統 DB

| 場景 | 選擇 |
|------|------|
| 高頻讀寫、ACID 事務 | Cloud SQL（OLTP） |
| 歷史資料分析、BI 報表 | BigQuery（OLAP） |
| 大量非結構化資料 | BigQuery + Cloud Storage |

---

## Compute Engine 連接 Cloud SQL（Private IP）

```bash
# 在 VM 內安裝 MySQL Client
sudo apt-get update && sudo apt-get install mysql-client

# 使用 Cloud SQL Private IP 連線
mysql -h <CLOUD_SQL_PRIVATE_IP> -u <USER_NAME> -p
```

前置條件：Cloud SQL 須開啟 Private IP，且與 Compute Engine 在相同 VPC 網路下。

---

## BigQuery 建置步驟

### 1. 建立資料集 (Dataset)

1. GCP Console → BigQuery
2. 點擊專案 → 建立資料集
3. 設定資料集 ID、地區、資料保留期限

### 2. 建立資料表 (Table)

- 導入外部檔案（CSV、JSON、Avro 等）
- 或從 Cloud Storage 讀取
- 或從 BigQuery 快取 Google Drive 資料

### 3. 執行查詢

```sql
-- 範例：查詢公開資料集
SELECT name, SUM(number) as total
FROM `bigquery-public-data.usa_names.usa_1910_2013`
WHERE state = 'TX'
GROUP BY name
ORDER BY total DESC
LIMIT 10;
```

### 4. 連接方式

| 方式 | 說明 |
|------|------|
| GCP Console | 直接在網頁上執行 SQL |
| bq CLI | 命令列工具 |
| REST API | 程式化存取 |
| 第三方 BI 工具 | Looker、Tableau 等 |

---

## BigQuery 文件注入（Java Spring Boot）

> 預設情況下，在免費層級 GCP 帳戶中，注入資料至 BigQuery 的唯一方法是通過**文件輸入**。使用 API 將資料逐一輸入僅適用於付費層。

### 工作流程

```
JDBCTemplate 查詢資料
  → 讀入 CSV 檔案
  → 注入 BigQuery
```

### 步驟

**步驟 1：建立具有 BigQuery 權限的服務帳號**

**步驟 2：將 JSON key 轉成 Base64**

```bash
# Linux
cat xxxxx.json | base64
```

**步驟 3：Maven 新增 BigQuery 相依**

```xml
<dependency>
    <groupId>com.google.cloud</groupId>
    <artifactId>google-cloud-bigquery</artifactId>
</dependency>
```

**步驟 4：建立資料集**

- GCP Console → BigQuery → 建立資料集
- 設定地區、資料保留期限

## 參考

- [Cloud SQL 文件](https://cloud.google.com/sql/docs)
- [BigQuery 文件](https://cloud.google.com/bigquery/docs)
- [Cloud Storage 文件](https://cloud.google.com/storage/docs)
