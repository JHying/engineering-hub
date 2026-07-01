---
date: 2026-06-30
keywords: Spring Boot, Spring Actuator, HikariCP, Tomcat JDBC Pool, Connection Pool, DataSource, Health Check, 健康監測, 自動重連, Spring Retry
---

# Spring Actuator 監測 DB 連線健康狀態與自動重連策略

## 問題背景

Spring Boot 應用在長時間運行後，DB 連線可能因網路中斷、DB 重啟、NAT/防火牆 idle timeout 等原因靜默失效（連線物件存在但已死亡）。需要兩層防護：

1. **可觀測層**：透過 Spring Actuator 即時暴露 DB 健康狀態，供監控系統或 K8s liveness probe 使用
2. **恢復層**：連線失效時自動重建，不需人工重啟，並在業務層提供重試降級

---

## 研究結論

### 一、Spring Actuator Health Endpoint

Spring Boot Actuator 內建 `DataSourceHealthIndicator`，不需額外實作即自動監測 DataSource。

**設定：**

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, metrics, info
  endpoint:
    health:
      show-details: always
      show-components: always
  health:
    db:
      enabled: true
```

**`/actuator/health` 回應範例：**

```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "MySQL",
        "validationQuery": "isValid()"
      }
    }
  }
}
```

**Metrics 監控（需開啟）：**

```yaml
management:
  metrics:
    enable:
      hikaricp: true
```

可觀測指標：
- `hikaricp.connections.active` — 使用中連線數
- `hikaricp.connections.idle` — 閒置連線數
- `hikaricp.connections.pending` — 等待中請求數
- `hikaricp.connections.timeout.total` — 連線 timeout 累計次數

---

### 二、HikariCP 自動重連（Spring Boot 2.x+ 預設 Pool）

HikariCP 透過 **keepalive + connection lifecycle 管理** 實現自動重連，不依賴 JDBC URL 的 `autoReconnect` 參數。

```yaml
spring:
  datasource:
    hikari:
      pool-name: AppPool
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000       # 等待連線最長時間 (ms)
      idle-timeout: 600000            # idle 連線最長閒置時間
      max-lifetime: 1800000           # 連線最長生命週期（建議 < DB 的 wait_timeout）
      keepalive-time: 60000           # 定時送 ping 保持連線
      connection-test-query: SELECT 1 # 借出前驗證（JDBC4 用 isValid()，此項為備援）
      validation-timeout: 5000
      initialization-fail-timeout: -1 # -1 = 啟動時 DB 未就緒不 fail，適合容器環境
```

**關鍵參數說明：**

| 參數 | 用途 |
|------|------|
| `max-lifetime` | 強制回收舊連線，避免 DB 端 timeout 踢掉連線 |
| `keepalive-time` | 主動 ping，防止 NAT/防火牆切斷 idle 連線 |
| `initialization-fail-timeout: -1` | 啟動階段 DB 尚未就緒不報錯（K8s 場景重要） |

---

### 三、Tomcat JDBC Pool 自動重連（Spring Boot 1.x 預設，2.x 需明確指定）

**依賴：**

```xml
<dependency>
    <groupId>org.apache.tomcat</groupId>
    <artifactId>tomcat-jdbc</artifactId>
</dependency>
```

**設定：**

```yaml
spring:
  datasource:
    type: org.apache.tomcat.jdbc.pool.DataSource
    tomcat:
      max-active: 20
      min-idle: 5
      initial-size: 5

      # 驗證（核心重連機制）
      test-on-borrow: true          # 借出前執行 validationQuery
      test-while-idle: true         # 定時驗證 idle 連線
      test-on-return: false         # 返還時不驗證（效能考量）
      validation-query: SELECT 1
      validation-interval: 30000    # 同一連線兩次驗證最短間隔 (ms)

      # Idle 回收
      time-between-eviction-runs-millis: 5000
      min-evictable-idle-time-millis: 60000
      max-age: 1800000              # 連線最長壽命（類似 HikariCP max-lifetime）

      # 廢棄連線處理
      remove-abandoned: true
      remove-abandoned-timeout: 60  # 借出超過 60 秒視為廢棄
      log-abandoned: true           # 記錄廢棄連線 stack trace

      max-wait: 30000
      init-sql: "SET time_zone='+08:00'"
```

**Tomcat Pool 特有：Interceptor 機制**

```yaml
spring:
  datasource:
    tomcat:
      jdbc-interceptors: >
        ConnectionState;
        StatementFinalizer;
        SlowQueryReport(threshold=2000);
        ResetAbandonedTimer
```

| Interceptor | 用途 |
|-------------|------|
| `ConnectionState` | 連線返還時自動還原 autoCommit / readOnly / catalog |
| `StatementFinalizer` | 確保 Statement 一定關閉，防資源洩漏 |
| `SlowQueryReport(threshold=N)` | 記錄超過 N ms 的慢查詢 |
| `ResetAbandonedTimer` | 執行 SQL 時重置廢棄計時器，避免長查詢誤判為廢棄 |

---

### 四、HikariCP vs Tomcat JDBC Pool 比較

| 特性 | Tomcat JDBC Pool | HikariCP |
|------|-----------------|----------|
| Spring Boot 預設 | 1.x | 2.x+ |
| 驗證方式 | `testOnBorrow` + `validationQuery` | `isValid()` 或 `connectionTestQuery` |
| Keepalive | `testWhileIdle` 定時掃描 | `keepalive-time` 主動 ping |
| 連線壽命 | `maxAge` | `max-lifetime` |
| 廢棄連線處理 | `removeAbandoned` | 靠 `max-lifetime` 間接處理 |
| 擴充機制 | **Interceptor（強項）** | 無 |
| 效能 | 良好 | 優於 Tomcat Pool |
| 適用場景 | 需要 Interceptor 插入邏輯 | 一般高效能場景 |

---

### 五、業務層重試：Spring Retry

Pool 層保證連線層重連；業務層若 DataSource 仍拋例外（如 DB 重啟期間短暫不可用），需 Spring Retry 接手。

**依賴：**

```xml
<dependency>
    <groupId>org.springframework.retry</groupId>
    <artifactId>spring-retry</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-aspects</artifactId>
</dependency>
```

**啟用：**

```java
@SpringBootApplication
@EnableRetry
public class Application { ... }
```

**使用：**

```java
@Service
public class UserService {

    @Retryable(
        retryFor = {DataAccessException.class},
        maxAttempts = 3,
        backoff = @Backoff(delay = 1000, multiplier = 2)  // 1s → 2s → 4s
    )
    public User findUser(Long id) {
        return userRepository.findById(id).orElseThrow();
    }

    @Recover
    public User recover(DataAccessException ex, Long id) {
        log.error("DB 重試 3 次仍失敗，id={}", id, ex);
        throw new ServiceUnavailableException("資料庫暫時無法使用");
    }
}
```

---

### 六、自訂 Health Indicator（更細粒度監測）

```java
@Component
public class DatabaseConnectionHealthIndicator implements HealthIndicator {

    @Autowired
    private DataSource dataSource;

    @Override
    public Health health() {
        try (Connection conn = dataSource.getConnection()) {
            if (conn.isValid(2)) {
                return Health.up()
                    .withDetail("validation", "passed")
                    .build();
            }
            return Health.down().withDetail("reason", "connection invalid").build();
        } catch (SQLException e) {
            return Health.down()
                .withException(e)
                .withDetail("error", e.getMessage())
                .build();
        }
    }
}
```

---

### 七、整體架構流程

```
請求進來
  ↓
Connection Pool 借出連線（testOnBorrow / isValid 驗證）
  ├─ 驗證成功 → 正常執行
  └─ 驗證失敗 → 丟棄並重建連線（自動重連）
       ├─ 重建成功 → 正常執行
       └─ 重建失敗 → 拋出 DataAccessException

業務層 @Retryable 攔截
  → 重試 N 次（exponential backoff）
  → 全部失敗 → @Recover 降級

/actuator/health 即時反映 db status: DOWN
背景 keepalive / eviction 執行緒持續維護 Pool 健康
```

---

## 參考

- Spring Boot Actuator Health：`org.springframework.boot.actuate.jdbc.DataSourceHealthIndicator`
- HikariCP 官方文件：https://github.com/brettwooldridge/HikariCP
- Tomcat JDBC Pool 文件：https://tomcat.apache.org/tomcat-9.0-doc/jdbc-pool.html
- Spring Retry：https://github.com/spring-projects/spring-retry
