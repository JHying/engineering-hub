---
status: "accepted"
date: "2025-02-18"
decision-makers: "Backend / Platform Engineering"
---

# Entity / DTO boundary and object mapping

## Context and Problem Statement

While migrating persistence from hand-written JDBC to an ORM (Spring Data JPA), a
recurring question arose: when a use case needs computed or presentation-shaped
fields, should those fields be added to the `@Entity`, or should the Entity stay
a pure database mapping with a separate DTO carrying business/transport concerns?
The answer affects query performance, coupling between the API and the database
schema, and long-term maintainability. What is the standard boundary?

## Decision Drivers

* Single Responsibility — an Entity maps a table; it should not absorb API or
  computed concerns.
* JPA read/write performance — avoid loading columns the query does not need and
  avoid lazy-loading surprises (N+1).
* Decoupling — an API shape change must not force a schema change, and vice versa.
* Mapping cost — conversion overhead should be negligible relative to the query.

## Considered Options

* **(a) Rich Entity** — put computed/business/transport fields directly on the
  `@Entity` (using `@Transient` where they must not persist).
* **(b) Pure Entity + DTO + compile-time mapper** — Entity is ORM-only; a DTO
  carries business/transport concerns; map between them with MapStruct.
* **(c) Projection / DTO query** — for read-heavy paths, select directly into a
  DTO via Spring Data Projections or `@Query`.

## Decision Outcome

Chosen option: **(b) pure Entity + DTO with MapStruct, plus (c) Projections for
heavy read paths**. Keeping the Entity a faithful table mapping preserves the
single-responsibility boundary and protects query performance; business/computed
fields live on the DTO. MapStruct is preferred over reflective mappers because it
generates mapping code at compile time, so the conversion cost is effectively
nil. For read-heavy queries, projecting straight into a DTO avoids materialising
unneeded columns.

### Consequences

* Good, because an API/DTO change no longer ripples into the Entity or the
  schema; the layers evolve independently.
* Good, because queries fetch only what they need; no `@Transient` clutter on the
  Entity and fewer accidental N+1s.
* Neutral, because there is an explicit mapping step — but with a compile-time
  mapper the runtime cost is negligible compared with the SQL it accompanies.
* Bad, because there is more boilerplate (DTOs + mappers); accepted as the price
  of decoupling and predictable performance.

### Confirmation

A review/ArchUnit-style rule that Entities expose no presentation-only fields and
that mapping happens in the service layer (not in controllers or repositories);
mappers are MapStruct, not reflective.

## Pros and Cons of the Options

### (a) Rich Entity

* Good, because there is no separate DTO to maintain in simple cases.
* Bad, because it violates SRP, couples API shape to schema, and risks loading
  unnecessary columns and lazy-loading N+1s; over-use of `@Transient` makes the
  Entity complex.

### (b) Pure Entity + DTO + MapStruct

* Good, because of clean separation and compile-time, reflection-free mapping.
* Bad, because of mapping boilerplate (mitigated by the generator).

### (c) Projection / DTO query

* Good, because the database returns exactly the DTO shape, minimising I/O.
* Neutral, because it is best for read paths; writes still go through the Entity.

## More Information

**ORM type-mapping conventions.** Auto-generated Entities map database types
inconsistently unless conventions are fixed. Adopted rules to make generation
deterministic and stable across environments:

* Use the widest integer type intentionally — e.g., reserve `NUMBER` for `Long`,
  and standardise so the same logical column is never `NUMBER(1)` in one table
  and `NUMBER(4)` in another (which would generate different Java types).
* `NUMBER(1)` → `Boolean`; `NUMBER(2..5)` → `Integer`; `TIMESTAMP`/`DATE` →
  `Timestamp`.
* Prefer boxed types over primitives on Entities, so a missing/nullable value
  does not throw on mapping.
* When the DTO omits a not-null Entity field, guard inserts with `@PrePersist` /
  `@DynamicInsert` to avoid a transient-value rollback.
* Prefer `@IdClass` over `@EmbeddedId` for composite keys — it maps to DTOs more
  cleanly.
* Do not bake environment-specific column defaults into the generated Entity;
  defaults differ per environment.
