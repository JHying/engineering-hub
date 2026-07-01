---
status: "accepted"
date: "2025-04-01"
decision-makers: "Backend / Platform Engineering"
---

# Saga pattern: local orchestration with choreographed compensation

## Context and Problem Statement

A core user-facing write spans multiple steps and two storage systems — a
durable checkpoint write, a call to an external system, and a final state
transition — and must give the caller an immediate, synchronous acknowledgement
within a tight latency budget. A failure partway through must leave the system
in a recoverable, not corrupted, state. How should this multi-step,
cross-system write be coordinated?

## Decision Drivers

* The caller needs a synchronous, low-latency acknowledgement — not eventual
  confirmation.
* A failure at any step must be compensable, not just logged.
* The steps act on one logical aggregate (one request), which argues for
  locality over distributed coordination.
* A separate coordinator service must not become a new bottleneck or single
  point of failure on the hot path.
* Recovery from a partial failure (e.g. the process crashes mid-flow) must be
  automatic, not manual.

## Considered Options

* **A centralised saga orchestrator service** — a dedicated component drives
  every step and compensation across services.
* **Pure choreography** — each step reacts to the previous step's event; no
  component holds the overall flow.
* **Local orchestration with choreographed compensation** — the service that
  owns the request drives its own steps directly (including a call to another
  system), and publishes an event only for the compensation/notification that
  other services need to react to.

## Decision Outcome

Chosen option: **local orchestration with choreographed compensation**. All
steps operate on the same logical aggregate (one request, one owner), which is
the textbook case for local orchestration rather than distributing the flow
across a saga coordinator. A dedicated orchestrator service was rejected for
two reasons: it sits on the latency-critical synchronous path, so it would
become a new bottleneck precisely where the system can least afford one; and it
is a new single point of failure for a flow that previously had none, since the
owning service already had everything it needed locally. Pure choreography
(event-only, no local driving) was rejected because a chain of
produce→consume→produce cannot deliver the synchronous acknowledgement the
caller requires within the latency budget — an event round-trip is fundamentally
not a request/response primitive.

### Consequences

* Good, because the owning service can give a synchronous response without
  waiting on any other service's event loop.
* Good, because there is no new coordinator component to operate, monitor, or
  treat as a single point of failure.
* Good, because compensation/notification to other services still happens via
  asynchronous events, keeping those other services decoupled from the flow's
  internal steps.
* Bad, because the saga's logic lives inside the owning service rather than
  being centrally visible in one orchestrator — understanding the full flow
  means reading that service's code, not a single coordinator's state machine.
* Bad, because a sub-flow that itself needs compensation (an "undo" of an
  earlier step) is a nested saga with its own recovery logic, adding internal
  complexity to the owning service.

### Confirmation

A durable checkpoint is written before any externally-visible side effect, so
that a crash mid-flow leaves enough state for an automatic recovery process to
detect and retry or compensate the in-flight request, without manual
intervention.

## Pros and Cons of the Options

### A centralised saga orchestrator service

* Good, because the full flow is visible in one place.
* Bad, because it sits as a new component directly on the synchronous,
  latency-critical path, and becomes a new single point of failure and scaling
  bottleneck.

### Pure choreography

* Good, because no component holds global flow state; maximally decoupled.
* Bad, because it cannot deliver a synchronous response — incompatible with a
  caller that needs an immediate acknowledgement.

### Local orchestration with choreographed compensation

* Good, because it gives a synchronous response with no new coordinator
  component, while still notifying other services asynchronously for
  compensation.
* Bad, because the flow's logic is local to the owning service rather than
  centrally visible, and nested sub-flows add internal complexity.

## More Information

A durable, automatically-recovered checkpoint is also what makes a fast,
per-pod recovery loop (rather than a distributed lock) the right tool for
retrying stuck in-flight steps — see
[ADR-0018](0018-distributed-scheduling-strategy.md) for why that recovery loop
deliberately runs per-pod rather than under a cluster-wide lock.
