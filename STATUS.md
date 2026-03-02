# NTARI OS — Project Status

**Last Updated**: 2026-02-17
**Version**: 1.5.0-dev
**Status**: Phase 6 — ROS2 Integration (Starting)

---

## Overview

NTARI OS is a network-first cooperative infrastructure OS built on Alpine Linux
and ROS2. Version 1.5 formalizes the architectural expansion from the v1.0
SoHoLINK-centric AAA platform to a full graph-native operating system with
four layers: Base (Alpine 3.23), Middleware (ROS2 Jazzy + Cyclone DDS),
Services (ROS2 lifecycle node packages), and Interface (globe visualization).

This file tracks actual implementation status. For the full roadmap, see
[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

---

## Repository Structure (Post-Merge)

This canonical folder consolidates the two previous working directories:
- `NTARI OS\` — v1.5 documentation and scripts (primary)
- `NTARIOS\ntari-os\` — v1.4 build environment and source (integrated)

```
ntari-os/
├── build/
│   ├── Dockerfile              ✅ Created (v1.5 pending Alpine 3.23 update)
│   ├── Makefile                ✅ Created
│   ├── build-iso.sh            ✅ Created (v1.0 structure; v1.5 supersedes)
│   ├── build-alpine.sh         ✅ Integrated from NTARIOS (v1.0 builder)
│   └── docker-build.sh         ✅ Integrated from NTARIOS (Docker wrapper)
├── config/
│   ├── network/interfaces      ✅ Created
│   ├── security/               ✅ Directory created
│   └── services/
│       ├── chrony.conf         ✅ Created
│       ├── soholink.initd      ✅ Created
│       └── soholink.confd      ✅ Created
├── docs/
│   ├── ARCHITECTURE.md         ✅ Rewritten for v1.5 (four-layer)
│   ├── INSTALL.md              ✅ Created
│   ├── OPERATIONS.md           ✅ Created
│   ├── ROS2_MUSL_COMPATIBILITY.md  ✅ Created (v1.5 research)
│   ├── DOCKER_FIX.md           ✅ Integrated from NTARIOS
│   ├── QEMU_BOOT_ISSUES.md     ✅ Integrated from NTARIOS
│   ├── VIRTUALBOX_METHOD.md    ✅ Integrated from NTARIOS
│   ├── globe-interface/
│   │   ├── GLOBE_INTERFACE_DESIGN.md  ✅ Created (v1.5)
│   │   └── ntarios-globe.html         ✅ Created (interactive prototype)
│   └── history/
│       └── README.md           ✅ Version history index (v1.0–v1.4)
├── installer/
│   └── package.json            ✅ Integrated from NTARIOS (Electron app spec)
├── iso/
│   ├── overlay/                ✅ Directory created
│   └── profile/                ✅ Directory created
├── packages/
│   └── soholink/APKBUILD       ✅ Created
├── scripts/
│   ├── install.sh              ✅ Created
│   ├── setup-network.sh        ✅ Created
│   ├── setup-soholink.sh       ✅ Created
│   ├── harden-system.sh        ✅ Created
│   ├── health-check.sh         ✅ Created
│   ├── ntari-admin.sh          ✅ Created (CLI admin dashboard)
│   ├── ntari-init.sh           ✅ Integrated from NTARIOS (first-boot init)
│   └── ntari-cli.sh            ✅ Integrated from NTARIOS (interactive CLI)
├── tests/
│   ├── integration/test-suite.sh  ✅ Created
│   └── run-tests.sh            ✅ Created
├── vm/
│   ├── packer/ntari-os.pkr.hcl ✅ Created
│   ├── build-vm.sh             ✅ Created
│   └── quickstart.sh           ✅ Created
├── CHANGELOG.md                ✅ Created (v1.0 → v1.5)
├── CONTRIBUTING.md             ✅ Created
├── DEVELOPMENT_PLAN.md         ✅ Updated for v1.5 (Phases 6–9 added)
├── LICENSE                     ✅ AGPL-3.0
├── README.md                   ✅ Rewritten for v1.5
└── STATUS.md                   ✅ This file
```

---

## Phase Status

### ✅ Phase 1 — Foundation (Scripts Complete)

- [x] Project directory structure
- [x] Build environment Dockerfile
- [x] Makefile for build automation
- [x] ISO build script (v1.0)
- [x] Docker build wrapper
- [x] Build-alpine setup script (generates package lists)
- [x] SoHoLINK APK package template
- [x] SoHoLINK OpenRC service
- [x] First-boot setup script (`ntari-init.sh`)
- [ ] First bootable ISO (v1.5 Alpine 3.23 — pending Phase 6)
- [ ] ISO tested in VirtualBox/VMware

**Note:** A 906MB v1.0 ISO was built in Feb 2026 using Alpine 3.19. It has
a known boot issue (see `docs/QEMU_BOOT_ISSUES.md`). The v1.5 build
system (`make iso`) will resolve this by following Alpine's standard
`mkimage` conventions.

---

### ✅ Phase 2 — Hardening (Scripts Complete)

- [x] Security hardening script
- [x] SSH hardening
- [x] Kernel security parameters
- [x] fail2ban configuration
- [x] AIDE file integrity setup
- [x] Health check script
- [x] Admin dashboard (CLI) — `ntari-admin.sh`
- [x] NTARI interactive CLI — `ntari-cli.sh`
- [x] Update check and system update scripts
- [ ] Security audit on actual running system
- [ ] Monitoring/logging validated

---

### ⏳ Phase 3 — Federation (Deferred)

Original libp2p/DHT approach superseded by WireGuard + DDS domain bridging
(see Phase 9). Phase 3 content folded into Phase 9.

---

### ⏳ Phase 4 — Distribution (Pending)

- [ ] Release preparation (depends on Phase 6 completion)
- [ ] First public release

---

### 🔵 Phase 6 — ROS2 Integration (Starting)

This is the current active phase.

- [ ] Alpine Linux 3.23 base (update from 3.19)
- [ ] Fork/adopt SEQSENSE aports-ros-experimental as NTARI APK repository
- [ ] Build ROS2 Jazzy + Cyclone DDS on Alpine 3.23
- [ ] Cyclone DDS thread stack patch (128 KB → adequate for musl)
- [ ] OpenRC `ros2-domain.initd` service (DDS domain first at boot)
- [ ] `/etc/profile.d/ros2.sh` environment configuration
- [ ] First live node visible in ROS2 graph (`ros2 node list`)

**Key Technical Requirement:** Cyclone DDS thread stack size patch.
See `docs/ROS2_MUSL_COMPATIBILITY.md`, Section 5, item 2.

---

### 📋 Phase 7 — Services Layer (Planned)

ROS2 lifecycle node packages for all network services:

| Node Package | Service | Status |
|---|---|---|
| `ntari_dns_node` | dnsmasq | 📋 Planned |
| `ntari_dhcp_node` | Kea DHCP | 📋 Planned |
| `ntari_ntp_node` | Chrony | 📋 Planned |
| `ntari_web_node` | Caddy | 📋 Planned |
| `ntari_cache_node` | Redis | 📋 Planned |
| `ntari_container_node` | Podman | 📋 Planned |
| `ntari_vpn_node` | WireGuard | 📋 Planned |
| `ntari_identity_node` | FreeIPA | 📋 Planned |
| `ntari_files_node` | Samba/NFS | 📋 Planned |

---

### 📋 Phase 8 — Globe Interface (Planned)

- [ ] WebSocket bridge ROS2 node (live DDS → browser)
- [ ] Connect `docs/globe-interface/ntarios-globe.html` prototype to bridge
- [ ] Caddy deployment at `http://ntari.local`
- [ ] Three.js evaluation for >50 nodes

---

### 📋 Phase 9 — Cooperative Federation (Planned)

- [ ] WireGuard inter-cooperative tunnel setup
- [ ] DDS domain bridge configuration
- [ ] `ntari-fed-setup` federation management tool
- [ ] Multi-cooperative graph visualization in globe interface

---

## Known Issues / Technical Debt

| Item | Severity | Status |
|---|---|---|
| musl thread stack defaults (128 KB) | High | Requires Cyclone DDS patch (Phase 6) |
| `dlclose()` no-op in musl | Medium | Plugin lifecycle management required |
| Python `musllinux` wheel gaps | Medium | Source compilation fallback |
| Globe prototype at >80 nodes | Medium | Three.js migration (Phase 8) |
| SEQSENSE aports dependency | High | Fork/adopt as NTARI APK repo (Phase 6) |
| No live ROS2 → globe bridge | High | WebSocket bridge node (Phase 8) |
| v1.0 ISO boot issue (SquashFS/initramfs mismatch) | Medium | Resolved in v1.5 `make iso` |

---

## Next Steps (Priority Order)

### Immediate (Phase 6)

1. Update Dockerfile and build scripts for Alpine 3.23
2. Set up SEQSENSE aports fork as NTARI APK repository
3. Attempt ROS2 Jazzy build on Alpine 3.23 (inside Docker)
4. Identify and apply Cyclone DDS thread stack patch
5. Boot node, confirm `ros2 node list` shows DDS participants

### Short Term (Phase 7)

1. Package `ntari_dns_node` as first ROS2 lifecycle service
2. Confirm dnsmasq/ROS2 integration works
3. Add subsequent Core Tier services one by one
4. Validate OpenRC → ROS2 service dependency ordering

### Medium Term (Phases 8–9)

1. WebSocket bridge node connecting DDS graph to browser
2. Connect prototype globe to live bridge
3. WireGuard tunnel between two test nodes
4. DDS domain bridge across WireGuard tunnel
5. Verify globe shows federated nodes from both cooperatives

---

## External Dependencies

| Dependency | Purpose | Status |
|---|---|---|
| Alpine Linux 3.23 | Base OS | Stable, available |
| SEQSENSE aports-ros-experimental | ROS2 APK packages for Alpine | Available; needs fork |
| ROS2 Jazzy (LTS) | Middleware | Builds on Alpine 3.20/3.23 via SEQSENSE |
| Cyclone DDS (EPL-2.0) | DDS implementation | musl thread stack patch needed |
| WireGuard | Federation VPN | In Alpine kernel; available |
| FreeIPA | Identity management | Available (not yet packaged as ROS2 node) |

---

## Resources

- **GitHub:** https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os
- **Email:** contact@ntari.org
- **Documentation:** See `docs/` directory

---

*This status reflects the consolidated project state as of 2026-02-17.*
*Both working directories (NTARI OS, NTARIOS) have been merged into this canonical repository.*
