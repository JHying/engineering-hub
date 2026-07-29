# HTTP 契約 groovy 範本


### `_valid.groovy`

```groovy
package contracts.<feature>

import org.springframework.cloud.contract.spec.Contract

Contract.make {
    description "POST /<path> - valid request returns 200"
    request {
        method POST()
        url '/<path>'
        headers {
            contentType(applicationJson())
        }
        body([
            key    : $(consumer(regex(nonBlank())), producer('SOME_KEY')),
            message: [
                action      : $(consumer(regex(nonBlank())), producer('expectedAction')),
                userId      : $(consumer(regex(nonBlank())), producer('user1')),
                optionalField: $(consumer(optional(regex(nonBlank()))), producer('value')),
                amount      : $(consumer(regex('[0-9]+(\\.[0-9]+)?')), producer(100.00))
            ]
        ])
    }
    response {
        status OK()
        headers {
            contentType(applicationJson())
        }
        body([
            status   : 200,
            amount   : 100.00,
            updatedTs: $(consumer('2001-09-09T01:46:40.000+00:00'), producer(regex('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}[+-]\\d{2}:\\d{2}')))
        ])
    }
}
```

### `_invalid.groovy`

```groovy
package contracts.<feature>

// 異常情境：
// 1. key 為空白 → 400, "key can not be empty."
// 2. action 為空白 → 400, "action can not be empty."
// 3. userId 為空白 → 400, "userId can not be empty."
// 4. amount 為 null → 400, "amount can not be empty."
// 5. amount 為負數 → 400, "amount should greater than 0."
// 6. action 錯誤 → 401, "action does not match."
// 7. key 無效 → 401, "Invalid website key."

import org.springframework.cloud.contract.spec.Contract

[
    Contract.make {
        description "POST /<path> - blank key returns 400"
        request { ... }
        response {
            status BAD_REQUEST()
            body([ status: 400, errors: ["MethodArgumentNotValidException", "key can not be empty."], payload: null ])
        }
    },

    // ... 其他 400 情境 ...

    Contract.make {
        description "POST /<path> - wrong action returns 401"
        request {
            body([ key: 'SOME_KEY', message: [ action: 'WRONG_ACTION', ... ] ])
        }
        response {
            status UNAUTHORIZED()
            body([ status: 401, errors: ["AuthenticationException", "action does not match."], payload: null ])
        }
    },

    Contract.make {
        description "POST /<path> - invalid key returns 401"
        request {
            body([ key: 'BAD_KEY', message: [ action: 'expectedAction', ... ] ])
        }
        response {
            status UNAUTHORIZED()
            body([ status: 401, errors: ["AuthenticationException", "Invalid website key."], payload: null ])
        }
    }
]
```

---
