---
status: "accepted"
date: "2025-04-10"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# Observability strategy: from infrastructure monitoring to a full tracing/metrics platform

## Context and Problem Statement

The legacy monolith was monitored at the infrastructure level: is the host up,
is the process up, is the JVM healthy. That answers "is it alive," but not "why
is this one API slow" or "which of ten services caused this failed request."
Once the platform is decomposed into many services
([ADR-0032](0032-service-decomposition-for-independent-scaling.md)), a failure
or slowdown can originate in any one of them, and infrastructure-level
monitoring alone cannot localise it. What does the monitoring strategy need to
become?

## Decision Drivers

* Ability to localise a slow or failing request to the specific service/API
  responsible, not just "something is wrong."
* A consistent, vendor-neutral instrumentation standard, so it scales across
  many services without bespoke per-service tooling.
* Correlated logs, metrics and traces — so the route from "an alert fired" to
  "here is the request and the code path" is short.
* A path toward metrics-driven automated response, not just human-paged alerts.

## Considered Options

* **Keep infrastructure-level monitoring** (host/process/JVM health).
* **Adopt a standards-based observability platform** — OpenTelemetry for
  instrumentation, a metrics/trace backend, and a unified dashboard layer.

## Decision Outcome

Chosen option: **adopt a standards-based observability platform**, built on
OpenTelemetry for vendor-neutral instrumentation across services, with metrics,
logs and traces correlated and explorable from one place. Infrastructure
monitoring answers "is it alive"; this answers "which API, which service, which
request, and why" — which is the question that actually matters once a single
user-facing failure can originate in any one of many services.

### Consequences

* Good, because a slow or failing request can be traced to the responsible
  service and code path, not just flagged as "something is wrong somewhere."
* Good, because OpenTelemetry as a standard means new services are
  instrumented consistently without bespoke per-service tooling.
* Good, because correlated logs/metrics/traces shorten the path from alert to
  root cause, and open the door to metrics-driven automated remediation rather
  than purely human-paged response.
* Bad, because the platform now operates a telemetry pipeline (collector,
  storage, dashboards) as infrastructure in its own right, with its own
  capacity planning and noise-management concerns.

### Confirmation

A new service ships instrumented from day one (the OTel agent/SDK is part of
the base image, not opt-in); on-call can go from "alert" to "responsible
service and API" without manually correlating logs across services by hand.

## Pros and Cons of the Options

### Infrastructure-level monitoring only

* Good, because it is simple and already familiar.
* Bad, because it cannot answer "which service in this request chain is the
  problem," which is exactly the question decomposition makes common.

### Standards-based observability platform

* Good, because it localises problems to a specific service/API/request, and
  scales consistently as services are added.
* Bad, because it is new operational infrastructure to run and tune (noise
  filtering, sampling, storage).

## More Information

This record establishes the strategic shift toward a full observability
platform. Which backend actually implements it is a separate decision — see
[ADR-0030](0030-observability-backend-selection.md). The instrumentation
challenges specific to this platform — propagating trace context across
WebSocket connections, thread pools, and scheduled jobs, which standard
auto-instrumentation does not reach — are a third, narrower question,
documented in the companion
[`distributed-tracing-reference`](https://github.com/YOUR_USERNAME/distributed-tracing-reference)
repository once the chosen backend is in place.
