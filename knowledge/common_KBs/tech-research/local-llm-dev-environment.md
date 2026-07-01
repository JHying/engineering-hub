---
date: 2026-06-27
keywords: LLM, Ollama, Open WebUI, n8n, Continue.dev, Docker, Windows, 本地推論
---

# 本地 LLM 開發環境建置

**日期**：2026-06-27  
**關鍵字**：LLM, Ollama, Open WebUI, n8n, Continue.dev, Docker Desktop, Windows, 本地推論

## 問題背景

在不依賴雲端 API 的情況下，於 Windows 本機架設完整的 LLM 推論環境，用途包含：
- 以 n8n 跑排程自動化工作流（資料 pipeline、CRM 同步）
- 以 AI Chat UI 作為個人助理處理臨時任務、管理收件匣

## 架構總覽

| 服務 | 端口 | 用途 |
|------|------|------|
| Open WebUI | 8000 | Chat UI 介面 |
| Ollama API | 11434 | LLM 模型推論 |
| n8n | 5678 | 自動化流程 UI |

技術棧：**Windows + Docker Desktop（WSL2）+ Ollama + Open WebUI + n8n + Continue.dev（IDE Plugin）**

## 前置需求

- Docker Desktop for Windows（含 WSL2）
- Ollama（[https://ollama.com](https://ollama.com)）
- IntelliJ IDEA（搭配 Continue.dev Plugin）

## 研究結論

### 啟動流程

```powershell
cd <ollama-world-dir>
docker compose up -d
docker compose ps   # 確認狀態
docker compose down # 停止
```

### IDE 整合（IntelliJ + Continue.dev）

`~/.continue/config.json` 範例：

```json
{
  "models": [
    {
      "title": "Qwen2.5 Coder (Local)",
      "provider": "ollama",
      "model": "qwen2.5-coder:7b",
      "apiBase": "http://localhost:11434"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Autocomplete",
    "provider": "ollama",
    "model": "qwen2.5-coder:7b",
    "apiBase": "http://localhost:11434"
  }
}
```

常用快捷鍵：`Ctrl + Shift + J`（開啟 Chat）、選取程式碼後 `/edit`、`/explain`、`/test`

### n8n 自動化情境

| 情境 | 節點組合 |
|------|---------|
| Email 摘要 | Gmail Trigger → Ollama → Gmail Reply |
| Telegram 問答機器人 | Telegram Trigger → Ollama → Telegram Reply |
| Notion 自動筆記 | Webhook → Ollama → Notion |
| 定時產生報告 | Schedule → Ollama → Email/Notion |

### PowerShell 快捷設定（Docker 模式）

在 `$PROFILE` 加入別名，省去每次輸入 `docker exec -it ollama ollama`：

```powershell
function ollama { docker exec -it ollama ollama $args }
```

### 安全注意事項

- `WEBUI_AUTH=False` 僅限本機開發，上線前改為 `True`
- Port 5678（n8n）與 8000（WebUI）不要對外開放
- Ollama API 11434 預設無驗證，僅供本機使用

---

## V2 架構決策（2026-06-27）：移除 OpenClaw，以 n8n 為核心

### 問題

V1 架構在入口層和執行層之間插入了 OpenClaw 作為 Agent 層，負責理解 Telegram 訊息意圖、路由到 n8n。實際評估後，這層對於排程自動化 / 固定 SOP 的使用情境是多餘的。

### 決策：移除 OpenClaw

| 比較項目 | OpenClaw（V1） | n8n 直接處理（V2） |
|---------|--------------|-----------------|
| 接收 Telegram | 透過 OpenClaw 中繼 | Telegram Trigger 節點，原生支援 |
| AI 推理路由 | OpenClaw 呼叫 Claude API | n8n AI Dispatcher Workflow |
| 執行整合 | 呼叫 n8n Webhook | n8n 本身直接執行 |
| 持久記憶 | 內建 | 需外掛（Notion / SQLite），接受此限制 |
| 動態 Agent 行為 | 支援 | 不支援（固定 Workflow 路徑），但使用情境不需要 |
| 安全性 | 自主運行，難以審計 | 每個 Workflow / Credential 需明確授權，有執行紀錄 |
| 建置複雜度 | 高 | 低（UI 配置） |

### V2 架構分層

```
入口層   [Claude介面]  [IntelliJ Plugin]  |  [Telegram Bot]  [Open WebUI]
         ← 純AI工具 →                     ←── 任務入口 ───→
                ↓ 主推理                        ↓ Telegram Trigger
推理層   [Claude API (主)]          [Ollama :11434 (備援/離線)]
                       ↑ 意圖解讀推理 ↑
執行層   ┌──────────── n8n :5678 ────────────────────────────┐
         │  ① AI Dispatcher  ② 排程/SOP  ③ MCP Server 接口  │
         └──────────────────────────────────────────────────┘
整合層   [Gmail]  [Notion]  [Calendar]  [Telegram通知/Jira]
```

### n8n MCP Server 接口

n8n 可暴露 MCP（Model Context Protocol）端點，讓 Claude 介面透過 MCP 直接驅動 n8n Workflow，取代原先需要獨立架設 MCP Server 的需求。這使 n8n 同時扮演：

- 自動化執行引擎（Workflow）
- AI 推理路由器（AI Dispatcher）
- MCP Server（供 Claude 介面使用）

整合彈性顯著提升，且不需要額外維護獨立的 MCP Server 服務。

### Open WebUI 定位調整

V2 中 Open WebUI 回歸純工具角色：模型調教、RAG 測試、直連 Ollama。不再作為任務路由的入口。

---

## 參考

- [Ollama 官方文件](https://ollama.com)
- [Open WebUI 文件](https://docs.openwebui.com)
- [n8n 文件](https://docs.n8n.io)
- [Continue.dev 文件](https://docs.continue.dev)
- [n8n MCP 整合文件](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-langchain.mcptrigger/)
