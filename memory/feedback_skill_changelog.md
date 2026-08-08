---
name: feedback-skill-changelog
description: 每次修改 skill 的 SKILL.md 都必須同步更新對應的 CHANGELOG.md，這是使用者明確要求的工作流規則
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 84b4dafd-ddf9-4c3e-b969-d6b566698ad8
  modified: 2026-08-08T09:12:52.389Z
---

每次修改任何 skill 的 SKILL.md 時，必須在同一個 session 內同步更新該 skill 目錄下的 CHANGELOG.md。

**Why:** 使用者希望所有 skill 的異動都有記錄可追溯，CHANGELOG 是 skill 演進的正式紀錄文件。

**How to apply:** 凡是對 `skills/<skill-name>/SKILL.md` 做任何修改（新增功能、調整流程、去識別化等），完成後立即更新 `skills/<skill-name>/CHANGELOG.md`，加入對應版本條目（版本號、日期、Added/Changed/Removed 清單）。CHANGELOG 本身也需去識別化：不只是不含專案名稱/ticket 編號/真實類別名稱，Context/起因段落也不能寫得太具體——不敘述「誰做了什麼、因為內容含有什麼真實資訊」這類敘事細節，一律改寫成結構性、抽象化的理由描述。2026-08-08 使用者明確要求所有 git-tracked CHANGELOG 都比照此標準維護，已同步寫入 CLAUDE.md「Skill 開發規範」。
