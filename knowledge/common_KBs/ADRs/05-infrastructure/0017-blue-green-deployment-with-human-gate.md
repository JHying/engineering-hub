---
status: "accepted"
date: "2025-04-20"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# Blue-Green deployment with a human promotion gate

## Context and Problem Statement

For environments serving real users at meaningful concurrency, a deployment
that goes wrong needs to be both detectable before it affects everyone, and
instantly reversible. A plain rolling update replaces old pods with new ones
gradually, but a subtly broken new version still ends up serving production
traffic, just more slowly. What deployment strategy gives both an observation
window before full exposure and a near-instant rollback?

## Decision Drivers

* A bad deploy should be observable before it serves all production traffic.
* Rollback must be near-instant — reverting should not require redeploying the
  previous version from scratch.
* For higher-stakes environments, a human should confirm health before traffic
  fully switches; for low-stakes developer environments, that gate is
  unnecessary overhead.
* The mechanism should integrate with existing service-mesh traffic
  management rather than requiring a parallel routing system.

## Considered Options

* **Rolling update** — gradually replace old pods with new ones; traffic
  distribution follows pod replacement directly.
* **Blue-Green with automatic promotion** — new version receives full traffic
  automatically once basic health checks pass.
* **Blue-Green with a human promotion gate** — new pods come up isolated from
  production traffic; a human (or an explicit, observed approval step)
  confirms health before traffic is switched; the previous version is kept
  running for instant rollback.

## Decision Outcome

Chosen option: **Blue-Green with a human promotion gate**, for higher-stakes
environments; lower-stakes developer environments use a plain rolling update
since their isolated, per-branch namespaces already limit blast radius. New
pods come up under a preview routing path, invisible to real traffic, while the
previous (active) version keeps serving everything. An operator observes
dashboards and health signals against the preview pods, then explicitly
promotes — at which point the service mesh's traffic rule flips active traffic
to the new version. The previous version's pods are retained running, so a
rollback is the same traffic-rule flip in reverse, not a redeploy.

A rolling update was rejected for these environments because a subtly broken
version still serves real traffic as it rolls out — there is no isolated
observation window before exposure. Automatic promotion was rejected because
basic health checks (is the process up, does it respond) do not catch every
class of regression; for a high-stakes environment, an explicit confirmation
step is worth the added deployment time.

### Consequences

* Good, because a new version can be observed against real-shaped (or
  selectively mirrored) conditions before it receives any production traffic.
* Good, because rollback is a traffic-rule flip, not a redeploy — effectively
  instant.
* Good, because the same underlying mechanism supports additional progressive-
  delivery modes (see below) without new infrastructure.
* Bad, because it roughly doubles the running pod count during a deploy (old
  version retained alongside new), an accepted resource cost for the safety it
  buys.
* Bad, because a human gate adds latency to the deploy process for the
  environments that use it — an explicit trade against fully automated,
  unattended delivery.

### Confirmation

Automated rollback triggers (error rate, latency, message-queue lag, and
health-check failures crossing defined thresholds) can revert a promotion even
without waiting for human action, so the human gate is a forward-promotion
safeguard, not the only line of defence against a bad deploy that's already
been promoted.

## Pros and Cons of the Options

### Rolling update

* Good, because it is the simplest model and uses the least additional
  resources.
* Bad, because a broken version is exposed to real traffic incrementally as it
  rolls out, with no isolated observation window.

### Blue-Green with automatic promotion

* Good, because it adds the instant-rollback property without a manual step
  slowing down delivery.
* Bad, because basic automated health checks do not catch every regression
  class; some failures only show up under real or near-real traffic shape.

### Blue-Green with a human promotion gate

* Good, because it adds a genuine observation window plus instant rollback.
* Bad, because of the added resource cost and the deploy-time latency of a
  manual confirmation step.

## More Information

The same mesh-based traffic control that powers Blue-Green also supports
incremental canary rollout (a small percentage of traffic shifted, observed,
then increased) and traffic mirroring (shadowing real traffic to the new
version with responses discarded, for pre-promotion validation), without
additional infrastructure — both are step variations on the same underlying
promotion mechanism. Per-developer environments additionally use
header-based routing on this same mesh layer to route a request chain to a
specific branch's pods; that mechanism (and how trace context stays attached to
it across asynchronous boundaries) is documented in the companion
[`distributed-tracing-reference`](https://github.com/YOUR_USERNAME/distributed-tracing-reference)
repository rather than repeated here.
