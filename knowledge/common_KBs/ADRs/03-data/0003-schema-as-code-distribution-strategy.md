---
status: "accepted"
date: "2025-03-05"
decision-makers: "Backend / Platform Engineering, DBA"
consulted: "DBA, SRE"
---

# Schema-as-Code distribution strategy across services

## Context and Problem Statement

Database schema for ~10 services must be under version control with CI/CD, so
that every environment is reproducible and free of drift, the DBA has a reviewable
single source of truth, environments can be rebuilt quickly (IaC), and disaster
recovery is a known-good rollback rather than archaeology. The open question is
*where the DDL lives* and *how it reaches each service* — centrally, with each
service, or a hybrid. Which distribution model do we adopt?

## Decision Drivers

* Cross-environment consistency / no schema drift (highest weight).
* System stability and DBA control over what reaches production.
* RD developer velocity (local iteration, feature branches).
* DBA review burden and audit trail.
* Fast DB rebuild for ephemeral environments and disaster recovery.
* Implementation and ongoing maintenance cost.

## Considered Options

* **A — Pure Central.** One central DB repository owns all DDL; services pull a
  versioned schema artifact (Maven dependency).
* **B — Service + Contract.** DDL lives with each service; a schema registry plus
  consumer-driven contract tests (Pact-style) guard compatibility.
* **D — Hybrid.** A central repo owns the stable, full schema; during development
  each service carries its own *pending* DDL, which is merged centrally once
  reviewed.

## Decision Outcome

Chosen option: **D — Hybrid**, because it scored highest on a weighted
evaluation (below). It keeps the consistency, DBA control, fast-rebuild and DR
strengths of a central source of truth, while restoring the local developer
velocity that a pure-central model loses — RD can iterate on pending DDL in the
service repo and run integration tests against `stable + pending` without waiting
on a central release.

### Weighted evaluation

| Driver | Weight | A (Central) | B (Service+Contract) | D (Hybrid) |
|---|---:|---:|---:|---:|
| Implementation complexity | 10% | 6 | 2 | 7 |
| Maintenance cost | 10% | 6 | 2 | 6 |
| RD velocity | 15% | 4 | 10 | 8 |
| DBA burden | 10% | 10 | 6 | 10 |
| System stability | 12% | 10 | 8 | 10 |
| Defect detection | 8% | 8 | 10 | 8 |
| Fast DB rebuild (IaC) | 10% | 10 | 8 | 10 |
| Disaster recovery | 10% | 10 | 8 | 10 |
| Cross-env consistency | 10% | 10 | 6 | 10 |
| Test authoring ease | 5% | 4 | 10 | 8 |
| **Weighted total** | 100% | **7.8** | **7.4** | **8.9** |

### Consequences

* Good, because staging/production always deploy from the single stable schema —
  no drift, clean rollback, simple DR.
* Good, because feature branches stay fast: Entity changes and their pending DDL
  live together and run under TestContainers immediately.
* Bad, because there are now two DDL sources (stable + pending) to keep in sync;
  after a stable update, pending branches must rebase. This is the main residual
  risk and is mitigated by CI checks.
* Neutral, because the team operates a sync mechanism and a registry; modest
  ongoing maintenance (~15–20 engineer-days/year, comparable to the central
  model).

### Confirmation

CI enforces: SQL style/format and header completeness (SQLFluff + custom checks),
conflict detection against the current schema, and a TestContainers run with
`hibernate.ddl-auto=validate` so Entity/DDL mismatches fail the build. The stable
schema is rebuilt deterministically from `current + pending` (TestContainers
dump) rather than from any live DB, so manual drift cannot leak in.

## Pros and Cons of the Options

### A — Pure Central

* Good, because of a single source of truth, strict DBA control, complete audit
  trail, and one-line version-pinned rebuilds.
* Bad, because RD velocity suffers: Entity changes wait on a central DDL release,
  and feature branches are awkward because cross-repo Entity/DDL drift easily.

### B — Service + Contract

* Good, because velocity is highest (Entity and DDL co-located) and contract
  tests catch breaking changes at commit time.
* Bad, because there is no unified schema view: the DBA must watch ~10 repos,
  drift risk rises, and a schema registry + contract broker is the most
  expensive option to build and run.

### D — Hybrid

* Good, because it keeps central consistency/control and DR while restoring local
  velocity; both "pin a stable version" and "stable + feature pending" rebuilds
  are supported.
* Bad, because of the dual-source sync overhead noted above.

## More Information

The stable schema is kept as a **squashed** full snapshot (not an append-only
chain of `ALTER`s), so TestContainers initialisation stays fast as history
grows; migration history is archived separately. Same model applies to the
document store (a JS migration file) as to the relational store. Tooling such as
Flyway/Liquibase governs the live-DB apply step per environment branch.
