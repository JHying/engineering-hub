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

docker-compose 只在 container 內跑 ollama，host 上沒有原生 ollama.exe，直接打 `ollama` 會 command not found。
`Tools/ollama.cmd` 是一支包裝腳本，把 `ollama <args>` 轉發成 `docker exec -it ollama ollama <args>`。
跑完 `docker compose up -d` 後，執行這支腳本把 `Tools/` 加進使用者層級的 PATH：

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-ollama-path.ps1
```

之後開新的終端機視窗（cmd.exe / PowerShell / Git Bash 都可以）就能直接用 `ollama`，不需要改動任何 shell 的 profile。腳本是冪等的，重複執行不會在 PATH 裡加重複項。若 `RemoteSigned` 執行原則被擋，用系統管理員身份執行:

```powershell
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

## 八、用 Claude Code CLI 呼叫本機 Ollama Model

Ollama v0.14+ 內建 Anthropic Messages API 相容端點（`/v1/messages`），Claude Code 可以透過改 `ANTHROPIC_BASE_URL` 直接連本機 Ollama，不需要額外的轉換層。

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\claude-ollama.ps1
```

腳本會列出 `docker exec ollama ollama list` 目前有的 model 讓你選（或直接帶 `-Model <name>` 跳過選單），選完設定 `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` 後啟動 `claude --model <name>`。

**限制**：多數本機 model 的 tool calling（讀檔、跑指令、套用修改等 Claude Code 的核心能力）支援很弱或完全不支援，這代表大部分互動可能只能拿到建議、無法真的自動執行。官方文件建議用 `qwen3-coder`、`glm-4.7:cloud`、`gpt-oss:20b` 這類有標註 tool-calling 支援的 model。

**純 CPU（無獨立顯卡）的機器要注意**：Claude Code 本身固定的 system prompt + tool schema 開銷就有數萬 tokens，純 CPU 處理這麼大的 prefill 非常慢。Claude Code 預設有一個 5 分鐘的閒置逾時（收不到任何 streaming byte 就判定卡住、直接 abort），純 CPU 推理很容易撐不過這個時間而直接失敗——腳本已經加上 `API_FORCE_IDLE_TIMEOUT=0`（關閉這個逾時）跟 `API_TIMEOUT_MS=1800000`（總逾時拉到 30 分鐘），實測一個 2B 等級的小 model 光回一句「hi」都跑了 22 分鐘。這代表純 CPU 機器上這個組合技術上可行、但不具備日常互動的實用性，適合當一次性驗證，不建議拿來做真正的開發工作流。

---

## 參考資源

- [Ollama 官方文件](https://ollama.com)
- [Ollama Anthropic API 相容性](https://docs.ollama.com/api/anthropic-compatibility)
- [Claude Code Model Configuration](https://code.claude.com/docs/en/model-config)
- [Open WebUI 文件](https://docs.openwebui.com)
- [n8n 文件](https://docs.n8n.io)
- [Continue.dev 文件](https://docs.continue.dev)
- [n8n MCP Trigger](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-langchain.mcptrigger/)
