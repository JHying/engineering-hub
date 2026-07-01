---
status: "accepted"
date: "2025-03-10"
decision-makers: "Backend / Platform Engineering, DBA"
consulted: "DBA"
---

# Integration testing against real datastores, not in-memory substitutes

## Context and Problem Statement

Persistence-layer tests need a database to run against. An in-memory substitute
(e.g. a lightweight embedded SQL engine standing in for the production
relational database) is fast and needs no external process, but it does not
behave identically to the production engine in every respect. Given the schema
pipeline already version-controls and reviews real migration scripts (see the
companion [`db-as-code`](https://github.com/YOUR_USERNAME/db-as-code)
reference), should persistence tests run against a lightweight substitute, or
against the real engines?

## Decision Drivers

* A test passing against a substitute must mean the same thing as passing
  against production — a false-positive pass is worse than no test.
* Database-specific behaviour (implicit commit semantics, vendor-specific DDL
  syntax, partitioning, upsert semantics) varies between engines in ways that
  matter for correctness, not just performance.
* The same migration script that's reviewed and applied to production should be
  the one validated in CI — no separate "test schema" that can drift from
  what's actually deployed.
* Test speed still matters; the heavier option must not make the inner
  developer loop unbearable.

## Considered Options

* **An in-memory substitute engine**, standing in for the relational database.
* **Mocked repositories**, standing in for both the relational and document
  stores.
* **Real engines via ephemeral containers**, initialised from the actual
  reviewed migration scripts.

## Decision Outcome

Chosen option: **real engines via ephemeral containers**, initialised from the
exact migration script files that the DBA reviews and that are applied to
production — the same file serves as the CI lint target, the test
container's initialisation script, and the production migration artifact, with
no "test DDL" that can diverge from what's actually deployed. An in-memory
substitute was rejected because the production relational engine has behaviours
a lightweight substitute does not emulate faithfully — implicit-commit
semantics around DDL, vendor-specific sequence and partitioning syntax, and
upsert/merge semantics differences — any of which can make a test pass against
the substitute and fail against the real engine for reasons that have nothing
to do with the code under test. Mocked repositories were rejected for the
document store specifically because a key correctness guarantee (the
upsert-based idempotency guard from
[ADR-0015](0015-multi-layer-idempotency-guard.md)) depends on the real
wire-protocol behaviour of a conditional insert against a unique index — a
mock returns whatever the test setup tells it to return, which cannot verify
that the real database actually enforces the guarantee.

### Consequences

* Good, because a passing persistence test is real evidence the code works
  against the actual engine, not against an approximation of it.
* Good, because there is exactly one migration-script artifact, eliminating an
  entire class of "passed in test, broke in production" caused by test/prod
  schema divergence.
* Good, because correctness guarantees that depend on real engine behaviour
  (the idempotency guard) are actually exercised, not assumed.
* Bad, because container-backed tests are slower to start than an in-memory
  substitute; mitigated by reusing one long-lived container across a test suite
  rather than starting one per test class.
* Neutral, because not everything needs this treatment — components where the
  real-vs-mock behavioural delta is negligible (an RPC client, an HTTP client,
  a lightweight in-memory message-broker substitute) are still mocked or
  stubbed; this decision is scoped to the persistence layer specifically, where
  the delta is not negligible.

### Confirmation

The container-backed persistence test suite runs as a blocking step before
static analysis and before any deployment artifact is built — a migration
script that fails against the real engine blocks the pipeline before anything
downstream is produced.

## Pros and Cons of the Options

### An in-memory substitute engine

* Good, because it starts fast and needs no external process.
* Bad, because vendor-specific behaviour differences mean a pass does not
  reliably predict a pass against the real production engine.

### Mocked repositories

* Good, because tests run with no external dependency at all and are very
  fast.
* Bad, because a mock cannot verify real wire-protocol-level guarantees (like a
  conditional insert's exact behaviour against a unique index), so it cannot
  actually test the correctness property that matters most.

### Real engines via ephemeral containers

* Good, because what passes in CI is genuine evidence of correctness against
  the real engine, using the exact same migration artifact that reaches
  production.
* Bad, because of slower test start time relative to an in-memory or mocked
  alternative, mitigated by container reuse across the suite.

## More Information

This decision is the testing-side half of the schema pipeline documented in
the companion [`db-as-code`](https://github.com/YOUR_USERNAME/db-as-code)
repository: that reference shows the same container-backed,
real-engine-validated pattern applied to the Entity↔schema contract test, using
the published schema as the single source of truth for what "correct" means.
