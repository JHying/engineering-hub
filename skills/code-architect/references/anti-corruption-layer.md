## Anti-Corruption Layer（外部型別隔離）規則

Domain 層（`..vo..` 下的 VO、`..service.domain..` 下的 DomainService）與其上層（AppService、Controller）不得直接依賴外部系統的原生型別；所有外部型別都必須先在邊界層轉換為專案自訂的 VO，才能往上層流動。

### 禁止依賴清單

Domain 層與其上層不得 import 或依賴：
- gRPC / Protobuf 生成類（package 含 `*.grpc.*`、`*.proto.*`，或類別名稱模式如 `*Grpc`、`*OuterClass`）
- 外部 API 的 request / response 型別（非專案 `..vo..` 套件下、由第三方 SDK 或 API 文件生成的 `*Request`/`*Response`）
- 持久層型別（`..infra.data.entity..` 下的 `*Entity`，或 MongoDB `*Document`）
- 訊息格式原始型別（Kafka event 的原始 payload class，例如未經轉換的 `*Event`／`*Message` schema 類）

### 轉換責任

上述外部型別只能出現在邊界層——依本專案分層即 **Manager**（存取 Infra、呼叫對應 `*Mapper` 完成轉換）與 **Mapper** 本身。DomainService 向 Manager 取得的資料必須已經是 VO；不可讓 Manager 回傳半轉換或原始外部型別，再由 DomainService 自行轉換。

*（此規則對應 REVIEW_GUIDE 2-4 DDD 概念中的 Anti-Corruption Layer 審查點；目前尚無對應 ArchUnit 測試強制外部型別 import，屬 Code Review 階段檢查項，非 CI 保證攔截。）*

### 可 Grep 判準（常見違規訊號）

在 `..service.domain..`（DomainService）或 `..vo..`（VO/DTO）底下的檔案，若 import 出現以下任一模式即為可疑違規，需人工確認是否已透過 Mapper 轉換：

```
import *.grpc.*
import *.proto.*
import *.*Entity;        // 非透過 Mapper 產生的巢狀 VO
import *.*Document;
```

或類別內欄位、方法簽名直接使用 `*Request`、`*Response`（非 `..vo..` 下自訂型別）、`*Event`（未轉換的訊息 payload 原始型別）。

### 範例

```java
// ❌ DomainService 直接依賴外部型別（proto 生成類、持久層 Entity 滲透進 Domain 層）
public class InvoiceDomainService {
    public InvoiceStatusVO checkStatus(InvoiceProto.InvoiceInfo invoice, InvoiceEntity entity) {
        // Domain 層直接操作 gRPC 生成類與持久層 Entity → 違反 ACL
        boolean active = invoice.getStatus() == InvoiceProto.Status.ACTIVE;
        return new InvoiceStatusVO(entity.getInvoiceId(), active);
    }
}

// ✅ 正確：轉換發生在 Manager 邊界，DomainService 只接觸專案自訂的 VO
public class InvoiceDomainService {
    private final InvoiceManager invoiceManager;

    public InvoiceStatusVO checkStatus(String invoiceId) {
        InvoiceVO invoice = invoiceManager.getInvoice(invoiceId); // 已是 VO，非 proto/Entity
        return new InvoiceStatusVO(invoice.getInvoiceId(), invoice.isActive());
    }
}

@Component
public class InvoiceManager {
    public InvoiceVO getInvoice(String invoiceId) {
        InvoiceProto.InvoiceInfo proto = invoiceGrpcClient.getInvoice(invoiceId); // 外部型別止步於 Manager
        InvoiceEntity entity = invoiceRepository.findById(invoiceId).orElseThrow();
        return invoiceMapper.toVO(proto, entity); // 立即轉換，不讓外部型別繼續往上流
    }
}
```
