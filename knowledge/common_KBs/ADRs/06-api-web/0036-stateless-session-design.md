---
status: "accepted"
date: "2025-03-08"
decision-makers: "Backend / Platform Engineering"
---

# Stateless session design: removing sticky sessions

## Context and Problem Statement

The legacy platform relied heavily on sticky sessions: a user's requests were
pinned to the server instance holding their in-memory session state. That
coupling between *a user* and *a specific instance* sits awkwardly with a
horizontally-scaled, frequently-redeployed microservices platform. Should
session affinity remain the default, and if not, what replaces it?

## Decision Drivers

* Horizontal scaling must not be constrained by where a user's state lives.
* Rolling deploys should not disrupt sessions pinned to a recycled instance.
* Availability — losing the one instance holding a session should not lose
  the session.
* Some session-like behaviour is still useful to keep "sticky" deliberately
  (e.g. routing a user's WebSocket frames to the same pod for the life of a
  connection), which is a different concern from storing *business* session
  state in instance memory.

## Considered Options

* **Keep sticky sessions** as the default, with session data in instance memory.
* **Go fully stateless** — externalise session state, no affinity anywhere.
* **Externalise session state, and reserve affinity only for cases that
  genuinely need it** (e.g. a live connection, not business state).

## Decision Outcome

Chosen option: **externalise session state, and reserve affinity only where a
live connection genuinely requires it**. Storing business session state in
instance memory and routing by affinity creates a hard coupling between a user
and a specific instance: scaling out doesn't help that user, recycling that
instance loses their session, and any rebalancing is a user-visible disruption.
Moving session state to a shared, externalised store removes that coupling.
Where a live, stateful connection (not business session data) genuinely
benefits from being pinned — see
[ADR-0032](0032-service-decomposition-for-independent-scaling.md)'s WebSocket
context — affinity is kept, deliberately, at the routing layer rather than by
holding state in instance memory.

### Consequences

* Good, because any instance can serve any user's next request; horizontal
  scaling and rolling deploys no longer risk dropping a user's session.
* Good, because instance loss no longer means session loss.
* Neutral, because the small remaining cases that benefit from affinity (live
  connections) get it at the routing layer (e.g. consistent-hash load
  balancing), which is a narrower, intentional use of the same idea — not a
  default.
* Bad, because externalised session reads add a network hop that in-memory
  session access did not have; mitigated by using a fast shared cache for
  session storage.

### Confirmation

No service stores business session state only in instance memory; any
deliberate use of routing affinity is documented as serving a specific
stateful-connection need, not as a substitute for externalised session storage.

## Pros and Cons of the Options

### Keep sticky sessions (status quo)

* Good, because in-memory session access has no network hop.
* Bad, because it directly limits horizontal scaling and availability — exactly
  the properties the platform decomposition in
  [ADR-0032](0032-service-decomposition-for-independent-scaling.md) is meant to
  gain.

### Go fully stateless, no affinity anywhere

* Good, because it is the simplest mental model — any instance, any request.
* Bad, because a small number of genuinely connection-based cases (e.g. a live
  WebSocket) lose a legitimate optimisation if affinity is banned outright,
  not just discouraged as a default.

### Externalise session state; reserve affinity for genuine connection cases

* Good, because it gets the scaling/availability benefit everywhere it matters,
  while not over-correcting against the cases where affinity is the right tool.
* Bad, because it requires the team to be disciplined about *which* cases
  qualify, rather than defaulting to "just pin it" out of habit.

## More Information

The connection-affinity case (routing a live WebSocket to a consistent pod) is
implemented at the service-mesh layer rather than the application layer,
keeping the "business session is stateless" rule unambiguous in application
code.
