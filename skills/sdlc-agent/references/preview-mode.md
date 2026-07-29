# Step 5-PREVIEW — PREVIEW 模式並行分析（明細）

### Step 5-PREVIEW — PREVIEW 模式並行分析

> 此步驟只在選擇模式 **4. PREVIEW** 時執行。

#### Step M1 — 取得 Story 內容

問使用者：

```
請輸入要分析的 Jira 單號（例：PROJECT-123），或直接貼上 Story 內容：
```

- 若輸入單號格式 → 嘗試用 Jira MCP 拉取 issue 內容；失敗則請使用者貼文字
- 若直接貼文字 → 直接使用

等待使用者提供內容後，進入 M2。

#### Step M2 — 並行派工兩個 Subagent

**在同一個 response 中**同時發出兩個 `Agent` tool call（不等第一個完成才發第二個）。兩個 Agent 呼叫皆須明確指定：
- `subagent_type: general-purpose`
- `model: sonnet`（角色 stage 子代理屬「實作/分析明確規格」等級；調度原則見 `governance/model-dispatch.md` §1，未來調整只改該處）

以下是兩個 subagent 的 prompt 模板，發出前請將所有 `{...}` 替換為實際值：

---

**BACKEND Subagent prompt：**

```
你是 {$PROJECT_KBs 對應的專案名稱} 的 Backend Developer。

## 任務
分析以下 Story，執行 BACKEND 工作流程的 Step 2～Step 4。
不需等待使用者選擇，直接產出方案 A 與方案 B，並在最後標注推薦方案及原因。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 必讀文件（依序讀取）
1. 角色定義：{role_backend 完整路徑}
2. 工作流程：{flow_backend 完整路徑}
3. 通用 KB 主索引：{$KB_ROOT}/knowledge/common_KBs/MASTER_INDEX.md
   → 讀完後依 Story 主題判斷相關的 ADR 分類（01~08）與 tech-research 筆記，只讀取相關項目
4. 專案索引：{$master_indexes 中各 KB 的 MASTER_INDEX.md 完整路徑}

## Story 內容
{story_content}

## 回答規則
- 只能使用 KB 內文件，不可使用訓練資料或推測
- 若 KB 無相關資訊，說明「KB 無此資訊」，不得假設
- 回答結尾附引用來源區塊（格式：📚 參考來源）
```

---

**QA Subagent prompt：**

```
你是 {$PROJECT_KBs 對應的專案名稱} 的 QA Engineer。

## 任務
分析以下 Story，執行 QA 工作流程的 Step 2～Step 4。
不需等待使用者選擇，直接產出測試策略方案 A 與方案 B，並在最後標注推薦方案及原因。

## Knowledge Hub 根路徑
{$KB_ROOT}

## 必讀文件（依序讀取）
1. 角色定義：{role_qa 完整路徑}
2. 工作流程：{flow_qa 完整路徑}
3. 通用 KB 主索引：{$KB_ROOT}/knowledge/common_KBs/MASTER_INDEX.md
   → 讀完後依 Story 主題判斷相關的 ADR 分類（01~08）與 tech-research 筆記，只讀取相關項目
4. 專案索引：{$master_indexes 中各 KB 的 MASTER_INDEX.md 完整路徑}

## Story 內容
{story_content}

## 回答規則
- 只能使用 KB 內文件，不可使用訓練資料或推測
- 若 KB 無相關資訊，說明「KB 無此資訊」，不得假設
- 回答結尾附引用來源區塊（格式：📚 參考來源）
```

---

#### Step M3 — 彙整輸出

等兩個 subagent 都回傳結果後，以以下格式合併輸出：

```
# Multi-Role 分析報告：{Story 標題或單號}

## BACKEND 分析（實作方案）
{BACKEND subagent 輸出}

---

## QA 分析（測試策略）
{QA subagent 輸出}

---

## 下一步
輸入 B  → 繼續 BACKEND Phase 2（產出完整程式碼）
輸入 Q  → 繼續 QA Phase 2（產出完整測試規劃）
輸入 BQ → 同時進行兩者（再次並行）
```

#### Step M4 — 接收使用者指示

- 輸入 `B` → 以 BACKEND 角色繼續，執行 `{{flow_backend}}` Step 5
- 輸入 `Q` → 以 QA 角色繼續，執行 `{{flow_qa}}` Step 5
- 輸入 `BQ` → 再次並行派兩個 subagent（`subagent_type`、`model` 設定比照 Step M2），各自執行對應 Phase 2，完成後彙整輸出
