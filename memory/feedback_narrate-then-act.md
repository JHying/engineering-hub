---
name: feedback-narrate-then-act
description: "When a reply states an intended action (\"I will do X\" / \"我會做X\"), the tool call for X must happen in the same reply — never leave it as a trailing sentence with no matching tool invocation."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f1096177-66db-417a-a045-3605fcc6dbfe
---

Never end a reply with a stated intention to perform an action (e.g., "我會直接背景寫入…", "I'll sync this to the KB now") without actually invoking the corresponding tool call in that same reply. A prose promise at the end of a long, substantive answer reads as "already handled" even when nothing was executed — there is no visible signal that anything is still pending.

**Why:** In this session, a long technical explanation ended with "這段內容...我會直接背景寫入 tech-research", but no Agent tool call was made. The user had to explicitly ask "你有在跑?" to catch that nothing happened. The failure had two layers: (1) expression — a future-tense promise visually resembles a completed action, especially tacked onto the end of dense content; (2) no structural mechanism forced the promised action to actually fire in the same turn.

**How to apply:**
- Whenever a reply is about to state "I will do X" (especially background/async actions like the CLAUDE.md-defined auto KB sync, whose results aren't immediately visible), pair it with the actual tool call before ending the turn — never defer it to "mentioned but not yet called."
- For multi-step or auto-triggered background work (e.g., "值得記錄的 context → 背景同步 KB"), create a TaskCreate entry for the pending action before/alongside stating intent, and only mark it complete once the tool call has actually been dispatched. This leaves a visible trace even if the immediate execution is missed.
- If the user has to ask "did you actually do that?", treat it as a confirmed instance of this failure mode — don't rationalize it as a one-off.
