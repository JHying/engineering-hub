---
date: 2026-06-27
keywords: UML, OOAD, OOA, OOD, Use Case, Class Diagram, Sequence Diagram, Activity Diagram, 迭代開發, USDP
---

# UML 圖表應用與 OOAD 系統分析設計

**日期**：2026-06-27  
**關鍵字**：UML, OOAD, OOA, OOD, Use Case Diagram, Class Diagram, Activity Diagram, Sequence Diagram, USDP, 迭代開發

## 問題背景

系統分析設計（SA/SD）需要標準化的視覺語言來描述需求、結構與行為。UML（Unified Modeling Language）提供多種圖表類型，OOAD 則是指導整個分析設計過程的方法論。

---

## 研究結論

### 一、OOAD（Object-Oriented Analysis and Design）

OOAD 是根據 OO 方法學，對軟體系統進行分析與設計的過程，分兩個核心階段：

| 階段 | 核心問題 | 解決內容 |
|------|---------|---------|
| **OOA（分析）** | What to do？ | 建立業務問題域的清晰視圖、列出系統核心任務、建立公用詞彙表 |
| **OOD（設計）** | How to do？ | 如何解決具體業務問題、引入支援元素、定義實現策略 |

---

### 二、開發過程模型

#### 傳統瀑布模型
```
需求分析 → 系統設計 → 程式編碼 → 測試 → 維護
```
各階段線性執行，前一階段完成才進入下一階段。

#### USDP（統一軟體開發過程）— 迭代遞增模型

```
Inception → Elaboration → Construction → Transition
   啟動         精化           建構           轉移
```

| 階段 | 英文 | 主要工作 |
|------|------|---------|
| **Inception** | Start up | 定義業務問題域、識別主要風險、確定需求範圍 |
| **Elaboration** | Refine | 高層分析設計、建立基礎架構、監控風險、制定建構計畫 |
| **Construction** | Implement | 程式碼實現、功能遞增交付 |
| **Transition** | Promotion | 向用戶發布、Beta 測試、效能調優、用戶培訓 |

**迭代模型優勢：**
- 降低成本（早期發現風險）
- 便於追蹤進度
- 適應需求動態變化
- 利於團隊協作

---

### 三、UML 圖表分類

UML 分兩大類：

| 類別 | 說明 | 常見圖表 |
|------|------|---------|
| **行為圖（Behavior）** | 描述系統的動態行為、事件流程 | Use Case、Activity、State Machine、Sequence |
| **結構圖（Structure）** | 描述系統靜態結構 | Class、Component、Deployment |

---

### 四、Use Case Diagram（使用案例圖）

描述系統外部用戶（Actor）與系統功能（Use Case）的互動關係。

**關鍵概念：**
- **Actor**：使用系統的外部角色（人或外部系統），位於系統邊界外
- **System Boundary**：明確標示系統範圍的矩形框
- **Include（包含關係）**：Use Case A 執行時必定包含 Use Case B（類似函式呼叫）
  - 例：「買票」包含「付款」
- **Extend（延伸關係）**：在特定條件下擴展原 Use Case 的行為，不影響原流程
  - 例：「買東西」可選擇「填入統編」（非強制）

---

### 五、Class Diagram（類別圖）

描述類別的屬性、方法與類別間的靜態關係。

**五種關係類型（由弱到強）：**

| 關係 | 符號 | 說明 | 使用時機 |
|------|------|------|---------|
| **Dependency（相依）** | 虛線箭頭 | 使用到另一個類別，但非屬性（如方法參數） | 暫時性使用 |
| **Association（結合）** | 實線箭頭 | 一個類別擁有另一個作為屬性 | 持久引用 |
| **Aggregation（聚合）** | 空心菱形 | 弱整體-部分關係，部分可獨立存在 | 如班級-學生 |
| **Composition（組合）** | 實心菱形 | 強整體-部分關係，整體消亡則部分消亡 | 如訂單-訂單項目 |
| **Generalization（一般化）** | 空心三角箭頭 | 繼承關係，箭頭指向父類別 | 是一種（is-a） |

> **Aggregation vs Composition**：兩者都是「包含」，差別在於生命週期。Composition 中部分的存在依附於整體（如房間依附於建築物）；Aggregation 中部分可獨立（如引擎可從車上拆下）。

---

### 六、Activity Diagram（活動圖）

描述業務流程或演算法的控制流，特別適合條件、迴圈、並行邏輯。

| 符號 | 說明 |
|------|------|
| 實心圓點 | 活動起始節點 |
| 同心圓點 | 活動終止節點 |
| 長方形 | 行動節點（執行的操作） |
| 菱形 | 決策節點 |
| 水平粗線（分） | Fork：一條路徑分成多條並行 |
| 水平粗線（合） | Join：多條並行路徑合回一條 |

---

### 七、Sequence Diagram（時序圖）

描述物件間訊息傳遞的時間順序，強調「誰在什麼時間點對誰發送什麼訊息」。

**與 Activity Diagram 的差異：**
- Activity Diagram → 描述**活動流程**（做什麼、如何分支）
- Sequence Diagram → 描述**訊息流程**（誰呼叫誰、何時觸發）

**適用場景：**
- API 呼叫流程設計
- 微服務間互動描述
- 功能 Case 的系統互動說明（搭配 Use Case 使用）

---

## 參考

- 來源：Notion 開發學習筆記 — 專案管理 > SA - UML 應用、SA - OOAD 理論
