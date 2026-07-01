---
status: "accepted"
date: "2025-04-05"
decision-makers: "Backend / Platform Engineering"
---

# Event-driven state propagation over polling

## Context and Problem Statement

Two recurring patterns in the legacy platform used polling where a push model
would do: a client repeatedly polled to confirm whether its connection/login
state was still valid (rather than the server proactively notifying it), and a
server-side in-memory cache refreshed itself by repeatedly polling the database
for changes (rather than reacting to a change event). Both add load — network
traffic in the first case, database read pressure in the second — proportional
to the polling interval and client count, not to how often the underlying state
actually changes. Should these be redesigned as event-driven, and what is the
trade-off?

## Decision Drivers

* Reduce load proportional to *polling frequency* down to load proportional to
  *actual change frequency*.
* Faster propagation of a state change (push is near-immediate; polling is
  bounded by interval).
* Avoid unnecessary network/database traffic at scale — the cost of polling
  multiplies with the number of clients or cache instances.

## Considered Options

* **Keep polling** — simple, but cost scales with interval × client count.
* **Move to event-driven push** — the source of a state change notifies
  interested parties directly when it happens.

## Decision Outcome

Chosen option: **event-driven push**, for both cases. For connection/session
state, the server proactively notifies the client when state changes
(e.g. a forced disconnect) instead of the client repeatedly asking; this removes
polling traffic that scales with client count regardless of whether anything
changed. For cache refresh, the source of truth publishes a change event when
data actually changes, and the cache updates in reaction, instead of querying
the database on a fixed interval regardless of whether the underlying data
changed at all.

### Consequences

* Good, because network/database load now scales with *actual change
  frequency*, not with polling interval × number of clients/instances — a
  meaningfully better scaling curve as the platform grows.
* Good, because state changes propagate close to immediately, rather than being
  bounded by a polling interval.
* Bad, because an event-driven design requires a reliable delivery mechanism
  (a message broker, see [ADR-0042](0042-asynchronous-messaging-backbone.md))
  and the discipline to ensure every state-changing write actually emits its
  event — a polling reader cannot "miss" a change the way a missed/lost event
  can be missed if delivery is not handled carefully.

### Confirmation

New state-propagation needs default to an event on the writer side rather than
a polling reader; an exception requires a stated reason a push model does not
fit.

## Pros and Cons of the Options

### Polling

* Good, because it is simple to reason about and needs no delivery
  infrastructure — a reader just asks again later.
* Bad, because cost scales with polling interval × client/instance count
  regardless of whether anything actually changed, and propagation is bounded
  by the interval.

### Event-driven push

* Good, because cost scales with actual change frequency, and propagation is
  near-immediate.
* Bad, because it depends on reliable event delivery, which is a real piece of
  infrastructure and discipline to get right.

## More Information

The messaging backbone used for event delivery, and why it was chosen over a
simpler pub/sub primitive, is covered in
[ADR-0042](0042-asynchronous-messaging-backbone.md).
