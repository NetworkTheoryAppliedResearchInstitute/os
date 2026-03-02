# NTARI OS Architecture

**Version:** 1.5
**Date:** 2026-02-17
**License:** AGPL-3.0

---

## Overview

NTARI OS is a network-first operating system built on Alpine Linux and ROS2
middleware. It inverts the conventional OS design priority: rather than treating
networking as a layer added to a local-computation base, NTARI OS places the
ROS2 DDS communication graph as the foundational abstraction. Every service
runs as a node within that graph. Local computation is understood as a node's
contribution to the network, not as the primary purpose of the machine.

This architecture serves cooperatives, mutual aid networks, community mesh
deployments, Teen Tech Centers, and rural ISPs — organizations that need
reliable, auditable, community-maintainable networking infrastructure.

### Scope

NTARI OS is an independent operating system. It is not a cooperative cloud
platform. Downstream projects (such as SoHoLINK) may deploy on NTARI OS nodes
to provide cloud-equivalent services, but those projects are outside NTARI OS
scope. NTARI OS ends at the OS layer: hardware configuration, cooperative
networking services, security, and federation.

---

## Design Principles

1. **Minimal Footprint** — <100MB base system; deployable on single-board
   computers, repurposed routers, and low-power mesh nodes
2. **Offline-First** — Full functionality without internet connectivity
3. **Security by Default** — Hardened configuration, minimal attack surface,
   small auditable base
4. **Network-First Interface** — The ROS2 computation graph is the primary
   interface; no traditional desktop environment in the base system
5. **Multi-Architecture** — x86_64 and ARM64 (Raspberry Pi)
6. **Federation-Ready** — WireGuard tunnels + DDS domain bridging for
   inter-cooperative federation
7. **Community Governance** — Services layer is modular, community-replaceable,
   and AGPL-3.0 licensed throughout

---

## Four-Layer Stack

```
┌─────────────────────────────────────────────────────────────┐
│  APPLICATION LAYER  (SoHoLINK — not part of NTARI OS)      │
│                                                             │
│  Downstream platforms run ON NTARI OS as applications.      │
│  Example: SoHoLINK AAA platform, Globe Network Graph UI,   │
│  LBTAS-NIM behavioral scoring, distributed services.       │
│                                                             │
│  NTARI OS admin interfaces (minimal, config-only):          │
│  ├─ ntari-node-policy   (/node/policy, port 8091)          │
│  ├─ ntari-scheduler     (/scheduler,   port 8092)          │
│  └─ ntari-admin.sh      (CLI, SSH/headless)                │
├─────────────────────────────────────────────────────────────┤
│  SERVICES LAYER                                             │
│                                                             │
│  Core Tier (all deployments)                               │
│  ├─ ntari_dns_node      (dnsmasq)                          │
│  ├─ ntari_dhcp_node     (Kea DHCP)                         │
│  ├─ ntari_ntp_node      (Chrony)                           │
│  ├─ ntari_web_node      (Caddy)                            │
│  ├─ ntari_cache_node    (Redis)                            │
│  └─ ntari_container_node (Podman/LXC)                      │
│                                                             │
│  High Priority Tier (cooperative deployments)              │
│  ├─ ntari_vpn_node      (WireGuard)                        │
│  ├─ ntari_identity_node (FreeIPA)                          │
│  └─ ntari_files_node    (Samba/NFS)                        │
│                                                             │
│  Community Tier (optional, deployment-specific)            │
│  ├─ ntari_chat_node     (Matrix/Synapse)                   │
│  ├─ ntari_voip_node     (FreeSWITCH)                       │
│  ├─ ntari_mail_node     (Postfix + Dovecot)                │
│  ├─ ntari_backup_node   (rsync + Bacula)                   │
│  ├─ ntari_media_node    (Jellyfin)                         │
│  └─ ntari_radius_node   (SoHoLINK — legacy compat)        │
│                                                             │
│  Each service node:                                         │
│  ├─ Starts as OpenRC-managed ROS2 lifecycle node           │
│  ├─ Publishes to /ntari/<service>/health                   │
│  ├─ Publishes to /ntari/<service>/status                   │
│  └─ Independently auditable and replaceable                │
├─────────────────────────────────────────────────────────────┤
│  MIDDLEWARE LAYER                                           │
│                                                             │
│  ROS2 Jazzy (LTS)                                          │
│  ├─ Cyclone DDS (EPL-2.0) — exclusive RMW implementation   │
│  │   ├─ DDS domain 0 (local cooperative)                   │
│  │   ├─ Automatic peer discovery (multicast)               │
│  │   ├─ Publish-subscribe topic model                      │
│  │   ├─ QoS policies for intermittent connectivity         │
│  │   └─ Domain bridging for inter-cooperative federation   │
│  ├─ Lifecycle node management (structured startup/shutdown)│
│  ├─ Graph introspection (ros2 node/topic/service CLI)      │
│  └─ Graph introspection (queryable via ros2 CLI)           │
│                                                             │
│  Environment:                                               │
│  ├─ RMW_IMPLEMENTATION=rmw_cyclonedds_cpp                  │
│  ├─ ROS_DOMAIN_ID=0 (default; configurable)                │
│  └─ Installed at: /usr/ros/jazzy/                          │
├─────────────────────────────────────────────────────────────┤
│  BASE LAYER                                                 │
│                                                             │
│  Alpine Linux 3.23                                          │
│  ├─ Linux Kernel (hardened configuration)                  │
│  ├─ musl libc (strict POSIX; smaller attack surface)       │
│  ├─ BusyBox (minimal userland)                             │
│  ├─ OpenRC (init system; starts DDS domain before all)     │
│  └─ APK package manager (NTARI + SEQSENSE APK repos)       │
│                                                             │
│  Security baseline:                                         │
│  ├─ AppArmor (MAC)                                         │
│  ├─ AIDE (file integrity monitoring)                       │
│  ├─ fail2ban (intrusion prevention)                        │
│  ├─ iptables (firewall, restrictive defaults)              │
│  └─ Chrony (NTP — critical for DDS QoS timestamps)         │
└─────────────────────────────────────────────────────────────┘
```

---

## Base Layer Detail

### Alpine Linux 3.23

- **Version:** 3.23 (current stable with SEQSENSE ROS2 APK support)
- **Init:** OpenRC — simpler, more auditable, easier to customize for
  non-standard boot sequences than systemd. Boot priority: DDS domain first.
- **C library:** musl libc — strict POSIX compliance, smaller attack surface,
  eliminates glibc-specific GNU extensions that create supply chain risk
- **Userland:** BusyBox — minimal, auditable
- **Package manager:** APK from three repositories:
  1. Alpine official packages
  2. NTARI APK repository (services layer node packages)
  3. SEQSENSE ROS experimental aports (ROS2 packages for Alpine)

### Boot Priority

OpenRC starts services in this order:
1. Kernel + networking drivers
2. Network interface (DHCP or static)
3. **ROS2 DDS domain** (`ros2-domain` OpenRC service) ← first priority
4. Chrony NTP (clock sync for DDS QoS)
5. Core tier service nodes
6. ntari-web (Caddy — admin UIs, reverse proxy)

The machine reaches a functional network graph state before it reaches a
usable local state. This is the architectural inversion in practice.

### musl libc Compatibility Notes

musl libc differs from glibc in ways relevant to ROS2:
- `dlclose()` is a no-op — loaded libraries never unload. Plugin lifecycle
  in `pluginlib` must be managed carefully to avoid memory accumulation.
- Default thread stack size is 128 KB (vs glibc's 2–10 MB). Cyclone DDS
  internal threads require a targeted patch to set explicit stack sizes.
- No lazy symbol binding — all symbols resolve at load time. ROS2 packages
  must be compiled natively on Alpine; glibc-compiled binaries will not work.
- Full technical assessment: `docs/ROS2_MUSL_COMPATIBILITY.md`

---

## Middleware Layer Detail

### ROS2 + Cyclone DDS

**Why ROS2:** Originally robotics middleware, ROS2's DDS-based communication
model provides exactly the properties needed for community mesh networks:
automatic peer discovery without centralized configuration, QoS policies that
survive intermittent connectivity, topic-based publish-subscribe that decouples
senders from receivers, and a queryable computation graph that makes network
topology a visible, first-class object.

**Why Cyclone DDS (not Fast-DDS):**
- Written in C — minimal dependency surface, no Boost/ASIO/C++ runtime issues
- EPL-2.0 license — no single corporate owner; aligns with AGPL-3.0 governance
- musl patches merged upstream — upstream-supported on Alpine
- Simpler dependency tree — critical for community maintenance burden
- Default RMW in ROS2 Humble/Jazzy

**Computation graph:** A live map of all nodes, topics, services, and data
flows active in the system at any moment. This graph is the network's topology
expressed in machine-readable terms — queryable via `ros2 node list`,
`ros2 topic list`, and `ros2 topic echo`. Downstream applications (e.g.
SoHoLINK's Globe Network Graph) may visualise it, but that is an application
concern, not an OS concern.

---

## Services Layer Detail

### Design Contract

Every service in the services layer must:
1. Run as a ROS2 lifecycle node
2. Be startable/stoppable via OpenRC without affecting other nodes
3. Publish `/ntari/<service>/health` (bool) at 1 Hz
4. Publish `/ntari/<service>/status` (string) at 0.1 Hz
5. Be packaged as an APK in the NTARI APK repository
6. Be licensed AGPL-3.0 or compatible

### Service Selection Rationale

| Service | Choice | Rationale |
|---|---|---|
| VPN/Federation | WireGuard | In-kernel, minimal overhead, Alpine-native |
| Identity | FreeIPA | Open source, Kerberos, cross-coop federation |
| Chat | Matrix/Synapse | Federated by design, AGPL-3.0 |
| Media | Jellyfin | AGPL-3.0 (vs Plex which is proprietary) |
| DNS/DHCP | dnsmasq / Kea | Lightweight, Alpine-packaged |
| NTP | Chrony | Already in v1.0; proven on Alpine |
| Cache | Redis | Widely used, well-tested on musl |
| Containers | Podman | Rootless, daemonless, OCI-compliant |

### Legacy Compatibility

**SoHoLINK (RADIUS)** from v1.0 remains available as `ntari_radius_node`.
Deployments requiring RADIUS for WiFi authentication (e.g., existing
Captive Portal or 802.1X infrastructure) can continue to use it. It is not
the primary identity model in v1.5 but is not removed.

---

## Application Layer Boundary

NTARI OS ends at the Services Layer. Everything above — network graph
visualisation, behavioral scoring, cooperative governance, distributed
services — is the concern of applications that run on NTARI OS.

**SoHoLINK** is the reference downstream application. It provides:
- Globe Network Graph UI (`ui/globe-interface/ntarios-globe.html`)
- WebSocket bridge (polls ROS2 DDS graph → browser)
- LBTAS-NIM behavioral scoring
- AAA platform (RADIUS, Ed25519, OPA policy engine)

**What NTARI OS exposes for applications:**
- Live ROS2 DDS computation graph (queryable via `ros2` CLI)
- Per-service health topics at `/ntari/<service>/health`
- Node capabilities at `/ntari/node/capabilities`
- Role assignments at `/ntari/scheduler/roles`
- Admin HTTP UIs: `/node/policy` (8091), `/scheduler` (8092)
- CLI: `ntari-admin.sh`, `health-check.sh`

**Headless by design.** NTARI OS nodes run fully without any downstream
application deployed. The ROS2 graph, all services, and all health
publishing operate independently.

---

## Federation Architecture

### Inter-Cooperative Federation (v1.5)

```
Cooperative A                        Cooperative B
┌────────────────┐                  ┌────────────────┐
│ DDS Domain 0   │                  │ DDS Domain 0   │
│ (local graph)  │                  │ (local graph)  │
│                │  WireGuard       │                │
│ ntari_vpn_node ├──────────────────┤ ntari_vpn_node │
│                │  tunnel          │                │
│ DDS Bridge     ├──────────────────┤ DDS Bridge     │
│ (remote.*)     │                  │ (remote.*)     │
└────────────────┘                  └────────────────┘
```

- WireGuard establishes an encrypted tunnel between cooperatives
- Cyclone DDS domain bridge propagates the graph across the tunnel
- Remote nodes appear in the local DDS domain with `remote.` prefix
- Remote nodes appear in the local DDS graph and are queryable via `ros2` CLI
- Federation is governed by a signed YAML federation agreement

### Comparison to v1.0 Approach

v1.0 proposed libp2p + Kademlia DHT for federation. v1.5 replaces this with
WireGuard + DDS domain bridging because:
- WireGuard is simpler (fewer moving parts), more auditable, and in-kernel
- DDS domain bridging is a native Cyclone DDS capability — no extra protocol
- The resulting federation is visible in the same graph model as local nodes
- Community administrators can understand and audit WireGuard tunnels; libp2p
  DHT is significantly harder to reason about

---

## Security Architecture

### Defense in Depth (unchanged from v1.0)

1. **Network Layer:** iptables firewall, restrictive defaults
2. **Application Layer:** Service hardening, AppArmor profiles per node
3. **File System:** AIDE integrity monitoring
4. **Access Control:** MAC with AppArmor
5. **Intrusion Detection:** fail2ban
6. **Identity:** FreeIPA (Kerberos-based) for cooperative members

### Behavioral Security (SoHoLINK layer — out of NTARI OS scope)

The NTARI OS security model is the static defense-in-depth stack above
(iptables, fail2ban, AppArmor, AIDE). Behavioral scoring of cooperative
members — trajectory-weighted scoring, graduated enforcement, and
LLM-generated remediation guidance — is cooperative governance logic that
belongs in the SoHoLINK platform layer, not in the OS.

SoHoLINK and similar downstream platforms can implement behavioral security
by consuming the DDS graph and the service health topics that NTARI OS
publishes. The OS provides the observable infrastructure; policy decisions
about member behavior are a platform concern, not an OS concern.

### Firewall Defaults

```
INPUT: DROP (default)
  ├─ ACCEPT: loopback
  ├─ ACCEPT: established, related
  ├─ ACCEPT: SSH (22/TCP)
  ├─ ACCEPT: DDS multicast (239.255.0.1:7400-7500/UDP — local only)
  ├─ ACCEPT: WireGuard (51820/UDP — when vpn node active)
  ├─ ACCEPT: Globe interface (8080/TCP — localhost only by default)
  ├─ ACCEPT: RADIUS Auth (1812/UDP — when radius node active)
  ├─ ACCEPT: RADIUS Acct (1813/UDP — when radius node active)
  └─ ACCEPT: ICMP echo-request

FORWARD: DROP (default)
OUTPUT: ACCEPT (default)
```

---

## Disk Layout

```
/
├── /etc
│   ├── /ntari/          # NTARI OS configuration
│   │   ├── /federation/ # WireGuard + DDS bridge config
│   │   └── /services/   # Per-node service config
│   ├── /soholink/       # Legacy SoHoLINK config
│   ├── /network/        # Network interfaces
│   └── /security/       # AppArmor, AIDE policies
├── /usr/ros/jazzy/      # ROS2 installation (Alpine-native APK path)
├── /var
│   ├── /lib/ntari/      # Service node data
│   ├── /log/            # System and service logs
│   └── /cache/ntari/    # Update cache
├── /usr/local/bin/      # Admin scripts
└── /home/               # User directories
```

### Disk Usage Estimates

| Component | Size |
|---|---|
| Alpine 3.23 base | ~80 MB |
| ROS2 Jazzy (ros_core + ros_base) | ~300 MB |
| Cyclone DDS | ~15 MB |
| Core services tier | ~100 MB |
| Globe interface | ~2 MB |
| **Total (core deployment)** | **~500 MB** |

Note: v1.0 targeted <100MB (SoHoLINK only). ROS2 middleware significantly
increases disk footprint. For severely resource-constrained nodes, the
middleware layer can be omitted — such nodes run only the Alpine base and
connect to a nearby node running the full stack.

---

## Performance Characteristics

### Resource Usage

| Metric | Value |
|---|---|
| Boot time to DDS domain ready | ~8–12 seconds |
| Idle RAM (base + ROS2 + core services) | ~200–350 MB |
| Idle CPU | <5% |
| Disk I/O | Minimal during normal operation |

### Scalability

- **Local DDS graph:** 100+ nodes on a single cooperative deployment
- **Topics:** No practical limit; graph introspection scales linearly
- **Federation:** 10+ cooperative peers via WireGuard + DDS bridge
- **Globe interface:** Performant to ~80 nodes (Canvas 2D); Three.js
  migration extends this to 500+ nodes

---

## Deployment Scenarios

### 1. Minimal Edge Node
- Hardware: Raspberry Pi 4, 2GB RAM, 32GB SD card
- Stack: Base layer + Middleware layer only
- Role: Graph participant, data publisher

### 2. Community Hub Node
- Hardware: x86_64 mini-PC, 8GB RAM, 256GB SSD
- Stack: Full four-layer stack, core + high-priority services
- Role: DNS, DHCP, NTP, identity, file sharing, WAN gateway
- Serves as the "anchor" for a local cooperative deployment

### 3. Federation Gateway
- Hardware: Any with WireGuard support and internet uplink
- Stack: Base + middleware + VPN node
- Role: Bridges two or more cooperative DDS domains
- Minimal services; its job is tunnel management

### 4. Headless Server Node
- Hardware: Any
- Stack: Base + middleware + services (no globe interface)
- Role: Specialized service node (mail, backup, media, etc.)
- Administered via SSH and `ros2` CLI

---

## Build System

### Build Process (updated for v1.5)

```
Source Files
     │
     ▼
Docker Builder (Alpine 3.23)
     │
     ▼
Alpine 3.23 Base ISO
     │
     ▼
Customizations
  ├─ APK repos (NTARI + SEQSENSE)
  ├─ ROS2 Jazzy packages
  ├─ Service node packages
  ├─ OpenRC service configs
  ├─ Globe interface files
  └─ Security baseline
     │
     ▼
Build ISO
     │
     ▼
Build VM (Packer)
     │
     ▼
Outputs:
  ├─ ISO (ntari-os-1.5.0-x86_64.iso)
  ├─ QCOW2 (for QEMU/KVM)
  └─ VMDK (for VMware/VirtualBox)
```

---

---

## Planned Architecture Additions (Phases 10–13)

### Phase 10 — Hardware Detection

`ntari-hw-profile`: detects NIC count/type, RAM, CPU, storage, GPU presence.
Publishes to `/ntari/node/capabilities` (DDS latched topic).

### Phase 11 — Contribution Policy + Node Role Assignment

`ntari-node-policy`: member declares what hardware they are willing to
contribute to the cooperative mesh (networking, storage, compute, GPU, uptime
window). Policy is signed with the node's ed25519 key and published to
`/ntari/node/policy`.

`ntari-scheduler`: reads capabilities + policy from all mesh peers, assigns
node roles (router / server / edge / hub) within declared policy limits, and
deploys appropriate services. Never exceeds a member's stated constraints.

### Phase 12 — Internet/Broadcast Configuration

`ntari-wan`: WAN interface detection, DHCP/static IP configuration, NAT
management. Makes internet-facing configuration as simple as LAN configuration.

`ntari-bgp` (optional): BIRD2 BGP for IXP participation and anycast prefix
advertisement on major cooperative nodes.

---

**Roadmap complete at Phase 12.** Behavioral security (LBTAS-NIM) is a
SoHoLINK-layer concern and is out of NTARI OS scope. See Security
Architecture section above.

---

For implementation details and phase-by-phase tasks, see
[DEVELOPMENT_PLAN.md](../DEVELOPMENT_PLAN.md).

For the complete changelog, see [CHANGELOG.md](../CHANGELOG.md).
