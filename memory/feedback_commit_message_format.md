---
name: feedback-commit-message-format
description: Commit message 格式偏好（通則）— conventional type(TICKET) + 繁體中文業務語句摘要 + bullet list
metadata:
  node_type: memory
  type: feedback
---

Commit message 一律採用以下格式：

```
<type>(<TICKET>): <繁體中文一行摘要，業務功能語句>

  - <變更點1，業務功能語句，繁體中文>
  - <變更點2>
  - ...

  重構：（若本次連帶重構，另起一段，非必要不出現）
  - <重構點1，功能/責任層級的描述，不點名 class/method>
```

**格式細節：**
- `<type>`：conventional commit type（`feat`/`fix`/`refactor`/`chore` 等），依變更性質選擇
- `<TICKET>`：ticket 單號，無單號的雜項清理才省略括號部分
- 摘要與所有 bullet 一律用繁體中文
- bullet 前縮排兩個空格，用 `-` 開頭
- **bullet 內容要寫業務功能語句，不要寫程式細節描述**——不點名改了哪個 class / method / 欄位，改描述「對使用者或系統行為而言改變了什麼」
- 若本次異動包含重構（非行為變更、純內部結構調整），另起「重構：」小節列出，同樣用功能/責任層級語句，不列 class/method 名稱

**Why:** 舊版本此偏好曾誤判為「要點名具體 class/method」，是對單次技術修正 commit 要求的過度解讀。使用者後續明確推翻：commit message 不要程式細節，要業務功能語句；並確認這是通則，套用到所有專案的預設行為。

**How to apply:** 往後在任何專案產生 commit message 時，預設套用「業務功能語句」這個格式。**若使用者針對某個特定專案明確要求不同的 commit message 風格**（例如要求點名 class/method），那是該專案的客製化覆蓋，應存成該專案自己 KB 內的記憶，不要拿來覆蓋這份通則。若使用者要求實際執行 `git commit`（而非只是生成文字），仍需在訊息結尾加上 `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` trailer——這個格式規範只管內容風格，不取代該 trailer 要求。
