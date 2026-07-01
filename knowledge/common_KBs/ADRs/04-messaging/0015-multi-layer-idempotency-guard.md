---
status: "accepted"
date: "2025-04-14"
decision-makers: "Backend / Platform Engineering"
---

# Multi-layer idempotency guard

## Context and Problem Statement

At-least-once event delivery ([ADR-0014](0014-save-then-publish-ordering.md))
means the same logical operation can arrive more than once: a retried client
request, a redelivered Kafka message after a pod restart, or the same event
reaching two pods concurrently. A duplicate that reaches the database is, at
best, wasted load, and at worst, a correctness bug (double-charging,
double-counting). Where should deduplication happen, and is one layer enough?

## Decision Drivers

* Every duplicate that reaches the database is unnecessary load at volume — the
  goal is to catch most duplicates before they get that far.
* A single layer's specific weakness (e.g. a cache that expires, a service
  that's briefly unavailable) must not become a correctness hole.
* The guarantee must hold even if one layer is degraded, not just in the happy
  path.

## Considered Options

* **Database-only deduplication** (a unique constraint, checked on every write).
* **Cache-only deduplication** (a fast distributed lock/flag, no DB-level
  backstop).
* **A graduated, multi-layer guard** — a local in-process cache, then a
  distributed cache lock, then a database constraint, each catching a
  different class of duplicate.

## Decision Outcome

Chosen option: **a graduated, multi-layer guard**, with three layers, each
eliminating a different class of duplicate so that the most expensive
operations are not reached unnecessarily:

| Layer | Mechanism | Catches |
|-------|-----------|---------|
| L1 — Local in-process cache | An update-if-newer check against a short-lived local cache | The same event re-delivered to the same pod within a short window |
| L2 — Distributed lock | A `SET`-if-not-exists style atomic lock keyed by a request identifier, short TTL | The same event delivered to two different pods concurrently |
| L3 — Database constraint | A uniqueness constraint enforced at insert time, with the conflict caught and treated as a no-op | Races where the L2 lock expires before the operation completes, or redelivery after a pod restart clears L1/L2 state |

Database-only deduplication was rejected as the *sole* layer because, at
volume, every duplicate — not just the rare genuine one — would still hit the
database to be rejected, which is exactly the unnecessary load the earlier
layers exist to avoid. Cache-only deduplication was rejected because a cache
entry's TTL expiring, or the cache being briefly unavailable, would silently
remove the only protection in place; the database constraint is what makes the
guarantee hold even when the faster layers fail, not just when they succeed.

### Consequences

* Good, because most duplicates are caught at L1/L2, before they generate any
  database load.
* Good, because the guarantee holds under degradation: if the distributed cache
  is unavailable, L3 is still the authoritative backstop and no duplicate can
  silently corrupt data; if only the local cache misses, L2 still catches it.
* Good, because no single point of failure removes deduplication entirely — each
  layer's specific weakness is covered by the next.
* Bad, because there are three places where deduplication logic can have a bug,
  rather than one; each layer needs to be correctly implemented and tested
  independently.

### Confirmation

A new write path that can receive duplicate or redelivered requests implements
all three layers, not just the cheapest one that "usually works"; the database
constraint is non-negotiable even when L1/L2 make it rarely triggered in
practice.

## Pros and Cons of the Options

### Database-only deduplication

* Good, because it is the simplest to implement and is always correct as a
  final backstop.
* Bad, because every duplicate, common or rare, pays the full cost of a
  database round-trip and constraint check.

### Cache-only deduplication

* Good, because it is fast and removes load from the database for the common
  case.
* Bad, because a TTL expiry or cache outage silently removes the only
  protection — no backstop exists if the cache layer fails.

### A graduated, multi-layer guard

* Good, because each layer's weak point is covered by the next, and the common
  case is handled cheaply while the rare/degraded case still cannot corrupt
  data.
* Bad, because of the added implementation and testing surface of three
  coordinated layers instead of one.

## More Information

This pattern is the consumer-side counterpart to
[ADR-0014](0014-save-then-publish-ordering.md): because event delivery is
at-least-once rather than exactly-once, this graduated guard is what makes
that weaker delivery guarantee safe to build on.
