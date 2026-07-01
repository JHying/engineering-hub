---
date: YYYY-MM-DD
branch: {分支名稱，如 feature/TICKET}
ticket: {ticket 單號，如 PROJ-123；無則填 n/a}
reviewer: {reviewer 帳號}
service: {涉及的服務名稱，如 order-service}
scope: {審查範圍一行描述，如 下單流程從 API 入口到 Kafka produce}
mode: {ticket 模式 / 範圍模式}
---

# Code Review — {標題}

## 審查範圍

| 類別 | Class |
|------|-------|
| {分類} | `{com.example.package.ClassName}` |
| {分類} | `{com.example.package.ClassName}` |

---

## 品質問題（Quality Issues）

### {ClassName}
- **[已修 / 不處理 / 後續追蹤]** {違規類型}：{OOP / Clean Code / SOLID / DDD}
  - 原：`{違規程式碼片段或描述}`
  - 修正：{修正方式或程式碼}
  - 保留原因（若不處理）：{說明}

（無問題時寫：✅ 無品質問題）

---

## 效能瓶頸 / 資料原子性（Performance & Atomicity Issues）

### {ClassName}
- **[已修 / 不處理 / 接受 / 撤銷]** {問題類型}：{DB / Redis / Kafka / HTTP / 並行 / 跨Pod / WebSocket}
  - 問題：{描述}
  - 風險：{說明影響，強制門檻或優化項}
  - 修正：{修正方式}
  - 說明（若接受/撤銷）：{說明原因}

（無問題時寫：✅ 無效能 / 原子性問題）

---

## 設計模式（Design Pattern Review）

- **[建議引入]** {模式名稱} @ `{ClassName / 方法}` — {引入理由}
- **[已使用]** {模式名稱} @ `{ClassName}` — {合適 / 誤用，說明}
- **[過度設計]** {位置} — {說明}

（三個子項若均無內容，寫：✅ 無設計模式問題）

---

## 本次修改檔案

| 檔案 | 類型 | 異動摘要 |
|------|------|---------|
| `{ClassName}.java` | 新建 / 修改 | {一行說明} |

---

## 相關 ADR

- [ADR-{nnnn}](../ADRs/{slug}.md) — {說明}（若有）

---

## 未解決 / 後續追蹤

| 項目 | 建議行動 |
|------|---------|
| {問題描述} | {建議，如：確認單位後修正魔術數字} |
