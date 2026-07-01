---
status: "accepted"
date: "2025-03-12"
decision-makers: "Engineering leadership, Backend / Platform Engineering"
---

# Service decomposition: independent, targeted scaling over a single scalable monolith

## Context and Problem Statement

The legacy platform was already horizontally scalable as a single deployable —
more instances behind a load balancer. Given that, splitting it into ~10
services is not free: it adds network hops, operational surface, and
coordination cost. So the question must be answered on its merits: **what does
decomposition buy that scaling the monolith does not**, for a workload that is
read/write heavy, has uneven load across functions, and has a hard low-latency
requirement on a subset of paths?

## Decision Drivers

* Infrastructure cost should track the actual hotspot, not the whole system.
* A defect in one function must be hotfixable without redeploying everything.
* Startup/restart time matters for fast, fine-grained scaling and recovery.
* Inter-service call overhead must not erode the gains.

## Considered Options

* **Scale the monolith** — add instances of the single deployable.
* **Decompose into services**, scaled independently per hotspot.

## Decision Outcome

Chosen option: **decompose into independently-scaled services**, because a
monolith scales as one unit — every instance carries the full heap and thread
pool for *all* functions, so capacity added for one hot function is paid for
across the whole application. Profiling showed throughput stalling while CPU
stayed low, the signature of an I/O-bound bottleneck (the system spending time
waiting, not computing) localized to a few specific functions — exactly the
case decomposition is suited to: scale the bottleneck function's pods, leave
the rest at baseline.

### Consequences

* Good, because infrastructure spend aligns with actual hotspots instead of the
  whole system; capacity for one busy function no longer taxes every other one.
* Good, because a single-service defect is hotfixed and redeployed in isolation
  — a small, fast deploy instead of a full-application redeploy.
* Good, because per-service startup is fast (each service initializes only its
  own state), versus a monolith that pays a heavy one-time cost loading shared
  state for every function at boot — which directly limits how quickly new
  capacity can come online under load.
* Bad, because what used to be in-process calls became network calls; this is
  mitigated by an efficient RPC protocol (see
  [ADR-0033](0033-inter-service-communication-protocol.md)) and by keeping
  chatty interactions inside one service's boundary.
* Bad, because operational surface grows — more deployables, more dashboards,
  more to keep healthy. Addressed by the platform tooling in
  [ADR-0035](0035-containerization-and-orchestration.md) and
  [ADR-0039](0039-centralizing-cross-cutting-concerns.md).

### Confirmation

A service is a decomposition candidate if it shows hotspot load independent of
the rest of the system (profiled, not assumed); services that always scale
together stay together.

## Pros and Cons of the Options

### Scale the monolith

* Good, because there is one deployable, one thing to operate.
* Bad, because scaling is all-or-nothing: capacity for one busy function is
  paid for everywhere; a defect anywhere requires a full redeploy; cold-start
  is the slowest one of the whole system's combined initialization, which
  limits responsiveness to sudden load.

### Decompose into services

* Good, because scaling, deploys and startup all become per-function instead of
  whole-system.
* Bad, because it introduces network calls and more operational surface in
  exchange.

## More Information

This decision establishes *that* decomposition is worth it; the daily
operational comparison between the old and new model is in
[ADR-0035](0035-containerization-and-orchestration.md#more-information). The
question of whether to later reverse this decision is a separate, later
decision — see [ADR-0007](0007-reverting-microservices-to-a-monolith.md).
