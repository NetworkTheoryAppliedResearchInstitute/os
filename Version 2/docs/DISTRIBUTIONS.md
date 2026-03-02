# NTARI OS Distributions

**Version:** 2.0
**Date:** 2026-02-18
**License:** AGPL-3.0

---

## What Is a Distribution?

A **distribution** is a use-case-specific packaging of the NTARI OS
kernel, selected infrastructure implementations, and selected modules.
Distributions live in Tier 4 of the four-tier stack.

A distribution:
- Selects which Tier 2 infrastructure nodes to include
- Selects which Tier 3 modules to include
- Configures the kernel policy engine for the deployment context
- Ships as a signed ISO with a preconfigured first-boot wizard
- **Adds no new runtime logic**

The distinction is important: distributions are configuration, not code.
If a distribution requires new code to function, that code belongs in a
module (Tier 3) or infrastructure node (Tier 2), not in the distribution
itself.

---

## Distribution Catalog

### ntari-municipal

**Purpose:** City and municipal government cooperative infrastructure

**Infrastructure (Tier 2):**
- Core: DNS · DHCP · NTP · Web · Cache · Containers
- Cooperative: VPN · Identity (FreeIPA) · Files
- Community: Chat (Matrix) · Mail (Postfix)

**Modules (Tier 3):**
- Governance module (public record, proposal tracking)
- Identity federation for inter-department coordination

**Policy configuration:**
- Federated identity across city departments
- Public-access governance record (read-only)
- Mandatory audit logging

**Target hardware:** x86_64 server, 16+ GB RAM
**ISO:** `ntari-os-2.0.0-municipal-x86_64.iso`

---

### ntari-cooperative

**Purpose:** Worker and consumer cooperatives

**Infrastructure (Tier 2):**
- Core: DNS · DHCP · NTP · Web · Cache · Containers
- Cooperative: VPN · Identity · Files
- Community: Chat · VoIP · Backup

**Modules (Tier 3):**
- Agrinet (if agricultural cooperative)
- Fruitful (if food distribution cooperative)
- Token ledger (economic coordination)
- Governance module (democratic decision-making)

**Policy configuration:**
- One-member-one-vote governance
- Federation agreements with peer cooperatives
- Transparent economic record-keeping

**Target hardware:** Raspberry Pi 4 (4 GB) or x86_64 mini-PC
**ISO:** `ntari-os-2.0.0-cooperative-x86_64.iso`
         `ntari-os-2.0.0-cooperative-arm64.iso`

---

### ntari-school

**Purpose:** Teen Tech Centers and educational institutions

**Infrastructure (Tier 2):**
- Core: DNS · DHCP · NTP · Web · Cache
- Legacy: SoHoLINK RADIUS (for existing 802.1X infrastructure)
- Community: Media (Jellyfin) · Files

**Modules (Tier 3):**
- Network literacy module (educational graph visualization)
- Project coordination module

**Policy configuration:**
- Filtered DNS for educational environment
- Content-access governance (student vs. instructor roles)
- SoHoLINK RADIUS for WiFi authentication

**Target hardware:** x86_64 mini-PC or Raspberry Pi 4
**ISO:** `ntari-os-2.0.0-school-x86_64.iso`

---

### ntari-rural-isp

**Purpose:** Rural community ISPs and neighborhood networks

**Infrastructure (Tier 2):**
- Core: DNS · DHCP · NTP · Web · Cache
- Cooperative: VPN (federation with upstream provider)
- Legacy: SoHoLINK RADIUS (Captive Portal for new user onboarding)

**Modules (Tier 3):**
- SoHoMesh (mesh topology coordination)
- Bandwidth coordination module

**Policy configuration:**
- Federated peering with regional cooperative ISPs
- Fair-use policy enforcement (declarative, not procedural)
- Community governance for service-level decisions

**Target hardware:** x86_64 or ARM64 router-class hardware
**ISO:** `ntari-os-2.0.0-rural-isp-x86_64.iso`

---

## Building a Distribution

### 1. Define the Distribution Manifest

Create `distributions/<name>/manifest.yaml`:

```yaml
name: ntari-cooperative
version: "2.0.0"
kernel_version: ">=2.0"
description: "Worker and consumer cooperative infrastructure"

infrastructure:
  - ntari_dns_node
  - ntari_dhcp_node
  - ntari_ntp_node
  - ntari_web_node
  - ntari_cache_node
  - ntari_container_node
  - ntari_vpn_node
  - ntari_identity_node
  - ntari_files_node
  - ntari_chat_node
  - ntari_voip_node
  - ntari_backup_node

modules:
  - agrinet           # optional; include only if selected during first-boot
  - fruitful          # optional
  - token-ledger
  - governance

policy:
  - policy/cooperative-governance.rego
  - policy/federation-defaults.rego

first_boot:
  wizard: true
  steps:
    - network
    - cooperative-identity
    - federation-agreement
    - module-selection
    - complete
```

### 2. Write Policy Files

Policy files configure the kernel policy engine for the deployment
context. They are Rego or NTARI DSL files — no procedural code.

```rego
# policy/cooperative-governance.rego
package ntari.governance

default vote_weight = 1

# One-member-one-vote
vote_weight = 1 {
    input.member.status == "active"
}

default quorum_met = false

quorum_met {
    count(input.votes) >= (count(input.eligible_members) * 0.5)
}
```

### 3. Configure the First-Boot Wizard

The first-boot wizard is driven by the manifest's `first_boot.steps`
list. Each step maps to a wizard screen in the kernel's onboarding
runtime. Distributions do not implement wizard screens — they configure
which built-in screens appear and in what order.

Custom wizard screens, if required, must be implemented as a module
with a declared `onboarding:` capability.

### 4. Build the ISO

```bash
make distribution NAME=ntari-cooperative ARCH=x86_64
# Output: build-output/ntari-os-2.0.0-cooperative-x86_64.iso
```

For ARM64:
```bash
make distribution NAME=ntari-cooperative ARCH=arm64
# Output: build-output/ntari-os-2.0.0-cooperative-arm64.iso
```

---

## Distribution vs. Custom Kernel

If you find yourself modifying kernel source to create a distribution,
stop. Modifications to the kernel are contributions to the kernel, not
distributions. A distribution that requires kernel changes either:

1. Needs a new module (move the logic to Tier 3), or
2. Has identified a kernel deficiency (open an issue or PR)

Forking the kernel to create a distribution undermines the federation
model: a forked kernel cannot federate with the canonical kernel without
explicit bridge configuration.

---

## SoHoLINK and Distributions

SoHoLINK (the RADIUS/AAA infrastructure node) is included in two
distributions: `ntari-school` and `ntari-rural-isp`. It is not included
by default in `ntari-cooperative` or `ntari-municipal`.

This reflects the correct relationship:

- **SoHoLINK** is one infrastructure option in the Tier 2 catalog
- Distributions that need 802.1X or Captive Portal authentication include it
- Distributions that use FreeIPA-based identity do not

SoHoLINK is not the identity of the project. It is a legacy-compatible
infrastructure node that some deployments require.

---

## Versioning

Distributions track the kernel version:

```
ntari-os-<kernel-version>-<distribution-name>-<arch>.iso
ntari-os-2.0.0-cooperative-x86_64.iso
```

Distribution manifests declare a minimum kernel version, not an exact
version, to allow kernel patch releases without rebuilding all
distribution ISOs.

---

For architecture context, see [ARCHITECTURE.md](ARCHITECTURE.md).
For module development, see [MODULES.md](MODULES.md).
For the federation protocol, see [FEDERATION.md](FEDERATION.md).
