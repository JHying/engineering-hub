---
name: feedback-scripts-ascii-english
description: "Default script content (comments, strings, output messages) to plain English/ASCII, not Traditional Chinese"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2913343b-97f7-47f4-b4e0-7fe66d3eb7ac
  modified: 2026-07-28T08:17:36.171Z
---

When writing scripts for this user (PowerShell `.ps1` especially, but as a general default for other script types too), default all content to plain English and ASCII-only: comments, string literals, and any text the script itself emits (log lines, hook `systemMessage`/`additionalContext` output, etc.). Avoid embedding Traditional Chinese text or non-ASCII punctuation (em dashes "—", curly quotes, full-width parentheses) in the script file.

**Why:** Windows PowerShell 5.1 defaults stdout to the system ANSI codepage (Big5 on this Traditional-Chinese Windows host) whenever the script isn't attached to a real console — e.g. piped by a hook runner, or invoked via Git Bash. A `.ps1` file without a UTF-8 BOM then gets its non-ASCII bytes misread and the text comes out corrupted, sometimes badly enough to break string-literal parsing entirely. Hit this twice in one session building the SessionStart hooks `check-memory-link.ps1` / `check-project-kb.ps1` in the Knowledge Hub ([[reference_knowledge_base]]) — once with Traditional Chinese message text, once with a single Unicode em dash left inside an otherwise-English string. Pure ASCII sidesteps this whole class of bug regardless of BOM/encoding settings.

**How to apply:** Scoped to script file content only — not a change to how I converse with the user, which stays Traditional Chinese per [[user instructions]]. Confirmed explicitly with the user on 2026-07-28 that this does NOT extend to `~/.claude/settings.json`'s `"language"` field (that governs conversational language and was deliberately left untouched). If a script must display something to the end user directly and English would be actively confusing for that specific case, ask first rather than assuming — but the default, absent other instruction, is English/ASCII.

**Scope is broader than just corruption-prone output.** Initially assumed this only applied to text a script emits through a corruption-prone path (hook `systemMessage`, stdout) and left plain data/doc comments alone (`paths.yml` comments, the Chinese description heredoc `setup-host.ps1`/`.sh` write into `reference_knowledge_base.local.md`) since those aren't "executed and piped" and the KB's docs are otherwise all Chinese. The user corrected this same session: convert those too. So the real default is "no Chinese in anything under `setting/` (or similar script-adjacent tooling), including comments and generated-file content templates" — not narrowly scoped to the encoding-bug rationale. Apply the broader version going forward; ask only if it's ambiguous whether something counts as "script-adjacent" (e.g. actual KB knowledge-content docs under `knowledge/` were never in scope here, only tooling under `setting/`).
