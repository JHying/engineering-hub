# CI/CD Pipeline

## Repository 對應

| Repo | 用途 |
|------|------|
| `cicd-build` | Jenkins Pipeline 定義（Jenkinsfile + Dockerfile）+ Shared Libs |
| `gitops-deploy` | GitOps 部署宣告（Kustomize base + overlays） |
| `config-server` | Spring Cloud Config 設定檔（各環境） |
| 各 service repo | 應用程式碼 + `docs/db/` DB 異動腳本 |

## CI Pipeline 流程（`{service}-ci-pipeline`）

| Stage | 說明 | 失敗行為 |
|-------|------|---------|
| Determine CI Mode & Branch | 判斷 MR / Push，解析目標 branch | block |
| Check DB Script Files | 偵測 `docs/db/` 下是否有 `.sql` / `.js` | 無檔案則 skip |
| DB Lint | sqlfluff（Oracle SQL）/ JS schema 格式驗證 | block |
| Build & Unit Test | Maven test（含 TestContainers 整合測試） | block |
| SonarQube Analysis | 靜態分析 + Code Coverage | block |
| Quality Gate | SonarQube Quality Gate（等待結果，逾時 3min）| block |
| Trigger CD | `DEPLOY_ELIGIBLE=true` 時自動觸發 CD Pipeline | — |

## CD Pipeline 流程（`{service}-cd-pipeline`）

| Stage | 說明 |
|-------|------|
| Init Common Env | 載入 Registry URL、Config repo 等共用環境變數 |
| Determine Branch & Profile | 解析 branch → 決定 Maven profile / ArgoCD overlay |
| Build Docker Image | Maven package → Docker build → push Harbor Registry |
| Update GitOps Repo | 更新 `gitops-deploy` 對應 overlay 的 image tag |
| Wait ArgoCD Deployment | 輪詢 ArgoCD API 確認 Rollout 完成（逾時 10min）|

## Branch → 環境對應

| Branch pattern | 部署環境 | overlay 路徑 |
|----------------|---------|-------------|
| `develop` | dev | `overlays/dev/{service}/develop/` |
| `feature/{ticket}` | dev（個人分支） | `overlays/dev/{service}/feature-{ticket}/` |
| `release/*` | staging | `overlays/staging/{service}/` |
| `main` | prod | `overlays/prod/{service}/` |

## Harbor Registry

| 環境 | Registry URL |
|------|-------------|
| DEV | `registry.internal.example.com:80` |
| STAGING / PROD | `registry.example.com`（需 mTLS 憑證）|

## Shared Libs（`platform-pipeline-libs`）

| 函式 | 用途 |
|------|------|
| `commonEnv()` | 初始化共用環境變數 |
| `determineCiContext()` | 判斷 CI 觸發模式與 branch |
| `determineBranchProfile()` | branch → Maven profile / overlay 對應 |
| `checkDbScriptFiles()` | 偵測 DB 腳本是否存在 |
| `runDbLint()` | 執行 sqlfluff DB lint |
| `runVerification()` | Maven test + TestContainers |
| `runSonarAnalysis()` | SonarQube 分析 |
| `qualityGate()` | 等待 Quality Gate 結果 |
| `buildAndPushDockerImage()` | Docker build + push Harbor |
| `updateGitOpsRepo()` | 更新 gitops-deploy image tag |
| `waitArgoDeployment()` | 輪詢 ArgoCD 部署完成 |
| `notifySlack()` | 部署成功 / 失敗 Slack 通知 |
