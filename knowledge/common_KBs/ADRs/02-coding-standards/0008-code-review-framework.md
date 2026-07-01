---
status: "accepted"
date: "2025-05-10"
decision-makers: "Backend / Platform Engineering"
---

# Code-review framework and engineering-quality standards

## Context and Problem Statement

With many services and multiple contributors, review depth and focus varied
person to person and PR to PR. Performance issues in particular were often
caught late — after merge, sometimes after a production incident — despite the
system running well above typical request volume against large tables, where a
missed N+1 or a non-atomic check-then-act is not a style nitpick but a
production risk. How should review be structured so it reliably catches the
things that matter, not just whatever the reviewer happens to notice?

## Decision Drivers

* Performance and correctness issues should surface in review, not in
  production.
* Review quality should not depend on which reviewer happened to pick up the PR.
* The framework must be checkable — a reviewer (or the author, beforehand)
  should be able to tell whether a review was thorough.
* It should scale across many contributors without becoming a rigid checklist
  nobody actually reads.
* Performance thresholds should be grounded in the platform's actual scale
  (real concurrency and throughput figures), not intuition — a "this might be
  slow" comment is weaker than a comment tied to a concrete number the team
  already knows it must hold.

## Considered Options

* **Unstructured review** — reviewer applies their own judgement, no required
  format.
* **A single checklist** — one flat list of items to check.
* **A multi-axis structured framework** — review is required to address
  distinct categories explicitly, each with its own standards.

## Decision Outcome

Chosen option: **a multi-axis structured framework**, with a mandatory
three-block output covering Quality Issues, Performance & Atomicity, and Design
Patterns. A flat checklist tends to be skimmed top-to-bottom and abandoned once
"enough" boxes are checked; requiring three distinct blocks forces a reviewer to
explicitly reason about performance and atomicity as a category, not as an
afterthought to general code quality — which is precisely the category that was
previously slipping through.

### Consequences

* Good, because performance/atomicity issues get a dedicated review pass instead
  of competing for attention with style and naming feedback.
* Good, because review quality becomes checkable: a review missing one of the
  three blocks is visibly incomplete, not just possibly shallow.
* Good, because the standards within each block (below) give reviewers a shared
  vocabulary, so feedback is consistent across different reviewers.
* Bad, because three required blocks is more overhead per review than a quick
  skim; accepted because the issues this catches are expensive once they reach
  production.

### Confirmation

A PR review is incomplete if any of the three blocks is missing; a missing
block is itself a blocking finding, not just a quality gap.

## Pros and Cons of the Options

### Unstructured review

* Good, because it has zero process overhead.
* Bad, because review quality and focus drift with whoever happens to review,
  and the category most likely to be skipped (performance/atomicity) is
  exactly the one with the highest production cost when missed.

### A single checklist

* Good, because it is more consistent than no structure at all.
* Bad, because a flat list does not force depth on any one category; it
  invites skimming rather than reasoning.

### A multi-axis structured framework

* Good, because each axis gets dedicated attention, and completeness is
  directly checkable.
* Bad, because it asks more of the reviewer's time per PR.

## More Information

### Standards adopted per axis

| Axis | Key standards |
|------|----------------|
| OOP | Encapsulation, Tell-Don't-Ask, Law of Demeter, polymorphism over `instanceof` chains |
| SOLID | SRP / OCP / LSP / ISP / DIP — interfaces introduced only once more than one implementation exists |
| Clean Code | Methods kept short and single-purpose, parameter counts bounded, named constants over magic values, no silent exception swallowing |
| DDD | Entity → Value Object → Aggregate → Domain Service → Repository layering |
| Performance | Atomicity of check-then-act sequences (native atomic ops or a scripted atomic operation, not a separate get/check/set), bounded queue/dead-letter handling for async work, awareness of the runtime's I/O concurrency model |
| Design patterns | Singleton (as a managed bean, not a hand-rolled static holder — see the companion record on static vs Singleton vs bean), Factory Method, Abstract Factory, Aggregator — each with explicit misuse criteria, not just "when to use" |

This framework is the review-time counterpart to two other records in this set:
the static/Singleton/bean criteria reviewed here are the same ones in
[ADR-0005](0005-stateless-utility-singleton-vs-static.md); and structural rules
that can be mechanically enforced rather than relying on a human reviewer to
catch them are the subject of
[ADR-0022](0022-build-time-architecture-enforcement.md) — review focuses on
business logic, performance and design judgement; tooling enforces the rules
that don't need a human to check.

### Performance axis — common failure patterns by technology

The performance block is not a vague "check for slowness" prompt; it is
grounded in a recurring list of concrete, technology-specific failure patterns
that reviewers check for explicitly:

| Layer | Top risk items |
|-------|-----------------|
| JPA / relational | N+1 query, missing index, a long-running transaction holding a lock across an outbound HTTP/Kafka call |
| Redis | A non-atomic check-then-act sequence (must be a native atomic command or a Lua script — see [ADR-0026](0026-redis-lua-scripts-when-needed.md)), a hot key, a missing TTL |
| Kafka | No deduplication on the consumer side, a missing partition key for an entity that requires ordering, no dead-letter handling |
| HTTP / gRPC | Missing connect/read/write timeout configuration, a new client instantiated per request instead of reused, a synchronous remote call made inside a transaction |
| Multi-pod | A local in-process cache not invalidated across pods, a mutable field on a singleton-scoped bean, a scheduled task missing the distributed lock it needs (see [ADR-0018](0018-distributed-scheduling-strategy.md)) |
| WebSocket | Session state held only in memory with no recovery path, an O(N) broadcast loop, the I/O event-loop thread blocked by application logic |

Grounding the performance axis in this list, rather than leaving it to
individual reviewer intuition, is what makes the axis catchable in the first
place: a reviewer scanning a diff for "N+1" or "missing partition key" finds
something concrete; a reviewer asked to assess "is this performant" in the
abstract usually does not.
