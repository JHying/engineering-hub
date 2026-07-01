---
status: "accepted"
date: "2025-03-18"
decision-makers: "Backend / Platform Engineering"
---

# Service decomposition principles: drawing boundaries beyond "split for scaling"

## Context and Problem Statement

[ADR-0032](0032-service-decomposition-for-independent-scaling.md) established
*that* decomposition is worth it, on scaling economics. It does not say *where*
the boundaries should fall. Scaling profile is one input, but several services
were split (or deliberately kept together) for reasons that have nothing to do
with throughput — protocol translation, security sensitivity, change
frequency, and correctness isolation all argued for boundaries independently.
What principles, beyond scaling, actually decide where a service boundary
belongs?

## Decision Drivers

* A scaling-profile mismatch (e.g. a connection-heavy component next to a
  transactional-heavy one) is one valid reason to split, but not the only one.
* External protocol or hardware-specific detail should not leak into business
  logic.
* Security-sensitive logic (credential/token issuance) should be able to change
  on its own cadence, independent of less sensitive logic that happens to
  involve the same entity.
* Correctness-critical batch work should not share a failure domain with
  latency-sensitive real-time paths.
* Administrative/back-office traffic spikes should not be able to degrade
  user-facing latency.

## Decision Outcome

Chosen option: **six explicit principles**, applied as a checklist when
drawing or reviewing a service boundary — not a single rule, because the six
reasons below are independent of each other and a boundary can be justified by
any one of them even when the others don't apply.

| # | Principle | Reasoning |
|---|-----------|-----------|
| 1 | Split connection-lifecycle concerns from business-domain concerns | A connection-handling component's concurrency profile (very high connection count, low per-connection CPU) and a transactional component's profile (lower connection count, heavier per-request work) are incompatible scaling shapes in one process — this is the scaling-driven case from [ADR-0032](0032-service-decomposition-for-independent-scaling.md). |
| 2 | Isolate external protocol translation behind an anti-corruption layer | A component that speaks to an external system (a hardware integration, a legacy protocol) absorbs that system's vocabulary and quirks; its event types and formats must not leak into the core business domain's model. |
| 3 | Separate rarely-changing global/static configuration from request-time logic | Data that changes rarely and is broadcast rather than queried per-request does not belong inside a service that other services call synchronously at request time. |
| 4 | Treat identity and profile data as separate domains | Security-sensitive logic (credential/token issuance) has a different change cadence and a different risk profile than general account/profile data about the same entity, even though both "belong to the user." |
| 5 | Isolate correctness-critical settlement/batch work into its own failure domain | Work where a mistake is expensive and hard to reverse should not share infrastructure dependencies (the same message broker, the same cache) with everyday real-time traffic, so a real-time incident cannot cascade into a settlement error and vice versa. |
| 6 | Treat administrative/back-office traffic as a separate failure domain from user-facing traffic | A spike in administrative activity must not be able to degrade the latency of user-facing paths; changes propagate from admin to user-facing services asynchronously rather than via a synchronous call on the hot path. |

### Consequences

* Good, because boundaries are justified individually and explicitly, which
  makes them defensible in review and revisitable on their own merits — a
  boundary drawn for principle 5 (failure-domain isolation) is not weakened by
  an argument that addresses only principle 1 (scaling).
* Good, because principle 2 (anti-corruption layer) keeps external/legacy
  vocabulary from spreading into the core domain model, which keeps the rest of
  the system free to evolve its own language.
* Bad, because six independent principles means six independent justifications
  to maintain — a boundary review has to check each one, rather than applying
  one universal rule.

### Confirmation

A proposed service boundary (new split or a proposed merge) states which of the
six principles justifies it; "it felt right" is not sufficient grounds on its
own.

## More Information

These principles are the boundary-drawing complement to the scaling argument in
[ADR-0032](0032-service-decomposition-for-independent-scaling.md): that record
establishes *that* decomposition pays off; this one establishes *where* the
cuts should fall when scaling alone doesn't answer the question.
