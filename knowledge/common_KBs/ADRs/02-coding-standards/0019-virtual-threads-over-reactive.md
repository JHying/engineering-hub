---
status: "accepted"
date: "2025-03-28"
decision-makers: "Backend / Platform Engineering"
---

# Virtual threads over reactive for I/O-bound concurrency at scale

## Context and Problem Statement

The platform targets a very high count of concurrent, mostly-idle, I/O-bound
connections — a C10K-class workload. The classic answer to that workload shape
is a reactive stack: non-blocking I/O all the way through, freeing OS threads
from being held hostage by slow I/O. But the codebase is built on a layered,
imperative domain model (see [ADR-0021](0021-fifth-ddd-layer-manager.md)), and
reactive programming is not a drop-in addition — it is a different programming
model end to end. Is a reactive rewrite actually necessary to hit the
concurrency target, or is there a path that gets the same throughput without
restructuring the whole call stack?

## Decision Drivers

* Platform threads cannot scale to C10K directly — each carries a fixed-size
  stack, and stack memory plus OS scheduler overhead become the binding
  constraint well before the target connection count.
* A reactive rewrite is not syntactic — every I/O-performing method in a
  layered call stack must change its return type and composition style, which
  invalidates structural rules built around the existing layered model.
  domain-layer return-type enforcement see [ADR-0022](0022-build-time-architecture-enforcement.md).
* The relational persistence layer in use has no first-class reactive driver,
  so a reactive rewrite would still need to bridge blocking calls anyway.
* CPU-bound work (as opposed to I/O-bound) should not share the same execution
  model as I/O-bound work.

## Considered Options

* **Stay on platform threads**, scaling capacity by adding more OS threads.
* **Rewrite the I/O-bound call paths as reactive** (a non-blocking, declarative
  composition model throughout the stack).
* **Adopt virtual threads** for I/O-bound concurrent paths, keeping the
  existing imperative, layered programming model unchanged.

## Decision Outcome

Chosen option: **virtual threads for all I/O-bound concurrent paths**, with the
existing imperative call stack left structurally unchanged. At target
concurrency, platform threads (each carrying a fixed, comparatively large
stack) would require several gigabytes of stack memory just to hold idle
connections, on top of OS scheduler overhead from managing that many native
threads — a real, binding ceiling. Virtual threads park, rather than block,
when waiting on I/O, releasing the underlying carrier thread back to a small
pool sized roughly to CPU core count; the JVM can schedule a very large number
of virtual threads with negligible per-thread stack overhead while they wait.
This gets the platform-thread ceiling problem solved without adopting reactive
programming: a reactive rewrite would have meant changing the return type and
composition style of every I/O-performing method across the layered call stack,
which directly conflicts with structural rules that depend on that layered
model's method signatures, and — since the relational persistence layer used
has no first-class reactive driver — would still need to wrap blocking calls in
a reactive-compatible adapter, adding reactive syntax without removing the
underlying blocking call. Virtual threads deliver the same I/O-bound throughput
ceiling improvement with zero structural change to the codebase.

### Consequences

* Good, because the C10K-class concurrency target is reachable without a
  reactive rewrite — the existing imperative, layered architecture and its
  structural enforcement rules remain valid as-is.
* Good, because adopting virtual threads is additive: existing code does not
  need to change its programming model, only the executor it runs on.
* Bad, because virtual threads do not automatically inherit tracing context
  from the thread that spawned them, requiring an explicit context-wrapping
  step on every virtual-thread executor — covered in the companion
  [`distributed-tracing-reference`](https://github.com/YOUR_USERNAME/distributed-tracing-reference)
  repository.
* Neutral, because CPU-bound work is deliberately kept off virtual threads,
  using a separately bounded platform-thread pool instead — virtual threads
  solve the I/O-wait problem, not the "too much CPU work for too few cores"
  problem, and mixing the two on one pool risks starving the carrier threads
  virtual threads depend on.

### A clarification: the I/O event loop is not converted to virtual threads

It is worth being explicit about what does *not* change: the embedded
container's own I/O event-loop threads (the small pool of platform threads that
handle non-blocking socket I/O — accepting connections, reading frames) are
**not** converted to virtual threads and must not be, since that loop is
already non-blocking and is designed to never park. Virtual threads are
introduced one layer up: once a frame or request is handed off from the event
loop to application code, *that* hand-off runs on a virtual thread, where
blocking I/O (Redis, gRPC, an external HTTP call) is expected and safe. The two
thread models are complementary and operate at different layers — the platform
threads keep the event loop responsive; the virtual threads let application
code block freely without the platform-thread ceiling this record describes.

### Confirmation

A new I/O-bound concurrent path uses a virtual-thread executor by default; a
genuinely CPU-bound path uses a separate, bounded platform-thread pool, stated
explicitly as such.

## Pros and Cons of the Options

### Stay on platform threads

* Good, because it requires no new concurrency model to learn.
* Bad, because stack memory and OS scheduler overhead become a hard ceiling
  well below the target connection count.

### Rewrite as reactive

* Good, because reactive is a well-established answer to exactly this workload
  shape in other ecosystems.
* Bad, because the rewrite cost is architectural, not syntactic — every
  I/O-performing method in a layered stack changes shape, the relational
  persistence layer needs a blocking-call bridge anyway, and structural rules
  built around the current layered model would need to be rebuilt for a
  different composition style.

### Virtual threads

* Good, because it removes the platform-thread ceiling with zero structural
  change to the existing imperative, layered codebase.
* Bad, because tracing context propagation across virtual-thread boundaries
  needs explicit handling, since it is not automatic.

## More Information

This decision is paired with
[ADR-0024](0024-reactive-edge-imperative-core.md), which addresses the one
place reactive programming *is* adopted (a pure I/O proxy at the system edge,
with no domain logic) and explains why that one case is different from the
business-service case decided here.
