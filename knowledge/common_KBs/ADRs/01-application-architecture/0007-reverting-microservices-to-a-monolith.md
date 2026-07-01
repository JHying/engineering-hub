---
status: "accepted"
date: "2026-05-18"
decision-makers: "Engineering leadership, Backend / Platform Engineering"
consulted: "SRE, QA, Product"
---

# Whether to revert microservices to a monolith

## Context and Problem Statement

A high-concurrency, real-time platform was migrated from a monolithic application
(thread-per-request, deployed as a single artifact) to microservices on
Kubernetes, with the core real-time flows **redesigned** — not merely ported — to
meet a C10K-class target (hundreds of thousands of concurrent connections, high
sustained throughput, zero-downtime deployment). After the migration, leadership
observed that feature delivery felt slower than in the monolith and asked whether
the platform should **revert to the monolith** and re-implement new features
there. Should it?

This record evaluates the question along three axes: raw performance against the
C10K target, *current* development velocity (not velocity at the start of the
migration), and the cost to reconstruct the flows that were redesigned during the
migration.

## Decision Drivers

* The C10K-class concurrency/throughput target is a hard, non-negotiable
  requirement.
* Development velocity **as of today**, given the team has already absorbed the
  new architecture — not velocity during the migration's run-in period.
* The cost and regression risk of rebuilding redesigned flows inside a
  high-coupling monolith.
* The long-term trajectory of technical debt and change risk under each option.
* Preserving prior investment (architecture boundaries, contract tests, secrets
  and config tooling, CI quality gates) where it still pays off.

## Considered Options

* **Option 1 — Revert to the monolith** and re-implement current/new
  functionality there.
* **Option 2 — Keep microservices** and fix the specific engineering pain points
  that slow delivery.
* **Option 3 — Partial consolidation** — merge a few services that were split too
  finely, without a wholesale return to the monolith.

## Decision Outcome

Chosen option: **Option 2 — keep microservices and fix the concrete pain points**
(with Option 3 applied selectively where boundaries are genuinely too fine).
Reverting cannot meet the hard performance target, no longer offers even a
short-term velocity gain now that the team has internalised the new architecture,
and would require rebuilding months of redesigned flow logic in a high-coupling
environment at significant regression risk.

### Reasoning

1. **Performance is a hard ceiling, independent of velocity.** A
   thread-per-request monolith allocates a thread per long-lived connection;
   hundreds of thousands of concurrent connections is not reachable on that
   model. Non-blocking I/O plus per-service horizontal scaling is what makes the
   target attainable. This axis alone rules out a full revert.

2. **The "monolith is faster early" advantage has already expired.** That
   advantage is real, but only during the migration's run-in period. The
   preconditions that made it true are now reversed: the team is fluent in the
   new layered architecture; service boundaries are defined and enforced;
   cross-service coordination tooling (contract tests), a standardised local
   environment, a knowledge base, and CI quality gates all exist. Reverting now
   *adds* a fresh learning curve and migration cost rather than removing one.

3. **Redesigned flows would have to be rebuilt, not moved.** The core flows were
   newly designed for the microservices model — e.g., an idempotency /
   de-duplication pipeline, a connection-lifecycle layer separated from business
   logic, distributed scheduling with leader election, and pre-deduction/session
   state machines with explicit concurrency handling. None of these "port"; each
   would be re-implemented inside a high-coupling monolith without breaking the
   existing behaviours, an effort estimated in months during which new feature
   work would largely stall.

4. **Most prior investment remains valuable.** Architecture boundary enforcement,
   contract testing, centralised config and secrets, and CI coverage/quality
   gates are durable assets that a revert would discard.

5. **"Development is slow" has targeted fixes** (see below) that do not require
   architectural regression.

### Consequences

* Good, because the hard performance target stays reachable and prior investment
  is preserved.
* Good, because the genuine slowdowns are addressed at their root cause rather
  than by reversing the architecture.
* Neutral, because a few over-split services may be consolidated — a local
  correction, not a strategic reversal.
* Bad, because the team must actually execute the pain-point fixes; choosing this
  option is a commitment to that work, not a no-op.

### Confirmation

The short-term actions below are tracked to completion; perceived velocity is
re-checked after they land, before any architectural question is reopened.

## Pain-point analysis — root cause to fix

| Reported pain | Root cause | Targeted fix |
|---|---|---|
| Running several services locally is painful | No one-command local stack | A `docker-compose` one-command environment |
| Cross-service API changes need manual coordination | No automated contract verification | Consumer-driven contract tests in CI |
| Inconsistent layering / unfamiliarity | Boundaries not mechanically enforced | Architecture rules enforced in CI (fail the build on violation) |
| Standing up a new service is heavy | No scaffold | A boilerplate/starter project |
| Boundaries too fine in places | Over-decomposition | Merge specific services (Option 3) — not a full revert |
| Hard to locate business logic | Knowledge spread across services | A maintained knowledge base |

## Pros and Cons of the Options

### Option 1 — Revert to the monolith

* Good, because a single deployable is simpler to run and reason about locally.
* Bad, because it cannot meet the C10K-class target (hard ceiling); the
  early-stage velocity advantage no longer exists; redesigned flows must be
  rebuilt at high regression cost; and architectural debt resumes accumulating,
  re-creating the conditions that motivated the original migration.

### Option 2 — Keep microservices, fix pain points

* Good, because it preserves the performance ceiling and prior investment while
  removing the real friction at its source.
* Bad, because it requires disciplined follow-through on the fixes.

### Option 3 — Partial consolidation

* Good, because merging genuinely over-split services cuts coordination cost
  without sacrificing the ability to scale hotspots independently.
* Neutral, because it is complementary to Option 2, applied case by case.

## More Information

This record deliberately separates a **performance** question (a hard
constraint) from a **velocity** question (an engineering-process problem with
process fixes). Conflating the two is what makes "go back to the monolith" sound
like a velocity fix when it is actually an architectural regression that also
fails the performance constraint. Revisit if the hard concurrency target is ever
relaxed, which would change axis 1 materially.
