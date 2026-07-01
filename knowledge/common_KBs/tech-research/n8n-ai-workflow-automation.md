---
date: 2026-06-27
keywords: n8n, AI Agent, Workflow Automation, RAG, MCP, LLM, Webhook, Trigger, LM Studio, Tavily, Vector DB, FAISS, Query Rewriting, HyDE, Multi-Query, 進階檢索
---

# n8n × LLM：AI 自動化工作流設計

**日期**：2026-06-27  
**關鍵字**：n8n, AI Agent, Workflow Automation, RAG, MCP, LM Studio, Webhook, Schedule Trigger, Tavily, Vector DB, FAISS

## 問題背景

企業需要串接多個系統（Email、試算表、Line、API）並加入 LLM 推理能力，形成完整的自動化流程。n8n 提供可視化、低程式碼的工作流引擎，能整合雲端 LLM 與本地模型，打造從辦公自動化到 AI Agent 的全場景方案。

---

## 研究結論

### 一、n8n 部署選型

| 方式 | 優點 | 缺點 | 適用情境 |
|------|------|------|---------|
| **Docker 本地安裝** | 完全掌控環境、可整合本地服務 | 初始設定較複雜 | 開發 / 測試 / 商用長期運行 |
| **HuggingFace Spaces** | 免費、不需本地伺服器 | 初始設定複雜、資料不持久 | Demo / 測試 |
| **n8n Cloud（官方託管）** | 穩定、安全、免維護 | 需付費、功能限制 | 商用長期運行 |

**Docker Compose 最小配置：**

```yaml
version: "3.8"
services:
  n8n:
    image: n8nio/n8n:latest
    ports:
      - "5678:5678"
    volumes:
      - ./n8n_data:/home/node/.n8n
    restart: always
```

---

### 二、觸發器類型（Trigger Nodes）

| 觸發器 | 說明 | 適用場景 |
|--------|------|---------|
| **Manual Trigger** | 手動點擊執行 | 開發測試 |
| **Webhook Trigger** | 提供 HTTP Endpoint，接收外部推送 | API 呼叫、LINE OA 訊息接收 |
| **Schedule Trigger** | 定時執行（Cron 語法） | 每日新聞摘要、定時爬蟲 |
| **Gmail Trigger** | 收到 Email 時自動觸發 | 郵件智慧分類、自動回覆 |

---

### 三、核心節點類型

| 節點 | 功能 |
|------|------|
| **HTTP Request** | 呼叫任意外部 API（GET/POST/PUT） |
| **Set（Edit Fields）** | 清整、重新命名、對齊資料欄位 |
| **Code** | 執行 JavaScript 或 Python，處理複雜邏輯 |
| **Switch** | 依條件分流（如依 MIME type 分派 PDF / 圖片 / 音訊） |
| **Sub-Workflow（Execute Workflow）** | 呼叫另一個已發布的 n8n 工作流，實現模組化 |
| **AI Agent** | 整合 LLM + Tools + Memory，能自主決策使用哪個工具 |

---

### 四、AI Agent 架構

```
使用者輸入
    ↓
AI Agent Node
  ├─ LLM（Gemini / OpenAI / 本地 LM Studio API）
  ├─ Memory（保留對話歷史）
  └─ Tools（可動態調用）
       ├─ Tavily Search（即時網路搜尋）
       ├─ Google Sheets（讀寫試算表）
       ├─ Gmail（寄送 / 讀取郵件）
       ├─ Google Calendar（查詢行事曆）
       ├─ Data Table（n8n 內建資料表）
       └─ Sub-Workflow（呼叫自定義工具）
    ↓
回覆使用者
```

**AI Agent System Prompt 設計要點：**
- 明確說明助理角色與回應語言
- 為每個 Tool 撰寫清楚的 Description（讓 LLM 知道何時使用）
- 敏感 Action（如寄信）建議加入「先確認再執行」的 prompt 設計

---

### 五、RAG 工作流設計

**RAG（Retrieval Augmented Generation）**：上傳私有文件，讓 LLM 基於文件內容回答問題。

#### 雲端 RAG 流程

```
表單上傳 PDF
    ↓
Extract Text（讀取文件內容）
    ↓
Text Splitter（分割成 Chunks）
    ↓
Embedding Model（Gemini / OpenAI）→ 向量化
    ↓
Vector Store（如 Supabase pgvector）← 儲存
    ↓
使用者提問 → Retrieve 相關 Chunks → LLM 生成回答
```

#### 本地 RAG 流程（無雲端 API）

```
PDF → Local Embedding API（FAISS + sentence-transformers）
                ↓
          faiss_server.py（Flask API）
                ↓
n8n 工作流 → HTTP Request 呼叫本地 API
                ↓
         LM Studio API（本地 LLM）→ 生成回答
```

**本地技術棧：**
- **Embedding**：`sentence-transformers` + `faiss-cpu`（不需 GPU）
- **Vector Store**：FAISS（輕量，適合單機）
- **LLM**：LM Studio 載入模型（如 gemma-4-e2b-it），提供 OpenAI 相容 API
- **Serving**：Flask 封裝成 REST API，供 n8n 呼叫

---

### 六、MCP Server / Client（Model Context Protocol）

**MCP** 讓 n8n 工作流可作為標準化工具，供其他 LLM Client（包含另一個 n8n AI Agent）呼叫。

```
MCP Client（n8n AI Agent）
    ↓  呼叫工具
MCP Server（另一個 n8n 工作流）
    └─ 封裝：查詢訂單明細、計算 Google Sheet、取得天氣 API...
```

**應用場景：**
- 將複雜的多步驟工作流封裝為單一工具
- 多個 AI Agent 共用同一套業務邏輯工具集
- 實現工具的版本化與集中管理

---

### 七、常見整合場景清單

| 場景 | 觸發方式 | 工具 |
|------|---------|------|
| 智慧 Gmail 分類 + 摘要 + 自動回覆 | Gmail Trigger | LLM + Gmail |
| 每日新聞搜尋 + 寄送 Email 摘要 | Schedule Trigger | Tavily + Gmail |
| LINE OA 隨身 AI 助理（文字/圖片/語音） | Webhook（LINE Messaging API） | LM Studio / Gemini |
| PDF / 圖片上傳分析（自動分流） | Webhook（表單） | Switch → LLM |
| RAG 知識庫問答 | Chat / Webhook | Vector Store + LLM |
| 訂單明細 ERP 助手 | Chat | AI Agent + Data Table |
| Google Drive 檔案搜尋與下載 | Chat | AI Agent + Google Drive |
| 定時爬取討論版發文 | Schedule Trigger | HTTP Request + Code |
| AI 清整資料夾（依副檔名分類） | Chat | AI Agent + File API |
| Sub-Workflow 天氣查詢工具 | Chat（作為工具被呼叫） | 氣象開放平台 API |

---

### 八、Webhook 進階：作為 API Endpoint

n8n Webhook 可作為自定義 API 對外提供服務：

```
外部呼叫 → http://{n8n_host}/webhook/{path}?key=value
    ↓
Webhook Trigger Node（接收 query / body / headers）
    ↓
業務邏輯（Set / Code / AI Agent）
    ↓
Respond to Webhook Node（回傳 JSON Response）
```

**開發 vs 生產模式：**
- 開發模式：`/webhook-test/{path}`（測試用，觸發一次後停止）
- 生產模式：`/webhook/{path}`（持續監聽，需 Activate 工作流）

---

### 九、RAG 進階檢索策略

> 追加日期：2026-07-01

基礎 RAG 的問題在於：使用者輸入往往口語、模糊或缺乏上下文，直接轉向量送進 FAISS 召回率差。以下三種進階策略可大幅提升檢索品質：

| 策略 | 做法 | 原理 |
|------|------|------|
| **Query Rewriting** | LLM 將口語問句改寫為精確查詢語句，再送 Embedding → FAISS | 精確語句的向量更貼近文件向量 |
| **HyDE**（Hypothetical Document Embeddings） | LLM 先「假裝」生成一個可能的答案，用答案向量去搜尋 | 答案向量比問題向量更接近文件向量，召回率高 |
| **Multi-Query** | LLM 將一個問題展開為 3–5 個不同角度的子問題，各自搜尋後合併去重 | 覆蓋不同語意角度，減少單一查詢的語意盲點 |

**在 n8n 的實作方式（以 Query Rewriting 為例）：**

```
使用者輸入問句
    ↓
LLM 節點（改寫 prompt：「將以下問題改寫為精確的知識庫查詢語句...」）
    ↓
改寫後語句 → Embedding 模型 → FAISS 相似度搜尋
    ↓
相關 Chunks → LLM 生成回答
```

架構多一個 LLM 節點，但效果差異顯著；HyDE 與 Multi-Query 同理，皆在 Embedding 前插入一個 LLM 改寫/展開步驟。

---

## 參考

- 來源：n8n × 大語言模型課程筆記（2026-04-20）
- 相關筆記：[local-llm-dev-environment.md](local-llm-dev-environment.md)（Ollama + Open WebUI 本地 LLM 環境建置）
