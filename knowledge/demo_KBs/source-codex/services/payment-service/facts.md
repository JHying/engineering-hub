# payment-service — 業務邏輯事實

> 機械抽取自 codebase 的業務規則事實。
> 格式：每行一個可查核的 fact，保持 code-like，不寫散文。

---

## 付款冪等保護

```
OrderCreatedEventConsumer.consume(OrderCreatedEvent)
  → DB check: PAYMENT_IDEMPOTENCY WHERE order_id = event.orderId
      row exists → skip（return, offset commit）
      row not exists
        → INSERT PAYMENT_IDEMPOTENCY(order_id, payment_id, created_at)
            INSERT fails (duplicate key) → skip（並發場景防護）
        → INSERT PAYMENTS(status=INITIATED, amount, order_id, user_id)
        → Redis.set("payment:idem:{orderId}", paymentId, TTL=24h)
        → PaymentGatewayService.charge(paymentId, amount)
```

## Gateway 呼叫分支

```
PaymentGatewayService.charge(paymentId, amount)
  → HTTP POST ${payment.gateway.base-url}/charge
      timeout = 30s
      HTTP 200, body.success = true
        → UPDATE PAYMENTS SET status=SUCCESS, gateway_tx_id=body.txId
        → Redis.set("payment:status:{orderId}", "SUCCESS", TTL=30m)
        → KafkaProducer.send("payment-result", {status:SUCCESS})
      HTTP 200, body.success = false
        → UPDATE PAYMENTS SET status=FAILED, gateway_code=body.errorCode
        → Redis.set("payment:status:{orderId}", "FAILED", TTL=30m)
        → KafkaProducer.send("payment-result", {status:FAILED})
      HTTP non-200 or ConnectTimeout
        → UPDATE PAYMENTS SET status=TIMEOUT
        → Redis.set("payment:gateway-pending:{orderId}", paymentId, TTL=5m)
        （不發 payment-result，等補償排程查詢後再發）
```

## 重試限制規則

```
PaymentRetryService.validateRetry(orderId)
  → SELECT retry_count, status FROM PAYMENTS WHERE order_id=orderId
      status = SUCCESS                  → throw PaymentAlreadySuccessException → HTTP 409
      status = PROCESSING               → throw PaymentInProgressException → HTTP 409
      retry_count >= 3                  → throw MaxRetryExceededException → HTTP 409
      status = FAILED or TIMEOUT
        and retry_count < 3             → UPDATE retry_count + 1, status=INITIATED
                                          → re-invoke PaymentGatewayService.charge()
```

## 逾時補償排程

```
GatewayTimeoutCompensationScheduler（@Scheduled fixedDelay=300_000ms）
  → Redis.scan("payment:gateway-pending:*")
      for each key:
        orderId = extract from key
        → HTTP GET ${payment.gateway.base-url}/query?orderId=orderId
            HTTP 200, body.status = SUCCESS
              → UPDATE PAYMENTS SET status=SUCCESS, gateway_tx_id=body.txId
              → Redis.del("payment:gateway-pending:{orderId}")
              → KafkaProducer.send("payment-result", {status:SUCCESS})
            HTTP 200, body.status = FAILED
              → UPDATE PAYMENTS SET status=FAILED, gateway_code=body.errorCode
              → Redis.del("payment:gateway-pending:{orderId}")
              → KafkaProducer.send("payment-result", {status:FAILED})
            HTTP 404（Gateway 查無記錄）
              → UPDATE PAYMENTS SET status=FAILED, gateway_code=GATEWAY_RECORD_NOT_FOUND
              → Redis.del("payment:gateway-pending:{orderId}")
              → KafkaProducer.send("payment-result", {status:FAILED})
            Exception
              → log error, skip（TTL 到期後 key 自動消失）
```

## 付款狀態快取規則

```
payment:status:{orderId} TTL = 30m
寫入時機：Gateway 呼叫完成（SUCCESS 或 FAILED）
讀取方：api-gateway（GET /payments/{orderId}）
快取 miss 時：從 PAYMENTS 表讀取並回寫 Redis（Cache-Aside）
```
