---
status: "accepted"
date: "2025-04-08"
decision-makers: "Backend / Platform Engineering"
---

# Asynchronous messaging backbone: Kafka vs Redis pub/sub

## Context and Problem Statement

The event-driven patterns adopted in
[ADR-0040](0040-event-driven-state-propagation.md) need a delivery mechanism.
Redis pub/sub was already in use as a broadcast primitive elsewhere in the
stack, so it was the natural first candidate. Does it actually meet the bar for
a general-purpose, reliable eventing backbone, or does the platform need
something more?

## Decision Drivers

* Delivery must be reliable — a consumer that is briefly behind or restarts
  must not silently lose events.
* Visibility into consumer lag/health, not just "did the publish call succeed."
* A path to handle poison/failing messages without blocking the whole stream.
* Durability — events should not vanish purely because no consumer was
  listening at the instant of publish.
* Room to grow into cross-region event distribution as the platform expands.

## Considered Options

* **Redis pub/sub** — already present, simple fire-and-forget broadcast.
* **Kafka** — a durable, partitioned log with consumer offset tracking.

## Decision Outcome

Chosen option: **Kafka**, as the backbone for event-driven flows that need
reliability guarantees. Redis pub/sub is a broadcast primitive: it has no
concept of consumer offset, so there is no way to know whether a consumer is
keeping up, and a message published while no consumer is connected is simply
lost — neither property is acceptable for state-propagation events where a
missed message means stale state. Kafka tracks consumer offsets explicitly, so
lag is observable and a restarted consumer resumes where it left off; it
supports a dead-letter pattern for handling messages that repeatedly fail to
process without blocking the rest of the stream; and as a durable log it does
not depend on a consumer being connected at publish time. Redis pub/sub remains
appropriate for genuinely fire-and-forget, low-stakes broadcasts where losing a
message has no real consequence.

### Consequences

* Good, because consumer lag and health become observable instead of opaque,
  which materially improves operability of event-driven flows.
* Good, because a restarted or briefly-behind consumer resumes from its offset
  instead of silently missing events.
* Good, because a dead-letter pattern isolates poison messages instead of
  letting one bad message stall an entire stream.
* Good, because durability removes the "no consumer was listening" failure mode
  entirely, and the log model has a clearer path toward cross-region
  distribution than a broadcast primitive does.
* Bad, because Kafka is materially heavier operational infrastructure to run
  than Redis pub/sub — partitions, retention, broker operations — taken on
  deliberately in exchange for the reliability guarantees above.

### Confirmation

A new event-driven flow that requires delivery reliability (no silent message
loss, observable consumer lag) is built on Kafka; Redis pub/sub is used only
where message loss is an accepted, low-stakes outcome.

## Pros and Cons of the Options

### Redis pub/sub

* Good, because it is already present in the stack and simple to use for a
  basic broadcast.
* Bad, because it has no consumer offset tracking (no lag visibility, no
  resume-from-where-you-left-off) and no durability (a message published with
  no listener is lost) — both unacceptable for reliable state propagation.

### Kafka

* Good, because of consumer offset tracking, durability, and a dead-letter
  pattern for failure isolation; a stronger foundation for cross-region growth.
* Bad, because it is meaningfully heavier infrastructure to operate than a
  pub/sub primitive.

## More Information

This backbone is what makes the event-driven patterns in
[ADR-0040](0040-event-driven-state-propagation.md) reliable in practice, not
just in design; a polling fallback was the alternative being replaced, not a
fire-and-forget broadcast, which is why the reliability bar here is higher than
"better than nothing."
