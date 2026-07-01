# 本地 AI 開發環境建置
> Windows + Docker Desktop + Ollama + Open WebUI + n8n + Continue.dev

用 n8n 作為統一自動化執行引擎：跑排程、工作流（資料 pipeline、CRM 同步）、接收 Telegram 指令驅動 AI 任務，並透過 MCP Server 接口讓 Claude 介面直接驅動 Workflow。

---

## 架構總覽（V2）

![Architecture](localAI_architecture.md)

| 服務         | URL                     | 用途                          |
|------------|-------------------------|-------------------------------|
| Open WebUI | http://localhost:8000   | 模型調教 / RAG 測試（直連 Ollama）  |
| Ollama API | http://localhost:11434  | LLM 本地推論                    |
| n8n        | http://localhost:5678   | 統一自動化執行引擎（含 MCP Server 接口）|

> **架構分層**：入口層（Claude介面 / IntelliJ / Telegram / Open WebUI）→ 推理層（Claude API / Ollama）→ 執行層（n8n）→ 整合層（Gmail / Notion / Calendar / Telegram通知）

---

## 前置需求

- [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
- IntelliJ IDEA（任意版本）
- WSL2（Docker Desktop 安裝時會引導啟用）
- 安裝 ollama (https://ollama.com/)

---

## 一、建立volume目錄

```
例如:
C:\MyApps\server\ollama-world\
  ├── ollama-webui\  ← Open WebUI 資料
  └── n8n\           ← n8n 流程資料
```
---

## 二、compose.yml & DockerFile

建立 `C:\MyApps\server\ollama-world\compose.yaml`

---

## 三、啟動服務

```powershell
cd C:\MyApps\server\ollama-world
docker compose up -d
```

確認狀態：
```powershell
docker compose ps
```

停止服務：
```powershell
docker compose down
```

---

## 四、在 host 設定 Ollama 指令 (docker安裝下可選)

powershell 綁定 ollama = docker exec -it ollama ollama，不用每次都輸入一長串前綴

```powershell
# 打開 powershell 開啟 profile
notepad $PROFILE

# 在檔案中加入這行
function ollama { docker exec -it ollama ollama $args }

# 存檔後重新載入
. $PROFILE

# 權限問題: 用系統管理員身份執行這個指令解鎖
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 五、IntelliJ + Continue.dev 設定

這邊設定的 model 需先用 ollama 裝好，可安裝的 model: https://ollama.com/library?sort=newest

### 5.1 安裝 Plugin

1. IntelliJ → `Settings` → `Plugins`
2. 搜尋 **Continue**
3. 安裝並重啟 IDE

### 5.2 設定 config.json

開啟 `~/.continue/config.json`（Windows: `C:\Users\{你的帳號}\.continue\config.json`）：

```json
{
  "models": [
    {
      "title": "Qwen2.5 Coder (Local)",
      "provider": "ollama",
      "model": "qwen2.5-coder:7b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "Llama3.2 (Local)",
      "provider": "ollama",
      "model": "llama3.2:3b",
      "apiBase": "http://localhost:11434"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Autocomplete",
    "provider": "ollama",
    "model": "qwen2.5-coder:7b",
    "apiBase": "http://localhost:11434"
  },
  "contextProviders": [
    { "name": "code" },
    { "name": "file" },
    { "name": "currentFile" },
    { "name": "problems" }
  ]
}
```

### 5.3 常用快捷鍵

| 功能 | 快捷鍵 |
|------|--------|
| 開啟 Chat | `Ctrl + Shift + J` |
| 選取程式碼並問問題 | 選取 → `Ctrl + Shift + J` |
| 直接修改選取的 code | 選取 → `/edit 你的指令` |
| 解釋程式碼 | 選取 → `/explain` |
| 產生測試 | 選取 → `/test` |

---

## 六、n8n 自動化整合

n8n 作為統一執行引擎，承擔三個角色：

### 6.1 AI Dispatcher Workflow（意圖路由）

接收 Telegram 訊息後，呼叫 Claude / Ollama 解讀意圖，再用 Switch 節點路由到對應子 Workflow。

```
Telegram Trigger → AI 節點（Claude/Ollama）→ Switch → 子 Workflow A / B / C
```

### 6.2 排程 / SOP Workflows

| 情境 | n8n 節點組合 |
|------|-------------|
| Email 摘要 | Gmail Trigger → Ollama → Gmail Reply |
| Telegram 問答機器人 | Telegram Trigger → Ollama → Telegram Reply |
| Notion 自動筆記 | Webhook → Ollama → Notion |
| 定時產生報告 | Schedule → Ollama → Email/Notion |

### 6.3 MCP Server 接口

n8n 可暴露 MCP（Model Context Protocol）端點，讓 Claude 介面直接透過 MCP 呼叫 Workflow，不需另外架設 MCP Server。

- n8n 側：使用 **MCP Trigger** 節點建立 MCP 端點
- Claude 側：在 Claude Code / Claude Desktop 設定中加入 n8n MCP Server URL
- 效果：在 Claude 對話中可直接驅動 n8n Workflow，整合彈性最大化

參考：[n8n MCP 整合文件](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-langchain.mcptrigger/)

---

## 七、安全注意事項

- `WEBUI_AUTH=False` 僅限本機開發使用，上線前務必改為 `True`
- `WEBUI_SECRET_KEY` 請替換為隨機字串
- Port `5678`（n8n）與 `8000`（WebUI）不要對外開放
- Ollama API `11434` 預設無驗證，僅供本機使用
- n8n MCP 端點若要對外，需設定 n8n 的 API Key 驗證

---

## 參考資源

- [Ollama 官方文件](https://ollama.com)
- [Open WebUI 文件](https://docs.openwebui.com)
- [n8n 文件](https://docs.n8n.io)
- [Continue.dev 文件](https://docs.continue.dev)
- [n8n MCP Trigger](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-langchain.mcptrigger/)
