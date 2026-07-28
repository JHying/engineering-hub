# 專案 Participant 設定檔

路徑：與本次圖表**實際輸出目錄**同一目錄下的 `diagram-participants.md`。

- 未使用 `--output` 覆蓋時，預設輸出目錄為 `docs/`，故路徑為 `docs/diagram-participants.md`
- 使用 `--output <完整檔案路徑>` 時（例如呼叫方將圖表輸出到 KB 內的 `{$PROJECT_KB}/source-codex/services/{service}/`），`diagram-participants.md` 跟隨放在**同一目錄**，不固定寫死 `docs/`——參與者設定檔理應與它描述的圖表放在一起，才會在同一次 `/diagram sync` 或後續生成時被正確探索與維護
- 一個專案若在不同目錄下累積多份圖表（例如同時有 `docs/` 下的圖與 KB 內的圖），對應也會有多份 `diagram-participants.md`，各自維護該目錄下圖表用到的 alias，不強制合併

```markdown
<!-- diagram-participants -->
actor User
participant GW as api-gateway
participant SVC as order-service
participant CACHE as redis
participant DB as postgres
participant MQ as kafka
participant EXT as external-api
```

- 生成 / sync 時自動讀取（對應目錄下的那一份），**每次執行**都比對追蹤到的元件，補入尚未收錄的 alias
- 不存在時依追蹤到的元件名稱自動建立初稿並寫入該目錄
- 各專案自行維護此檔，skill 本身不內建任何 alias
