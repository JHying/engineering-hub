# Playwright MCP × Claude Code：原型頁面 → Spec / Impl KB 自動化工作流

**日期**：2026-07-01  
**關鍵字**：Playwright MCP, Claude Code, AI Engineering, Spec Automation, Prototype, Axshare, Knowledge Base

---

## 問題背景

企劃書通常發佈在 Axshare、Figma Prototype、Notion 等工具，需要登入或特定網址才能存取。
RD 在撰寫 Spec KB 與 Impl KB 時，必須手動對照原型頁面逐步抄寫驗收條件，過程耗時且容易遺漏。

**核心目標：** 讓 Claude Code 直接讀取原型頁面，自動化完成「原型 → 規格差距分析 → KB 生成」的全流程。

---

## 研究結論

### 工具組合

```
Claude Code
  └── Playwright MCP (@playwright/mcp@latest)
        └── Chromium（版本須對應 Playwright 版本）
```

### 安裝與設定

**1. 在 Claude Code 加入 MCP Server（`settings.json`）**

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

**2. 安裝對應版本的 Chromium（關鍵！）**

`@playwright/mcp` 內部鎖定特定 Playwright 版本，Playwright 版本再鎖定 Chromium 版本。
`npx playwright install chromium` 預設安裝最新 Chromium，**版本不符會導致執行失敗**。

正確做法：先確認 MCP 使用的 Playwright 版本，再用對應版本安裝 Chromium。

```bash
# 查看 @playwright/mcp 用哪個 playwright 版本
npx --yes @playwright/mcp@latest --version
# 假設輸出 "playwright: 1.57.0"

# 用對應版本安裝正確的 Chromium
npx playwright@1.57.0 install chromium
```

> **版本鎖定範例（2026-07-01）**：`@playwright/mcp@1.0.12` → `playwright@1.57.0` → `chromium-1200`

---

### 工作流步驟

#### Step 1：開啟原型頁面

若原型需要登入，先在瀏覽器中完成驗證，讓 session cookie 存在。
Playwright MCP 用 headless Chromium，通常不共享瀏覽器 session，可改用帶頭模式或直接提供 share link（Axshare 通常有公開 share link）。

#### Step 2：讓 Claude Code 導覽並讀取

```
# 指令給 Claude（直接說即可）：
用 playwright 去讀 https://xxx.axshare.com/?id=xxx&p=page_name
看還缺什麼功能
```

Claude 會依序使用：
- `playwright_navigate`：開啟頁面
- `playwright_get_visible_text`：提取所有可見文字（包含 AC 條件、流程說明）
- `playwright_screenshot`（可選）：截圖確認視覺佈局

#### Step 3：差距分析

Claude 將原型頁面內容與已知實作（或已有 KB）比對，列出：
- ✅ 已實作
- ⚠️ 部分實作 / 需確認
- ❌ 未實作 / 規格未涵蓋

#### Step 4：生成 KB 文件

依下列格式產出兩份文件：

| 文件 | 說明 | 路徑規範 |
|------|------|---------|
| `{TICKET}.md` | 需求 Spec — AC 條件、資料流、Contract、特殊限制 | `specs/{TICKET}.md` |
| `{TICKET}-impls.md` | 實作 Impl — AC 狀態表、系統流程、待處理清單 | `specs/impls/{TICKET}-impls.md` |

---

### 適用場景

| 場景 | 適合 | 說明 |
|------|------|------|
| Axshare / Figma Prototype share link | ✅ 最佳 | 公開 URL，無需登入 |
| 需密碼的 Axshare share link | ✅ | 在瀏覽器先輸入密碼後，提供帶 token 的 URL |
| Notion / Confluence 公開頁面 | ✅ | 直接讀取 |
| 需 SSO 登入的內部系統 | ⚠️ 有難度 | Playwright headless 不共享 browser session；可嘗試 cookie injection |
| PDF 規格書 | ❌ | 改用 Read tool 讀取 PDF |

---

### 產出品質關鍵

- **頁面選擇精確**：Axshare 每個分頁有獨立 URL（`p=page_name`），先確認要讀哪個分頁
- **提供足夠上下文**：先告知 Claude 目前已實作哪些部分，差距分析才準確
- **逐步驗核**：原型頁面可能有多個分頁，分次讀取後彙整
- **命名對齊**：KB 裡的 Step 名稱應對應原型的章節標題，方便日後追蹤更新

---

## 版本追蹤與已知問題

| 時間 | MCP 版本 | Playwright 版本 | Chromium | 備注 |
|------|---------|----------------|----------|------|
| 2026-07-01 | @playwright/mcp@1.0.12 | 1.57.0 | chromium-1200 | `npx playwright@1.57.0 install chromium` |

---

## 參考

- [Playwright MCP GitHub](https://github.com/microsoft/playwright-mcp)
- KB 格式規範：`demo_KBs/specs/spec-format.md`、`demo_KBs/specs/impls/impls-format.md`
- 應用案例：`demo_KBs/specs/DEMO-002.md` + `demo_KBs/specs/impls/DEMO-002-impls.md`
