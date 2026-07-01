---
status: "accepted"
date: "2025-04-02"
decision-makers: "Backend / Platform Engineering"
---

# Redis client library: Lettuce vs Redisson

## Context and Problem Statement

The platform leans on Redis heavily as a synchronization and caching layer —
including scheduled jobs that pull data from Redis to refresh local in-memory
caches. The existing client library was showing throughput headroom concerns
under the read/write pattern this produces. Should the platform switch Redis
client libraries, and on what evidence?

## Decision Drivers

* Raw throughput for the platform's actual read/write pattern (high-frequency
  counters and lookups, not just simple get/set).
* Reactive/async API support, to fit a non-blocking service style.
* Operational maturity and community support.
* Migration cost from the existing client.

## Considered Options

* **Redisson** — the existing client; rich feature set (distributed objects,
  locks, schedulers) beyond a plain Redis client.
* **Lettuce** — a lean, reactive-first Redis client built on Netty.

## Decision Outcome

Chosen option: **Lettuce**, for throughput-sensitive paths. A repeated
benchmark of the platform's actual access pattern (high-frequency counter
increments under a reactive/async workload) showed Lettuce sustaining
meaningfully higher throughput than Redisson in this configuration. Redisson's
extra features (distributed locks, distributed collections) were not the
deciding factor here, since the paths under test were plain reads/writes; where
those higher-level primitives are genuinely needed elsewhere, Redisson remains
an option rather than being removed outright.

### Consequences

* Good, because the throughput-sensitive scheduled-refresh / cache-update paths
  get measurably more headroom under load.
* Good, because Lettuce's reactive API fits the platform's broader non-blocking
  service style.
* Bad, because migrating existing call sites off Redisson is a real, if
  mechanical, body of work; done incrementally rather than as a single cutover.
* Neutral, because any genuine future need for Redisson-specific primitives
  (e.g. a distributed lock) is evaluated on its own merits rather than
  reflexively avoided.

### Confirmation

New Redis call sites use Lettuce by default; an exception requires a stated need
for a Redisson-specific feature.

## Pros and Cons of the Options

### Redisson

* Good, because it bundles distributed objects/locks/schedulers beyond a plain
  client, useful where those primitives are genuinely needed.
* Bad, because in benchmark it sustained lower throughput than Lettuce on the
  platform's actual high-frequency access pattern.

### Lettuce

* Good, because it sustained higher throughput in benchmark, and its
  reactive/async model fits the platform's non-blocking style.
* Bad, because it intentionally lacks Redisson's higher-level distributed
  primitives — those must be hand-built or sourced elsewhere if needed.

## More Information

### Benchmark summary

Indicative results from a repeated local benchmark (500,000 `INCR` operations,
reactive/async mode, local Redis, multiple runs). Treat as directional.

| Client | Throughput |
|---|---:|
| Redisson | ≈ 58K ops/sec |
| Lettuce | ≈ 75K ops/sec |
