---
status: "accepted"
date: "2025-04-09"
decision-makers: "Backend / Platform Engineering"
---

# Kafka topic and consumer-group conventions: fixed group vs fan-out group

## Context and Problem Statement

Once Kafka is the standard asynchronous backbone
([ADR-0042](0042-asynchronous-messaging-backbone.md)), every new topic still
needs answers to three independent questions: what is it named, how many
*logical* deliveries should each message get across a service's pods (exactly
one, or one per pod), and what determines message ordering. Getting the second
question wrong silently breaks correctness — it's invisible until a specific
failure pattern occurs in production. What conventions answer these three
questions consistently?

## Decision Drivers

* A topic name should signal at a glance whether it crosses service
  boundaries or stays internal to one service.
* The consumer-group strategy must match each topic's actual delivery
  semantics — some events should be handled exactly once across a fleet; others
  must reach *every* pod of a service, not just one.
* Events that must be processed in a specific order relative to each other need
  a partition key that guarantees that ordering.

## Decision Outcome

Chosen option: **three independent, explicit conventions**, applied to every
topic.

### 1 — Topic naming signals scope

A cross-service event (different producing and consuming services) carries a
shared namespace prefix; a topic with no prefix is service-local or an
intra-service fan-out channel. This makes scope visible from the topic name
alone, without having to trace producer/consumer code to find out who else
might be listening.

### 2 — Consumer group ID strategy must match delivery semantics

| Pattern | Group ID | Semantics | When to use |
|---------|----------|-----------|--------------|
| Work-queue | A fixed, shared group ID | Exactly one pod (of however many are running) processes each message | The action should happen exactly once cluster-wide, e.g. "clear this pending state once" |
| Fan-out broadcast | A unique group ID generated per pod at startup | Every pod receives every message independently | Every pod needs to react, e.g. "update every pod's local cache," or "every pod must check whether it owns the affected session" |

**The fan-out case has a specific, easy-to-miss justification:** when the
party who should ultimately receive a result is connected to *some* pod, but
the producer does not know *which* one, a fixed consumer group would deliver
the message to only one pod — and if that pod doesn't happen to be the one
holding the relevant connection, the message is effectively lost from the
recipient's point of view. A unique-per-pod group ID means every pod gets the
message and independently checks whether it is the one that should act on it —
exactly the same broadcast-and-let-the-owner-act pattern used for cross-pod
session actions (see
[ADR-0025](0025-websocket-session-ownership-across-pods.md)).

### 3 — Partition key governs ordering

Events that must be processed in production order relative to each other use a
shared partition key derived from the entity they describe (e.g. all events
about one logical resource use that resource's identifier as the key), so they
land on the same partition and are delivered to a given consumer in the order
they were produced. Events with no ordering dependency on each other can omit
a deliberate key.

### 4 — Serialization format must be paired, not assumed

A simple, flat event uses a plain string encoding; a complex, nested event
object uses a structured (JSON) encoding. The specific format matters less than
a stricter rule: **the producer's serializer and the consumer's deserializer
for a given topic must be the same format, deliberately paired, not just
happen to agree today.** For a topic crossing a service boundary, the message
shape (or an equivalent shared definition) must be available to both the
producing and the consuming service — typically via a shared library — so the
pairing is enforced by a shared type, not by two independently-maintained
classes that could drift apart silently. A producer/consumer format mismatch
on a cross-service topic is a deployment-time risk with no compiler to catch
it; treating the format choice as a deliberate, paired decision (recorded next
to the topic, not assumed from convention) is the mitigation.

### Consequences

* Good, because a topic's scope is visible from its name without reading code.
* Good, because correctness-critical "exactly once across the fleet" vs
  "every pod must see this" semantics are chosen deliberately per topic,
  instead of defaulting to whichever group-ID pattern was copy-pasted from the
  last topic someone created.
* Good, because ordering-sensitive event sequences are guaranteed to arrive in
  order to a given consumer, without needing application-level reordering
  logic.
* Bad, because getting the consumer-group choice wrong is a subtle, easy-to-miss
  bug — a fan-out topic accidentally given a fixed group silently delivers to
  only one pod, and the failure only shows up as "it works sometimes," not as
  an obvious error.

### Confirmation

A new topic states its intended delivery semantics (exactly-once-cluster-wide
vs every-pod) explicitly when introduced, and its consumer-group strategy is
reviewed against that stated intent, not assumed from convention alone.

## More Information

### A self-consumption pattern for cross-pod cache sync

One recurring pattern: a service both produces *and* consumes its own topic, using
the fan-out group-ID pattern, purely to propagate a local in-memory cache
update to every other pod of the same service. This reuses the same messaging
backbone already in place rather than introducing a separate cache-invalidation
broadcast mechanism — the service's own event stream doubles as its cache-sync
channel.

### Transaction boundary rule

A consistent rule applies across all producers: the owning database write
commits first, and only then is the corresponding event produced — see
[ADR-0014](0014-save-then-publish-ordering.md). A produce failure after a
successful write loses only the notification, never the underlying state,
which is what makes this ordering safe to rely on.
