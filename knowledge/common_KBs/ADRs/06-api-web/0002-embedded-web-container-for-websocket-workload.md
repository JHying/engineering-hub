---
status: "accepted"
date: "2025-04-22"
decision-makers: "Backend / Platform Engineering"
consulted: "SRE"
---

# Embedded web container for a WebSocket-heavy workload: Undertow vs Tomcat

## Context and Problem Statement

A connection-facing service holds a large number of long-lived WebSocket
connections, each sending frequent heartbeat/ACK traffic with a tight latency
budget (ACK expected within ~200 ms). The target is a C10K-class workload:
hundreds of thousands of concurrent connections across replicas. Tomcat's
thread-per-request model puts a hard ceiling on connection count, so the
embedded container choice directly determines whether the latency and
concurrency targets are reachable. Which embedded web container do we standardise
on for connection-facing services?

## Decision Drivers

* Sustained WebSocket throughput under load without dropping frames.
* Connection scalability — the model must not allocate a thread per connection.
* Resource efficiency and startup time (matters for fast, fine-grained scaling).
* Compatibility with Java 21 virtual threads.
* Ability to keep using the standard `jakarta.websocket` (JSR-356) programming
  model the team already knows.

## Considered Options

* **Tomcat + virtual threads**
* **Undertow + virtual threads**
* **Netty / a reactive stack**

## Decision Outcome

Chosen option: **Undertow + virtual threads**, because in a controlled heartbeat
benchmark it sustained materially higher WebSocket throughput without dropping
frames, started faster, and — unlike a reactive rewrite — let us keep the
familiar `jakarta.websocket` model. Netty was excluded because it forces a
reactive programming style and abandons `jakarta.websocket`, a conversion cost
not justified by this workload.

### Consequences

* Good, because Undertow's non-blocking I/O sustains many connections with a
  small thread pool, which is the property the C10K target requires.
* Good, because faster startup (~10 s vs ~16 s in test) shortens scale-out and
  rollout time.
* Neutral, because the team standardises on Undertow specifically for
  connection-facing services; request/response services can remain on the
  default container if preferred.
* Bad, because Undertow has a smaller community than Tomcat, so deep
  troubleshooting may rely more on source reading. Mitigation: the application
  can fall back to Tomcat (embedded JAR or WAR) if a Tomcat-specific need arises,
  so the choice is reversible.

### Confirmation

A load test reproducing the heartbeat/ACK pattern must show zero dropped frames
at the agreed per-replica connection and message-rate target before a
connection-facing service ships.

## Pros and Cons of the Options

### Undertow + virtual threads

* Good, because non-blocking I/O decouples connection count from thread count.
* Good, because it sustained the higher message rates in test with no loss.
* Good, because faster startup helps autoscaling.
* Bad, because of a smaller ecosystem/community than Tomcat.

### Tomcat + virtual threads

* Good, because it is the most familiar, best-documented default.
* Good, because virtual threads relieve some thread-per-request pressure.
* Bad, because under sustained high message rates it began dropping frames in
  test and collapsed quickly under burst, making the C10K target unreachable.

### Netty / reactive

* Good, because it is built for massive concurrency.
* Bad, because it requires a reactive programming model and gives up
  `jakarta.websocket`; the rewrite/learning cost is high and was not warranted,
  so it was excluded from head-to-head testing.

## More Information

### Benchmark summary

Indicative results from a controlled test on a developer-class machine (capped
at 500 concurrent users — beyond ~1,000 the I/O threads saturated and skewed the
comparison). Treat as directional, not as production capacity numbers.

Scenario: open WebSocket → send heartbeat frames → backend serialises to JSON
and records to cache → expect ACK within 200 ms → close.

| Scenario (500 users)              | Tomcat + VT          | Undertow + VT        |
|-----------------------------------|----------------------|----------------------|
| 20 frames / 5 s                   | ~1,984 QPS, OK       | ~1,996 QPS, OK       |
| 100 frames / 10 s                 | frames dropped       | ~4,977 QPS, OK       |
| 400 frames / 20 s                 | frames dropped       | ~9,944 QPS, OK       |
| Unbounded burst until failure     | peak ~15,973 QPS, collapsed after ~0.6 s | peak ~23,021 QPS, collapsed after ~1.14 s |
| Startup time                      | ~16 s                | ~10 s                |

Reading: at moderate sustained load Tomcat began losing messages where Undertow
stayed lossless; at burst, Undertow reached a ~44% higher peak and held it
longer. The stronger the hardware, the wider the gap is expected to be.

### Related research

A separate internal JMeter benchmark comparing Netty against Javax WebSocket
(blocking IO, thread-per-connection) corroborates this ADR's problem statement:
under a 6,000-connection load, the blocking model showed materially higher CPU
consumption (283–314% vs Netty's 180%) and message delay (4–5 s vs Netty's
~2.7 s), degrading further as concurrency grew relative to available threads.
See [Netty vs Javax WebSocket performance comparison](../../tech-research/netty-vs-javax-websocket-performance.md).
