---
name: feedback-flow-skill-autosync
description: sdlc-agent 的 flow-*.md 與 skill.md 對應內容須自動同步，不需使用者提醒
metadata:
  node_type: memory
  type: feedback
---

sdlc-agent 的 role-flow 文件（`$KB_ROOT/role-flows/flow-*.md`）與 skill.md（`~/.claude/skills/sdlc-agent/SKILL.md`）的對應 stage 內容互為**同步對**：改動其一（新增/修改某 stage 的步驟、Output、規則）時，另一方**自動一併更新**，並同步 skill.md 的 `version` bump + CHANGELOG.md 條目。**不需使用者每次提醒。**

慣例：清單/規則本體寫在 flow-*.md（單一真相源），skill.md 對應 stage 只**引用 + 列項名**，避免兩處重複維護。

**Why:** 兩份文件描述同一套 pipeline，任一漏更新就會不一致、步驟被漏做（skill.md 的「Output 動作追蹤」會掃 Output 清單）。
**How to apply:** 每次編輯 flow-*.md 或 skill.md 的 stage 內容，收尾前檢查對應方是否需同步；改 skill.md 內容規則必連動 CHANGELOG。相關 [[feedback-sa-jira-writeback]]（同屬 flow↔skill 同步的先例）。
