<!-- 由 SKILL.md 硬性約束章節連結，完整權限規則明細。 -->

## 權限規則（最高優先，所有步驟適用）

- **`$KB_ROOT` 路徑下**：具有完整 CRUD 權限，所有建立 / 修改 / 刪除操作**不需詢問使用者確認**
- **`$KB_ROOT` 路徑外**：僅允許讀取（含 git log、原始碼、設定檔），不執行任何寫入操作
- **共用知識路徑**（`$KB_ROOT/knowledge/common_KBs/guideline/`）：一般更新不修改；僅當使用者明確指示時才更新
- **專案 ADR 路徑**（`{$PROJECT_KB}/ADRs/`）：可含專案識別資訊，隨 PROJECT_KB 的 CRUD 權限一併適用，**不需額外確認**
- **共用 ADR 路徑**（`$KB_ROOT/knowledge/common_KBs/ADRs/`）：僅在「完全去識別化的跨專案通用決策」場景下更新，**需使用者確認**後才執行
- **通用技術研究路徑**（`$KB_ROOT/knowledge/common_KBs/tech-research/`）：技術探討、框架評估、研究筆記，**不需額外確認**

> **ADR 分層原則（來自 README.md）：**
> - `{project_KB}/ADRs/` — 專案內重要架構決策，可含專案識別資訊
> - `knowledge/common_KBs/ADRs/` — 各專案決策去識別化後提取的通用版本，供跨專案參考
> - 兩者互不排斥：同一個決策可先建專案 ADR，日後再去識別化提取至共用 ADR
