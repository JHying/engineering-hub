---
status: "accepted"
date: "2025-03-06"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# A config backbone with hot-reload, and why not Kubernetes-native config

## Context and Problem Statement

Kubernetes provides a native way to inject configuration into a pod. The
platform instead routes non-secret application configuration through a
dedicated config server, backed by the same discovery/coordination backbone
used elsewhere ([ADR-0001](0001-service-discovery-and-config-backbone.md)),
with changes picked up by running services without a restart. For connection-
heavy services holding many long-lived sessions, is that extra layer actually
justified, or would the platform-native mechanism have been good enough?

## Decision Drivers

* For a service holding many long-lived connections, a config change should
  not require restarting pods — a rolling restart to pick up a config change
  would disconnect every active session on the recycled pods.
* A config change should go through the same review process as application
  code, not bypass it via a direct cluster-side edit.
* Secrets must never live alongside general configuration in the same
  reviewed-and-applied artifact.
* Reuse existing infrastructure where possible rather than adding a new system
  for a problem an existing one can solve.

## Decision Outcome

Chosen option: **a dedicated config server backed by the existing
discovery/coordination backbone**, with configuration changes propagated to
running services via watch-and-refresh, in place without a pod restart.
Configuration lives in a Git-reviewed source; a sync step applies it to the
backbone's key-value store; running services watch for changes and refresh
their configuration beans in place, typically within a few seconds and with
zero dropped connections. Kubernetes-native configuration injection was
rejected for connection-heavy services specifically: picking up an environment-
sourced configuration change generally requires recycling the pod (a rolling
restart, or an extra operator component to avoid one), and either path disrupts
active long-lived sessions — exactly the disruption the hot-reload behaviour is
designed to avoid. It was also rejected because the native mechanism's refresh
signal is not integrated with the application framework's in-place
configuration-bean refresh mechanism, and because a direct cluster-side
configuration edit bypasses the same pull-request review gate that application
code changes go through, creating an inconsistent change-control bar between
"a code change" and "a config change" that should arguably be reviewed just as
carefully.

### Consequences

* Good, because configuration changes reach running services without
  disconnecting active sessions — directly serving the platform's
  zero-disruption deployment goals.
* Good, because every configuration change goes through the same
  pull-request review as application code, with no direct-to-cluster bypass
  path.
* Good, because it reuses the discovery/coordination backbone already deployed
  for [ADR-0001](0001-service-discovery-and-config-backbone.md), rather than
  operating a second system.
* Bad, because the platform now depends on that backbone's availability for
  configuration delivery as well as for discovery — an additional reason for
  that backbone to be operated at a high availability bar.

### Confirmation

No configuration change reaches a running service except through the reviewed
source and the watch-based refresh path; secrets are never present in that
configuration source — they are sourced exclusively from the secrets engine
described in [ADR-0013](0013-secrets-transit-engine-pattern.md).

## Pros and Cons of the Options

### Kubernetes-native configuration injection

* Good, because it requires no additional system — it's part of the platform
  already in use.
* Bad, because picking up a change generally means recycling the pod, which
  disrupts long-lived connections, and a direct cluster-side edit bypasses
  code-level review.

### A dedicated config server with hot-reload

* Good, because configuration changes apply without disrupting active
  sessions, and go through the same review gate as code.
* Bad, because it adds a dependency on the backbone's availability for a second
  concern (configuration) beyond its original purpose (discovery).

## More Information

Configuration is organised per service with shared, all-environment defaults
plus a small number of per-environment override files (e.g. for the cache
client, the messaging client, the database connection, and other
environment-varying settings) — one reviewed change updates every environment
atomically, consistent with the "central truth, local autonomy" pattern applied
elsewhere in this record set (see
[ADR-0034](0034-polyglot-persistence-secondary-document-store.md) and the
companion [`db-as-code`](https://github.com/YOUR_USERNAME/db-as-code)
reference for the same pattern applied to schema).
