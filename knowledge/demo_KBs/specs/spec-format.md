# Spec 文件格式

此文件定義 `specs/{TICKET}.md` 的標準格式。

Spec 記錄「要做什麼」：功能目標、資料流、商業規則、驗收條件、特殊限制。
不記錄「怎麼做」——class 位置、package、config 變更屬於 impl 文件（`specs/impls/{TICKET}-impls.md`）。

---

## 文件結構

```markdown
# {TICKET} {標題}

## 需求描述

ticket 的範疇 (Scope)、業務需求內容與交付標準摘要。

## 驗收條件與邊界情境

AC 條件概述，逐條列出，使用 checkbox 格式：
- [ ] 條件一
- [ ] 條件二

## 功能目標

條列式說明此 ticket 要達成的事。

## 資料流

使用 code-like facts 格式，以縮排 code block 呈現，每行一個可查核的 fact。
不寫散文說明。

後端涉及的 ticket：
```
ClassName
  → reads/writes: key / topic / collection / table
  → next ClassName
      returns: field, field
  → Kafka.send(topic) / WsSession.send(...) / HTTP.post(url)
```

純 FE 的 ticket：
```
trigger: <事件>
check:   <條件判斷>
  <結果 A> → <動作>
  <結果 B> → <動作>
data source: <來源，若無 API 則標 no API call>
```

## 影響範圍

- **目標 Service**：列出涉及哪些 service
- **新增 / 修改的層級與類別**：按 service 分組，列出 class 名稱與所在層級

## 前後端、services 間 Contract

（若有）API response 結構、WebSocket 訊息格式、gRPC、Kafka topic、欄位說明。

## 特殊限制

（選填）設計時不能踩的地雷：
- 哪個 service 沒有哪個依賴
- 為什麼不能用某個方案
- 特定的 key 格式或 TTL 限制
```

---

## 撰寫原則

- **具體值要記錄**：Redis key 格式、Kafka topic 名稱、DB table 名稱要明確寫出
- **資料流要可追蹤**：讀者應能從資料流描述中直接找到對應的 class
- **AC 要可測試**：每條 AC 必須有明確的 input / output，不接受「正常運作」這種模糊描述
- **不寫實作決策**：class 放哪個 package、用什麼設計模式，留給 impl 文件
