---
status: "accepted"
date: "2025-04-22"
decision-makers: "Backend / Platform Engineering"
---

# WebSocket session ownership across pods: index, don't transfer

## Context and Problem Statement

A live WebSocket session object is a handle to an open TCP connection. It is
not serializable and cannot be moved between JVMs — there is no way to "hand
off" a connection object from one pod to another. But other pods and other
services routinely need to answer two questions about that connection: "is
this user currently connected, and where," and "force-close this user's
connection." How can the rest of the system act on a connection it
structurally cannot hold a reference to?

## Decision Drivers

* The connection object itself cannot move between processes — any solution
  must work around that constraint, not against it.
* Cross-pod operations (closing a session, checking presence) must reach the
  *owning* pod reliably, without the caller needing to know in advance which
  pod that is.
* The mechanism must survive a pod restart — a request to close a connection
  must not be silently lost if the target pod happens to be restarting at that
  moment.
* The hot path (sending a message to a connection the local pod already holds)
  must stay at local, in-process speed.

## Considered Options

* **Try to make the session itself shareable** — serialize or replicate
  connection state across pods.
* **Pod-to-pod direct calls**, with the caller looking up which pod holds a
  given session and calling it directly.
* **Index identity, broadcast intent** — keep the live connection strictly
  local; maintain a fast, shared index of *which pod currently owns which
  session*; reach a specific connection by broadcasting an intent to every pod
  and letting the owning pod act.

## Decision Outcome

Chosen option: **index identity, broadcast intent**, using three tiers:

| Tier | Mechanism | Responsibility |
|------|-----------|-----------------|
| Local, in-process map | A local, pod-scoped map from session identifier to the live connection object | O(1) hot-path message delivery and liveness checks — no network involved |
| Shared identity index | A fast, shared key-value index recording which pod currently owns a given user's session | Answers "is this user connected, and conceptually where" without needing to reach the connection object itself |
| Broadcast-based cross-pod action | Every pod subscribes to a per-service "session action" stream with its own independent delivery group, so every pod receives every action event; only the pod that actually owns the target session acts on it, the rest no-op | Closing/affecting a session whose owning pod is not known in advance by the caller |

Trying to make the session object itself shareable was rejected outright — it
contradicts the basic nature of a live TCP connection handle, which is
inherently local to one process by construction; there is nothing to serialize
that would still be a working connection on the other side. Direct pod-to-pod
calls were rejected because the caller would need a registry mapping sessions
to specific pod network addresses, adding a discovery problem the
broadcast-based approach avoids entirely: broadcasting to every pod and letting
the owner self-select removes the need for any pod registry at all. A
fire-and-forget broadcast primitive without delivery guarantees was rejected
for the action stream specifically, because it can silently drop a message
during a pod restart — an action event arriving exactly when the target pod is
cycling would be lost, and the session it was meant to close would never close.
A durable streaming backbone with independent per-pod consumption avoids this:
the restarted pod reads the action event on reconnect instead of having missed
it permanently.

### Consequences

* Good, because the hot path — delivering a message to a connection the local
  pod already owns — never leaves process memory.
* Good, because no component anywhere needs a registry of which pod holds which
  connection; "broadcast and let the owner act" structurally removes that
  problem.
* Good, because the action stream's durability means a pod restart does not
  silently drop in-flight session-affecting requests aimed at it.
* Bad, because every pod receives every action event, even though only one will
  ever act on it — a deliberate trade of some redundant message delivery for
  not needing a pod registry.
* Neutral, because a separate, lighter-weight validation step (matching a
  session-continuity token issued at login) guards against a stale browser tab
  reconnecting after the user has already logged in elsewhere — a correctness
  concern distinct from, but related to, the ownership-tracking problem this
  record addresses.

### Confirmation

A request to act on a specific user's session always goes through the
broadcast action stream, never through a direct pod-to-pod call that assumes
prior knowledge of which pod owns the target session.

## Pros and Cons of the Options

### Make the session itself shareable

* Good, because if it worked, it would need no indexing or broadcast logic at
  all.
* Bad, because a live connection handle is not a value that can be meaningfully
  serialized or moved between processes — this option does not actually exist
  for what a WebSocket session is.

### Pod-to-pod direct calls with a session registry

* Good, because, in principle, it avoids broadcasting to pods that don't own
  the target session.
* Bad, because it requires building and keeping correct a registry mapping
  sessions to specific pod addresses — a new source of staleness and failure
  on its own.

### Index identity, broadcast intent

* Good, because it needs no pod registry, keeps the hot path local, and (with a
  durable action stream) survives pod restarts without losing in-flight
  requests.
* Bad, because every pod processes every broadcast action event, even the ones
  that don't apply to it.

## More Information

This pattern complements [ADR-0042](0042-asynchronous-messaging-backbone.md)'s
choice of a durable messaging backbone over a fire-and-forget broadcast
primitive — the durability property that decision establishes generally is
exactly what makes the cross-pod session-action stream here safe against pod
restarts. A shared module exposes this pattern as a single opt-in annotation,
so a new connection-handling service adopts consistent session-action behaviour
without reimplementing the broadcast/ownership logic itself.
