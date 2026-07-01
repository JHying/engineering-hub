---
status: "accepted"
date: "2025-04-24"
decision-makers: "Backend / Platform Engineering"
---

# Protobuf contract evolution: backward-compatible changes only

## Context and Problem Statement

With gRPC as the internal synchronous protocol
([ADR-0033](0033-inter-service-communication-protocol.md)), the `.proto`
contract is shared, generated code across every caller and callee. Unlike a
JSON payload, where an unexpected field is silently ignored, a Protobuf field
number is part of the wire format — reusing or removing one incorrectly can
silently corrupt data for any party still running older generated code.
Rolling deploys mean caller and callee briefly run different versions of a
service routinely, not just during an incident. What rules keep contract
changes safe across that window?

## Decision Drivers

* During a rolling deploy, old and new versions of a service run
  simultaneously for a period — a contract change must be safe across that
  mixed-version window, not just safe "once everything has redeployed."
* A field number, once assigned, must never silently mean something different
  later — Protobuf decodes by field number, not by name.
* The rule needs to be simple enough to apply correctly under normal
  development pressure, not something that only works when someone remembers
  to think hard about it.

## Considered Options

* **No formal rule** — trust reviewers to notice a breaking proto change.
* **Coordinate every proto change with a simultaneous deploy** of every
  affected service, regardless of whether the change is actually breaking.
* **A backward-compatibility rule set**: additive changes are always safe for
  a rolling deploy; field-identity changes require explicit handling.

## Decision Outcome

Chosen option: **a backward-compatibility rule set**, applied to every proto
change:

| Change type | Rolling-deploy safe? | Rule |
|---|---|---|
| Add a new optional field | Yes | Old code simply does not read it; safe by construction |
| Add a new RPC method | Yes | Old clients never call it; safe by construction |
| Change a field's number | **No** | Old and new code disagree on what a given wire position means — never done |
| Delete a field | **No**, unless retired correctly | The field number must be marked reserved, never reused by a future field — otherwise a future, unrelated field silently inherits old data shaped for a different meaning |
| Change a field's type | **No** | Requires a coordinated, simultaneous deploy of every affected service — treated as a breaking change, not a routine one |

Trusting reviewers without a formal rule was rejected because the danger here
is not visible in a diff the way most bugs are — a field-number reuse looks
like an ordinary, small change and only manifests as data corruption later,
under the specific condition of a rolling deploy crossing old and new code.
Requiring a coordinated simultaneous deploy for *every* proto change, even
purely additive ones, was rejected as unnecessary overhead — the whole point of
the additive-change category is that it does not need coordination, and
treating every change as if it did would erase the benefit of having a
generated, versioned contract in the first place.

### Consequences

* Good, because the common case — adding a field or a method — ships on a
  normal rolling deploy with zero coordination overhead.
* Good, because the dangerous case (field-identity changes) is explicitly named
  and requires explicit, deliberate handling rather than being indistinguishable
  from a routine change.
* Good, because retired fields are marked reserved rather than silently
  available for reuse, preventing a future field from accidentally inheriting
  differently-shaped old data.
* Bad, because the rule depends on the contract author correctly classifying
  their own change — there is no tooling described here that mechanically
  blocks a non-additive change, only a stated discipline.

### Confirmation

A proto change is reviewed against the table above explicitly; a field-number
reuse or an unmarked field deletion is a blocking finding, not a style
preference.

## Pros and Cons of the Options

### No formal rule, trust review

* Good, because it adds no process overhead.
* Bad, because the failure mode (field-number reuse) is exactly the kind of
  subtle, delayed-impact bug that ordinary review is least likely to catch.

### Coordinate every change with a simultaneous deploy

* Good, because it is maximally safe — nothing is ever in a mixed-version
  state.
* Bad, because it discards the practical benefit of a versioned, additive-safe
  contract format for the (common) case of additive changes, adding
  coordination overhead where none is needed.

### A backward-compatibility rule set

* Good, because it matches the coordination cost to the actual risk of each
  change type — none for additive, explicit handling for identity-changing.
* Bad, because correct application depends on the author classifying the
  change correctly; the rule is a discipline, not an automated gate.

## More Information

This rule set governs the evolution of the same internal contracts whose
*initial* protocol choice (gRPC over REST for internal calls) is decided in
[ADR-0033](0033-inter-service-communication-protocol.md) — that record
addresses *which* protocol to use; this one addresses how that protocol's
contracts are safely changed once services depend on them.
