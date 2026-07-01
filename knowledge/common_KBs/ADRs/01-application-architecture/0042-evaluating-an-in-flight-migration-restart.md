---
status: "accepted"
date: "2025-05-02"
decision-makers: "Engineering leadership"
consulted: "Backend / Platform Engineering, Product"
---

# Evaluating an in-flight migration restart: sunk cost vs a ground-up, AI-assisted rewrite

## Context and Problem Statement

Partway through a multi-month migration from a legacy monolith to the
decomposed platform described in this record set, a tempting alternative
surfaced: stop the in-flight, hand-built migration and instead restart from the
legacy codebase using an AI-assisted approach — using AI tooling to read the
old system, propose a modular decomposition, and machine-translate it onto the
new framework. The premise was that AI assistance could shortcut work that had,
up to that point, been done by hand. Should the team switch to that path, or
continue the migration already underway?

This decision is distinct from [ADR-0007](0007-reverting-microservices-to-a-monolith.md)
(whether to abandon microservices and go back to a monolith). Here, the target
architecture is not in question — both paths still aim for the decomposed
platform. The question is *how to get there*: continue the in-flight,
human-driven migration, or restart it as an AI-assisted rewrite of the legacy
system.

## Decision Drivers

* How much of the already-completed work (infrastructure, redesigned core
  flows, validated patterns) would the alternative approach actually reuse,
  versus need to redo?
* How reliably can an AI-assisted process infer correct business semantics from
  a legacy codebase with significant accumulated implicit behaviour, without a
  human having to verify nearly everything it produces?
* What is the realistic timeline of each path to an equivalent, production-ready
  state — not the optimistic case for either.
* Team continuity and morale: a visible "start over" decision has a cost
  independent of the technical merits.
* Risk concentration: does the alternative path replace many small, reviewed
  steps with one large, harder-to-de-risk effort?

## Considered Options

* **Continue the in-flight migration** — keep building out the decomposed
  platform on the path already underway.
* **Restart as an AI-assisted rewrite** — abandon the in-flight migration,
  use AI tooling to read the legacy system, propose module boundaries, and
  machine-translate it onto the new framework.
* **Adopt AI assistance *within* the in-flight migration**, for well-scoped
  sub-tasks, without abandoning the work already done.

## Decision Outcome

Chosen option: **continue the in-flight migration**, optionally drawing on AI
assistance for well-scoped sub-tasks rather than as a wholesale restart. Three
reasons drove this, independent of each other:

1. **Reuse is asymmetric.** The work completed so far is not just feature code
   — it includes platform infrastructure, redesigned core flows, and validated
   operational patterns (the subjects of the other records in this set).
   Restarting from the legacy system would not reuse most of that; it would
   need to re-derive it, on a new, less-proven path.
2. **AI-assisted semantic extraction from a legacy system carries unverified
   risk.** A codebase that accumulated implicit, undocumented behaviour over
   time is exactly the case where an automated process is most likely to
   produce a plausible-looking but subtly incorrect translation — and every
   output would need substantial human verification to catch that, eroding
   much of the assumed time saving.
3. **The realistic timeline for the alternative was not clearly shorter** once
   re-deriving the platform infrastructure, validating the AI-assisted
   translation, and re-implementing functionality the in-flight migration had
   already completed were accounted for — and that is before counting the
   human cost of asking a team to discard completed, working progress.

### Consequences

* Good, because already-completed infrastructure and redesigned flows continue
  to be built on rather than discarded.
* Good, because risk stays distributed across many small, reviewed migration
  steps rather than concentrated in one large, harder-to-verify rewrite.
* Neutral, because AI assistance is not rejected outright — it remains
  available for specific, well-scoped sub-tasks where its output is easy to
  verify, just not adopted as the primary mechanism for the whole migration.
* Bad, because this commits the team to completing the remaining, sometimes
  tedious, scope of the original migration rather than hoping a shortcut
  removes it.

### Confirmation

Any future proposal to introduce AI-assisted automation into the migration is
evaluated sub-task by sub-task — scoped narrowly enough that its output can be
verified against a clear specification — rather than as a wholesale
replacement for the migration approach.

## Pros and Cons of the Options

### Continue the in-flight migration

* Good, because it preserves and builds on everything already validated and
  shipped.
* Good, because risk stays incremental and reviewable.
* Bad, because the remaining scope still has to be done; there is no shortcut.

### Restart as an AI-assisted rewrite

* Good, because, in principle, automation could reduce some categories of
  manual translation effort.
* Bad, because it discards completed, working infrastructure and flows; because
  legacy implicit behaviour is a poor fit for automated semantic extraction
  without heavy human verification; and because the realistic (not optimistic)
  timeline was not clearly better once that verification cost is included.

### Adopt AI assistance within the in-flight migration

* Good, because it can capture genuine efficiency gains on well-scoped,
  verifiable sub-tasks without the risk of a wholesale restart.
* Neutral, because it requires deliberately scoping *where* AI assistance is
  trustworthy, rather than applying it uniformly.

## More Information

This decision is a sibling to [ADR-0007](0007-reverting-microservices-to-a-monolith.md):
both evaluate a proposal to discard in-flight, validated work in favour of an
alternative that looks attractive at a glance. The same discipline applies to
both — separate the *technical* question (is the target architecture still
right?) from the *execution* question (is this specific alternative path to it
actually faster and lower-risk, once realistically accounted for?) — and answer
each on its own evidence rather than letting one carry the other.
