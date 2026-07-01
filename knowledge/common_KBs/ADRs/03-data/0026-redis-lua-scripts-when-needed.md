---
status: "accepted"
date: "2025-04-06"
decision-makers: "Backend / Platform Engineering"
---

# Redis Lua scripts: only for what a native atomic command cannot express

## Context and Problem Statement

Some Redis operations need more than one logical step — check a value, then
conditionally act on it. Done as separate round-trips (a `GET`, then later a
conditional `DEL`, for example), this is not atomic: another client can act
between the two round-trips, on the same key, producing a race. Redis Lua
scripting executes a sequence as one atomic server-side operation, removing the
race — but it is also more to write, test, and reason about than a single
native command. When does a multi-step sequence actually need a script, versus
when is a native command sufficient on its own?

## Decision Drivers

* Correctness: any check-then-act sequence on shared state must be atomic, or
  it is a race condition waiting to happen under concurrent load.
* Simplicity: a single native atomic command is easier to read, test, and
  reason about than a script, and should be preferred whenever it can actually
  express the operation.
* Cluster compatibility: a multi-key script in a clustered deployment requires
  every key it touches to live on the same cluster slot, which has to be
  designed for deliberately.

## Decision Outcome

Chosen option: **use a native atomic command whenever the operation is
genuinely single-step; reach for a Lua script only when the operation requires
multiple logically-dependent steps that a single native command cannot
express.**

| Operation shape | Mechanism | Reason |
|---|---|---|
| Set-if-absent with an expiry, in one call | A native atomic command (e.g. `SET ... NX EX`) | The conditional-set-with-expiry is already a single atomic primitive — no script needed |
| Check-then-conditionally-delete (e.g. release a lock only if you're still the holder) | A Lua script | Two logical steps (check, then delete) with a race window between them if done as separate calls |
| A multi-key check-and-update where the keys must be touched together | A Lua script, with the keys deliberately co-located (the same cluster hash slot) | Atomicity across more than one key is not expressible as a single native command at all |

**The canonical example of the race a script closes:** releasing a lock
correctly requires verifying you still hold it (matching a token you were
given when you acquired it) before deleting it. Done as a plain `GET` followed
later by a `DEL`, another client can acquire the lock in the gap between your
`GET` and your `DEL` — and your `DEL` would then delete *their* lock, not
yours. A Lua script expressing "if the stored value still matches my token,
delete it" as one atomic server-side operation closes that gap entirely; there
is no in-between state another client can observe or act on.

**The cluster-mode prerequisite for multi-key scripts:** a Lua script touching
more than one key only works in a clustered deployment if every key it touches
resolves to the same hash slot — otherwise the script cannot execute, since
Redis Cluster requires all keys in one script invocation to be co-located. Where
a multi-key atomic check is needed, the key naming pattern is designed
deliberately with a shared hash-tag component so the keys land on the same
slot, making the script viable in the first place.

### A deliberate exception: not every check-then-act sequence gets a script

The rule above is not applied dogmatically. One recurring shape — read a cached
value, decide in application code, write the cache — looks like the same race
condition the lock-release case closes, but is deliberately left as plain,
non-atomic Redis calls in one specific situation: when the cache is a
read-through cache in front of an authoritative store that itself enforces
correctness (a unique constraint, a row-level lock — see
[ADR-0012](0012-cross-service-data-ownership-boundaries.md)). If two concurrent
operations race at the cache level there, the authoritative store's own
constraint catches and resolves the conflict, and the cache is corrected on its
next refresh cycle. Spending Lua-script complexity to make a *non-authoritative,
self-healing* cache layer atomic adds cost without adding a correctness
guarantee that does not already exist one layer down. This is the same
discipline as the multi-layer idempotency guard in
[ADR-0015](0015-multi-layer-idempotency-guard.md): identify which layer is
actually authoritative, and spend the atomicity budget there, not on every
layer uniformly.

### Consequences

* Good, because correctness-critical check-then-act sequences are genuinely
  atomic, removing an entire class of race condition that separate round-trips
  cannot avoid.
* Good, because the platform doesn't reach for scripting by default — single-step
  operations stay simple, native commands, easier to read and review.
* Bad, because Lua scripts are harder to unit test and debug than a native
  command call, and that cost is only justified where atomicity actually
  requires it.
* Neutral, because multi-key scripts require deliberate key-naming design
  (shared hash-tag) up front — this has to be planned at the time the key
  pattern is designed, not retrofitted later.

### Confirmation

A code-review rule applies directly: a non-atomic check-then-act sequence
against shared Redis state (e.g. separate `GET` and conditional `SET`/`DEL`
calls) is a blocking finding; it must be a single native atomic command or a
Lua script.

## Pros and Cons of the Options

### Always use separate round-trip calls

* Good, because it requires no scripting knowledge and is the simplest code to
  write.
* Bad, because any check-then-act sequence done this way is a race condition
  under concurrent access — this option is not actually viable wherever
  correctness depends on atomicity.

### Always use Lua scripts, even for single-step operations

* Good, because it is uniformly safe — never accidentally non-atomic.
* Bad, because it adds unnecessary scripting complexity to operations a native
  command already handles atomically on its own, with no correctness benefit.

### Match the mechanism to whether the operation is genuinely multi-step

* Good, because correctness-critical multi-step sequences get real atomicity,
  while simple operations stay simple.
* Bad, because it requires a developer to correctly recognise which category a
  given operation falls into.

## More Information

This decision is the Redis-specific instance of a broader pattern already
established for the lock-release case in particular; the same
check-then-act-atomicity reasoning applies anywhere shared mutable state is read
and conditionally modified under concurrency, not just in Redis.
