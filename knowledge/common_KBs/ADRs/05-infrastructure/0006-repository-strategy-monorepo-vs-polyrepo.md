---
status: "accepted"
date: "2025-02-25"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# Source repository strategy: monorepo vs polyrepo (hybrid)

## Context and Problem Statement

The platform is roughly ten services plus a body of shared code — a parent build
descriptor, common DTOs, a base controller, and cross-cutting toolbox libraries.
We must decide how source is organised: one monorepo for everything, one repo per
service (polyrepo), or a hybrid. The choice affects how shared code is versioned,
how independently services deploy, how teams scale, and how CI decides what to
build. What repository layout do we standardise on?

## Decision Drivers

* Management of shared/common code and consistent versions.
* Independent deployment and divergent release cadence per service.
* Team scaling — different groups owning different services.
* Build tooling fit (multi-module builds, an internal artifact registry).
* CI efficiency — build/test only what changed.

## Considered Options

* **Monorepo** — all services and libraries in one repository.
* **Polyrepo** — every service (and library) in its own repository.
* **Hybrid** — shared libraries managed together and published as versioned
  artifacts; each service in its own repository, consuming those artifacts.

## Decision Outcome

Chosen option: **Hybrid**. Shared code (parent build descriptor, common DTOs,
toolbox libraries) lives in a small number of shared repositories and is
published to an internal Maven registry as versioned artifacts; each service
keeps its own repository and pulls the shared libraries as dependencies. CI uses
`git diff` to run tests/builds only for the directories or services that changed.
This keeps shared code consistent and centrally versioned while letting services
deploy and version independently.

### Consequences

* Good, because shared libraries have one authoritative version, so services do
  not drift apart on common DTOs/utilities.
* Good, because each service deploys on its own cadence with its own history and
  permissions — suited to multiple teams.
* Bad, because a breaking change in a shared library requires a coordinated
  version bump across consumers; this is an explicit, reviewable step rather than
  an invisible monorepo-wide edit.
* Neutral, because the team must run an internal artifact registry (already part
  of the platform).

### Confirmation

Shared libraries are consumed only as published, versioned artifacts (no source
copies); CI condition-build is in place so unaffected services are not rebuilt on
every change.

## Pros and Cons of the Options

### Monorepo

* Good, because of atomic cross-cutting changes, one build/version pipeline, and
  easy visibility of change impact.
* Bad, because it fits best when services are highly interdependent or the team is
  small; at this size it couples release cadence and complicates per-team
  ownership and independent deployment.

### Polyrepo

* Good, because services are fully independent, ideal when stacks and release
  cycles diverge and teams are large.
* Bad, because shared code has no natural home; duplicating utilities across
  repos invites inconsistency.

### Hybrid

* Good, because it captures the best of both: consistent shared libraries +
  independent services, with CI building only what changed.
* Bad, because of the coordinated-bump cost for breaking shared-library changes.

## More Information

The shared parent build descriptor centralises dependency and plugin versions
across all services, so upgrades (framework, BOM) are made once and inherited.
This ADR is the source-layout counterpart to the schema distribution decision in
[ADR-0003](0003-schema-as-code-distribution-strategy.md), which applies the same
"central source of truth + local autonomy" principle to database schema.
