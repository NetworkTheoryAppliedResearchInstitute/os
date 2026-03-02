# NTARI OS — Changelog

All notable changes to this project are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.0.0-dev] — 2026-02-27

### Summary

Version 2.0 clarifies the scope and completes the roadmap for NTARI OS as an
independent operating system. All Phase 1–9 code is complete. Phases 10–13
define the remaining work to a shippable v2.0 release.

### Changed

- **Scope boundary established.** NTARI OS is an independent OS — not a
  cooperative cloud platform. SoHoLINK and similar platforms are downstream
  projects that deploy on NTARI OS nodes. This distinction is now explicit
  in all documentation. The roadmap ends at Phase 13.

- **Roadmap updated.** `DEVELOPMENT_PLAN.md` rewritten to reflect actual
  state (Phases 1–9 code-complete) and correct remaining phases (0, 10–13).
  Previous plan was outdated (referenced v1.3/v1.5 milestones already
  completed) and incorrectly scoped cooperative cloud services as NTARI OS
  phases.

- **`DEVELOPMENT_STATUS.md` rewritten.** Previous version was stale (v1.3,
  February 15). Replaced with accurate current-state snapshot.

- **`docs/ARCHITECTURE.md` updated.** Added explicit scope section, planned
  Phase 10–13 components, and LBTAS-NIM behavioral security specification
  placeholder.

- **`README.md` updated.** Phase status table reflects actual completion.
  Contributing section updated to current areas of need.

- **`CLAUDE.md` updated.** Phase status updated to 2026-02-27. Phases 0 and
  10–13 added. Scope boundary note added to prevent future scope-creep.

### Added

- **Phase 0 (Live Validation)** defined as the immediate gate: boot ISO in
  Alpine 3.23, validate all 8 service nodes, globe interface, and DDS graph.

- **Phase 10 (Hardware Detection + Easy Configuration):** `ntari-hw-profile`
  detects hardware capabilities and publishes to DDS. `ntari-node-policy`
  guides member through a 2-minute contribution policy setup.

- **Phase 11 (Contribution Policy + Node Role Assignment):** `ntari-scheduler`
  assigns node roles (router/server/edge/hub) within member-declared policy
  limits. Never exceeds declared constraints.

- **Phase 12 (Internet/Broadcast Configuration):** `ntari-wan` for WAN
  interface setup and NAT. `ntari-bgp` (optional) for IXP participation.

- **Phase 13 (LBTAS-NIM Behavioral Security):** Continuous behavioral scoring
  via the Leveson-Based Trade Assessment Scale — Network Infrastructure Manager.
  Four components: collector, scorer, enforcer, and local LLM remediation comms.

---

## [1.5.0] — 2026-02-17

### Summary

Version 1.5 represents a major architectural evolution from NTARI OS as a
federated AAA platform (SoHoLINK-centric) to a full **network-first operating
system** grounded in ROS2 middleware and a new graph-native user interface.
This version incorporates research and design work conducted in the session of
2026-02-17 and formalizes decisions that were implicit or deferred in v1.0.

This is not a breaking change to the base Alpine/OpenRC foundation — it is an
architectural expansion. All v1.0 work remains valid and is subsumed into the
new layer model.

---

### Added

#### Architectural Concept

- **Network-first OS paradigm formally adopted.** NTARI OS now explicitly
  inverts the conventional local-first OS design priority. The network
  communication graph is the primary abstraction; local computation is
  understood as a node within that graph. This is grounded in the historical
  analysis documented in `docs/NETWORK_FIRST_RATIONALE.md`.

- **Four-layer architecture defined:**
  1. **Base Layer** — Hardened Alpine Linux 3.23, OpenRC, network drivers.
     Primary boot responsibility: join the DDS domain before anything else.
  2. **Middleware Layer** — ROS2 (Jazzy LTS) compiled against Alpine's musl
     libc, Cyclone DDS as the exclusive RMW implementation.
  3. **Services Layer** — Functional capabilities as composable ROS2 node
     packages (see Services Layer Specification below).
  4. **Interface Layer** — Graph-native globe visualization; no traditional
     desktop environment.

#### ROS2 Middleware Integration

- **ROS2 Jazzy selected** as the middleware distribution (current LTS).
- **Cyclone DDS selected** as the exclusive DDS implementation (EPL-2.0
  license, no single corporate owner, upstream musl patches merged, C-based
  core with minimal dependency surface). Fast-DDS explicitly excluded.
- **Alpine Linux 3.23 selected** as the base (superseding 3.19 from v1.0).
- **Build infrastructure:** SEQSENSE `aports-ros-experimental` adopted as the
  basis for NTARI's own Alpine ROS2 APK repository, with attribution to
  SEQSENSE contributors.
- **Technical compatibility research completed** and documented in
  `docs/ROS2_MUSL_COMPATIBILITY.md`. Key findings:
  - Core packages (`ros_core`, `ros_base`, Cyclone DDS) build and run on
    Alpine 3.20/3.23 via SEQSENSE experimental aports.
  - Highest-priority open issue: thread stack size defaults (128 KB on musl
    vs 2–10 MB on glibc). Requires targeted patch to Cyclone DDS internal
    thread spawning. Tracked as near-term technical priority.
  - `dlclose()` no-op in musl is a known permanent limitation; plugin
    lifecycle management must account for memory accumulation.
  - Python `musllinux` wheel ecosystem incomplete; Python ROS2 tooling
    requires source compilation.

#### Services Layer Specification

A full inventory of network services drawn from the Network Services reference
document (ChatGPT, 2026-02-17) has been mapped to NTARI OS node packages.

**Core Tier** (required for all deployments):

| Service | Implementation | ROS2 Node Package |
|---|---|---|
| DNS | dnsmasq | `ntari_dns_node` |
| DHCP | Kea DHCP | `ntari_dhcp_node` |
| NTP | Chrony | `ntari_ntp_node` |
| Web (interface serving) | Caddy | `ntari_web_node` |
| Memory Cache | Redis | `ntari_cache_node` |
| Container Runtime | Podman/LXC | `ntari_container_node` |

**High Priority Tier** (recommended for cooperative deployments):

| Service | Implementation | ROS2 Node Package |
|---|---|---|
| VPN / Federation | WireGuard | `ntari_vpn_node` |
| Identity / Directory | FreeIPA | `ntari_identity_node` |
| File Sharing | Samba/NFS | `ntari_files_node` |

**Community Tier** (optional, deployment-specific):

| Service | Implementation | ROS2 Node Package |
|---|---|---|
| Chat / IM | Matrix (Synapse) | `ntari_chat_node` |
| VoIP / Emergency | FreeSWITCH | `ntari_voip_node` |
| Mail | Postfix + Dovecot | `ntari_mail_node` |
| Backup | rsync + Bacula | `ntari_backup_node` |
| Media | Jellyfin | `ntari_media_node` |

**Key decisions from services research:**
- WireGuard chosen over OpenVPN/StrongSwan for cooperative federation
  (in-kernel on modern Linux, minimal overhead, fits Alpine philosophy).
- FreeIPA chosen over Active Directory for cooperative identity management
  (open source, Kerberos integration, cross-cooperative federation support).
- Matrix chosen over XMPP (ejabberd) for community chat (federated by design,
  modern protocol, bridges to other networks).
- Jellyfin chosen over Plex (AGPL-3.0 license; Plex is proprietary).

#### Globe Interface

- **Graph-native globe interface designed and prototyped.** The primary
  interface is a live visualization of the ROS2 DDS computation graph rendered
  as luminous nodes on an abstract wireframe sphere. No geography, no
  political borders.
- **Prototype delivered:** `docs/globe-interface/ntarios-globe.html` —
  single-file, zero-dependency HTML/CSS/JS canvas implementation.
- **Design document delivered:** `docs/globe-interface/GLOBE_INTERFACE_DESIGN.md`
- **Key interface behaviors:**
  - Globe radius grows logarithmically with node count (intimate at 2 nodes,
    expansive at 20+).
  - Farthest node (highest latency) always placed on the opposite hemisphere.
  - Auto-zoom engages at >10 nodes in display area.
  - Node labels in JetBrains Mono; globe in deep-space industrial aesthetic.
  - Search by node name or topic name; selection orients globe toward node.
  - Node detail panel shows status, latency, RMW, and subscribed topics.
- **Production path:** WebSocket bridge ROS2 node streams live graph data to
  browser interface at 1–2 Hz. Node positions derived from measured DDS
  round-trip latency. Three.js migration recommended at 50+ nodes.

#### Documentation

- `docs/ROS2_MUSL_COMPATIBILITY.md` — Full technical assessment of ROS2/musl
  compatibility as of early 2026. Covers 9 specific compatibility issues,
  DDS vendor comparison, community infrastructure, and remaining open problems.
- `docs/globe-interface/GLOBE_INTERFACE_DESIGN.md` — Design rationale,
  interaction model, color palette, typography, state definitions, production
  implementation path, and open design questions.
- `docs/globe-interface/ntarios-globe.html` — Interactive prototype.
- `docs/SERVICES_LAYER_SPEC.md` — Network services inventory and node package
  mapping (this session; see DEVELOPMENT_PLAN.md for full spec).

---

### Changed

#### Base System

- **Alpine Linux version:** 3.19 → **3.23** (current stable with active
  SEQSENSE ROS2 package support).
- **Alpine version references** in `build/Dockerfile`, `build/build-iso.sh`,
  and `vm/packer/ntari-os.pkr.hcl` updated accordingly in v1.5 builds.

#### Architecture

- **System stack diagram** expanded from 5 layers to include ROS2 middleware
  and graph-native interface layers above the existing Alpine base.
- **Federation layer** redesigned: libp2p/DHT approach (v1.0) superseded by
  **WireGuard + DDS domain bridging** for inter-cooperative federation.
  WireGuard establishes secure tunnels between cooperatives; DDS domain
  bridging allows the ROS2 graph to span federated nodes transparently.
- **Admin dashboard** (CLI, v1.0) remains as a fallback/headless interface.
  The globe interface is the primary interface for nodes with display
  capability.

#### Design Principles

- Principle 6 updated: "Easy Deployment" → **"Network-First Interface"** —
  the graph is the primary user experience, not a secondary configuration view.
- New Principle 7 added: **"Community Governance"** — the services layer is
  modular and community-replaceable. Cooperatives deploy only the services
  relevant to their use case, audit each independently, and contribute
  modifications upstream under AGPL-3.0.

#### License Clarification

- License confirmed as **AGPL-3.0** throughout all new documents. This
  applies to NTARI OS, the globe interface, all ROS2 node packages in the
  services layer, and all documentation produced in this session. The AGPL-3.0
  requirement to share modifications applies to network-deployed services,
  which is appropriate and intentional for cooperative infrastructure.

---

### Deprecated

- **libp2p as primary federation transport.** Phase 3 (v1.0) proposed libp2p
  + Kademlia DHT for node discovery and federation. This approach is
  superseded by WireGuard tunnels + DDS domain bridging, which is simpler,
  more auditable, and aligns better with the ROS2 graph model. libp2p may
  still be evaluated for specific bootstrap/discovery use cases in a future
  phase.

---

### Fixed (Design)

- **Services layer governance gap** identified in the original article
  (Section 7, "How Modern Operating Systems Prioritized Local Computation"):
  the article proposed community governance of the services layer without
  specifying mechanism. v1.5 addresses this with: AGPL-3.0 licensing (forces
  modification sharing), modular ROS2 node packages (auditable independently),
  and the NTARI-maintained APK repository (community-governed package
  acceptance).

- **Interface layer vagueness** in the original article: "graph-native
  interface" was described architecturally but not as a user experience.
  v1.5 resolves this with the globe prototype and full design document.

---

### Technical Debt Introduced

The following items are known limitations accepted in v1.5 with planned
resolution:

| Item | Severity | Resolution Path |
|---|---|---|
| musl thread stack defaults (128 KB) | High | Targeted patch to Cyclone DDS thread spawning |
| `dlclose()` no-op in musl | Medium | Plugin lifecycle design in `pluginlib` usage |
| Python `musllinux` wheel gaps | Medium | Contribute wheels upstream; compile from source |
| Globe prototype at >80 nodes | Medium | Three.js migration in v0.2 of interface |
| SEQSENSE aports dependency | High | Fork/adopt as NTARI-maintained repository |
| No live ROS2 → globe bridge | High | WebSocket bridge node in v1.6 |

---

## [1.0.0-alpha] — 2026-02-13

### Added

- Initial project structure and build system
- Alpine Linux 3.19 base with custom ISO builder
- SoHoLINK (Federated AAA) integration
  - APK package template (APKBUILD)
  - OpenRC service configuration
  - First-boot setup script
- Network configuration (DHCP/static)
- Firewall setup (iptables, restrictive defaults)
- Time synchronization (Chrony)
- Security hardening script (SSH, kernel params, fail2ban, AIDE)
- Health check and admin dashboard (CLI)
- Update mechanism with approval and backup
- VM image building (Packer, QCOW2/VMDK)
- Integration test suite
- Full documentation set (INSTALL, ARCHITECTURE, OPERATIONS)

### Design Principles (v1.0)

1. Minimal Footprint (<100MB base)
2. Offline-First
3. Security by Default
4. Federation-Ready
5. Multi-Architecture (x86_64, ARM64)
6. Easy Deployment

### License

AGPL-3.0

---

*This changelog is maintained by the NTARI OS development team.*
*Repository: https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os*
