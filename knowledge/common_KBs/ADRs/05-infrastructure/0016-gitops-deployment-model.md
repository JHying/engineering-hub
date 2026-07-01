---
status: "accepted"
date: "2025-03-02"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# GitOps deployment model: declarative CD over scripted/imperative deployment

## Context and Problem Statement

With containers and Kubernetes adopted as the runtime
([ADR-0035](0035-containerization-and-orchestration.md)), deployment still
needs a defined model: what triggers a deployment, what is the source of truth
for what's running, and how does rollback work. Should deployment be driven
imperatively (scripts/pipeline steps that push changes to the cluster), or
should the cluster state be declared and reconciled?

## Decision Drivers

* Cluster state should be reconstructable from version control alone, not from
  tribal knowledge of what scripts were last run.
* Rollback should be fast and not depend on re-running a pipeline.
* Many developers working on parallel branches should be able to deploy
  isolated environments without colliding.
* The CI (build/test) and CD (what's deployed where) concerns benefit from
  being separated, so a build doesn't implicitly deploy.

## Considered Options

* **Imperative CD** — a pipeline step pushes changes directly to the cluster
  (`kubectl apply`, scripted deploys).
* **Declarative GitOps** — a Git repository is the source of truth for desired
  cluster state; a controller continuously reconciles the live cluster to match
  it.

## Decision Outcome

Chosen option: **declarative GitOps**. CI builds and tests an image; a separate
step writes only the new image tag into a deployment-configuration repository;
a cluster-side controller watches that repository and reconciles the cluster to
match automatically. This separates "build and test passed" from "this is now
deployed" into two explicit, auditable steps, and means the cluster's desired
state is always exactly what's in Git — recoverable, diffable, and reviewable
the same way application code is.

### Consequences

* Good, because rollback is a Git revert of the image tag; the controller
  re-syncs automatically within seconds, with no pipeline re-run needed.
* Good, because every change to what's deployed is a reviewable pull request,
  not an ad hoc `kubectl apply` that bypasses review.
* Good, because per-branch, per-developer isolated environments are just
  another entry in the declared configuration — adding one doesn't require new
  scripting, just a new overlay.
* Bad, because there are now two repositories in play for a single deploy (the
  application/build repo and the deployment-config repo), which is an extra
  layer of indirection to understand when first learning the system.

### Confirmation

No deployment change reaches the cluster except through a reviewed change to
the deployment-configuration repository; direct `kubectl apply` to
shared/persistent environments is treated as a process violation, not a
convenience.

## Pros and Cons of the Options

### Imperative CD

* Good, because it is conceptually simpler — one pipeline does build and
  deploy in one straight line.
* Bad, because the cluster's actual state can drift from what anyone scripted,
  there is no single reviewable source of truth, and rollback means re-running
  a pipeline rather than reverting a commit.

### Declarative GitOps

* Good, because Git is the auditable, reviewable, single source of truth for
  cluster state, and rollback is a revert, not a re-run.
* Bad, because of the added conceptual layer of a separate deployment-config
  repository and a reconciling controller to understand and operate.

## More Information

### Configuration-management tooling choices

**Manifest composition — overlay-based composition over a templating engine:**
chosen because the deployment manifests across services are largely identical,
differing only in a small number of fields (image tag, resource limits, replica
count) per environment. Overlay-based composition (a base manifest plus small,
explicit per-environment patches) is simpler to read and diff than a full
templating language when the vast majority of the manifest is shared and only a
few fields vary.

**Reconciliation tooling — a GitOps controller with native progressive-delivery
support:** chosen in part because it deploys the same custom resource it
natively manages for progressive delivery (canary/blue-green), avoiding the
need for a second, separate progressive-delivery tool bolted on afterward (see
[ADR-0017](0017-blue-green-deployment-with-human-gate.md)).

**Per-developer isolation:** every feature branch gets its own namespaced
overlay — an independent deployment, independent of other branches — generated
and torn down automatically as part of the branch lifecycle, so parallel
development does not collide on a shared environment.
