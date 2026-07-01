---
status: "accepted"
date: "2025-04-16"
decision-makers: "Backend / Platform Engineering"
---

# Distributed scheduling: matching the lock strategy to task side-effect type

## Context and Problem Statement

A scheduled (timer-driven) task running identically on every pod of a
horizontally-scaled service is fine for some tasks and actively wrong for
others. If a task's side effect is idempotent and purely local to the pod
(recovering that pod's own in-flight state), running it on every pod is exactly
right. If a task's side effect is a cross-service call or a shared write, N
pods running it simultaneously produces N duplicate side effects, not one.
Should every scheduled task use the same coordination mechanism?

## Decision Drivers

* A scheduled task's correct execution count (once cluster-wide, vs once per
  pod) depends entirely on what its side effect actually is — there is no
  single right default.
* The coordination mechanism for "exactly once across the cluster" must not add
  meaningful latency for tasks that need sub-second intervals.
* Adding a new scheduling mechanism (e.g. a full job-scheduling system) should
  only happen if the existing options can't satisfy the requirement.

## Considered Options

* **One mechanism for everything — a cluster-wide lock for every scheduled
  task**, regardless of side-effect type.
* **One mechanism for everything — bare per-pod scheduling for every task**,
  regardless of side-effect type.
* **Match the mechanism to the task**: a lightweight distributed lock for
  cross-service/shared-write tasks; bare per-pod scheduling for local,
  idempotent recovery tasks.
* **A full distributed job-scheduling system** (e.g. one requiring its own job
  store and cluster heartbeat).

## Decision Outcome

Chosen option: **match the mechanism to the task's side-effect type**.

| Task type | Mechanism | Why |
|-----------|-----------|-----|
| Cross-service call or shared write — N simultaneous executions means N incorrect side effects | A lightweight distributed lock wrapping a standard scheduled-method annotation | Ensures the task runs once cluster-wide per interval, at the cost of one lock acquisition |
| Per-pod local, idempotent state recovery — must run on every pod, not just one | Bare per-pod scheduling, no cluster coordination | Each pod only ever recovers its own local state; a cluster-wide lock would leave every *other* pod's local state stuck, since only the lock-holder would run |

A single "always use a cluster-wide lock" default was rejected because it would
break the local-recovery case directly: if only one pod can hold the lock, every
other pod's local state never gets its recovery tick, which is the opposite of
correct. A single "always run bare per-pod" default was rejected because for
tasks with cross-service or shared-write side effects, every pod firing
identically multiplies the side effect by the pod count. A full distributed
job-scheduling system (with its own persistent job store) was rejected as
disproportionate: it requires new schema/infrastructure that nothing else in
the stack uses, and its cluster heartbeat model adds latency unsuitable for
tasks that need to run on short, sub-second intervals; a lightweight lock
wrapping the existing scheduling annotation achieves the same "once
cluster-wide" guarantee with none of that overhead, for tasks where the
interval requirement allows it.

### Consequences

* Good, because each task's coordination matches its actual correctness
  requirement, instead of a one-size-fits-all default that is wrong for one of
  the two cases by construction.
* Good, because the lightweight lock adds no new schema or infrastructure on
  top of what was already in use for scheduling.
* Bad, because a developer adding a new scheduled task must correctly classify
  it (cross-service/shared-write vs local/idempotent) — getting this wrong in
  either direction produces a real bug, not just a style issue.

### Confirmation

A new scheduled task's side-effect type (cross-service/shared-write vs
local/idempotent) is stated explicitly when it is introduced, and that
classification determines which of the two mechanisms it uses; "no
coordination" is never the default for a task with a shared side effect. When
the classification is genuinely unclear, the default is the distributed lock,
not the bare per-pod scheduler — a task that runs once when it could safely
have run on every pod is a missed optimisation; a task that runs on every pod
when it needed to run once is a correctness bug. The tie-breaker favours the
safer failure mode.

## Pros and Cons of the Options

### Cluster-wide lock for everything

* Good, because it is simple to reason about — "only one pod ever runs this."
* Bad, because it actively breaks any task that needs to run its own
  per-pod-local recovery, since non-lock-holding pods never execute.

### Bare per-pod scheduling for everything

* Good, because it is the simplest possible mechanism, with no coordination
  overhead.
* Bad, because any task with a cross-service or shared-write side effect
  produces N duplicate effects across N pods.

### Match the mechanism to the task

* Good, because each task gets the coordination its actual side effect
  requires.
* Bad, because it requires correct classification per task, and two
  mechanisms to understand instead of one.

### A full distributed job-scheduling system

* Good, because it provides general-purpose cluster-wide scheduling with
  built-in tooling.
* Bad, because it requires new persistent infrastructure the stack does not
  otherwise need, and its coordination heartbeat is too slow for sub-second
  scheduling intervals.

## More Information

The local, per-pod recovery case is the same recovery mechanism referenced in
[ADR-0011](0011-saga-pattern-local-orchestration.md): a saga's automatic
recovery of stuck in-flight steps is exactly the "must run on every pod, purely
local, idempotent" case this record's second row describes — which is why that
recovery loop deliberately avoids a cluster-wide lock.
