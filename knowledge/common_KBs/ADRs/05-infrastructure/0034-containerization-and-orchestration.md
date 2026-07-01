---
status: "accepted"
date: "2025-02-28"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# Containerization and orchestration: Kubernetes over VM-based autoscaling

## Context and Problem Statement

Once the platform is decomposed into many independently-scaled services
([ADR-0032](0032-service-decomposition-for-independent-scaling.md)), the
deployment unit and scaling mechanism for each of those services has to be
decided. The prior deployment model was VM-based: a full application server
provisioned and configured per instance. With ~10 services, each needing its
own scale-out behaviour, does that model still hold up, or does the platform
need a container/orchestration layer?

## Decision Drivers

* Speed from "need more capacity" to "capacity is serving traffic."
* Environment consistency between dev, staging and production.
* Automated, metric-driven scaling rather than manual/scripted intervention.
* Fast rollback when a deploy goes wrong.
* Efficient use of host resources across many small services.

## Considered Options

* **VM-based deployment**, scaled with VM/instance autoscaling.
* **Containers on Kubernetes**, scaled with pod-level autoscaling (HPA).

## Decision Outcome

Chosen option: **containers on Kubernetes**. A VM-based scale-out has to boot a
machine image before the application even starts — on the order of minutes —
because the scaling unit is "a machine." A container's scaling unit is "a
process," so a new replica is ready in roughly the time the application itself
takes to start, commonly low single-digit seconds for these services. With ~10
independently-scaled services, that gap compounds: Kubernetes' Horizontal Pod
Autoscaler reacts to load metrics automatically per service, where VM
autoscaling groups were typically tuned and adjusted by hand.

### Consequences

* Good, because Dev/staging/production run the same image, removing a class of
  "worked in staging" environment-drift incidents.
* Good, because rollback is "point at the previous image tag," which is fast and
  uniform across every service.
* Good, because HPA scales each service independently off real metrics (CPU,
  memory, request rate), which is what makes the per-hotspot scaling economics
  in [ADR-0032](0032-service-decomposition-for-independent-scaling.md) actually
  realisable in operation, not just in theory.
* Good, because multiple containers share a host's OS, using host resources more
  efficiently than one VM per service.
* Bad, because the team now operates a Kubernetes cluster — a genuinely new
  operational discipline (networking, scheduling, manifests) on top of what
  application teams previously needed to know.

### Confirmation

A new service ships as a container image with a defined HPA policy from day
one; no service is hand-deployed to a VM going forward.

## Pros and Cons of the Options

### VM-based deployment

* Good, because it is the team's existing, familiar operational model.
* Bad, because scale-out latency is bounded by machine boot time, and
  autoscaling tends toward manual tuning rather than fully automatic,
  metric-driven response.

### Containers on Kubernetes

* Good, because scale-out is process-speed, not machine-speed, and HPA makes
  per-service autoscaling automatic.
* Good, because consistent images close the dev/staging/prod drift gap.
* Bad, because of the added operational learning curve of running a cluster.

## More Information

This is the platform layer the rest of the stack builds on: service discovery
and config ([ADR-0001](0001-service-discovery-and-config-backbone.md)),
GitOps-based deployment, and the shared infrastructure concerns in
[ADR-0039](0039-centralizing-cross-cutting-concerns.md) all assume Kubernetes as
the runtime.
