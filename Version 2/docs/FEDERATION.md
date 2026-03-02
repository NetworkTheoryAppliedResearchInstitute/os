# NTARI OS Federation Protocol

**Version:** 2.0
**Date:** 2026-02-18
**License:** AGPL-3.0

---

## Overview

Federation is the kernel's core capability. It is what distinguishes
NTARI OS from a single-node service manager: any two cooperatives
running the kernel can establish a federated relationship, share their
DDS computation graphs, and enforce mutually agreed governance — without
a central authority brokering the connection.

Federation is a Tier 1 concern. Modules do not implement federation.
Modules consume federation.

---

## Federation Model

Two cooperatives federate by:

1. Establishing an encrypted WireGuard tunnel (transport layer)
2. Bridging their DDS domains across that tunnel (graph layer)
3. Agreeing on a governance policy that governs the relationship
   (policy layer)

Once federated, each cooperative's local DDS graph includes the remote
cooperative's nodes, prefixed with `remote.<cooperative-name>.`. These
remote nodes are visible in the globe interface with distinct visual
treatment.

```
Cooperative A                           Cooperative B
┌───────────────────────┐              ┌───────────────────────┐
│  DDS Domain 0         │              │  DDS Domain 0         │
│                       │              │                       │
│  /ntari/dns/...       │              │  /ntari/dns/...       │
│  /ntari/identity/...  │              │  /ntari/identity/...  │
│  /ntari/agrinet/...   │              │  /ntari/fruitful/...  │
│                       │  WireGuard   │                       │
│  ntari_vpn_node  ─────┼──────────────┼──── ntari_vpn_node   │
│  DDS Bridge      ─────┼──────────────┼──── DDS Bridge       │
│                       │  encrypted   │                       │
│  remote.coop-b/...    │◄─────────────┤  remote.coop-a/...   │
└───────────────────────┘              └───────────────────────┘
```

---

## Federation Components

### WireGuard (Transport)

WireGuard provides the encrypted tunnel between cooperatives. It is
in-kernel, minimal, and auditable — consistent with the NTARI OS
security baseline.

Each cooperative runs an `ntari_vpn_node` (Tier 2 infrastructure)
that manages WireGuard configuration based on active federation
agreements.

WireGuard is not exposed as a user-configurable service. Federation
agreements drive tunnel configuration. Users approve federation
agreements; the kernel manages tunnels.

### Cyclone DDS Domain Bridge (Graph Layer)

The DDS domain bridge propagates the computation graph across the
WireGuard tunnel. Remote nodes and topics become visible in the local
DDS domain with `remote.<cooperative-name>.` prefix.

```
Local DDS domain (Cooperative A, before federation):
  /ntari/dns/status
  /ntari/identity/status
  /ntari/agrinet/harvest_schedule

After federating with Cooperative B:
  /ntari/dns/status
  /ntari/identity/status
  /ntari/agrinet/harvest_schedule
  remote.coop-b/ntari/dns/status       ← Cooperative B's nodes
  remote.coop-b/ntari/fruitful/orders  ← visible in A's graph
```

The bridge is bidirectional by default. Federation agreements can
restrict which topics are bridged.

### Federation Agreement (Policy Layer)

A federation agreement is a signed YAML document that defines:

- The identity of both cooperatives (public keys)
- Which topics each cooperative exposes to the other
- Governance rules governing the relationship
- Expiry and renewal terms

Federation agreements are evaluated by the kernel policy engine.
The kernel enforces them. Neither cooperative's modules have direct
access to modify the agreement.

---

## Federation Agreement Specification

```yaml
# federation-agreement-coop-a-coop-b.yaml
version: "2.0"
created: "2026-02-18"
expires: "2027-02-18"

parties:
  local:
    name: "cooperative-a"
    public_key: "<wireguard-pubkey>"
    endpoint: "10.0.0.1:51820"
    dds_domain: 0
  remote:
    name: "cooperative-b"
    public_key: "<wireguard-pubkey>"
    endpoint: "10.0.0.2:51820"
    dds_domain: 0

topic_policy:
  expose_to_remote:
    - /ntari/agrinet/*        # Agrinet module topics
    - /ntari/kernel/health    # Kernel health (read-only)
  accept_from_remote:
    - /ntari/fruitful/*       # Fruitful module topics
    - /ntari/kernel/health

governance:
  policy_files:
    - federation-governance.rego
  dispute_resolution: "mutual-agreement"
  amendment_requires: "both-parties"

signatures:
  local: "<ed25519-signature>"
  remote: "<ed25519-signature>"
```

**Topic policy** controls what each cooperative shares. Topics not
listed are not bridged. This is the principal mechanism for scope
control in federated deployments.

**Governance** references Rego policy files that the kernel evaluates
for cross-cooperative decisions. The files live in the policy engine;
the agreement references them by name.

**Signatures** are Ed25519 signatures from each cooperative's kernel
identity key. An unsigned or malformed agreement is rejected.

---

## Federation Lifecycle

### 1. Initiation

Either cooperative can propose a federation agreement. The proposal
is transmitted out-of-band (email, secure channel) as a signed YAML
file.

```bash
ntari federation propose \
  --remote-name cooperative-b \
  --remote-key <pubkey> \
  --remote-endpoint 10.0.0.2:51820 \
  --expose "/ntari/agrinet/*" \
  --accept "/ntari/fruitful/*"
```

This generates a draft agreement and outputs it for review.

### 2. Review and Signing

Both cooperatives review the agreement independently. Governance
approval (per each cooperative's local policy) may be required before
signing.

```bash
ntari federation sign federation-agreement-coop-a-coop-b.yaml
```

### 3. Activation

Once both parties have signed, either party can activate the
agreement. The kernel:

1. Validates both signatures
2. Configures the WireGuard tunnel
3. Starts the DDS domain bridge
4. Begins enforcing the topic policy

```bash
ntari federation activate federation-agreement-coop-a-coop-b.yaml
```

### 4. Monitoring

Active federation relationships are visible in the globe interface
and queryable via the DDS graph:

```bash
ros2 topic echo /ntari/kernel/federation/status
ros2 topic echo /ntari/kernel/federation/peers
```

### 5. Termination

Either party can terminate a federation agreement. Termination
removes the WireGuard tunnel and stops the DDS domain bridge. Remote
nodes disappear from the local graph.

```bash
ntari federation terminate cooperative-b
```

Termination does not require the remote party's participation.
Unilateral termination is always permitted.

---

## Topic Policy Enforcement

The kernel policy engine enforces topic exposure rules defined in the
federation agreement. This happens at the DDS bridge layer — topics not
permitted by the agreement are not propagated across the tunnel.

Module developers must declare which topics their module exposes for
federation in the module's policy file:

```rego
# modules/agrinet/policy/federation.rego
package ntari.agrinet.federation

# These topics may be included in federation agreements
federatable_topics = {
    "/ntari/agrinet/harvest_schedule",
    "/ntari/agrinet/node_status",
    "/ntari/agrinet/coordinator/health"
}

# These topics are never federatable (internal module state)
private_topics = {
    "/ntari/agrinet/internal/*"
}
```

A federation agreement that attempts to expose a topic in
`private_topics` will be rejected by the kernel policy engine.

---

## Multi-Cooperative Federation

A single node can federate with multiple cooperatives. Each
relationship is governed by its own agreement. There is no implicit
transitivity: Cooperative A federating with Cooperative B, and B
federating with Cooperative C, does not automatically federate A
with C.

```
Coop A ──── (agreement) ──── Coop B ──── (agreement) ──── Coop C
  │                                                          │
  └────────── No automatic relationship ────────────────────┘
              (requires explicit agreement)
```

This is a deliberate governance decision, not a technical limitation.
Cooperatives should federate intentionally.

---

## Security Properties

| Property | Mechanism |
|---|---|
| Confidentiality | WireGuard ChaCha20-Poly1305 encryption |
| Peer authentication | WireGuard public key pinning |
| Agreement integrity | Ed25519 signatures from both parties |
| Topic scope control | Kernel-enforced topic policy |
| Replay protection | WireGuard handshake rotation |
| Termination | Unilateral, immediate, no remote cooperation needed |

---

## Comparison to v1.x Approach

v1.x proposed libp2p + Kademlia DHT for federation. v2.0 uses
WireGuard + DDS domain bridging.

| | v1.x (libp2p + DHT) | v2.0 (WireGuard + DDS Bridge) |
|---|---|---|
| Transport | libp2p | WireGuard (in-kernel) |
| Discovery | Kademlia DHT | Explicit federation agreements |
| Graph propagation | Custom protocol | Native DDS domain bridging |
| Auditability | Complex DHT hard to reason about | WireGuard widely understood |
| Governance | Ad-hoc | Signed agreements + policy engine |
| Transitivity | Implicit (DHT routing) | Explicit (per-agreement) |
| Cooperative control | Limited | Full (unilateral termination) |

The shift from DHT-based to agreement-based federation reflects the
cooperative governance model: cooperatives federate intentionally,
with full visibility into what they are sharing and with whom.

---

For architecture context, see [ARCHITECTURE.md](ARCHITECTURE.md).
For module development, see [MODULES.md](MODULES.md).
For distribution packaging, see [DISTRIBUTIONS.md](DISTRIBUTIONS.md).
