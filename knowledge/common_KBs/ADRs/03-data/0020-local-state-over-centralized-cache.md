---
status: "accepted"
date: "2025-04-28"
decision-makers: "Backend / Platform Engineering"
---

# Local JVM state over centralizing everything in a shared cache

## Context and Problem Statement

A natural default in a distributed system is "anything that might be needed
elsewhere goes in a shared store" — it's simple to reason about and avoids
per-pod inconsistency. But for one connection-affined, latency-critical write
path, mutable per-request state was kept in a local, pod-scoped in-process
cache instead, with only the cross-service aggregate values centralized. Given
that connection-affined sessions are already pinned to one pod (see
[ADR-0037](0037-stateless-session-design.md) for the general no-sticky-session
rule and its deliberate exception for live connections), was keeping some state
local actually justified, or is "always centralize" still the safer default?

## Decision Drivers

* Data that, by construction, only one pod will ever need should not pay the
  cost of a network round-trip on every access.
* Some flags are correctness-sensitive specifically *because* they must reset
  on crash — persisting them somewhere durable would be a bug, not a safety
  net.
* Added Redis round-trips on an already latency-dominated hot path are not
  free at volume.
* Whatever the answer, normal disconnect/reconnect must not lose state a user
  would expect to still be there.

## Considered Options

* **Centralize all mutable state in Redis**, including per-request,
  pod-affined data.
* **Keep all mutable state local to the JVM**, with no externalized backup at
  all.
* **Partition state by who actually needs it**: per-request, pod-affined data
  stays local; values genuinely needed cross-pod go in the shared cache; a
  durable system of record holds the authoritative checkpoint.

## Decision Outcome

Chosen option: **partition state by who actually needs it**, across three
tiers:

| Data | Storage | Reason |
|------|---------|--------|
| Per-request working state (e.g. details of one in-flight write, scoped to the connection that started it) | Local JVM cache | Session affinity (see [ADR-0037](0037-stateless-session-design.md)'s connection exception) means only this pod will ever touch it; local access is effectively free |
| An in-flight-operation flag that must be safe to lose on crash | Local JVM cache **only**, deliberately not persisted | If persisted, a crash mid-operation would leave the flag durably "true," permanently suppressing the automatic recovery process that depends on seeing it reset |
| Cross-pod aggregate values that other pods/services genuinely need to read | A shared, fast cache | This is real cross-cutting state — it belongs in tier 2 by the model in [ADR-0034](0034-polyglot-persistence-secondary-document-store.md) |
| The durable checkpoint of the operation itself | The system of record | Always written first — this is what survives a crash and drives recovery (see [ADR-0011](0011-saga-pattern-local-orchestration.md)) |

The deciding insight for the local-only flag is the crash-reset property:
because the flag's correctness depends on it disappearing when the pod that set
it dies, a *more durable* store is actually the wrong tool here, not a stronger
one — Redis persistence would survive the crash and keep the flag stuck "true,"
permanently blocking the very recovery mechanism designed to handle that crash.
No TTL choice fixes this, because the right "reset time" is exactly "when this
process dies," which only process-local memory provides for free.

For the broader per-request state, centralizing it would have added several
unnecessary round-trips to the shared cache per operation, on a path already
dominated by an external call and the durable write — multiplying out to a
meaningful, avoidable share of total cache load for data that, by construction
of the session-affinity rule, never crosses a pod boundary anyway.

### Consequences

* Good, because per-request state reads are local-memory speed, removing
  avoidable network round-trips from the hottest part of the write path.
* Good, because the in-flight-operation flag's crash-reset behaviour is correct
  by construction, with no TTL tuning required to approximate it.
* Good, because genuinely cross-pod data still goes through the shared cache —
  this is a deliberate partition, not a rejection of centralization in
  general.
* Bad, because local state is, definitionally, not visible to any other pod —
  if a session is ever force-migrated to a different pod outside the normal
  reconnect path, this local state does not travel with it.
* Bad, because recovering from an *abnormal* disconnect (not a clean crash) relies
  on a backup path: state is periodically and on-error written to the shared
  cache as a recovery point, so a normal reconnect can rebuild it. This backup
  path is additional logic that has to be kept correct alongside the
  local-first design.

### Confirmation

State is local-only if and only if exactly one pod can ever need it for the
life of that state (enforced by the session-affinity guarantee); anything a
second pod or service might legitimately need to read goes in the shared cache
by default, not local-by-habit.

## Pros and Cons of the Options

### Centralize all mutable state

* Good, because all state is uniformly visible from any pod, with no special
  cases to reason about.
* Bad, because it pays a network round-trip for state that, by construction,
  never needs to be read anywhere but the pod that created it — and it gets the
  crash-reset flag actively wrong, since a centralized, persisted flag survives
  the very crash it needs to reset on.

### Keep all mutable state local, no backup

* Good, because it is the fastest possible option for the common case.
* Bad, because an abnormal disconnect with no recovery path would simply lose
  state a user expects to still be there.

### Partition state by who actually needs it

* Good, because each piece of state lives in the tier matched to its actual
  access pattern and correctness requirement, including getting the
  crash-reset flag's behaviour right by using the absence of persistence as the
  mechanism.
* Bad, because it requires a recovery/backup path for the local tier to handle
  abnormal disconnects, adding logic beyond a single uniform storage choice.

## More Information

This is a concrete instance of a more general principle worth naming
explicitly: **default to centralizing shared state, but recognise when a
property you need (here, "reset exactly on process death") is something only
the absence of persistence can give you for free.** Reaching for the more
durable store is not automatically the safer choice when the durability itself
is the bug.
