# Tech Research — 技術探討與研究筆記索引

> 記錄技術選型評估、框架研究、跨專案可複用的技術發現。
> 與 ADR 的差異：非正式決策，而是研究過程、實驗結論、技術比較。

---

## 雲端基礎設施

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-26 | GCP 計算服務選擇指南（Serverless → IaaS 分層） | [gcp-compute-service-selection.md](gcp-compute-service-selection.md) | GCP, Cloud Run, App Engine, GKE, Compute Engine |
| 2026-06-26 | GCP 網路與安全架構（VPC、IAM、LB、Cloud Armor、IDS） | [gcp-networking-security.md](gcp-networking-security.md) | GCP, VPC, IAM, NEG, Load Balancer, WAF, DDoS |
| 2026-06-26 | GCP / AWS DNS、CDN 與流量路由策略 | [gcp-aws-dns-cdn-routing.md](gcp-aws-dns-cdn-routing.md) | GCP, AWS, Cloud DNS, Route 53, CloudFront, ALB, CORS |
| 2026-06-27 | Docker 容器化基礎：Container vs VM、網路架構、Image/Dockerfile | [docker-container-fundamentals.md](docker-container-fundamentals.md) | Docker, Container, Image, Dockerfile, VM, Bridge Network, docker compose |

## 系統性能

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-27 | 系統性能指標：RPS / QPS / TPS 定義、公式、關係與 Thread 最佳化 | [system-performance-metrics-rps-qps-tps.md](system-performance-metrics-rps-qps-tps.md) | RPS, QPS, TPS, 併發數, Thread, 吞吐量, 高併發 |
| 2026-06-27 | 高併發設計：指標、悲觀/樂觀鎖、分布式鎖（Redis Redisson）、分庫分表 | [high-concurrency-design.md](high-concurrency-design.md) | 高併發, QPS, 悲觀鎖, 樂觀鎖, 分布式鎖, Redisson, Sharding |
| 2026-06-27 | Redis 快取三大異常情境：穿透、雪崩、擊穿與資料不一致解法 | [redis-cache-failure-patterns.md](redis-cache-failure-patterns.md) | Redis, 快取穿透, 快取雪崩, 快取擊穿, 布隆過濾器, Cache-Aside |
| 2026-07-02 | Netty vs Javax WebSocket 效能實測比較（JMeter 壓測、CPU/記憶體、EventLoop 負載平衡） | [netty-vs-javax-websocket-performance.md](netty-vs-javax-websocket-performance.md) | Netty, Javax WebSocket, Tomcat, JMeter, 效能測試, EventLoop, 負載平衡, C10K |
| 2026-07-07 | 服務過載時的拒絕策略、HTTP 狀態碼語意與熔斷責任分層（Bulkhead、Istio/Envoy vs 應用層） | [overload-rejection-and-circuit-breaking-layers.md](overload-rejection-and-circuit-breaking-layers.md) | ThreadPoolExecutor, Bulkhead, AbortPolicy, CallerRunsPolicy, HTTP 503, HTTP 429, HTTP 502, Istio, Envoy, Resilience4j, Circuit Breaker |

## DevOps / 可觀測性

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-26 | GKE 架構、DevOps 工具鏈與 Service Mesh | [gcp-kubernetes-devops.md](gcp-kubernetes-devops.md) | GCP, GKE, Kubernetes, Istio, CI/CD, Cloud Build |
| 2026-06-26 | AWS 監控與可觀測性策略（CloudWatch、Prometheus、X-Ray、大規模成本估算） | [aws-monitoring-observability.md](aws-monitoring-observability.md) | AWS, CloudWatch, CloudTrail, Prometheus, Grafana, X-Ray |
| 2026-06-27 | Kubernetes 架構元件：Pod、Worker Node、Master Node、Cluster 與 Service 類型 | [kubernetes-architecture.md](kubernetes-architecture.md) | Kubernetes, K8s, Pod, Node, kubelet, kube-apiserver, etcd, kubectl |
| 2026-06-27 | IaC：Ansible 設定管理與 Terraform 基礎設施佈署 | [iac-ansible-terraform.md](iac-ansible-terraform.md) | IaC, Ansible, Terraform, Playbook, Provider, 宣告式, GitOps |
| 2026-06-30 | Spring Actuator 監測 DB 連線健康狀態與自動重連策略（HikariCP + Tomcat JDBC Pool） | [spring-actuator-db-connection-health.md](spring-actuator-db-connection-health.md) | Spring Boot, Spring Actuator, HikariCP, Tomcat JDBC Pool, Connection Pool, DataSource, Health Check, Spring Retry, 自動重連 |
| 2026-07-04 | WebSocket 使用 OTEL Baggage 傳遞版本號並整合 Istio 版本路由（自建 Spring AOP 工具補齊追蹤缺口） | [websocket-otel-baggage-version-routing.md](websocket-otel-baggage-version-routing.md) | WebSocket, OpenTelemetry, OTEL, Baggage, Istio, 版本路由, Canary, Spring AOP, Distributed Tracing |

## 資料與分析

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-26 | GCP 資料儲存與分析服務選擇（Cloud SQL、BigQuery） | [gcp-data-analytics.md](gcp-data-analytics.md) | GCP, Cloud Storage, Cloud SQL, BigQuery, OLTP, OLAP |
| 2026-06-27 | OLTP vs OLAP 與 ACID 四大特性 | [oltp-vs-olap.md](oltp-vs-olap.md) | OLTP, OLAP, ACID, 資料倉庫, BigQuery, ETL, 列式儲存 |
| 2026-06-27 | DB Cluster 讀寫分離與 Data Sharding 三大策略 | [db-sharding-cluster.md](db-sharding-cluster.md) | Sharding, 分庫分表, 讀寫分離, Hash-based, Range-based, Master-Slave |
| 2026-06-27 | NoSQL vs RDBMS 選型：CAP 定理、MongoDB vs Oracle 適用場景 | [nosql-vs-rdbms.md](nosql-vs-rdbms.md) | NoSQL, RDBMS, CAP, MongoDB, Oracle, 選型, 分散式 |

## 應用整合

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-26 | Firebase FCM 推播通知與即時聊天室（Server + Android + Realtime DB） | [firebase-fcm-push.md](firebase-fcm-push.md) | Firebase, FCM, Push Notification, Realtime Database, Android, Spring Boot |
| 2026-06-27 | Message Broker 選型（RabbitMQ / Kafka / RocketMQ）與 RabbitMQ AMQP 核心概念 | [message-broker-comparison.md](message-broker-comparison.md) | Message Broker, RabbitMQ, Kafka, AMQP, Exchange, Queue, 解耦, 削峰 |
| 2026-06-27 | Redis 核心概念：資料結構、快取設計、Cluster 架構與 Hash Slot | [redis-fundamentals.md](redis-fundamentals.md) | Redis, In-Memory, Cache Stampede, Consistent Hash, Cluster, Gossip, Hash Slot |
| 2026-07-04 | WebSocket API 文件自動生成：選型比較（AsyncAPI/Springwolf/Postman）與 Jakarta WebSocket + API Gateway 整合架構 | [websocket-api-doc-generation.md](websocket-api-doc-generation.md) | WebSocket, API 文件生成, AsyncAPI, Springwolf, STOMP, Jakarta WebSocket, Swagger, API Gateway |
| 2026-07-12 | 訊息協議 vs 自有協議平台：MQTT/STOMP/AMQP、Kafka 與 Redis Pub/Sub | [messaging-protocols-vs-platforms.md](messaging-protocols-vs-platforms.md) | MQTT, STOMP, AMQP, Kafka, RabbitMQ, Redis Pub/Sub, Redis Streams, 訊息佇列, 選型 |

## 網路基礎

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-27 | 網路協議棧：DNS、CDN 加速原理、OSI/TCP/IP 分層與 TLS | [network-protocol-stack.md](network-protocol-stack.md) | OSI, TCP/IP, DNS, CDN, TLS, HTTPS, 三次握手, DDoS, VIP, L4/L7, WebSocket, STOMP |
| 2026-06-27 | 密碼學基礎：Hash、對稱/非對稱加密、數字簽名與 CA 憑證 | [cryptography-digital-certificates.md](cryptography-digital-certificates.md) | Hash, AES, RSA, 數字簽名, 數字證書, CA, JWT, PKI |
| 2026-06-27 | HTTP vs MQTT：應用層通訊協議比較（IoT 選型、QoS、Pub/Sub） | [http-vs-mqtt-protocols.md](http-vs-mqtt-protocols.md) | MQTT, HTTP, IoT, Pub/Sub, QoS, Broker, Topic, 低功耗, 即時通訊 |

## 架構設計

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-27 | 微服務架構：拆分原則、Gateway 聚合模式與 12-Factor | [microservices-decomposition.md](microservices-decomposition.md) | 微服務, DDD, Bounded Context, 康威定律, Gateway, Edge Pattern, 12-Factor |
| 2026-06-27 | OOP 三大特性、SOLID 五大原則、Strategy Pattern 與 Clean Code | [oop-solid-design-patterns.md](oop-solid-design-patterns.md) | OOP, SOLID, SRP, OCP, LSP, ISP, DIP, Strategy Pattern, Clean Code |
| 2026-06-27 | 企業分層架構物件模式：POJO / DTO / VO / DAO / BO 定義與轉換關係 | [enterprise-object-layer-patterns.md](enterprise-object-layer-patterns.md) | POJO, JavaBean, PO, DTO, VO, DAO, BO, 分層架構, ORM, 持久層 |
| 2026-06-27 | UML 圖表應用與 OOAD 系統分析設計（OOA / OOD / USDP 迭代模型） | [uml-ooad-system-analysis.md](uml-ooad-system-analysis.md) | UML, OOAD, Use Case, Class Diagram, Activity Diagram, Sequence Diagram, USDP, 迭代開發 |
| 2026-06-27 | IoC、DI 與 AOP：控制反轉、依賴注入、切面、Bean 生命週期與 Scope；含 JVM 記憶體模型 / final JMM happens-before 保證 | [ioc-di-aop-patterns.md](ioc-di-aop-patterns.md) | IoC, DI, AOP, Bean, Bean Lifecycle, Bean Scope, Singleton, Prototype, Aspect, Pointcut, Advice, JVM, Stack, Heap, final, JMM, happens-before, Constructor 注入, Field 注入 |
| 2026-06-27 | ORM、JPA 與 Spring Data JPA：持久層技術棧與 Repository 體系 | [orm-jpa-spring-data.md](orm-jpa-spring-data.md) | ORM, JPA, Hibernate, Spring Data JPA, Entity, Repository, CrudRepository, 物件關聯對映 |
| 2026-06-27 | JVM 記憶體模型：Stack / Heap / String Pool、GC 與 Singleton vs Static | [jvm-memory-model.md](jvm-memory-model.md) | JVM, Stack, Heap, String Pool, Primitive Type, Reference Type, GC, Singleton, Thread |
| 2026-06-27 | Java 併發與執行緒安全：Thread、Thread Pool、Executor 體系與同步機制 | [java-concurrency-thread-safety.md](java-concurrency-thread-safety.md) | Thread, Process, Concurrency, Thread Safety, synchronized, ConcurrentHashMap, Thread Pool, ExecutorService, Executor |
| 2026-07-02 | Netty 執行緒模型與開發手冊：BIO/NIO/AIO 比較、主從 Reactor、BossGroup/WorkerGroup/EventLoop | [netty-reactor-thread-model.md](netty-reactor-thread-model.md) | Netty, BIO, NIO, AIO, Reactor 模型, BossGroup, WorkerGroup, EventLoop, ChannelPipeline, ByteBuf, IdleStateHandler |
| 2026-07-02 | Java NIO 核心元件：Buffer / Channel / Selector 深入與零拷貝（mmap / sendFile / DMA） | [nio-buffer-channel-selector-zero-copy.md](nio-buffer-channel-selector-zero-copy.md) | Java NIO, Buffer, Channel, Selector, SelectionKey, 零拷貝, mmap, sendFile, DMA, C10K |
| 2026-07-02 | Reactor 模式三種實現方式比較：單 Reactor 單/多線程、主從 Reactor 多線程 | [reactor-pattern-thread-models.md](reactor-pattern-thread-models.md) | Reactor 模式, 單 Reactor 單線程, 單 Reactor 多線程, 主從 Reactor 多線程, Dispatcher, I/O 多路複用 |
| 2026-07-02 | Netty 編解碼器與 TCP 粘包/拆包解決方案：Protobuf、ByteToMessageDecoder、LengthFieldBasedFrameDecoder | [netty-codec-and-tcp-sticky-packet.md](netty-codec-and-tcp-sticky-packet.md) | Netty, Codec, ByteToMessageDecoder, ReplayingDecoder, LengthFieldBasedFrameDecoder, TCP 粘包, TCP 拆包, Protobuf |
| 2026-07-02 | Netty 參考書籍導覽（章節地圖）：《Netty 实战》與《Netty 权威指南 第2版》 | [netty-book-reading-guide.md](netty-book-reading-guide.md) | Netty, Netty in Action, Netty 权威指南, 書籍導覽, 原始碼分析, 高性能之道 |
| 2026-06-29 | Java Sealed Interfaces 與 Pattern Matching：多態回傳型別建模、窮舉性保證與引入條件 | [java-sealed-interfaces-pattern-matching.md](java-sealed-interfaces-pattern-matching.md) | Sealed Interface, Pattern Matching, switch expression, JDK 17, JDK 21, 多態回傳型別, 窮舉性 |
| 2026-07-03 | JSP/Servlet + Quartz + 傳統 JDBC Web 應用遷移至 Spring Boot：分層架構對比、Servlet 重構 9 步驟 | [servlet-jsp-to-springboot-web-migration.md](servlet-jsp-to-springboot-web-migration.md) | Spring Boot, JSP, Servlet, Quartz, log4j2, Spring Data JPA, 分層架構重構, SpringBootServletInitializer, Connection Pool |
| 2026-07-04 | 從零建置技術基礎設施：治理骨幹決策與任務拆解方法論（微服務治理骨幹、平台工程雙案例） | [infra-buildout-governance-methodology.md](infra-buildout-governance-methodology.md) | 微服務治理骨幹, 平台工程, Spring Cloud, Vault, Kubernetes, GitOps, 任務拆解, 架構決策 |
| 2026-07-05 | Spring AOP 代理機制、Processor 體系（執行期/編譯期）與 WebSocket @OnOpen 時序陷阱 | [spring-aop-processor-mechanism-and-websocket-lazy-timing.md](spring-aop-processor-mechanism-and-websocket-lazy-timing.md) | Spring AOP, JDK Dynamic Proxy, CGLIB, BeanPostProcessor, BeanFactoryPostProcessor, AspectJ, Compile-Time Weaving, Load-Time Weaving, Jakarta WebSocket, ServerEndpoint, SpringConfigurator, @Lazy, self-invocation |
| 2026-07-12 | Consul Headless Service 與 Istio 不導流的節點故障事故（StatefulSet DNS 拓樸、Passthrough Cluster、Failover 責任歸屬） | [consul-headless-service-istio-routing-gap.md](consul-headless-service-istio-routing-gap.md) | Consul, Helm, Headless Service, StatefulSet, Istio, Envoy, PassthroughCluster, Service Discovery, Kubernetes, DNS, Failover |
| 2026-07-13 | `@Transactional` 放置層級與連線池成本排序的決策脈絡（self-invocation 修法比較、分層交易邊界、優先序） | [transactional-boundary-placement-tradeoffs.md](transactional-boundary-placement-tradeoffs.md) | Spring, AOP, Transactional, self-invocation, 連線池, 交易邊界, HikariCP, TransactionTemplate, AspectJ |

## 區塊鏈 / 分散式帳本

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-07-02 | 企業區塊鏈應用架構與技術棧：資料儲存、DID、供應鏈金融、數位同意書、證書平台、碳足跡上鏈 | [enterprise-blockchain-architecture-patterns.md](enterprise-blockchain-architecture-patterns.md) | Blockchain, DID, Verifiable Credential, Hyperledger Fabric, Ethereum, PKI, 供應鏈金融, 碳足跡, 混合架構 |
| 2026-07-03 | 企業區塊鏈實戰學習地圖：4 個專案分階段吃透 6 個應用情境，含進度追蹤 | [enterprise-blockchain-learning-roadmap.md](enterprise-blockchain-learning-roadmap.md) | Blockchain, DID, Verifiable Credential, Hyperledger Fabric, Web3j, Veramo, 學習地圖, Oracle Pattern |

## 資訊安全

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-30 | 常見 Web 攻擊方式全覽（XSS、CSRF、SQL Injection、DDoS、MITM、Phishing、Broken Authentication） | [web-security-attacks-overview.md](web-security-attacks-overview.md) | XSS, CSRF, SQL Injection, DDoS, MITM, Phishing, Broken Authentication, Web Security, 資安 |

## 前端開發

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-27 | 前端資安與非同步處理：CSRF、Cookie/Storage 比較、Token 儲存策略、async/await | [frontend-web-security.md](frontend-web-security.md) | CSRF, XSS, Cookie, LocalStorage, SessionStorage, HttpOnly, Bearer Token, Promise, async/await |

## AI 工具

| 日期 | 主題 | 檔案 | 關鍵字 |
|------|------|------|--------|
| 2026-06-27（更新 2026-07-20） | 本地 LLM 開發環境建置（Windows + Docker + Ollama + Open WebUI + n8n + Continue.dev；含 Claude Code CLI 串接本機 Ollama） | [local-llm-dev-environment.md](local-llm-dev-environment.md) | LLM, Ollama, Open WebUI, n8n, Continue.dev, Docker, Windows, 本地推論, Claude Code |
| 2026-06-27 | n8n × LLM：AI 自動化工作流設計（AI Agent、RAG、MCP、本地 LLM 整合、進階檢索策略） | [n8n-ai-workflow-automation.md](n8n-ai-workflow-automation.md) | n8n, AI Agent, Workflow, RAG, MCP, Webhook, Schedule Trigger, LM Studio, Tavily, FAISS, Query Rewriting, HyDE, Multi-Query |
| 2026-07-01 | Playwright MCP × Claude Code：原型頁面 → Spec / Impl KB 自動化工作流（Axshare、版本對齊、差距分析） | [playwright-mcp-spec-to-kb-workflow.md](playwright-mcp-spec-to-kb-workflow.md) | Playwright MCP, Claude Code, AI Engineering, Spec Automation, Prototype, Axshare, Knowledge Base |

---

## 筆記格式範本

```markdown
# [技術主題]

**日期**：YYYY-MM-DD  
**關鍵字**：（框架名稱、技術名稱）

## 問題背景

（要解決的問題或評估的情境）

## 研究結論

（發現、比較結果、推薦方向）

## 參考

（文件連結、相關 ADR）
```
