---
name: feedback-qa-comment-cleanup
description: sdlc-agent 的 QA stage 判定通過後，需先掃描本輪異動移除多餘註解才算完成
metadata:
  node_type: memory
  type: feedback
---

QA stage 功能正確性判定「通過」後、輸出總結前，需先掃描**本輪異動**（`git diff` 範圍，非全專案）的程式碼註解並移除——**範圍不限於「做什麼」的註解，「為什麼」的解釋性註解（null 語意契約、業務規則、deprecation 理由等）也一併移除**。只保留語言/框架層級硬性要求的標記本身（如 `@deprecated` tag、`// @formatter:off` 這類工具指令），且要去掉其附帶的說明文字，只留最精簡形式。

**Why:** 使用者在某次 pipeline 跑完後補充要求，第一次指示時誤判為「只移除 what、保留 why」，使用者隨後明確糾正「範圍包含解釋為什麼的註解」。已同步寫入 `role-flows/flow-qa.md`「通過後：移除多餘註解」小節，往後每次 pipeline 跑 QA stage 都應自動執行，不需使用者每次提醒。

**How to apply:**
- 適用於 `/sdlc-agent` pipeline 模式與單一角色 QA 模式，QA 判定通過的那一刻就要做，不要等使用者再提一次
- 只掃本次 ticket 的異動範圍，不要順便清理專案裡其他既有程式碼的註解（避免範圍外異動）
- 這與 [[feedback_commit_message_format]] 等其他 QA/收尾類 checklist 屬同一批「pipeline 收尾動作」，未來若有類似「收尾加一步」的指示，優先考慮是否也要同步進 flow-qa.md 或對應 flow 文件，而非只做一次性處理
