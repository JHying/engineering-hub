---
status: "accepted"
date: "2025-01-15"
decision-makers: "Backend / Platform Engineering"
---

# Record architecture decisions using MADR

## Context and Problem Statement

The platform spans roughly ten services with shared infrastructure decisions
(messaging, persistence, observability, deployment). Significant choices were
being made in chat threads, slide decks and people's heads, which made it hard
for new contributors to understand *why* the system looks the way it does, and
easy to relitigate settled questions. How do we keep a durable, reviewable trail
of architecturally significant decisions?

## Decision Drivers

* Decisions must outlive the conversation and the person who made them.
* The format must live next to the code, be diff-able, and require no tooling to
  read.
* Low friction — if recording a decision is heavy, it will not happen.

## Considered Options

* MADR (Markdown Any Decision Records)
* Nygard-style lightweight ADRs
* A wiki / Confluence space
* No formal record (status quo)

## Decision Outcome

Chosen option: **MADR**, because it is plain Markdown that versions with the
repository, has a richer template than the original Nygard format (explicit
*Decision Drivers* and *Pros and Cons of the Options*) which suits non-trivial
trade-off decisions, and imposes no external tooling.

### Consequences

* Good, because the rationale for each decision is reviewable in a pull request
  alongside the change that motivated it.
* Good, because "why not X?" is answered in the record, reducing re-debate.
* Neutral, because the team must remember to write a record when a decision is
  architecturally significant; this is enforced socially via review, not tooling.

### Confirmation

A decision is "architecturally significant" if it is costly to reverse, affects
multiple services, or constrains future options. Such changes are expected to
reference an ADR in their pull request.

## More Information

- MADR: https://adr.github.io/madr/
- Michael Nygard, *Documenting Architecture Decisions* (2011).
