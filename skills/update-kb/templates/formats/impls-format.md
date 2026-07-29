# Impl 文件格式規範

**建立時機：** 實作完成後，更新知識庫時。
**資料來源：** git diff + 對應 service 現有 KB（index.md + facts.md）+ 對應 spec（AC 清單）。
**實際範例：** `specs/impls/{TICKET}-impls.md`

---

## 檔案命名

`{TICKET}-impls.md`（例：`{TICKET}-impls.md`）

---

## 文件結構

```markdown
# {TICKET} 實作概述

> 對應 spec：`knowledge/specs/{TICKET}.md`
> 涉及服務：{service-name}（後端）、{FE framework}（前端，若有）
> 同步 commit：{commit hash}（KB 對應版本）

---

## 一、AC 實作概述

> {說明後端 / 前端 AC 分工，若有尚未補充的面向在此標注}

| AC | 涉及層 | 實作機制 |
|----|--------|---------|
| AC1：{條件描述} | BE / FE / BE+FE | {對應 class.method 或 FE 機制} |
| AC2：{條件描述} | ... | ... |

---

## 二、功能異動範圍與系統流程

### 異動範圍

（條列本次新增 / 修改的 class 或功能模組；若無 BE 新增類別需明確說明「沿用既有流程」）

### 系統流程（code-like-facts）

（每個主要流程一個區塊，用 code block 呈現）

\`\`\`
ClassName.methodName(input)
  → condition or reads/writes
      ClassName2.methodName2(...)
        reads:  RedisKey / MongoCollection / OracleTable
        writes: RedisKey / MongoCollection / OracleTable
      → sends: Kafka topic / WsSession.send(msgType)
  conditionA → action
  conditionB → action
\`\`\`

---

## 三、驗測方式

| 測試類型 | 對象 | 涵蓋範圍 |
|---------|------|---------|
| Unit Test | `ClassNameTest` | {說明} |
| Integration Test | TestContainers | {說明} |
| Contract Test | `contracts/xxx.groovy` | {說明，若有} |
| FE E2E / Unit | {component/store} | {說明，若有 FE} |

---

## 四、SA 系統需求規格實作

（**無異動時仍須填寫，明確寫「無新增」避免歧義**）

- **Redis key**：{`prefix:id` TTL=Xs，存放於 service} / 無新增（沿用 `existing-key`）
- **Kafka topic**：{`topic-name`，producer=X，consumer=Y} / 無新增（沿用 `existing-topic`）
- **MongoDB / Oracle**：{collection / table 名稱，schema} / 無新增
- **Config 變更**：{key，影響環境} / 無變更
- **合約異動（WS / gRPC / REST）**：{說明} / 無異動
- **特殊行為說明**：{補充規格層級的行為邊界，例如「成功不推送」、「特定條件判斷字串」}
```

---

## 撰寫原則

- **code-like-facts 要可追蹤**：每個節點要對應到可查的 class / method；不寫散文
- **AC 表格不可有空白 class**：若是純 FE 則寫「FE {機制描述}」，不留空
- **第四章無異動仍必填**：明確寫「無新增」可避免讀者不確定是否遺漏
- **後端 / 前端分工在開頭標注**：讓讀者知道哪些 AC 的 BE 實作細節已完整、哪些需 FE 補充
- **涉及多個 service 時分區塊**：每個 service 的流程獨立一個 code block
