---
name: project-state-goes-to-kb
description: 專案範圍的狀態/決策/工作紀律持久化進該專案 KB，不寫入個人記憶
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5f40493f-b3ed-48db-a919-f631718f59d3
---

專案範圍的內容——進度快照、已定案決策、下一步、專案內工作紀律——一律持久化到該專案 KB（MASTER_INDEX 進度快照節＋pending/logs/），**不要寫成個人記憶**。個人記憶只放跨專案的使用者偏好與工作方式回饋。

**Why**：使用者明確指正（2026-07-18，專案專屬的兩條記憶被退回）：專案 KB 才是專案狀態的單一事實來源；記憶重複記錄會漂移、也污染每個 session 的載入內容。

**How to apply**：收工要「記下來」時，寫進該專案 KB 的 MASTER_INDEX 進度快照節；下個 session 靠 KB 目錄名對上專案，開場先讀 MASTER_INDEX。想寫 project 類記憶前先自問：這件事離開此專案還成立嗎？不成立就進 KB。
