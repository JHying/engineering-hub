---
status: "accepted"
date: "2025-03-22"
decision-makers: "Backend / Platform Engineering, DBA"
consulted: "DBA"
---

# Cross-service data ownership and sharing boundaries

## Context and Problem Statement

Once data lives in per-service stores
([ADR-0034](0034-polyglot-persistence-secondary-document-store.md)), a question
becomes unavoidable: how does a service read data it does not own? Calling the
owner's API on every access is the textbook answer, but at high request volume
and connection count, an API call for every read of frequently-needed shared
state would multiply internal traffic substantially, and some data is
financial/correctness-sensitive in a way that API-level eventual consistency
cannot safely cover. What governs how data crosses service boundaries?

## Decision Drivers

* Avoid an internal traffic explosion from naive "always call the owner's API"
  reads of frequently-needed shared state.
* Financially/correctness-sensitive data needs ACID guarantees, not eventual
  consistency.
* Ownership must stay unambiguous — exactly one writer per piece of state.
* Schema changes should not require coordinating every service at once.
* Independent deployability must be preserved; data sharing must not become a
  backdoor coupling that defeats service boundaries.

## Considered Options

* **Full isolation** — every cross-service read goes through the owning
  service's API, no exceptions.
* **A shared application database** — services share one schema/database
  directly.
* **A three-tier model** — isolated primary stores by default, a controlled
  shared cache for frequently-needed hot data with one writer per key, and a
  small number of explicitly justified shared-table exceptions for ACID-bound
  correctness-critical data.

## Decision Outcome

Chosen option: **a three-tier model**.

| Tier | Mechanism | Rule |
|------|-----------|------|
| 1 — Primary store isolation | Each service owns its schema/collection | No other service writes it; reads go through the owning service's API |
| 2 — Shared read bus | Hot, ephemeral data written by one owner, read by consumers via a fast shared cache | Exactly one writer per key, enforced by a registry of key ownership |
| 3 — Deliberate shared-table exception | A small number of tables shared by a few correctness-critical services | Justified case by case by an ACID requirement; row-level locking coordinates access |

Full isolation was rejected because, for data that many requests need on a hot,
high-frequency path, routing every read through the owner's API would multiply
internal call volume directly with external traffic — an N×M scaling problem
that a shared cache avoids by letting many readers hit a fast store the owner
populated once. It was also rejected for the small set of genuinely
correctness-critical, financially-bound data, where eventual consistency from
an API call is not an acceptable substitute for a real transactional guarantee.
A shared application database was rejected outright: it makes ownership
ambiguous, blocks every dependent service on a single schema's changes, and
defeats independent deployability — exactly the properties service
decomposition was meant to gain.

### Consequences

* Good, because the common case (hot, frequently-read data) avoids an internal
  traffic explosion while keeping a single, registered owner per key.
* Good, because the rare, deliberate exception tier gives financially-sensitive
  data real ACID guarantees instead of forcing eventual consistency onto data
  that cannot tolerate it.
* Good, because most data stays fully isolated, preserving independent schema
  evolution and deployability for the large majority of services.
* Bad, because the shared-cache tier requires discipline: a registry of which
  service owns which key, enforced by convention/tooling rather than by the
  database itself.
* Bad, because the tier-3 exception is, by construction, a deliberate violation
  of per-service isolation — it must be justified individually, and reviewed if
  ever extended, so it doesn't quietly become the default escape hatch.

### Confirmation

A new shared-cache key has exactly one registered owning service before any
consumer reads it; a new tier-3 shared-table exception requires an explicit
ACID justification recorded alongside the schema, not just a convenience
argument.

## Pros and Cons of the Options

### Full isolation (API-only cross-service reads)

* Good, because ownership is maximally unambiguous and simple to reason about.
* Bad, because it does not scale for hot, frequently-read data, and provides no
  good answer for genuinely ACID-bound cross-service correctness needs.

### A shared application database

* Good, because reads are trivial — everything is in one place.
* Bad, because it destroys ownership clarity, blocks independent schema
  evolution, and reintroduces the coupling that decomposition was meant to
  remove.

### A three-tier model

* Good, because it matches the mechanism to the actual access pattern: isolated
  by default, a fast shared bus for hot reads, and a narrow, justified
  exception for true ACID needs.
* Bad, because it is the most complex option to explain and govern, requiring
  registry discipline and case-by-case justification for the exception tier.

## More Information

The tier-3 exception is intentionally rare. Its justification pattern — a
small, fixed set of correctness-critical services coordinating through
row-level locking on a shared table, each running with bounded concurrency
against that table by design — is what makes the exception safe rather than a
slippery slope; it does not generalise to "any two services can share a table
if it's convenient."
