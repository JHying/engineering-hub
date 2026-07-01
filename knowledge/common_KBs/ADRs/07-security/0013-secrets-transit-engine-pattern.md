---
status: "accepted"
date: "2025-03-30"
decision-makers: "Backend / Platform Engineering, SRE"
consulted: "SRE"
---

# Secrets and signing keys: a transit-engine pattern

## Context and Problem Statement

The identity service issues signed access tokens and encrypts refresh tokens.
Wherever the signing/encryption key material lives, it is a high-value target —
compromise it and an attacker can forge valid tokens. Where should
cryptographic key material live, and how should signing/encryption operations
actually happen?

## Decision Drivers

* Key material should never be exportable to, or resident in, application
  memory, config files, or container images.
* Key rotation must be an operational action, not a deployment (no rebuild,
  no pod restart required).
* Every signing/encryption operation should be individually auditable.
* The approach should reuse infrastructure already in place rather than adding
  a new system.

## Considered Options

* **A keystore file on disk** (e.g. baked into the deployment artifact).
* **Key material in a secrets store, loaded into application memory at
  startup.**
* **A transit-engine pattern** — the secrets engine performs sign/encrypt/decrypt
  operations itself; the key material never leaves it.

## Decision Outcome

Chosen option: **a transit-engine pattern**, using the secrets engine already
in place ([ADR-0001](0001-service-discovery-and-config-backbone.md)) to perform
signing and encryption operations directly, rather than handing key material to
the application. A keystore file was rejected because rotating it means
rebuilding and redeploying every consuming service — a deployment operation
standing in for what should be an operational one — and because the raw key
sits in an image layer, so a registry compromise exposes it directly. Loading
key material into application memory at startup was rejected too: the key is
then visible in a heap dump, rotation still requires a pod restart to pick up
the new key, and an audit log on the secrets store only records that the key
was *read*, not each individual signing operation performed with it. The
transit-engine pattern avoids all three: the key never leaves the secrets
engine, rotation is a single administrative action with no redeployment, and
every sign/encrypt/decrypt call is individually logged.

### Consequences

* Good, because key material is never exportable — there is no file, image
  layer, or heap dump that can leak it.
* Good, because rotation is decoupled from deployment entirely; it is an
  operational action with no service downtime or redeploy.
* Good, because every cryptographic operation is individually audited, not
  just key access.
* Good, because it reuses infrastructure already operated for service discovery
  and config, rather than introducing a new system.
* Bad, because the secrets engine is now on the critical path for every
  operation that needs a signature or decryption (e.g. login) — its
  availability directly gates that path, so it must run in a highly-available
  configuration with appropriate health-checked redundancy.

### Confirmation

No cryptographic key material appears in source control, configuration files,
container images, or is held resident in application memory; signing and
decryption happen via a call to the secrets engine, not a local key.

## Pros and Cons of the Options

### A keystore file on disk

* Good, because it requires no network call for signing — fast and simple.
* Bad, because rotation requires an image rebuild and full redeploy, and the
  raw key is exposed in the image layer.

### Key material loaded into application memory

* Good, because it avoids baking the key into an image.
* Bad, because the key is visible in heap dumps, rotation still requires a pod
  restart, and the audit trail covers key access, not individual operations.

### A transit-engine pattern

* Good, because key material never leaves the secrets engine, rotation needs
  no redeploy, and every operation is individually audited.
* Bad, because the secrets engine becomes a hard runtime dependency on a
  latency-sensitive path, requiring it to be operated at a higher availability
  bar than a passive secrets store would need.

## More Information

This is the same secrets engine already deployed as part of the discovery/config
backbone in [ADR-0001](0001-service-discovery-and-config-backbone.md); adopting
the transit pattern is an extension of that existing infrastructure rather than
a new operational dependency.
