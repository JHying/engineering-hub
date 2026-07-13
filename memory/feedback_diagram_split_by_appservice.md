---
name: feedback-diagram-split-by-appservice
description: /diagram 生成流程圖時，涉及不同 AppService 的流程不可合併在同一份 flow.md
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f87d7081-1e66-45d4-a739-52936d24a380
---

生成或新增 Mermaid 流程圖時，若一個流程的主要驅動者（entry point 呼叫的第一個 AppService）與另一個流程不同，**不可合併寫入同一份 `*-flow.md`**，即使兩者共用同一個 Controller/WebSocket 入口。每個由獨立觸發事件（WS 訊息類型、Kafka event、生命週期事件如 onOpen/onClose）驅動、且落在不同 AppService 的流程，應各自獨立成檔。

**How to apply:**
- `/diagram <範圍描述>` 生成新流程圖時，追蹤呼叫鏈後檢查：這個流程的主要 AppService 是否已經是另一份既有 flow.md 的主角？若不同，另開新檔，並在兩份文件互相加註參照（如 "偏好設定流程見 xxx-flow.md"）。
- `/diagram sync` 遇到 diff 中出現「新的 WS 訊息類型 / Kafka event / 生命週期事件」且指向新的 AppService 時，同樣要另開新檔，不要塞進被 sync 的既有檔案。
