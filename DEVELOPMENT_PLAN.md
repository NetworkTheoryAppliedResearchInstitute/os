# NTARI OS — Development Plan

**Network Theory Applied Research Institute Operating System**
*A Network-First Cooperative Infrastructure OS*

**License:** AGPL-3.0
**Last updated:** 2026-04-05

---

## What NTARI OS Is

NTARI OS is an independent Alpine Linux 3.23 operating system for cooperative
networking infrastructure. It runs on cooperative hardware nodes, configures
them for network participation, provides core networking services, exposes the
cooperative mesh as a live ROS2 DDS graph, and optionally operates as an
Internet Exchange Point.

**NTARI OS scope:**
- OS base layer and hardware configuration
- ROS2 Jazzy + Cyclone DDS as the foundational messaging abstraction
- Core cooperative networking services (DNS, NTP, DHCP, VPN, identity, files,
  web, cache)
- Hardware capability detection and node policy
- Internet/WAN configuration and optional BGP
- IXP operation (BGP route server, Layer 2 fabric, member registry,
  Looking Glass, Lightning settlement)
- Inter-cooperative DDS federation over WireGuard

**Not NTARI OS scope:**
- Behavioral security scoring (LBTAS-NIM) — SoHoLINK layer
- Desktop GUI or windowing environment — SoHoLINK `fedaaa-gui` client
- Distributed compute clusters, object storage, ML pipelines — SoHoLINK layer
- Network graph visualisation — SoHoLINK `ui/globe-interface/`

SoHoLINK and similar cooperative cloud platforms are downstream projects that
deploy *on* NTARI OS nodes. NTARI OS is the OS they run on — not the platform.

---

## Roadmap Status — Complete

The NTARI OS roadmap is closed. All planned phases are implemented.

| Phase | Description | Status |
|---|---|---|
| 1–5 | Foundation, hardening, build system, SoHoLINK v1.0 | ✅ Complete |
| 6 | ROS2 Jazzy + Cyclone DDS middleware | ✅ Validated |
| 7 | Services layer — 8 nodes (dns/ntp/web/cache/dhcp/vpn/identity/files) | ✅ Validated |
| 8 | Globe WebSocket bridge | ✅ Validated |
| 9 | WireGuard + DDS federation | ✅ Complete (opt-in) |
| 0 | Live validation — boot + full stack test | ✅ Complete |
| 10 | Hardware detection + node policy | ✅ Complete |
| 11 | Contribution policy + node role assignment | ✅ Complete |
| 12 | Internet/broadcast configuration + optional BGP | ✅ Complete |
| 14 | IXP BGP route server (FRRouting + ROS2 node) | ✅ Complete |
| 15 | IXP Layer 2 fabric management | ✅ Complete |
| 16 | IXP member registry + PeeringDB integration | ✅ Complete |
| 17 | Globe IXP mode extension | ✅ Complete |
| 18 | Looking Glass service | ✅ Complete |
| 19 | Lightning-settled paid peering (optional) | ✅ Complete |

Phase 13 (LBTAS-NIM behavioral security) was removed from the NTARI OS
roadmap. It is SoHoLINK scope. See `SoHoLINK/docs/ARCHITECTURE.md`.

---

## Phase 0 — Live Validation Findings

Completed 2026-02-28. Key findings that shaped later implementation:

- **ROS2 install path:** Alpine-native packages install to `/usr/ros/jazzy/`,
  not `/opt/ros/jazzy/`. Python 3.12, not 3.11.
- **Missing package:** `ros-jazzy-rosidl-generator-py` required for `rclpy`
  (`import_type_support`); without it `rclpy.create_node()` throws
  `NoTypeSupportImportedException`.
- **ntari-identity redesign:** kanidm is not packaged for Alpine 3.23;
  replaced with OpenLDAP (slapd).
- **ros2-domain OpenRC pattern:** `ros2 daemon start` is one-shot — requires
  custom `start()`/`stop()` functions, not `command_background="yes"`.
- **ntari-cache:** Redis must have `daemonize no` and no `pidfile` directive;
  OpenRC manages the process.
- **ntari-dhcp:** kea-dhcp4 self-daemonizes; omit `command_background="yes"`.
- **Modloop nesting:** Alpine live ISO modloop has `modules/KVER/` at root;
  after mounting at `/lib/modules/` path becomes `/lib/modules/modules/KVER/`
  — modprobe cannot find drivers. Fixed with bind-mount in `ntari-modloop`.
- **ntari-vpn:** Expected failure on first boot without WireGuard peer config.
  This is by design.
- **Caddy startup:** ~90 seconds when checking for TLS cert. Not a bug.

---

## Service Architecture

### Editions

| Edition | Description |
|---|---|
| `server` | Headless — base Alpine, no ROS2 |
| `ros2` | Jazzy + Cyclone DDS; all ntari-* service nodes |

### Boot Order

```
sysinit: ntari-modloop   (modloop fix + NIC drivers; before net; both editions)

net → ros2-domain → ntari-ntp → ntari-dhcp → ntari-dns → ntari-cache
    → ntari-vpn → ntari-identity → ntari-files → ntari-hw-profile
    → ntari-node-policy → ntari-scheduler → ntari-web
    → ntari-wan
```

`ntari-federation` — manual `rc-update add` only (requires WireGuard peer config)
`ntari-bgp` — manual `rc-update add` only (requires ASN + peer config)
`ntari-ixp-*` — manual `rc-update add` only (requires `config/services/ixp.conf`)

### DDS Domain Model

| Domain | Purpose | Transport |
|---|---|---|
| 0 | Local LAN cooperative mesh | Multicast |
| 1 | Federation overlay | WireGuard unicast (no multicast) |

### Phase 7 Service Nodes

| Node | Backend | Health topic |
|---|---|---|
| `ntari-dns` | dnsmasq | `/ntari/dns/health` |
| `ntari-ntp` | Chrony | `/ntari/ntp/health` |
| `ntari-web` | Caddy | `/ntari/web/health` |
| `ntari-cache` | Redis | `/ntari/cache/health` |
| `ntari-dhcp` | Kea DHCP | `/ntari/dhcp/health` |
| `ntari-vpn` | WireGuard | `/ntari/vpn/health` |
| `ntari-identity` | OpenLDAP (slapd) | `/ntari/identity/health` |
| `ntari-files` | Samba/NFS | `/ntari/files/health` |

### IXP Service Nodes (Phases 14–19)

| Node | Backend | Key topics |
|---|---|---|
| `ntari-ixp-bgp` | FRRouting | `/ixp/bgp/peers`, `/ixp/bgp/alerts` |
| `ntari-ixp-fabric` | OVS or Linux bridge | `/ixp/fabric/ports`, `/ixp/fabric/utilization` |
| `ntari-ixp-registry` | SQLite + bgpq4 | `/ixp/members/list`, `/ixp/members/provisioned` |
| `ntari-ixp-lg` | Python HTTP + vtysh | `/ixp/lg/health` |
| `ntari-ixp-settlement` | SQLite + Lightning | `/ixp/settlement/invoices` |

---

## Key Files

### Build

| File | Purpose |
|---|---|
| `build/build-iso.sh` | Main ISO builder — Alpine mkimage + apkovl overlay |
| `build/Dockerfile` | Alpine 3.23 build container |
| `build/docker-build.sh` | Windows/Git Bash wrapper (`MSYS_NO_PATHCONV=1`) |

### Scripts (copied into ISO overlay)

| File | Purpose |
|---|---|
| `scripts/ntari-init.sh` | First-boot init; edition-aware (server vs ros2) |
| `scripts/setup-ros2.sh` | ROS2 APK repo trust + install |
| `scripts/ros2-node-health.sh` | Shared DDS health publisher (all Phase 7+ nodes) |
| `scripts/ntari-federation.sh` | DDS domain 0 ↔ domain 1 bridge over WireGuard |
| `scripts/ntari-hw-profile.sh` | Hardware detection → `/ntari/node/capabilities` |
| `scripts/ntari-node-policy.sh` | Policy HTTP server; UI at `/node/policy`; port 8091 |
| `scripts/ntari-scheduler.sh` | Role assignment daemon; UI at `/scheduler`; port 8092 |

### OpenRC Services

| File | Purpose |
|---|---|
| `config/services/ros2-domain.initd` | ROS2 DDS domain 0; boots before all ntari-* |
| `config/services/ntari-modloop.initd` | Sysinit; modloop nesting fix + NIC drivers |
| `config/services/ntari-*.initd` | One per service node (Phase 7–12) |
| `config/services/ntari-ixp-*.initd` | One per IXP service node (Phase 14–19) |
| `config/services/ixp.conf` | Master IXP configuration (all IXP packages read this) |

### Packages

| File | Purpose |
|---|---|
| `packages/cyclonedds/APKBUILD` | Cyclone DDS with musl thread stack patch |
| `packages/cyclonedds/0001-musl-thread-stack-size.patch` | `pthread_attr_setstacksize(4MB)` fix |
| `packages/ixp-bgp/` | FRRouting ROS2 node, BGP monitor, FRR config template |
| `packages/ixp-fabric/` | Fabric management node, OVS + Linux bridge drivers |
| `packages/ixp-registry/` | Member DB, provisioning wizard, PeeringDB client |
| `packages/ixp-looking-glass/` | Looking Glass HTTP server + dark-themed UI |
| `packages/ixp-settlement/` | Traffic metering, Lightning settler, audit ledger |

### Documentation

| File | Purpose |
|---|---|
| `docs/ARCHITECTURE.md` | Four-layer stack: Base/Middleware/Services/Interface |
| `docs/FEDERATION.md` | Inter-cooperative federation setup and governance |
| `docs/IXP_SETUP.md` | IXP operator setup guide |
| `docs/IXP_OPERATIONS.md` | Day-to-day IXP operations reference |
| `docs/IXP_MEMBER_ONBOARDING.md` | Member onboarding procedures |

### Globe UI and IXP Extension

The Globe visualisation and IXP mode extension are SoHoLINK scope:

| File | Purpose |
|---|---|
| `ui/globe-interface/ixp_topics.js` | IXP mode toggle, status panel, BGP peer table |

NTARI OS exposes the ROS2 DDS graph. SoHoLINK consumes it.

---

## Future Development

The NTARI OS roadmap is closed. Future cooperative platform development
continues in **SoHoLINK**, which runs on NTARI OS nodes and provides:

- Globe network visualisation (`ui/globe-interface/`)
- Desktop client for cooperative members (`fedaaa-gui`)
- Hardware contribution layer (cross-platform)
- Cooperative network client (mDNS discovery + service consumption)
- LBTAS-NIM behavioral security scoring

See `SoHoLINK/docs/ARCHITECTURE.md` for the full SoHoLINK scope.

---

*NTARI OS is licensed AGPL-3.0.*
*Maintained by the Network Theory Applied Research Institute — https://ntari.org*
