---
date: 2026-07-02
keywords: Blockchain, DID, Verifiable Credential, Hyperledger Fabric, Ethereum, PKI, 供應鏈金融, 碳足跡, 混合架構
---

# 企業區塊鏈應用架構與技術棧

## 問題背景

評估多種企業區塊鏈應用情境（資料安全儲存、DID 分散式身分識別、供應鏈金融平台、DID 底層數位同意書、DID 證書平台、企業碳足跡上鏈）的現代（2026）開發流程與技術棧選型，並釐清與既有微服務 / DDD 架構知識的對應關係。

## 研究結論

### 共通架構模式：鏈上最小化 + 鏈下系統為主

企業級區塊鏈應用目前主流做法是「鏈下系統為主、鏈上只放最小必要資料」的混合架構，而非把整套系統搬上鏈：

| 階段 | 內容 | 對應既有架構知識 |
|---|---|---|
| 1. 信任模型判斷 | Permissioned（Hyperledger Fabric / Besu、企業聯盟鏈）vs Public L1/L2（Ethereum、Polygon） | 對應是否對外開放的基礎設施決策，見 `ADRs/05-infrastructure/` |
| 2. 合約 / Chaincode 設計 | Solidity（EVM 鏈）或 Fabric Chaincode（Go/Java） | 類似 Domain Service，但需額外考慮 gas cost、不可變性、升級策略（proxy pattern） |
| 3. 鏈下架構不變 | 微服務 + 關聯式/文件資料庫 + 快取 + 訊息佇列照舊，鏈只是多一個外部系統 | 對應 `microservices-decomposition.md`、`message-broker-comparison.md` |
| 4. Chain↔Off-chain 同步 | Event Listener / Indexer 服務監聽鏈上事件並寫回資料庫 | 等同 Save-then-Publish + 訊息消費模式，見 `ADRs/04-messaging/0014-save-then-publish-ordering.md` |
| 5. 金鑰管理 | KMS / HSM 簽署私鑰，不落地明碼 | 對應 `ADRs/07-security/`（Vault Transit Engine 類設計） |
| 6. 部署與可觀測性 | K8s 跑節點或用 BaaS 降低維運負擔；額外監控 gas fee、node sync 狀態 | 對應 `gcp-kubernetes-devops.md`、`ADRs/08-observability/` |

### 個別方案技術棧

**資料安全儲存**：鏈上只存資料 hash（Merkle root），原始資料加密後放去中心化儲存（IPFS/Filecoin）或雲端物件儲存，鏈僅作完整性證明。加解密沿用標準 AES/RSA（見 `cryptography-digital-certificates.md`）。

**DID 分散式身分識別**：標準為 W3C DID Core + Verifiable Credentials（VC）。可類比為去中心化版 PKI/CA——Issuer 簽發、Holder（錢包）持有、Verifier 驗證，結構同既有數位憑證/CA 概念，差異在信任源從單一 CA 變成分散式註冊表。常見底層：did:web / did:key，企業級可用 Hyperledger Aries/Indy。

**供應鏈金融平台**：使用聯盟鏈（Fabric/Besu/Corda），各參與方（金融機構、供應商、買方）各跑一個節點。智能合約編排融資流程（應收帳款融資、貿易確認），可類比為跨組織 Saga，差異在共識機制取代了原本靠訊息佇列 + 補償交易做的信任協調。

**DID 底層數位同意書**：使用者以自身 DID 私鑰簽署同意書，產生 VC 格式文件，時間戳錨定上鏈防抵賴。可類比為 event sourcing 的審計軌跡，差異在「事件」由使用者自己簽署，而非系統簽署。

**DID 證書平台**：Issuer 服務發行 VC（學歷、證照、徽章），搭配鏈上撤銷清單（Status List 2021）。架構上等同分散式 CA，與既有 PKI 結構高度重疊，差異在以 VC 格式取代 X.509。

**企業碳足跡上鏈**：IoT 感測器或 ERP 計算出的碳排資料，經 Oracle 服務彙整後批次錨定上鏈（MRV：量測、報告、驗證），碳權可代幣化（如 ERC-1155 類）。IoT 蒐集端可對應 MQTT 協定知識（見 `http-vs-mqtt-protocols.md`），Oracle 批次彙整邏輯類似既有訊息彙整/批次寫入模式。

## 參考

- `ADRs/04-messaging/0014-save-then-publish-ordering.md`
- `ADRs/05-infrastructure/`
- `ADRs/07-security/`
- `ADRs/08-observability/`
- `tech-research/cryptography-digital-certificates.md`
- `tech-research/microservices-decomposition.md`
- `tech-research/message-broker-comparison.md`
- `tech-research/http-vs-mqtt-protocols.md`
- `tech-research/gcp-kubernetes-devops.md`
