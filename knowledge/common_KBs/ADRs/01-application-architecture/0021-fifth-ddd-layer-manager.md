---
status: "accepted"
date: "2025-02-15"
decision-makers: "Backend / Platform Engineering"
---

# A fifth DDD layer: why heterogeneous infrastructure needs a Manager layer

## Context and Problem Statement

Classic DDD layering — Controller → Application Service → Domain Service →
Repository — maps cleanly when a service talks to one persistence backend.
Here, a typical service talks to several heterogeneous infrastructure backends
at once: a relational store, a document store, a fast cache, RPC stubs, and
HTTP clients. Without an additional seam, Domain Service would need to import
cache key formats, RPC-generated types, document-store collection structures,
and ORM entity types simultaneously — coupling business logic directly to
infrastructure details that change at different rates and for different
reasons. Is the classic four-layer model still sufficient, or does
heterogeneity at the infrastructure layer demand an explicit additional layer?

## Decision Drivers

* Domain logic should depend on domain language (value objects), not on the
  shape of whichever infrastructure client happens to provide the data.
* Different infrastructure backends evolve independently (a cache key format
  change is unrelated to an RPC contract change) — coupling them all into one
  layer means unrelated changes collide.
* The boundary needs to be enforceable, not just a convention developers are
  trusted to follow.

## Considered Options

* **Classic four-layer DDD** — Domain Service talks to repositories/clients
  directly.
* **A generic "infrastructure" catch-all layer** — one additional layer, but
  without a clearly stated single responsibility.
* **An explicit Manager layer** with a defined responsibility — aggregate
  infrastructure access and translate every infrastructure type into a domain
  value object, with nothing else allowed to cross this seam.

## Decision Outcome

Chosen option: **an explicit Manager layer**, inserted between Domain Service
and the infrastructure clients (repositories, cache clients, RPC stubs, HTTP
clients). Its responsibility is narrow and explicit: aggregate whatever
infrastructure calls are needed for one logical operation, and translate every
result into a value object before it crosses upward. No infrastructure type —
no ORM entity, no document-store object, no generated RPC type, no
cache-client-specific structure — is allowed to appear in Domain Service or
above. A generic, undefined "infrastructure layer" was rejected because without
a stated single responsibility it tends to absorb business logic over time,
becoming an unprincipled grab-bag rather than a clean seam.

A specific mechanical signal reinforces the boundary: the Manager layer is
marked with a generic "infrastructure coordinator" component annotation, not
the annotation conventionally reserved for "this bean makes business
decisions." Architectural enforcement (see
[ADR-0022](0022-build-time-architecture-enforcement.md)) checks that a Manager
class never carries the business-decision annotation — placing it there fails
the build. This catches, at build time, the specific drift pattern where a
Manager class gradually accumulates business logic until it has effectively
become an undeclared Domain Service.

### Why not simply extend the Repository abstraction

A natural-looking shortcut is to model the non-persistence infrastructure
access (a cache check, an RPC call) as just another Repository — a
"CacheRepository" or an "RpcRepository." This was rejected on conceptual
grounds: classic DDD gives Repository a specific, narrow contract — it is the
persistence abstraction for one Aggregate Root, with `find`/`save` semantics
tied to that aggregate's identity. A "Repository" that performs no persistence
and does not address an aggregate by identity is a Repository in name only; the
mismatch between the name's implied contract and its actual behaviour is
exactly the kind of drift this layering is meant to prevent elsewhere. The
Manager layer is named and scoped for what it actually does — aggregate and
translate infrastructure access — without borrowing a DDD term whose meaning it
would otherwise dilute.

### Consequences

* Good, because Domain Service's imports are limited to Manager classes and
  value objects — exactly the two things that belong in the domain's own
  language — making business logic readable without infrastructure noise.
* Good, because each infrastructure backend can evolve its own types/formats
  independently; the translation boundary absorbs that change without it
  propagating upward.
* Good, because the annotation-based signal turns "is this class drifting
  toward being a Domain Service" from a code-review judgement call into a
  build-time check.
* Bad, because it is one more layer to learn and navigate — a five-layer call
  stack is more ceremony than four for genuinely simple operations.
* Neutral, because the dependency limit placed on Manager constructors (bounded
  collaborator count) is a deliberate complexity signal: a Manager approaching
  the limit is doing too much aggregation and is a candidate to split.

### Confirmation

No JPA entity, document-store object, generated RPC type, or cache-client type
appears in a Domain Service or any layer above it; Manager classes carry the
infrastructure-coordinator annotation, never the business-decision one — both
checked by build-time architecture tests, not just code review.

## Pros and Cons of the Options

### Classic four-layer DDD

* Good, because it is the well-known, widely-documented default.
* Bad, because with several heterogeneous infrastructure backends, Domain
  Service ends up importing infrastructure-specific types directly, coupling
  business logic to details that should be free to change independently.

### A generic, undefined infrastructure layer

* Good, because it at least separates infrastructure from domain logic in
  principle.
* Bad, because without an explicit, enforced responsibility it tends to absorb
  business logic over time, becoming an unprincipled grab-bag layer.

### An explicit Manager layer with a defined responsibility

* Good, because the seam has one job — aggregate and translate — which is both
  narrow enough to enforce and clear enough to review against.
* Bad, because it adds a layer of indirection that a single-backend service
  would not need.

## More Information

This layer's boundary is enforced the same way the rest of the architecture's
structural rules are — see
[ADR-0022](0022-build-time-architecture-enforcement.md) for how dependency
direction, naming-to-location mapping, and stereotype constraints are checked
at build time rather than left to code review.
