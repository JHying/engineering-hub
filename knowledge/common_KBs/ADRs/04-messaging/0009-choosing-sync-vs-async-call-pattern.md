---
status: "accepted"
date: "2025-04-25"
decision-makers: "Backend / Platform Engineering"
---

# Choosing the call pattern: synchronous RPC vs asynchronous eventing

## Context and Problem Statement

Once both a synchronous protocol (gRPC, see
[ADR-0033](0033-inter-service-communication-protocol.md)) and an asynchronous
backbone (Kafka, see
[ADR-0042](0042-asynchronous-messaging-backbone.md)) are available, every new
cross-service interaction faces the same upstream question before protocol
choice even comes up: should this be a request that waits for an answer, or a
fact that gets published and forgotten? Picking the wrong pattern shows up
later as either unnecessary latency coupling or unnecessary complexity. What
decides which pattern a given interaction should use?

## Decision Drivers

* Does the caller need the result before it can proceed (or respond to its own
  caller)?
* Does exactly one party need to know, or do an unknown/growing number of
  parties need to react independently?
* What does a slow or failing callee do to the caller — does the caller fail
  too, or should it be unaffected?
* Tight request/response coupling between many services is itself an
  architectural smell to avoid by default.

## Considered Options

* **Default to synchronous RPC**, use eventing only for clearly fire-and-forget
  notifications.
* **Default to asynchronous eventing**, use RPC only where a response is
  unavoidable.
* **Decide per-interaction from the call's actual shape** — who needs to know,
  and do they need to know *now*.

## Decision Outcome

Chosen option: **decide per-interaction from the call's shape**, using two
questions: *does the caller block on the result*, and *is the consumer set
fixed-and-known or open-and-growing*. A call where the caller cannot proceed
without the answer (e.g. validating something before continuing a user-facing
flow) is synchronous by nature — wrapping it in an event and waiting for a
correlated response only adds latency and complexity for no benefit. A call
where the producer simply needs to record "this happened" and does not care who
acts on it, when, or how many consumers there end up being, is asynchronous by
nature — synchronous calls here would mean the producer's request depends on
the availability of every consumer, including ones added later.

### Consequences

* Good, because the decision is made on the interaction's actual shape, not on
  habit or on whichever mechanism happens to be top-of-mind that week.
* Good, because adding a new independent consumer to an existing fact (a new
  service that wants to react to the same event) requires zero change to the
  producer when the interaction was correctly classified as asynchronous up
  front.
* Good, because synchronous paths stay synchronous where that is the honest
  shape of the dependency, avoiding the anti-pattern of faking request/response
  over an event bus with correlation IDs and timeouts.
* Bad, because the two questions require the author to actually think about
  consumer cardinality and blocking semantics up front, rather than defaulting
  to whichever protocol was used in the last PR they touched.

### Confirmation

A new cross-service interaction states, in its design review, whether the
caller blocks on the answer and how many consumers are expected; the protocol
follows from that answer rather than the other way around.

## Pros and Cons of the Options

### Default to synchronous RPC

* Good, because request/response is the simpler mental model for most
  developers.
* Bad, because it silently couples the caller's success to every callee's
  availability, even for facts nobody needs an immediate answer to.

### Default to asynchronous eventing

* Good, because it decouples producers from consumers by default.
* Bad, because forcing genuinely blocking dependencies through an event bus
  (publish, then wait for a correlated response) adds latency and complexity
  without a real decoupling benefit.

### Decide per-interaction from the call's shape

* Good, because each interaction gets the pattern that actually matches its
  dependency shape.
* Bad, because it is a judgement call rather than a fixed default, and requires
  the two driving questions to actually be asked at design time.

## More Information

This record sits upstream of two protocol-specific decisions: once an
interaction is classified synchronous, [ADR-0033](0033-inter-service-communication-protocol.md)
governs which synchronous protocol to use; once classified asynchronous,
[ADR-0042](0042-asynchronous-messaging-backbone.md) governs the messaging
backbone.
