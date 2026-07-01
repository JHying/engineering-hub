---
status: "accepted"
date: "2025-01-28"
decision-makers: "Backend / Platform Engineering"
---

# Stateless utilities: static vs Singleton vs managed bean

## Context and Problem Statement

The legacy codebase relied heavily on a large number of hand-rolled Singleton
"manager" classes and ad-hoc static helpers. As code moves into a
dependency-injection framework (Spring), we need a consistent rule for *how a
shared piece of logic should be expressed*: a class of static methods, a classic
hand-written Singleton, or a framework-managed bean. Picking by habit produces an
inconsistent codebase that is hard to test. What is the rule?

## Decision Drivers

* Statefulness — does the unit hold shared mutable state, or is it pure logic?
* Thread-safety under concurrent access.
* Testability — can callers substitute/mock it in a unit test?
* Need for dependency injection, polymorphism, or configuration.
* Memory/footprint (a minor concern; the difference is small in practice).

## Considered Options

* **All-static utility class** — no instance, methods on the type.
* **Classic Singleton** — one eagerly/lazily created instance, accessed via a
  static accessor.
* **Framework-managed bean** — Spring `@Component`/`@Service` (default singleton
  scope), or `prototype` scope for per-use instances.

## Decision Outcome

Chosen option: **choose by state and collaboration needs**:

* **Stateless, pure logic** (format helpers, generic utils) → **static utility
  class**. There is no instance state to protect; the footprint is minimal and
  the metadata is shared safely across threads.
* **Shared state, or needs DI / polymorphism / mocking / config** (the typical
  "manager") → **framework-managed singleton bean**. The DI container gives one
  instance, injectable collaborators, and an interface seam for testing.
* **Per-request stateful collaborators** (e.g., a DAO-like object) → a **new
  instance per use or `prototype` scope**, backed by a thread-safe connection
  pool — so there is no shared-mutable-state hazard at all.

### Consequences

* Good, because the rule is mechanical: "does it hold shared state or need
  collaborators?" answers it, which keeps the codebase consistent.
* Good, because managed beans are mockable behind interfaces, so business logic
  becomes unit-testable — the main weakness of the legacy static/Singleton style.
* Bad, because migrating the legacy 50+ static/Singleton managers to beans is
  incremental work, not a one-shot change.
* Neutral, because the memory difference between static and a single instance is
  negligible; footprint is explicitly **not** a deciding factor.

### Confirmation

New shared logic is reviewed against the rule above; static is reserved for
stateless utilities. Where a Singleton truly must remain (and creation is cheap),
it is expressed as a `static final` instance rather than a hand-rolled lazy
holder.

## Pros and Cons of the Options

### All-static utility class

* Good, because there is no instance to manage and method metadata is loaded once
  and shared across threads.
* Good, because it is the right tool for stateless helpers.
* Bad, because it cannot be injected, mocked, or made polymorphic; any static
  mutable field reintroduces a synchronisation hazard.

### Classic Singleton

* Good, because it guarantees one instance with controlled access.
* Bad, because the static accessor couples callers to a concrete type and resists
  mocking; in DI code it duplicates what the container already provides.

### Framework-managed bean

* Good, because of injection, interface seams (testability), polymorphism, and
  configuration support; `prototype` scope cleanly handles stateful per-use cases.
* Neutral, because it requires the DI container — already present here.

## More Information

Implementation note: `@Autowired` does not belong on an abstract base class —
inject the dependency from the concrete subclass instead, so the base stays
constructible and testable.
