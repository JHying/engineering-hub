---
status: "accepted"
date: "2025-04-12"
decision-makers: "Backend / Platform Engineering"
---

# Ordering event delivery after the write that causes it

## Context and Problem Statement

Several flows write a state change and then publish an event announcing it. If
the event becomes visible to consumers before the write that caused it is
durable, a consumer can act on a fact that the system itself has not yet
committed to — and if the write actually fails, a published event describing
something that never happened is worse than no event at all. How is the
ordering between "the write happened" and "consumers can see the event"
guaranteed?

## Decision Drivers

* A consumer must never observe an event for a write that did not actually
  succeed.
* The mechanism should not require new infrastructure if a lighter guarantee is
  sufficient for the actual delivery semantics already in place (at-least-once
  with idempotent consumers).
* Latency added to the write path by ensuring ordering should be minimal.

## Considered Options

* **Publish-then-write** — emit the event immediately, write the state
  afterward.
* **Full transactional outbox** — write the state and an outbox row in one DB
  transaction; a separate relay process (e.g. change-data-capture) publishes
  from the outbox.
* **A lightweight, scheduled save-then-publish** — the write happens first; the
  publish step is skipped if the write did not succeed, and a short scheduling
  delay gives the write's commit time to become visible before the event is
  produced.

## Decision Outcome

Chosen option: **a lightweight, scheduled save-then-publish**. The Kafka
produce step is always subordinate to the DB write: if the write affects zero
rows or throws, the produce is skipped entirely. For events whose downstream
consumers poll the database directly (rather than relying solely on the event
payload), a short scheduling delay between commit and produce ensures the
commit has propagated before the event becomes visible, avoiding a race where a
consumer reacts to the event before it can see the corresponding row. A full
transactional outbox (a relay process reading a dedicated outbox table via
change-data-capture) was rejected as disproportionate at this scale: it adds a
relay component and operational surface to deliver a guarantee — exactly-once,
transactionally-coupled publish — that the system does not need, because
consumers are already built to be idempotent against at-least-once delivery.
Publish-then-write was rejected outright: it inverts the dependency a consumer
correctly assumes (that an event means the fact already happened).

### Consequences

* Good, because a consumer can trust that an event it receives corresponds to a
  write that actually succeeded and is durable.
* Good, because no new infrastructure (a relay process, a CDC pipeline) is
  required — the guarantee is achieved with the database write plus a simple
  conditional, scheduled produce.
* Bad, because the scheduling delay is a heuristic, not a guarantee — it is
  sized to be larger than expected commit-visibility latency, not derived from
  a strict ordering primitive; this is an accepted trade-off given consumers
  are idempotent and tolerant of at-least-once delivery.
* Neutral, because this pattern depends on consumers already handling
  duplicate/out-of-order delivery gracefully — see
  [ADR-0015](0015-multi-layer-idempotency-guard.md).

### Confirmation

A code-review rule applies to any new Kafka produce that corresponds to a DB
state change: the produce must follow the save, and must be skipped if the save
did not succeed; producing before a write is confirmed is a blocking finding.

## Pros and Cons of the Options

### Publish-then-write

* Good, because it has the lowest possible latency on the write path.
* Bad, because it lets a consumer observe a fact that may never actually
  commit — the worst-case failure mode this pattern exists to prevent.

### Full transactional outbox

* Good, because it gives the strongest guarantee: the event and the write are
  atomically coupled, with no scheduling heuristic involved.
* Bad, because it requires a relay process (often CDC-based) as new
  infrastructure, which is disproportionate when consumers are already
  idempotent and at-least-once delivery is an acceptable guarantee level.

### A lightweight, scheduled save-then-publish

* Good, because it gets the practically important guarantee — never publish
  before the write succeeds — with no new infrastructure.
* Bad, because the propagation-delay heuristic is not a strict ordering
  guarantee, relying on consumers tolerating at-least-once, possibly
  out-of-order-relative-to-commit delivery.

## More Information

This pattern depends on, and is paired with,
[ADR-0015](0015-multi-layer-idempotency-guard.md): because delivery is
at-least-once rather than exactly-once, consumers must already be safe against
duplicate or near-simultaneous delivery, which is what makes the lighter-weight
scheduling heuristic an acceptable trade against a full transactional outbox.
