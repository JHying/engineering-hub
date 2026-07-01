---
status: "accepted"
date: "2026-06-29"
decision-makers: "Backend Engineering"
---

# Defer sealed interfaces for multi-state return types until adoption conditions are met

## Context and Problem Statement

JDK 17 introduced sealed interfaces as a first-class mechanism for modelling
closed, exhaustive type hierarchies — a natural fit whenever a method returns
one of a fixed set of outcomes (e.g., success / timeout / failure). At the same
time, adopting sealed interfaces in a working codebase carries real costs: test
framework compatibility, the team's familiarity with the pattern, and the
stability of the state set itself all determine whether the benefit justifies the
investment *right now*. The question is: under what conditions should a team
introduce sealed interfaces, and when should it defer?

## Decision Drivers

* **Test framework compatibility.** JUnit 4 does not have built-in support for
  exhaustive pattern-match assertions on sealed types; workarounds are verbose
  and non-idiomatic, reducing the readability benefit that sealed interfaces are
  meant to provide.
* **Team familiarity.** A pattern introduced before the team understands it
  becomes a maintenance burden rather than a reliability aid — reviewers cannot
  spot misuse, and new contributors face a steeper onboarding curve.
* **State-set stability.** A sealed hierarchy is a closed contract. If the set
  of possible outcomes is still being discovered or actively debated, sealing it
  prematurely forces unnecessary hierarchy changes and invalidates existing
  exhaustive `switch` expressions every time a new case is added.
* **Readability and safety in reviews.** The value of sealed interfaces is
  compiler-enforced exhaustiveness — this benefit is lost if reviewers are not
  familiar enough to evaluate `when`/`switch` branches critically.

## Considered Options

* **Introduce sealed interface hierarchies now** for all multi-state return
  types, treating JDK 21 capabilities as baseline.
* **Use `enum` + `Optional` fields** to model multi-state outcomes with the
  existing team vocabulary.
* **Defer sealed interfaces** until defined adoption prerequisites are met;
  continue using existing idioms in the interim.

## Decision Outcome

Chosen option: **defer sealed interfaces** until the following conditions are
all true:

1. The team has migrated to **JUnit 5** (or added a compatible assertion
   library for sealed types).
2. The team has completed at minimum an internal session on sealed interfaces
   and pattern matching — reviewers must be able to assess exhaustiveness
   coverage.
3. The **state set being modelled is stable** — no open questions about adding
   or splitting cases within the next development cycle.

Until those conditions are met, model multi-state outcomes with existing
idioms (`enum`, result wrapper classes, or explicit boolean fields). When the
conditions are met, introduce sealed interfaces *at natural boundaries*
(new feature, extracted service) rather than retrofitting existing classes.

### Consequences

* Good, because the team avoids a learning-curve tax on pattern matching in
  production code before they can review it with confidence.
* Good, because deferring protects against a prematurely closed hierarchy
  that must be reopened when business states are still in flux.
* Bad, because multi-state `enum`-based returns lack compiler-enforced
  exhaustiveness — reviewers must manually verify that all states are handled.
* Neutral, because the deferral is condition-gated, not time-gated: if the
  team is ready and the states are stable, adoption can happen sooner than
  expected.

### Confirmation

During code review: if a PR introduces a sealed interface before the three
prerequisites above are satisfied, flag it as a finding. If a PR uses
`boolean` flags to approximate a three-or-more-state outcome *and* the
prerequisites are satisfied, suggest migrating to a sealed interface as a
non-blocking improvement note.

## Pros and Cons of the Options

### Introduce sealed interfaces now

* Good, because compiler-enforced exhaustiveness catches missing cases at
  compile time rather than at runtime or in review.
* Bad, because the test framework cannot leverage the sealed contract
  idiomatically, making tests harder to read and write.
* Bad, because unfamiliar reviewers cannot evaluate exhaustiveness coverage
  during review — the safety benefit is illusory until the team knows the
  pattern.
* Bad, because sealing an unstable state set forces hierarchy changes every
  time a new state is discovered.

### `enum` + result wrapper

* Good, because it is immediately understandable to the whole team.
* Good, because adding a new state is a one-line `enum` change (though callers
  do not receive a compile error for missing branches).
* Bad, because the compiler does not enforce exhaustiveness — a missing `case`
  silently falls through unless explicitly guarded.

### Defer until adoption conditions are met

* Good, because it ties adoption to readiness, not to JDK availability.
* Good, because when adoption does happen the team can use the pattern
  correctly from day one.
* Bad, because the team forgoes compiler-enforced exhaustiveness in the interim.

## More Information

Reconsider this decision when:

* The project migrates to JUnit 5 (see
  [ADR-0023](0023-integration-testing-real-datastores.md) for the testing
  strategy context).
* The set of states for a specific multi-state return type has been stable
  across two or more consecutive sprints.
* An internal knowledge-sharing session on JDK 17+ sealed interfaces and
  pattern matching has been completed.

Related: [ADR-0019](0019-virtual-threads-over-reactive.md) — another case of
a JDK 21 capability whose adoption timeline was evaluated separately from its
availability.
