# SRE 維運邊界

> 定義 SRE 在本專案中的責任範圍，避免模糊地帶造成資訊斷層。

## 責任矩陣

| 項目 | SRE 負責 | SRE 不負責 | SRE 可建議 |
|------|---------|-----------|-----------|
| K8s 部署 / Rollout | ✅ | | |
| ArgoCD 設定與同步 | ✅ | | |
| Kafka topic 建立 / partition 調整 | ✅ | | Partition 數量、retention 設定 |
| DB migration 執行（Prod） | ✅（旁觀確認）| 撰寫 SQL | |
| DB migration 協調停機視窗 | ✅ | | |
| 告警規則配置（AlertManager） | ✅ | | |
| Grafana Dashboard 建立 | ✅ | | |
| 基礎設施（K8s cluster / 網路）| ✅ | | |
| SSL 憑證管理 | ✅ | | |
| Redis / Kafka 日常維運 | ✅ | | |
| DB 日常維運（DBA 職責）| | ✅ | |
| 應用程式業務邏輯 bug fix | | ✅ | |
| API / Kafka topic 設計 | | ✅ | 可建議設計模式 |
| Feature 開發排程 | | ✅ | |
| Config 內容（application.yml 業務參數）| | ✅ | |
| TestContainers / Unit Test 撰寫 | | ✅ | |
| 第三方 Gateway 帳號 / 合約 | | ✅ | |
| Circuit Breaker 閾值調整 | 執行 config 變更 | 決定閾值 | 閾值建議值 |

## 緊急聯絡分工

| 告警類型 | 第一響應 | 升級對象 |
|---------|---------|---------|
| Pod CrashLoop / 無法啟動 | SRE | Backend Team（若非基礎設施問題）|
| Kafka consumer lag 暴增 | SRE + Backend | — |
| DB connection pool 耗盡 | SRE | DBA + Backend Team |
| payment-service Gateway 全失敗 | SRE + Backend | 第三方 Gateway 聯絡窗口 |
| notification 全部失敗 | SRE + Backend | Email / SMS Provider 客服 |
| Redis 全部不可用 | SRE | — |

## On-call 規則

- Prod Critical 告警：On-call SRE 必須在 15 分鐘內響應
- Prod Warning 告警：必須在 1 小時內評估
- Staging 告警：SRE 在正常工時內處理，不 on-call
- Dev 告警：關閉 on-call 通知，開發者自行觀察
