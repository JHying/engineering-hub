---
date: 2026-07-03
keywords: Blockchain, DID, Verifiable Credential, Hyperledger Fabric, Web3j, Veramo, 學習地圖, Oracle Pattern
---

# 企業區塊鏈實戰學習地圖

## 問題背景

延續 [enterprise-blockchain-architecture-patterns.md](enterprise-blockchain-architecture-patterns.md) 的六個企業區塊鏈應用情境（資料安全儲存、DID 分散式身分識別、供應鏈金融平台、DID 底層數位同意書、DID 證書平台、企業碳足跡上鏈），規劃一條以既有微服務 / 密碼學基礎（見 [cryptography-digital-certificates.md](cryptography-digital-certificates.md)）為起點、動手實作優先的學習路徑，避免六個方案各自重工。

## 研究結論

### 排序邏輯

依複雜度遞增排序，且後段專案直接複用前段搭好的基礎設施（錢包/金鑰管理、鏈上事件監聽服務）：

```
Project A（公鏈存證）→ Project B（DID/VC）→ Project D（IoT+Oracle）→ Project C（聯盟鏈）
   簡單/單體                身分/憑證核心         資料管線疊加         最複雜/多組織共識
```

### Phase 0 — 銜接補課（2~3 天）

已有 Hash / 非對稱加密 / 數字簽名 / PKI 基礎，只需補區塊鏈特有概念：
- 共識機制對比（PoW / PoS / PBFT）、UTXO vs Account Model、Gas 機制
- 錢包本質 = 私鑰管理（可對應既有 KMS/Vault 概念）
- 驗收：能解釋「為什麼私鑰簽名可以取代 CA」

### Phase 1 — Project A：雜湊存證服務（對應「資料安全儲存」，約 1 週）
- 內容：後端服務算資料 hash → 用 Web3j 呼叫測試網上一個極簡合約寫入 hash → 建 Indexer 監聽事件寫回 DB
- 工具：Solidity + Hardhat/Foundry、Web3j、MetaMask + 測試網水龍頭
- 驗收：竄改資料後重算 hash 應與鏈上記錄不符

### Phase 2 — Project B：自我主權身分 Demo（對應 DID 身分識別 + 數位同意書 + 證書平台，約 1.5 週）
- 內容：Issuer 簽發 Verifiable Credential → Holder 錢包持有（Veramo 或 Hyperledger Aries/ACA-Py）→ Verifier 驗證 + 檢查撤銷清單
  - 同意書場景：使用者自身 DID 簽署 VC 作為同意證明
  - 證書平台場景：機構 Issuer 簽發證照 VC
- 工具：Veramo（TypeScript，上手快）或 Hyperledger Aries/ACA-Py（企業級）
- 驗收：完整演示 Issue → Present → Verify → Revoke 四步

### Phase 3 — Project D：IoT 碳足跡上鏈（約 3~4 天，複用 Phase 1 基礎設施）
- 內容：模擬 MQTT 感測器發碳排數據 → Oracle 服務彙整批次寫入 Phase 1 的合約模式
- 重點：Oracle Pattern（鏈下資料如何可信地上鏈）
- 驗收：展示批次錨定 vs 逐筆上鏈的成本差異

### Phase 4 — Project C：聯盟鏈供應鏈融資（對應「供應鏈金融平台」，最難，約 2 週）
- 內容：Hyperledger Fabric test-network 起 2~3 個組織節點，寫 Chaincode（Go 或 Java）處理應收帳款融資流程
- 重點：多組織背書（endorsement policy）、Channel 隔離、與既有 Saga 模式的差異
- 驗收：模擬買方/供應商/銀行三方節點，展示一筆融資從發起到背書通過的完整流程

### 總覽時程

| 階段 | 時長 | 對應方案數 |
|---|---|---|
| Phase 0 | 2-3 天 | 銜接 |
| Phase 1 | ~1 週 | 1 |
| Phase 2 | ~1.5 週 | 3 |
| Phase 3 | ~3-4 天 | 1 |
| Phase 4 | ~2 週 | 1 |
| **合計** | **約 6 週**（全職節奏，兼職可拉長） | 6/6 |

### 進度追蹤

| 階段 | 狀態 | 完成日期 | 備註 |
|---|---|---|---|
| Phase 0 — 銜接補課 | [ ] 未開始 | | |
| Phase 1 — Project A | [ ] 未開始 | | |
| Phase 2 — Project B | [ ] 未開始 | | |
| Phase 3 — Project D | [ ] 未開始 | | |
| Phase 4 — Project C | [ ] 未開始 | | |

## 參考

- [enterprise-blockchain-architecture-patterns.md](enterprise-blockchain-architecture-patterns.md)
- [cryptography-digital-certificates.md](cryptography-digital-certificates.md)
- [http-vs-mqtt-protocols.md](http-vs-mqtt-protocols.md)
