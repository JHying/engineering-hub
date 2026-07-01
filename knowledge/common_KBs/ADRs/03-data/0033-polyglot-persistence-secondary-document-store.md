---
status: "accepted"
date: "2025-03-20"
decision-makers: "Backend / Platform Engineering, DBA"
consulted: "DBA"
---

# Polyglot persistence: adopting a secondary document store

## Context and Problem Statement

The platform's primary store is a relational database, well suited to
transactional, schema-strict data. Some data — configuration-like records,
settings objects, and other loosely-structured documents — fits a document
model better, and putting it in the relational store either forces an
awkward schema or wastes space/IO on structure it does not need. Should the
platform adopt a second, purpose-fit data store, and if so, on what basis is it
chosen?

## Decision Drivers

* Fit between data shape and storage model (structured/transactional vs
  loosely-structured documents).
* Reducing load and contention on the primary relational store.
* Operational maturity — the team must actually be able to run and support it.
* Blast-radius containment for schema changes once data is split out.
* Vendor support availability for production-grade incident response.

## Considered Options

* **Keep everything in the relational store**, accepting schema awkwardness for
  document-shaped data.
* **Adopt a document database** for the subset of data that fits that model.

## Decision Outcome

Chosen option: **adopt a document database for document-shaped data**, while
the relational store remains the system of record for transactional data.
Splitting loosely-structured, less transactional data out reduces load and
contention on the primary store, lets each engine be used where its model
fits, and — because the platform is already decomposed into services
([ADR-0032](0032-service-decomposition-for-independent-scaling.md)) — confines
the blast radius of a document-store schema change to the services that
actually own that data. A managed support contract was put in place before
production use, so incident response is not solely on the team's own expertise.

### Consequences

* Good, because document-shaped data no longer forces an awkward relational
  schema, and the primary store carries less incidental load.
* Good, because a schema change to document data is scoped to its owning
  service rather than risking the shared relational schema.
* Bad, because the team now operates a second storage engine, with its own
  operational learning curve; mitigated by a vendor support contract and by
  deliberately scoping its use to data that genuinely fits the model, rather
  than adopting it platform-wide.
* Neutral, because data now lives in two systems, which makes any
  cross-store consistency work (if it arises) more deliberate than a single-store
  transaction.

### Confirmation

A dataset is migrated to the document store only when it is genuinely
document-shaped (e.g. a settings/config-like object) and does not require
cross-row relational transactions; transactional, relationally-shaped data
stays in the relational store.

## Pros and Cons of the Options

### Keep everything in the relational store

* Good, because there is exactly one storage engine to operate and back up.
* Bad, because document-shaped data is forced into a relational schema it does
  not naturally fit, adding load and schema friction to the primary store.

### Adopt a document database

* Good, because each data shape is stored in the engine suited to it, and load
  is spread across two systems instead of concentrated on one.
* Bad, because of the added operational surface of a second engine — addressed
  with a support contract and a narrow, deliberate scope of use.

## More Information

Document-store schema is version-controlled the same way as the relational
schema — see the companion [`db-as-code`](https://github.com/YOUR_USERNAME/db-as-code)
reference, whose `mongo-ddl.js` shows the `$jsonSchema`-validator pattern used to
keep the document store's shape enforced and reviewable, the same discipline
applied to the relational side.
