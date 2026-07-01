---
status: "accepted"
date: "2025-02-10"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# Service discovery & dynamic-config backbone: Consul vs Nacos

## Context and Problem Statement

Moving from a single deployable to roughly ten independently deployed services
introduces cross-cutting infrastructure concerns that every service shares:
runtime configuration that can change without a redeploy, secret management, and
service registration/health. On Kubernetes, in-cluster service-to-service
routing can already be handled by the platform's DNS and `Service` objects, so
the real question is which system provides the **dynamic-configuration and
service-coordination backbone**, and how well it integrates with the rest of the
stack (Spring Cloud, a secrets engine, IaC). Which backbone do we standardise on?

## Decision Drivers

* First-class Spring Cloud integration (config refresh, discovery).
* Dynamic config with hot reload — config changes must not require a restart.
* Ecosystem fit with the chosen secrets engine and IaC tooling.
* Maturity and operational track record at production scale.
* International community and long-term support, over region-specific adoption.

## Considered Options

* **Consul** (HashiCorp) — discovery + KV config; integrates with a Vault
  secrets engine and Terraform.
* **Nacos** (Alibaba) — combined registry + config centre with a full web UI.
* **Kubernetes-native only** — DNS/`Service` for discovery + `ConfigMap`/secrets,
  no dedicated discovery/config product.

## Decision Outcome

Chosen option: **Consul as the config/coordination backbone, with Kubernetes
DNS handling in-cluster routing**, because it pairs cleanly with a Vault-based
secret strategy and Terraform-driven infrastructure, has official Spring Cloud
Consul support, and is a mature, internationally-supported choice for
production. Kubernetes DNS already covers the routing case, so a heavyweight
registry is not needed purely for discovery.

### Consequences

* Good, because Consul + Vault + Terraform form a coherent, well-documented
  ecosystem, which lowers integration and operational risk.
* Good, because configuration becomes dynamic and centrally versioned;
  hot-reload removes a class of "restart to pick up config" deployments.
* Bad, because Consul's built-in UI is comparatively spartan; richer config UX
  (a strength of Nacos) is traded away.
* Neutral, because the team takes on operating one more stateful cluster
  component, which SRE must monitor and back up.

### Confirmation

Config changes propagate to running services without redeploy (verified in a
staging drill); secret material is sourced from the secrets engine rather than
from config files or images.

## Pros and Cons of the Options

### Consul

* Good, because of deep ecosystem integration (Vault, Terraform, Nomad).
* Good, because of strong multi-language support and large-scale production use.
* Good, because of official Spring Cloud Consul support.
* Bad, because the native UI is basic and may need a third-party complement.

### Nacos

* Good, because it bundles registry **and** config centre with a complete web UI.
* Good, because Spring Cloud Alibaba provides solid integration.
* Bad, because the ecosystem leans toward the Alibaba stack and regional
  adoption; weaker fit with a Vault/Terraform-centric toolchain.

### Kubernetes-native only

* Good, because it adds no new component to operate.
* Bad, because `ConfigMap`-based config lacks ergonomic hot-reload and a
  unified change/audit story across services; secret rotation is harder without
  a dedicated engine.

## More Information

In-cluster routing is left to Kubernetes DNS; Consul is scoped to dynamic
configuration and coordination. This ADR is paired with the platform's secret
strategy (a Vault transit engine) and is expected to be revisited if the team
consolidates onto a managed cloud config/secret service.
