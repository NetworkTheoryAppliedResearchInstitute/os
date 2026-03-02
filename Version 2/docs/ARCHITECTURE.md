# NTARI OS Architecture

**Version:** 2.0
**Date:** 2026-02-18
**License:** AGPL-3.0

---

## Overview

NTARI OS is a **federated coordination kernel**. Its job is to make
independent cooperative nodes discoverable, interconnectable, and governable
— without a central authority, and without encoding any domain-specific
logic into the kernel itself.

The architecture is organized as four tiers with strict dependency rules:
upper tiers depend on lower tiers; lower tiers never depend on upper tiers.
The kernel (Tier 1) is the stable, domain-agnostic foundation. Distributions
(Tier 4) are what end users and deployers see.

---

## The Four-Tier Stack

```
┌──────────────────────────────────────────────────────────────────┐
│  TIER 4 — DISTRIBUTIONS                                          │
│                                                                  │
│  Use-case packaging. Selects modules and infrastructure nodes,   │
│  configures governance policy, ships as a signed ISO.            │
│                                                                  │
│  Examples: Municipal · Cooperative · School · Rural ISP          │
│                                                                  │
│  Tier 4 depends on Tier 3 and below.                             │
│  Tier 4 adds no new runtime logic.                               │
├──────────────────────────────────────────────────────────────────┤
│  TIER 3 — MODULES                                                │
│                                                                  │
│  Domain coordination logic. Each module is a composable set      │
│  of ROS2 node packages that publish to named topics and          │
│  consume kernel federation and governance services.              │
│                                                                  │
│  Examples: Agrinet · Fruitful · SoHoMesh · TokenLedger           │
│                                                                  │
│  Modules must not:                                               │
│  · Modify kernel topics (/ntari/kernel/*)                        │
│  · Implement federation logic directly                           │
│  · Embed policy rules in procedural code                         │
│                                                                  │
│  Tier 3 depends on Tier 2 and below.                             │
├──────────────────────────────────────────────────────────────────┤
│  TIER 2 — INFRASTRUCTURE IMPLEMENTATIONS                         │
│                                                                  │
│  Concrete service nodes. Each wraps an existing infrastructure   │
│  tool and exposes it as a ROS2 lifecycle node with standard      │
│  health and status topics.                                       │
│                                                                  │
│  Core (all deployments)                                          │
│  ├─ ntari_dns_node        (dnsmasq)                              │
│  ├─ ntari_dhcp_node       (Kea DHCP)                             │
│  ├─ ntari_ntp_node        (Chrony)                               │
│  ├─ ntari_web_node        (Caddy)                                │
│  ├─ ntari_cache_node      (Redis)                                │
│  └─ ntari_container_node  (Podman)                               │
│                                                                  │
│  Cooperative                                                     │
│  ├─ ntari_vpn_node        (WireGuard — federation transport)     │
│  ├─ ntari_identity_node   (FreeIPA — Kerberos/LDAP)             │
│  └─ ntari_files_node      (Samba/NFS)                            │
│                                                                  │
│  Community (optional)                                            │
│  ├─ ntari_chat_node       (Matrix/Synapse)                       │
│  ├─ ntari_voip_node       (FreeSWITCH)                           │
│  ├─ ntari_mail_node       (Postfix + Dovecot)                    │
│  ├─ ntari_backup_node     (rsync + Bacula)                       │
│  ├─ ntari_media_node      (Jellyfin)                             │
│  └─ ntari_radius_node     (SoHoLINK — 802.1X/Captive Portal)    │
│                                                                  │
│  SoHoLINK is one infrastructure implementation.                  │
│  It is not the identity of the project.                          │
│                                                                  │
│  Tier 2 depends on Tier 1 only.                                  │
├──────────────────────────────────────────────────────────────────┤
│  TIER 1 — NTARI OS KERNEL                                        │
│                                                                  │
│  Federated coordination runtime. No domain logic.                │
│                                                                  │
│  Base                                                            │
│  ├─ Alpine Linux 3.23                                            │
│  ├─ musl libc · BusyBox · OpenRC                                 │
│  └─ Hardened kernel (AppArmor · AIDE · fail2ban · iptables)      │
│                                                                  │
│  Middleware                                                       │
│  ├─ ROS2 Jazzy (LTS)                                             │
│  ├─ Cyclone DDS (EPL-2.0)                                        │
│  │   ├─ DDS domain 0 (local cooperative, default)               │
│  │   ├─ Automatic peer discovery (multicast)                    │
│  │   ├─ Publish-subscribe topic model                           │
│  │   ├─ QoS policies for intermittent connectivity              │
│  │   └─ Domain bridging for inter-cooperative federation        │
│  ├─ Lifecycle node management                                    │
│  ├─ Graph introspection (ros2 CLI)                               │
│  └─ WebSocket bridge (streams graph to globe interface)          │
│                                                                  │
│  Federation                                                      │
│  ├─ WireGuard (transport)                                        │
│  ├─ DDS domain bridge (graph propagation)                        │
│  └─ Federation agreement (signed YAML)                           │
│                                                                  │
│  Policy Engine                                                   │
│  ├─ Rego evaluation (Open Policy Agent)                          │
│  ├─ NTARI DSL (simplified governance DSL)                        │
│  └─ Policy topics: /ntari/kernel/policy/*                        │
│                                                                  │
│  Globe Interface                                                 │
│  ├─ Live DDS computation graph visualization                     │
│  ├─ Abstract wireframe sphere (no geographic features)           │
│  ├─ Node position = latency distance from local                  │
│  └─ Accessible at: http://ntari.local (mDNS)                    │
│                                                                  │
│  Tier 1 has no dependencies outside itself.                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## Kernel Internals

### Base Layer — Alpine Linux 3.23

- **Init:** OpenRC — auditable, DDS-first boot sequence
- **C library:** musl libc — strict POSIX, smaller attack surface
- **Userland:** BusyBox — minimal, community-auditable
- **Package manager:** APK from three repositories:
  1. Alpine official
  2. NTARI APK repository (kernel + infra node packages)
  3. SEQSENSE experimental aports (ROS2 on Alpine)

**Boot sequence (order is architectural):**

```
1. Kernel + networking drivers
2. Network interface (DHCP or static)
3. ROS2 DDS domain             ← first priority; graph exists before services
4. Chrony NTP                  ← DDS QoS timestamps require clock sync
5. Core infrastructure nodes   ← dns, dhcp, web, cache, container
6. Cooperative nodes           ← vpn, identity, files (if configured)
7. Module nodes                ← installed domain modules
8. Globe interface             ← web node + WebSocket bridge
```

The machine reaches a functional federation graph state before it reaches
a usable local state. This inversion is intentional and structural.

### Middleware Layer — ROS2 + Cyclone DDS

**Why ROS2:** The DDS pub-sub model provides automatic peer discovery
without a central registry, QoS policies that survive intermittent
connectivity, and a queryable computation graph that makes network topology
a visible, inspectable object. These properties are essential for
cooperative infrastructure that no single entity controls.

**Why Cyclone DDS (not Fast-DDS):**
- Written in C — minimal dependency surface
- EPL-2.0 — no single corporate owner; consistent with AGPL-3.0 governance
- musl patches merged upstream — native Alpine support
- Simpler dependency tree — lower community maintenance burden

**Environment:**
```
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ROS_DOMAIN_ID=0          (default; configurable per deployment)
Source: /opt/ros/jazzy/setup.sh
```

### Federation Layer

See [FEDERATION.md](FEDERATION.md) for the full protocol specification.

Summary:

```
Cooperative A                         Cooperative B
┌─────────────────┐                  ┌─────────────────┐
│  DDS Domain 0   │                  │  DDS Domain 0   │
│  (local graph)  │                  │  (local graph)  │
│                 │  WireGuard       │                 │
│  ntari_vpn_node ├──────────────────┤ ntari_vpn_node  │
│                 │  encrypted       │                 │
│  DDS Bridge     ├──────────────────┤ DDS Bridge      │
│  (remote.*)     │                  │ (remote.*)      │
└─────────────────┘                  └─────────────────┘
```

Remote nodes appear in the local graph with `remote.` prefix. Federation
is governed by a signed YAML federation agreement evaluated by the policy
engine — not by ad-hoc code in either cooperative's deployment.

### Policy Engine

Governance rules are **declarative**, not procedural. Policy is not
embedded in module or infrastructure code. It is expressed in:

- **Rego** (Open Policy Agent) — for complex graph-based rules
- **NTARI DSL** — a simplified governance DSL for common cooperative rules

Policy is distributed over DDS and evaluated by the kernel. Modules
declare what policies they require; the kernel enforces them. Modules do
not implement enforcement logic.

```
/ntari/kernel/policy/active      # Currently active policy set
/ntari/kernel/policy/proposals   # Pending governance proposals
/ntari/kernel/policy/votes       # Governance votes from peers
```

**Scope rule:** Policy governs coordination. Policy does not encode
domain logic (e.g., agricultural pricing rules). Domain policy belongs in
module-level policy declarations, not in the kernel policy engine.

---

## Dependency Rules

| From \ To | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| **Tier 1 (Kernel)** | internal | ✗ | ✗ | ✗ |
| **Tier 2 (Infra)** | ✅ | internal | ✗ | ✗ |
| **Tier 3 (Module)** | ✅ | ✅ | internal | ✗ |
| **Tier 4 (Distro)** | ✅ | ✅ | ✅ | internal |

Violations of these rules are **boundary leaks** and must be resolved by
moving the leaking logic upward, never by relaxing the rule.

### Identifying a Boundary Leak

A boundary leak is present when any of the following is true:

1. The kernel imports, calls, or publishes to a topic owned by a specific
   module (e.g., `/ntari/agrinet/*` in kernel code)
2. An infrastructure node contains domain logic (e.g., an AAA node that
   enforces application-layer business rules)
3. A module directly manages federation tunnels rather than consuming
   the kernel federation API
4. Policy rules are implemented as procedural code in a module rather
   than declared in a policy file evaluated by the kernel

---

## Globe Interface

The globe is a **kernel-layer interface** — it visualizes the DDS
computation graph, not any module's data model. It is part of Tier 1.

- **Sphere:** Abstract wireframe — no geographic features
- **Nodes:** Luminous points, one per active ROS2 node
- **Edges:** Active topic subscriptions (bezier curves)
- **Position:** Network latency distance from local node
- **Scale:** Globe radius grows logarithmically with node count
- **Remote peers:** Visually distinct from local cooperative nodes

The globe interface does not know about Agrinet, Fruitful, SoHoLINK, or
any other module. It knows about nodes, topics, and latency.

---

## Hardware

**Reference platforms:**
- Raspberry Pi 4 (4 GB RAM) — ARM64
- x86_64 mini-PC (8 GB RAM)

**Minimum (full kernel + infra):**
- CPU: 2 cores, 1.5 GHz
- RAM: 1 GB (kernel + ROS2), 2 GB (with services)
- Storage: 8 GB (kernel + services)
- Network: Ethernet or WiFi

**Disk usage:**

| Component | Size |
|---|---|
| Alpine 3.23 base | ~80 MB |
| ROS2 Jazzy (ros_core + ros_base) | ~300 MB |
| Cyclone DDS | ~15 MB |
| Core infrastructure tier | ~100 MB |
| Globe interface | ~2 MB |
| **Total (kernel + core infra)** | **~500 MB** |

**Deployment variants:**

| Variant | Tiers Active | Role |
|---|---|---|
| Minimal Edge Node | T1 + T2 (core) | Graph participant, sensor publisher |
| Community Hub | T1 + T2 (all) | DNS, DHCP, NTP, identity, globe |
| Federation Gateway | T1 + T2 (vpn) | Tunnel management between cooperatives |
| Module Node | T1 + T2 + T3 | Domain-specific coordination |
| Full Deployment | T1 + T2 + T3 + T4 | Complete distribution |

---

## Security Baseline

### Defense in Depth

1. **Network layer:** iptables, restrictive defaults (INPUT DROP)
2. **Application layer:** AppArmor profiles per node
3. **File system:** AIDE integrity monitoring
4. **Access control:** MAC with AppArmor
5. **Intrusion detection:** fail2ban
6. **Identity:** FreeIPA (Kerberos) for cooperative members

### Firewall Defaults

```
INPUT: DROP (default)
  ├─ ACCEPT: loopback
  ├─ ACCEPT: established, related
  ├─ ACCEPT: SSH (22/TCP)
  ├─ ACCEPT: DDS multicast (239.255.0.1:7400–7500/UDP — local only)
  ├─ ACCEPT: WireGuard (51820/UDP — when vpn node active)
  ├─ ACCEPT: Globe interface (8080/TCP — localhost only by default)
  ├─ ACCEPT: RADIUS Auth (1812/UDP — when radius node active)
  └─ ACCEPT: ICMP echo-request

FORWARD: DROP (default)
OUTPUT: ACCEPT (default)
```

---

## musl libc Compatibility Notes

musl libc differs from glibc in ways directly relevant to ROS2:

| Issue | Impact | Resolution |
|---|---|---|
| `dlclose()` is a no-op | Plugin memory accumulates | Design lifecycle nodes to avoid repeated load/unload |
| Thread stack 128 KB (vs 2–10 MB) | Cyclone DDS threads may overflow | Targeted stack-size patch (upstream) |
| No lazy symbol binding | glibc binaries fail | Compile natively on Alpine |
| `__xstat` missing | rcutils test mocking breaks | Fixed upstream (rcutils PR #330) |
| `_NP` pthread extensions | Fast-DDS build fails | Reason Cyclone DDS is mandatory (not Fast-DDS) |
| `execinfo.h` absent | Cyclone DDS backtrace fails | Fixed upstream (cyclonedds PR #384) |

Full assessment: `docs/ROS2_MUSL_COMPATIBILITY.md`

---

For the federation protocol, see [FEDERATION.md](FEDERATION.md).
For the module contract, see [MODULES.md](MODULES.md).
For distribution packaging, see [DISTRIBUTIONS.md](DISTRIBUTIONS.md).
