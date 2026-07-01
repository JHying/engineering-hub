---
status: "accepted"
date: "2025-03-25"
decision-makers: "Backend / Platform Engineering"
---

# Centralizing cross-cutting concerns in a shared infrastructure layer

## Context and Problem Statement

As the monolith split into independently-scaled services
([ADR-0032](0032-service-decomposition-for-independent-scaling.md)), a new
category of problem appeared: every service now needs to solve the same set of
*non-business* problems — configuration management, authentication and rate
limiting at the edge, service discovery and health checking, resilient
inter-service calls (timeouts, retries, circuit breaking), and request tracing.
Left to each service, these get reimplemented (and subtly reinvented)
~10 times. Where should these concerns live?

## Decision Drivers

* Avoid duplicated, drifting implementations of the same cross-cutting concern
  across services.
* Keep service code focused on business logic, not infrastructure plumbing.
* Configuration and policy changes should not require touching every service.
* Onboarding a new service should not require re-solving solved problems.

## Considered Options

* **Per-service implementation** — each service handles config, auth,
  discovery, resilience and tracing itself.
* **A shared library**, imported by every service, implementing these concerns.
* **A dedicated infrastructure layer** (config server, API gateway, service
  mesh / discovery backbone, a resilience library, and standardised tracing),
  so the concern is solved once, centrally, and consumed by every service.

## Decision Outcome

Chosen option: **a dedicated infrastructure layer** — a config server for
centralised, hot-reloadable configuration; a gateway for ingress auth and
traffic control; a discovery/coordination backbone (see
[ADR-0001](0001-service-discovery-and-config-backbone.md)) for service health
and dynamic config; a resilience library providing declarative
circuit-breaking/retry; and OpenTelemetry for unified tracing (see
[ADR-0038](0038-observability-strategy.md)). Business services consume these as
infrastructure, not as something each of them re-implements.

### Consequences

* Good, because solving a cross-cutting concern once means consistent
  behaviour across all services, instead of ~10 subtly different
  implementations drifting apart over time.
* Good, because business services stay focused on business logic; the
  boilerplate that used to surround it (config wiring, retry logic,
  auth checks) moves to the infrastructure layer.
* Good, because a policy change (e.g. a new retry budget, a new auth rule)
  is made once, centrally, and takes effect everywhere consuming it.
* Bad, because the infrastructure layer itself becomes critical shared
  infrastructure — its availability and correctness affects every service, so
  it is held to a higher operational bar than any single business service.

### Confirmation

A new service obtains configuration, discovery, resilience and tracing from the
shared infrastructure layer by default; a service implementing one of these
concerns itself is a deviation that needs a stated reason.

## Pros and Cons of the Options

### Per-service implementation

* Good, because each service can tune its own behaviour with no shared
  dependency.
* Bad, because the same problems get solved ~10 times, with drift and
  inconsistency the predictable result; maintenance cost grows with the number
  of services.

### A shared library

* Good, because logic is written once and imported everywhere, closer to
  consistent than per-service implementation.
* Bad, because policy changes still require a version bump and redeploy of
  every consumer — closer to centralised than per-service, but not as
  immediate as a runtime infrastructure layer for things like config changes.

### A dedicated infrastructure layer

* Good, because the concern is solved once and centrally, with changes taking
  effect without redeploying every service (for config) and with consistent
  behaviour guaranteed by construction (for discovery, resilience, tracing).
* Bad, because the infrastructure layer is now critical shared infrastructure
  in its own right.

## More Information

This is the architectural rationale for *why* cross-cutting concerns are
centralised; the specific tool choice for the discovery/config backbone is in
[ADR-0001](0001-service-discovery-and-config-backbone.md), and the
observability piece in [ADR-0038](0038-observability-strategy.md). Migrating
from a framework with substantial per-request boilerplate (e.g. raw Servlets)
to one with first-class support for this infrastructure layer (e.g. Spring
Boot/Cloud) is itself part of this rationale — less boilerplate per service
also means less surface for cross-cutting logic to leak into business code.
