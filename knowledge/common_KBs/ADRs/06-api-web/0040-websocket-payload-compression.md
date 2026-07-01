---
status: "accepted"
date: "2025-04-18"
decision-makers: "Backend / Platform Engineering"
---

# WebSocket payload compression strategy

## Context and Problem Statement

The platform's WebSocket traffic ranges from large, highly repetitive payloads
(e.g. an initial state sync sent on connect) to small, structurally simple
messages (e.g. a single user action). At the platform's message volume, wire
size directly affects bandwidth cost and, for the larger payloads, client-side
processing time. Should outbound WebSocket payloads be compressed, and if so,
is one strategy good enough for both payload shapes?

## Decision Drivers

* Reduce wire size for the largest, most repetitive payloads, where the
  potential saving is greatest.
* Must not meaningfully hurt latency for small, frequent messages — this is a
  real-time path.
* Processing overhead (serialize + compress) must stay negligible relative to
  the message-handling budget.

## Considered Options

* **No compression** — send serialized payloads as-is.
* **Compress every message uniformly**, regardless of size/shape.
* **Serialize with a compact format, then apply compression**, evaluated across
  both payload shapes (large/repetitive and small/simple) rather than assumed
  to behave the same for both.

## Decision Outcome

Chosen option: **serialize compactly, then compress, validated against both
payload shapes**. Testing showed the technique pays off very differently
depending on payload shape: large payloads with many repeated fields compress
dramatically, while small, structurally simple messages compress much less in
relative terms but still benefit, and in both cases the added processing time
stayed within a real-time budget. Validating both shapes (rather than assuming
the best case generalises) is what justified applying the strategy uniformly.

### Consequences

* Good, because the largest, most repetitive payloads — the ones that matter
  most for bandwidth — see the largest reduction.
* Good, because even small messages see a worthwhile reduction with processing
  overhead that stays within a real-time budget, so a single strategy can be
  applied uniformly instead of branching by message type.
* Neutral, because every message now carries a small fixed CPU cost for
  serialize+compress; acceptable given the measured overhead is sub-millisecond
  range, far inside the platform's latency budget.

### Confirmation

New WebSocket message types are measured against both a large/repetitive and a
small/simple representative payload before being added to the compressed path,
so the "it pays off" assumption is checked per message shape rather than taken
for granted.

## Pros and Cons of the Options

### No compression

* Good, because it is the simplest, with zero processing overhead.
* Bad, because it leaves a substantial, measured bandwidth saving on the table,
  especially for the largest payloads.

### Compress every message uniformly without validating both shapes

* Good, because it is easy to reason about — "always compress."
* Bad, because assuming the best-case (large/repetitive) result generalises to
  small/simple messages is an untested assumption; it happened to hold here,
  but adopting it without checking would have been the riskier path.

### Serialize compactly, then compress — validated per shape

* Good, because the decision is backed by evidence for the actual range of
  payloads the platform sends, not just the best case.
* Bad, because it requires an explicit measurement step for new message shapes
  rather than a blanket assumption.

## More Information

### Benchmark summary

Indicative results from testing against the platform's WebSocket traffic. Treat
as directional, not a guarantee for any arbitrary payload.

| Payload shape | Size reduction | Processing overhead |
|---|---:|---|
| Large, highly repetitive (e.g. initial state sync) | up to ~95% | sub-millisecond |
| Small, structurally simple (e.g. a single user action) | ~51% | sub-millisecond |

The compression strategy is applied at the serialization layer, so adding it to
a new message type is a configuration choice, not a per-message rewrite.
