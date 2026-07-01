---
status: "accepted"
date: "2025-03-15"
decision-makers: "Backend / Platform Engineering"
---

# Synchronous inter-service communication: gRPC vs REST/JSON

## Context and Problem Statement

Decomposing into services ([ADR-0032](0032-service-decomposition-for-independent-scaling.md))
turns what were in-process calls into network calls. For latency-sensitive,
high-frequency internal calls, the serialization format and protocol directly
affect throughput and tail latency. Which protocol do we standardise on for
synchronous service-to-service calls?

## Decision Drivers

* Throughput and P99 latency headroom for high-frequency internal calls.
* Payload size, since serialization cost and network bytes both matter at volume.
* A strict, versionable contract between caller and callee.
* Cross-language support, since the platform is not exclusively Java end-to-end.

## Considered Options

* **REST over JSON** — the default, human-readable, ubiquitous tooling.
* **gRPC over Protocol Buffers** — binary, contract-first, HTTP/2.

## Decision Outcome

Chosen option: **gRPC**, for internal synchronous service-to-service calls.
Protocol Buffers' binary encoding is materially cheaper to serialize/deserialize
than JSON and produces a much smaller wire payload, and the generated contract
(`.proto`) gives both sides a shared, versioned, cross-language interface
instead of an implicit JSON shape. REST/JSON remains the right choice at the
public/browser-facing edge, where human-readability and ubiquitous client
support matter more than the last bit of throughput.

### Consequences

* Good, because internal calls get materially higher throughput and lower tail
  latency headroom, which matters directly for the scaling economics in
  [ADR-0032](0032-service-decomposition-for-independent-scaling.md).
* Good, because the `.proto` contract is explicit and cross-language, reducing
  silent breaking changes between services owned by different people.
* Bad, because gRPC is not natively browser-friendly and is harder to
  inspect/curl ad hoc than REST; mitigated by keeping gRPC internal-only and
  REST at any client-facing boundary.
* Neutral, because the team takes on contract/codegen tooling as part of the
  build, in exchange for the stricter contract.

### Confirmation

New internal service-to-service synchronous calls default to gRPC; REST is used
where a human or browser client is the caller.

## Pros and Cons of the Options

### REST over JSON

* Good, because it is human-readable, universally supported, and trivially
  debuggable.
* Bad, because JSON serialization and the larger wire payload cost more CPU and
  bandwidth at high call volume than a binary protocol.

### gRPC over Protocol Buffers

* Good, because binary encoding is faster to (de)serialize and produces a much
  smaller payload than the equivalent JSON.
* Good, because the generated contract gives strict, versioned typing across
  language boundaries.
* Bad, because it is less human-debuggable and less natural for browser
  clients.

## More Information

### Benchmark summary

Indicative results from a Spring Boot service-to-service comparison. Treat as
directional — relative shape, not a production capacity guarantee.

| Metric | REST / JSON | gRPC |
|---|---:|---:|
| QPS | 15k – 40k | 50k – 200k |
| P99 latency | 20 – 50 ms | 5 – 15 ms |
| Payload size (relative) | 100% | 20% – 40% |
| CPU usage | Higher | Lower |

The gap widens with call volume and payload complexity; for low-volume,
simple-shaped calls the difference is less decisive, which is why the public
edge keeps REST rather than adopting gRPC everywhere by default.
