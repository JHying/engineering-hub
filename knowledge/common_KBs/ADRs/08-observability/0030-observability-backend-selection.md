---
status: "accepted"
date: "2025-04-11"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# Observability backend selection: a self-hosted, correlated stack over a managed APM

## Context and Problem Statement

[ADR-0038](0038-observability-strategy.md) establishes *that* the platform
needs a full observability platform — metrics, logs, and traces, correlated —
rather than infrastructure-level monitoring alone. That leaves the *which*
question open: which backend actually stores and serves these three signal
types, and how are they wired together so an operator can pivot between them
without switching tools mid-investigation?

## Decision Drivers

* **Single pane of glass** — metrics, traces, and logs should be queryable
  together in one UI; pivoting from an alert to the relevant trace to the
  underlying log line should not mean changing tools.
* **Vendor-neutral instrumentation** — the telemetry format itself should not
  lock the platform into one backend; switching backends later should not
  require re-instrumenting every service.
* **Operational footprint** — the team operating this stack is the same team
  operating everything else; a stack with fewer distinct components to run is
  preferable to a more "best-of-breed but disconnected" combination.
* **Data handling constraints** — some telemetry (request traces, error
  context) can carry information about end users; where it is stored, and
  under whose control, is a real constraint on backend choice, not just a
  technical preference.

## Considered Options

* **ElasticSearch/Logstash/Kibana (ELK) for logs, plus a separate APM tool**
  (e.g. Jaeger/Zipkin for traces) — best-of-breed per signal type, no built-in
  correlation between tools.
* **A managed, hosted observability SaaS** — a vendor-operated backend for
  metrics, logs and traces, with zero self-hosting overhead.
* **A self-hosted, single-vendor correlated stack** — one backend family
  (e.g. a Prometheus-compatible metrics store, a trace store, and a log store
  from the same ecosystem) presented through one shared UI, built on
  vendor-neutral OpenTelemetry instrumentation.

## Decision Outcome

Chosen option: **a self-hosted, single-vendor correlated stack**, instrumented
through OpenTelemetry so the instrumentation itself stays backend-agnostic.
ELK plus a separate APM tool was rejected because the two halves do not
natively correlate — pivoting from a log line to the matching trace requires
manual timestamp matching across two different tools, which is exactly the
friction ADR-0038 set out to remove. A managed SaaS backend was rejected for
two compounding reasons: it adds an external data-egress and compliance review
for telemetry that can carry user-identifying request context, and it adds a
SaaS dependency on top of infrastructure that is already otherwise self-hosted
— a second operational model to reason about rather than one. The self-hosted
correlated stack keeps the three signal types in one queryable UI, keeps
telemetry data under the platform's own control, and — because instrumentation
goes through OpenTelemetry rather than a backend-specific SDK — does not lock
the choice in permanently: swapping the storage backend later is a collector
configuration change, not a re-instrumentation project.

### Consequences

* Good, because an operator investigating an alert can pivot from a metric to
  the correlated trace to the underlying log line from one UI, without manual
  timestamp correlation across separate tools.
* Good, because OpenTelemetry as the instrumentation layer means the backend
  is replaceable later without touching application code — only the collector
  export configuration changes.
* Good, because telemetry that may carry user-identifying request context
  stays on infrastructure the platform controls directly, rather than being
  exported to a third-party SaaS.
* Bad, because the team now operates the full stack itself (collector, metrics
  store, trace store, log store, dashboards, alerting) rather than offloading
  that operational burden to a vendor.
* Neutral, because a label-indexed log store (indexing only stream metadata —
  pod, namespace, service — rather than full log-line content) was chosen over
  a full-text-indexed one, trading slower ad hoc full-text search for
  significantly lower storage and memory cost; this is an acceptable trade
  because the primary investigation path is trace-first, log-correlated, not
  log-search-first.

### Confirmation

A new service is instrumented through OpenTelemetry as a baseline requirement,
not an opt-in; no service ships its own separate, disconnected logging or
tracing solution outside the shared stack.

## Pros and Cons of the Options

### ELK + separate APM tool

* Good, because each component can be best-of-breed in its own domain.
* Bad, because there is no native correlation between the log tool and the
  trace tool; an operator manually bridges them by timestamp.
* Bad, because full-text log indexing is resource-intensive for structured
  application logs where full-text search is rarely the primary need.

### Managed observability SaaS

* Good, because there is no self-hosting overhead; availability is the
  vendor's responsibility.
* Bad, because telemetry that can carry user request context would leave the
  platform's own infrastructure, triggering a data-egress and compliance
  review the self-hosted option avoids entirely.
* Bad, because it adds a SaaS operational model alongside infrastructure that
  is otherwise self-hosted.

### Self-hosted, single-vendor correlated stack (chosen)

* Good, because all three signal types converge in one tool with native
  correlation, and data stays under the platform's own control.
* Good, because OpenTelemetry instrumentation keeps the backend choice
  replaceable later.
* Bad, because the full stack is genuinely more infrastructure to run,
  monitor, and capacity-plan than offloading to a vendor would be.

## More Information

This record answers *which backend*; [ADR-0038](0038-observability-strategy.md)
answers *whether to adopt a full observability platform at all*, and the
companion [`distributed-tracing-reference`](https://github.com/YOUR_USERNAME/distributed-tracing-reference)
repository answers a third, narrower question — *how* trace context is
propagated across the specific boundaries (WebSocket, thread pools,
schedulers) that standard auto-instrumentation does not reach, once this
backend is already in place. The three are deliberately layered: strategy,
then backend, then the hard implementation detail.
