# notification-service — 業務邏輯事實

> 機械抽取自 codebase 的業務規則事實。
> 格式：每行一個可查核的 fact，保持 code-like，不寫散文。

---

## 通知冪等保護

```
NotificationEventConsumer.consume(PaymentResultEvent)
  idem_key = "notif:sent:{orderId}:{channel}"
  Redis.get(idem_key) exists → skip（return, offset commit）
  Redis.get(idem_key) not exists → proceed to dispatch
```

## 使用者偏好查詢

```
UserPreferenceService.getPreference(userId)
  → Redis.get("notif:pref:{userId}")
      cache hit  → return preference（EMAIL / SMS / BOTH）
      cache miss → HTTP GET user-service /users/{userId}/preferences
                    HTTP 200  → Redis.set("notif:pref:{userId}", pref, TTL=10m)
                    HTTP 404 or Exception
                      → return DEFAULT_EMAIL（預設值，不 throw）
                      → log warn("user preference not found, fallback to EMAIL: userId={}")
```

## 通知分派規則

```
NotificationDispatcher.dispatch(event, preference)
  preference = EMAIL → EmailNotificationService.send(event)
  preference = SMS   → SmsNotificationService.send(event)
  preference = BOTH  → VirtualThread.ofVirtual().start(EmailNotificationService::send)
                        VirtualThread.ofVirtual().start(SmsNotificationService::send)
                        （兩者並行，各自獨立記錄 NOTIFICATION_LOG）
```

## Email Provider 熔斷降級

```
EmailNotificationService.send(event)
  → CircuitBreaker("email-primary").executeSupplier(
        () → HTTP POST ${notif.email.base-url}/send
    )
    CircuitBreaker OPEN or HTTP non-2xx
      → CircuitBreaker("email-backup").executeSupplier(
            () → HTTP POST ${notif.email.backup-url}/send
        )
        失敗 → INSERT NOTIFICATION_LOG(status=FAILED, channel=EMAIL, error_msg)
               log error（不 throw，不影響 Kafka offset commit）
    成功（任一 provider）
      → INSERT NOTIFICATION_LOG(status=SENT, channel=EMAIL, provider=primary or backup)
      → Redis.set("notif:sent:{orderId}:EMAIL", "1", TTL=1h)
```

## SMS Provider 熔斷降級

```
SmsNotificationService.send(event)
  → CircuitBreaker("sms-primary").executeSupplier(
        () → HTTP POST ${notif.sms.base-url}/send
    )
    CircuitBreaker OPEN or HTTP non-2xx
      → CircuitBreaker("sms-backup").executeSupplier(
            () → HTTP POST ${notif.sms.backup-url}/send
        )
        失敗 → INSERT NOTIFICATION_LOG(status=FAILED, channel=SMS, error_msg)
               log error（不 throw）
    成功
      → INSERT NOTIFICATION_LOG(status=SENT, channel=SMS, provider=primary or backup)
      → Redis.set("notif:sent:{orderId}:SMS", "1", TTL=1h)
```

## 通知模板對應

```
PaymentResultEvent.status → templateId 對應：
  SUCCESS  → templateId = "ORDER_PAYMENT_SUCCESS"
  FAILED   → templateId = "ORDER_PAYMENT_FAILED"
  TIMEOUT  → templateId = "ORDER_PAYMENT_TIMEOUT"
  其他     → templateId = "ORDER_STATUS_UPDATE"（fallback）
```

## CircuitBreaker 設定（Resilience4j）

```
failureRateThreshold = 50        # 50% 失敗率觸發 OPEN
slowCallDurationThreshold = 5s   # 慢呼叫閾值
slowCallRateThreshold = 80       # 80% 慢呼叫觸發 OPEN
waitDurationInOpenState = 30s    # OPEN 後等待 30s 再嘗試 HALF_OPEN
permittedCallsInHalfOpenState = 3
```
