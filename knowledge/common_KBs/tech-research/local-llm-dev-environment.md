---
date: 2026-06-27
keywords: LLM, Ollama, Open WebUI, n8n, Continue.dev, Docker, Windows, 本地推論, Claude Code
---

# 本地 LLM 開發環境建置

**日期**：2026-06-27（最後更新：2026-07-20）  
**關鍵字**：LLM, Ollama, Open WebUI, n8n, Continue.dev, Docker Desktop, Windows, 本地推論, Claude Code

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

> ⚠️ 此做法已被下方「PowerShell 快捷設定（跨 Shell Wrapper 模式，2026-07-20 更新）」取代，以下內容保留作歷史紀錄。

在 `$PROFILE` 加入別名，省去每次輸入 `docker exec -it ollama ollama`：

```powershell
function ollama { docker exec -it ollama ollama $args }
```

### PowerShell 快捷設定（跨 Shell Wrapper 模式，2026-07-20 更新）

上方寫入 `$PROFILE` 的別名做法已被取代，改為：

- 建立一支跨 shell 的 wrapper 腳本（不綁定 PowerShell 語法，其他 shell 也能呼叫）
- 把該腳本所在目錄加進使用者層級 PATH

取代理由：
- `$PROFILE` 寫法只有 PowerShell 能用，換到其他 shell 就失效
- 把特定工具（Ollama）的呼叫邏輯寫進使用者全域 profile，會讓 profile 混雜工具邏輯，不利維護與遷移

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

## Claude Code CLI 串接本機 Ollama（2026-07-20）

### 問題背景

Claude Code（Anthropic 官方的 agentic coding CLI 工具）預設呼叫 Anthropic 雲端 API。評估是否能讓它改接本機 Ollama 執行的模型，取代雲端 API 呼叫。

### 研究結論

1. **原生支援，免 proxy**：Ollama 自 v0.14.0（2026 年 1 月發布）起原生支援 Anthropic Messages API 相容端點（路徑 `/v1/messages`），因此 Claude Code 可以直接連線本機 Ollama，不需要額外的格式轉換 proxy。
2. **設定方式（三個環境變數）**：
   - `ANTHROPIC_BASE_URL=http://localhost:11434` — 決定請求送去哪裡（本機 Ollama 而非 Anthropic 官方 API）
   - `ANTHROPIC_AUTH_TOKEN=ollama` — 認證 token，Ollama 端不驗證實際內容，填任意非空字串即可
   - `ANTHROPIC_MODEL=<model-name>` 或啟動時帶 `--model <model-name>` — 指定要用哪個本機模型，name 需對應到 `ollama list` 顯示的本機已下載模型
3. **已知限制（官方文件明確提示）**：多數本機開源模型的 tool calling（Claude Code 賴以自動讀檔、跑指令、套用程式碼修改的核心 agentic 能力）支援很弱或完全不支援，代表很多互動可能只能拿到文字建議、無法真的自動執行動作。官方建議挑選明確標註支援 tool calling 的模型（例如 30B 等級的 coder 導向模型，需要 24GB 以上 VRAM）。
4. **已知 bug**：Ollama 的 Anthropic 相容層若收到它不支援的端點請求（例如某個 token 計數用的 beta 端點），伺服器會卡住沒回應，最終逾時並自動重啟。代表這個整合目前還在成熟中，不算完全穩定。
5. **實作方式**：寫一支腳本，先用 `docker exec` 呼叫容器內的 `ollama list` 列出本機已下載模型讓使用者互動選擇（或直接帶參數指定），選完後設定上述三個環境變數並啟動 `claude --model <選定的模型>`。腳本放在專案內的工具目錄，與既有的 docker-compose 環境放在一起，相對路徑範例：`<ollama-world-dir>/Tools/claude-ollama.ps1`。

### 查證方式

先由 AI 助理查證，中途一份查證結果被系統標記為疑似格式異常的內容，因此改用兩個獨立管道（網頁搜尋 + 直接讀取官方文件頁面）交叉驗證後才採信，最終內容一致。

### 實測結果補充（2026-07-20）

延續上述整合，在純 CPU（無獨立顯卡）環境下實際跑一次端到端測試：Claude Code CLI 接上本機小型模型（有效參數約 2B 等級），送出最簡單的打招呼訊息，驗證能否跑通。

**發現 1：串流閒置逾時機制**

- Claude Code 有「串流回應閒置逾時」：連續 5 分鐘收不到任何 byte 就中斷請求並回傳失敗。直連官方 API 時預設關閉，但透過自訂 base URL（如本機 Ollama）連線時預設**啟用**。
- 官方文件有對應可關閉此逾時的環境變數 `API_FORCE_IDLE_TIMEOUT`（設 0 停用、設 1 則強制在所有連線啟用，需 Claude Code v2.1.169 以上版本），另有獨立的「整體請求逾時」環境變數 `API_TIMEOUT_MS`，預設 600000 毫秒（10 分鐘），可調大。
- 關鍵釐清：此閒置逾時看的是「連續沉默多久」，不是「總處理時間多久」。模型開始吐出第一個 token 後，只要 token 間隔不超過 5 分鐘，計時器會持續重置、不會中斷。真正的關卡是 **prefill 階段**（模型開始輸出前、後端運算的沉默期）能否在 5 分鐘內結束。
- Claude Code 每次請求固定夾帶 system prompt + 工具 schema 開銷（實測約 26000 tokens 起跳，視啟用的客製化內容多寡而定），此開銷在純 CPU 環境的 prefill 運算耗時可觀，容易卡在 5 分鐘邊界。

**發現 2：實測數據**

- 關閉閒置逾時、整體逾時拉大到 30 分鐘後，完整跑完一次打招呼互動：總耗時約 22 分鐘，模型才吐出完整回覆。
- 未關閉閒置逾時時，多次重複測試中偶爾也會自然成功（未被中斷）——因為多個測試並行搶同一顆 CPU 時，prefill 所需時間會波動，是否剛好撐過 5 分鐘邊界並非每次都發生。代表關閉閒置逾時的意義是「避免 prefill 剛好卡在臨界點時被提前砍斷」，而非「本來必然失敗、關掉才能成功」。
- 對本機 Ollama 同時送出多個並行請求（例如同時開多個測試）會互搶 CPU 資源，拉長每個請求的 prefill 時間，實測時應避免同時並行多個請求。

**結論**

- 純 CPU、無 GPU 加速的硬體上，Claude Code 搭配本機小型模型技術上可行，但單次互動動輒十幾二十分鐘延遲，不具備日常開發互動的實用性，僅適合一次性技術可行性驗證。
- 要讓組合真正好用，需要 GPU 加速（降低 prefill 時間）或大幅縮減 Claude Code 每次請求的固定 prompt 開銷（例如更精簡的 CLAUDE.md、更少客製化內容）。
- 無論哪種情況，都建議保留關閉閒置逾時的設定，避免 prefill 剛好卡在 5 分鐘邊界時被誤判卡死而提前中斷。此設定已加入 `<ollama-world-dir>/Tools/claude-ollama.ps1` 腳本作為預設行為。

**查證方式**

- 先查到一個較舊、已關閉的 GitHub issue，聲稱某逾時環境變數測試無效、需要用二進位檔案 patch 才能繞過；但直接讀取官方文件原文後發現，真正對應此情境的是另一個獨立命名的環境變數 `API_FORCE_IDLE_TIMEOUT`（較新版本才加入，需 Claude Code v2.1.169 以上版本），文件明確寫出「本機模型在 chunk 之間停頓超過 5 分鐘」正是此變數設計要解決的情境。
- 兩份資料表面矛盾，最終以直接讀取官方文件原文為準，而非採信間接摘要或過時的社群討論。

---

## 參考

- [Ollama 官方文件](https://ollama.com)
- [Open WebUI 文件](https://docs.openwebui.com)
- [n8n 文件](https://docs.n8n.io)
- [Continue.dev 文件](https://docs.continue.dev)
- [n8n MCP 整合文件](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-langchain.mcptrigger/)
- [Ollama Anthropic API 相容性文件](https://docs.ollama.com/api/anthropic-compatibility)
- [Claude Code 模型設定文件](https://code.claude.com/docs/en/model-config)
