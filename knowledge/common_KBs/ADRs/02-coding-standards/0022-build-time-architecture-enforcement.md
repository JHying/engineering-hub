---
status: "accepted"
date: "2025-02-20"
decision-makers: "Backend / Platform Engineering"
---

# Build-time architecture enforcement via bytecode-level tests

## Context and Problem Statement

Layering rules, naming conventions, and dependency-direction constraints (see
[ADR-0021](0021-fifth-ddd-layer-manager.md)) are only useful if they actually
hold across ~10+ services and many contributors over time. A rule that lives
only in a document or a reviewer's memory drifts: it is caught inconsistently,
depends on who happens to review a given PR, and is expensive to verify by
reading code. How should structural architecture rules actually be enforced?

## Decision Drivers

* Enforcement must not depend on a human reliably noticing a violation in
  review.
* The rule needs to see actual dependency relationships (what imports what,
  what calls what), not just code style/syntax.
* Rules should run automatically on every build, the same as any other test.
* The mechanism must be shareable across many services without duplicating
  rule definitions per service.

## Considered Options

* **Rely on code review** to catch architecture violations manually.
* **A syntax/style linter** (e.g. a Checkstyle/PMD-class tool) configured with
  custom rules.
* **Bytecode-level architecture tests** — rules expressed as ordinary test
  classes that inspect the compiled class model (imports, call graphs,
  annotations), run as part of the normal test suite.

## Decision Outcome

Chosen option: **bytecode-level architecture tests**, written as ordinary test
classes and shared across every service via one test-scope dependency, so each
service inherits the full rule set by adding a single coordinate to its build —
no per-service rule duplication. A syntax-level linter was rejected for the
core requirement: it can enforce naming conventions and formatting, but it
cannot verify a true dependency-direction constraint like "this package must
never import from that package," because that requires understanding compiled
import/call relationships, not source text patterns. Relying on code review
alone was rejected because a human reliably catching every violation across
many services and contributors does not scale — and the violations this
catches are exactly the kind that are easy to miss reading one file in
isolation (an import is one line among many) but easy to check mechanically
across the whole compiled class model.

### Consequences

* Good, because a structural violation fails the build the same way a broken
  unit test would — it cannot merge silently.
* Good, because rules are defined once and shared, so adopting them in a new
  service is one dependency, not a rule rewrite.
* Good, because reviewers can stop spending attention on rules a machine
  already checks, and focus on business logic, performance, and design
  judgement instead — see [ADR-0008](0008-code-review-framework.md).
* Bad, because writing a correct architecture test (especially for nuanced
  dependency-direction rules) requires more upfront tooling investment than a
  linter config file.

### Confirmation

A structural rule violation (banned dependency direction, wrong naming-to-
package mapping, wrong stereotype annotation) fails the build; a passing build
is itself the confirmation that current code complies with every enforced
rule.

## Pros and Cons of the Options

### Code review alone

* Good, because it requires no tooling investment.
* Bad, because it does not scale reliably across many contributors and
  services, and the violations it's supposed to catch are easy to miss reading
  one file at a time.

### A syntax/style linter

* Good, because it is fast, well-understood tooling with broad ecosystem
  support.
* Bad, because it cannot express or verify true dependency-direction
  constraints — it operates on source syntax, not on the compiled
  import/call-graph model.

### Bytecode-level architecture tests

* Good, because it can express and enforce real dependency-direction and
  structural constraints as part of the normal test suite, shared across every
  service.
* Bad, because it requires more upfront investment to write well than a linter
  configuration.

## More Information

### A worked example: enforcing a data-safety rule structurally

One of the enforced rules is a global ban on a specific persistence-layer
method known to silently overwrite documents on a particular kind of
conditional insert — a footgun that corrupts the multi-layer idempotency
guarantee in [ADR-0015](0015-multi-layer-idempotency-guard.md) if used by
mistake. A reviewer cannot reliably catch every instance of a banned method
call across ~10 services by reading diffs; one architecture-test rule, checking
the compiled call graph for any call site of that method, catches all of them
automatically and structurally. This is the clearest illustration of using this
kind of enforcement for data *correctness*, not just for naming/style
consistency — and it's the reason the code-review guide explicitly marks
naming-and-layering concerns as **out of scope** for human review: the
architecture tests already own them, freeing review attention for the things a
machine cannot judge.
