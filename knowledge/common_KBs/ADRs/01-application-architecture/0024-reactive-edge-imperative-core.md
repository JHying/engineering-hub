---
status: "accepted"
date: "2025-03-26"
decision-makers: "Backend / Platform Engineering"
---

# A reactive edge, an imperative core: scoping where reactive programming pays off

## Context and Problem Statement

The edge gateway component is built on a reactive, non-blocking web framework —
the only place in the platform where that programming model is used. Every
business service behind it stays on the imperative model with virtual threads
(see [ADR-0019](0019-virtual-threads-over-reactive.md)). Is this an
inconsistency to fix, or are the gateway and the business services genuinely
different cases that warrant different answers?

## Decision Drivers

* The gateway's actual workload (proxy, header inspection, lightweight
  cache-backed checks) is a different shape from a business service's workload
  (domain logic, multi-backend persistence).
* Whatever framework choice is made at the gateway should fit what the gateway
  actually does, not be inherited automatically from what's used elsewhere.
* Migrating an existing imperative, layered codebase to reactive is a
  significant cost (see [ADR-0019](0019-virtual-threads-over-reactive.md)) —
  that cost should not be paid where it isn't needed.

## Decision Outcome

Chosen option: **reactive at the edge gateway only; imperative with virtual
threads everywhere else**. The reactive web framework's filter-chain model is
effectively mandatory for that framework — there is no blocking-mode
equivalent — and the gateway is precisely the workload reactive programming
suits well: a pure I/O proxy with no domain model, no transactional persistence
layer, no layered DDD structure to preserve. Every filter in its chain does
something like "check a fast cache, then forward" — exactly the non-blocking
I/O pattern reactive composition is built for. Migrating business services to
the same model was rejected for the reasons detailed in
[ADR-0019](0019-virtual-threads-over-reactive.md): the conversion cost there is
architectural, not syntactic, and virtual threads already solve the same
I/O-concurrency problem for those services without that cost. The two
components are doing genuinely different jobs; using a different tool for each
is the point, not an inconsistency to resolve.

### Consequences

* Good, because the gateway gets the framework best suited to its actual
  workload shape, without forcing that choice onto services where it would be
  expensive and unnecessary.
* Good, because business services keep their layered, imperative model and its
  structural enforcement ([ADR-0021](0021-fifth-ddd-layer-manager.md),
  [ADR-0022](0022-build-time-architecture-enforcement.md)) completely intact.
* Neutral, because the platform now has exactly one component using a
  different programming model than the rest — an explicit, narrow exception
  rather than a creeping inconsistency, because its scope (pure I/O proxy, no
  domain logic) is exactly what justifies the exception.

### Confirmation

A new edge-level concern (auth checks, rate limiting, routing) is implemented
in the gateway's filter chain; a new business capability is implemented in a
business service on the imperative model — the two are not interchangeable
homes for new code.

## More Information

### Three gateway-specific design choices worth recording

**Extracting a credential from a WebSocket upgrade request.** Browsers cannot
set an arbitrary authorization header on a WebSocket upgrade request. The
token-extraction logic therefore falls back to reading the credential from a
WebSocket-specific negotiation header when the standard authorization header is
absent — letting the gateway handle both plain HTTP and WebSocket upgrade
requests through the same authentication path rather than needing a separate
mechanism for each.

**A local, in-process revocation check instead of a per-request cache lookup.**
Every inbound request passes through a token-validation filter. Looking up
token revocation status in a shared cache on every single request would add a
small but non-trivial latency cost multiplied across all traffic. Instead, a
local in-process map holds revoked-token identifiers, giving an effectively
free lookup; the map is kept current by consuming revocation events published
when a token is revoked, rather than by querying a shared store per request.

**Injecting a pre-validated identity header for downstream services.**
Once the gateway has validated a credential, it injects the resulting validated
identity as a header on the forwarded request. Downstream services trust this
header rather than re-validating the original credential — signature
validation happens exactly once, at the edge, not redundantly in every
downstream service. The same header carries a pre-extracted key used for
data-partition routing further downstream, so that routing decision is made
once at the edge rather than being re-derived by every service that needs it.
