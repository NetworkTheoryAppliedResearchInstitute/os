# NTARI OS

**Network Theory Applied Research Institute Operating System**

A network-first cooperative infrastructure OS built on Alpine Linux and ROS2,
designed for community networks, cooperatives, and mutual aid organizations.

**Version:** 1.5.0 | **License:** AGPL-3.0 | **Status:** Active Development

---

## What Is NTARI OS?

Most operating systems treat networking as a feature — something added on top
of local computation. NTARI OS inverts this. The network *is* the primary
abstraction. Every machine is a node in a cooperative graph. Every service is
a participant in that graph. The first thing you see when you boot is not a
desktop or a file browser — it is your network.

Built on **Alpine Linux 3.23** and **ROS2 Jazzy** with **Cyclone DDS**
middleware, NTARI OS provides cooperative and community organizations with
reliable, auditable, community-maintainable networking infrastructure — without
dependency on extractive corporate platforms.

---

## Key Features

- **Network-First Interface** — A live globe visualization of the ROS2
  communication graph. Nodes are participants, not icons. The globe grows as
  your network grows.
- **ROS2 Graph-Native** — Every service runs as a ROS2 lifecycle node,
  visible and inspectable in the DDS computation graph
- **Alpine Linux Base** — <100MB base system; deployable on Raspberry Pi,
  repurposed routers, and low-power edge hardware
- **Cyclone DDS** — EPL-2.0, no single corporate owner, musl-compatible,
  written in C
- **Modular Services Layer** — DNS, DHCP, NTP, VPN, identity, files, chat,
  VoIP, and more — each a composable, replaceable node package
- **WireGuard Federation** — Inter-cooperative federation via WireGuard
  tunnels and DDS domain bridging
- **Cooperative Governance** — AGPL-3.0 throughout; every service is
  independently auditable and community-replaceable
- **Offline-First** — Full functionality without internet connectivity
- **Multi-Architecture** — x86_64 and ARM64 (Raspberry Pi)
- **Security by Default** — Hardened Alpine, AppArmor, AIDE, fail2ban

---

## Four-Layer Architecture

```
┌─────────────────────────────────────────────┐
│  INTERFACE LAYER                            │
│  Globe graph visualization (ntari.local)    │
├─────────────────────────────────────────────┤
│  SERVICES LAYER                             │
│  DNS · DHCP · NTP · VPN · Identity · Files  │
│  Chat · VoIP · Mail · Backup · Media · ···  │
├─────────────────────────────────────────────┤
│  MIDDLEWARE LAYER                           │
│  ROS2 Jazzy · Cyclone DDS · Graph bridge    │
├─────────────────────────────────────────────┤
│  BASE LAYER                                 │
│  Alpine Linux 3.23 · OpenRC · musl libc     │
└─────────────────────────────────────────────┘
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for full detail.

---

## Who Is This For?

- **Cooperatives** needing auditable, self-hosted infrastructure
- **Community mesh networks** (rural ISPs, neighborhood networks)
- **Teen Tech Centers** — local WiFi and services without cloud dependency
- **Mutual aid organizations** — resilient communications infrastructure
- **Technical volunteers** building cooperative alternatives to corporate platforms

---

## Quick Start

### Prerequisites

- Docker Desktop
- Git
- Make
- VirtualBox or VMware (for testing)
- 8GB RAM minimum, 50GB free disk space

### Build from Source

```bash
git clone https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os.git
cd ntari-os

# Build the ISO
make iso

# Output: build-output/ntari-os-1.5.0-x86_64.iso
```

### Run in a VM

```bash
# Build and launch VM image
make vm

# Or quick-start with QEMU:
./vm/quickstart.sh
```

Default credentials (change immediately after first boot):
- Username: `root`
- Password: `ntaripass`

Globe interface accessible at: `http://ntari.local` (after boot)

---

## Project Structure

```
ntari-os/
├── build/                    # Build scripts and tools
│   ├── Dockerfile            # Alpine 3.23 build environment
│   ├── Makefile              # Build automation
│   └── build-iso.sh          # ISO builder
├── iso/                      # ISO customization
│   ├── overlay/              # Files to include
│   └── profile/              # Alpine profile
├── scripts/                  # System scripts
│   ├── install.sh
│   ├── setup-network.sh
│   ├── setup-soholink.sh     # Legacy SoHoLINK (RADIUS)
│   ├── harden-system.sh
│   ├── health-check.sh
│   └── ntari-admin.sh        # CLI admin dashboard (headless)
├── config/                   # Configuration files
│   ├── network/
│   ├── security/
│   └── services/
├── packages/                 # Custom APK packages
│   └── soholink/             # Legacy SoHoLINK package
├── vm/                       # VM image builders
│   ├── packer/
│   └── cloud-init/
├── docs/                     # Documentation
│   ├── ARCHITECTURE.md       # Full architecture (v1.5)
│   ├── INSTALL.md
│   ├── OPERATIONS.md
│   ├── ROS2_MUSL_COMPATIBILITY.md   # ROS2/Alpine technical assessment
│   └── globe-interface/
│       ├── GLOBE_INTERFACE_DESIGN.md  # Interface design document
│       └── ntarios-globe.html         # Interactive prototype
├── tests/                    # Testing scripts
├── CHANGELOG.md              # Version history
├── DEVELOPMENT_PLAN.md       # Full roadmap (v1.5)
└── README.md                 # This file
```

---

## Development Status

**Current Version:** 2.0-dev
**Current Phase:** Phase 0 — Live Validation (gate for all new development)

| Phase | Description | Status |
|---|---|---|
| 1–5 | Foundation, hardening, build system, SoHoLINK v1.0 | ✅ Complete |
| 6 | ROS2 Jazzy + Cyclone DDS middleware | ✅ Code complete |
| 7 | Services layer — dns/ntp/web/cache/dhcp/vpn/identity/files | ✅ Code complete |
| 8 | Globe interface + WebSocket bridge | ✅ Code complete |
| 9 | WireGuard + DDS federation | ✅ Code complete (opt-in) |
| **0** | **Live validation — boot ISO, test full stack** | **⚠️ In progress** |
| 10 | Hardware detection + easy configuration | 📋 Planned |
| 11 | Contribution policy model + node role assignment | 📋 Planned |
| 12 | Internet/broadcast configuration | 📋 Planned |
| 13 | LBTAS-NIM behavioral security | 📋 Planned |

See [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) for the complete roadmap.

---

## Documentation

| Document | Description |
|---|---|
| [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) | Complete roadmap, all phases, task detail |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Four-layer stack, design decisions, deployment scenarios |
| [docs/INSTALL.md](docs/INSTALL.md) | Installation guide |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Day-to-day administration |
| [docs/ROS2_MUSL_COMPATIBILITY.md](docs/ROS2_MUSL_COMPATIBILITY.md) | Technical assessment: ROS2 on Alpine |
| [docs/globe-interface/GLOBE_INTERFACE_DESIGN.md](docs/globe-interface/GLOBE_INTERFACE_DESIGN.md) | Globe interface design document |
| [docs/globe-interface/ntarios-globe.html](docs/globe-interface/ntarios-globe.html) | Interactive globe prototype (open in browser) |
| [CHANGELOG.md](CHANGELOG.md) | Version history (v1.0 → v1.5) |

---

## Services Layer

NTARI OS implements network services as composable ROS2 node packages. Each
service is auditable, replaceable, and visible in the DDS computation graph.

**Core (all deployments):** DNS (dnsmasq) · DHCP (Kea) · NTP (Chrony) ·
Web (Caddy) · Cache (Redis) · Containers (Podman)

**Cooperative:** VPN/Federation (WireGuard) · Identity (FreeIPA) ·
Files (Samba/NFS)

**Community (optional):** Chat (Matrix) · VoIP (FreeSWITCH) · Mail (Postfix) ·
Backup (rsync) · Media (Jellyfin)

**Legacy:** RADIUS/AAA (SoHoLINK) — retained for 802.1X/Captive Portal compatibility

---

## Technical Stack

| Component | Choice | Rationale |
|---|---|---|
| Base OS | Alpine Linux 3.23 | Minimal, secure, musl-based, edge-deployable |
| Init | OpenRC | Auditable, DDS-first boot sequence |
| Middleware | ROS2 Jazzy (LTS) | DDS graph, peer discovery, QoS |
| DDS | Cyclone DDS (EPL-2.0) | C-based, musl-compatible, no corporate owner |
| VPN | WireGuard | In-kernel, minimal, auditable |
| Identity | FreeIPA | Open source, Kerberos, cross-coop federation |
| Chat | Matrix/Synapse | Federated, AGPL-3.0 |
| Media | Jellyfin | AGPL-3.0 (vs proprietary Plex) |

---

## Contributing

NTARI OS is built for and by cooperative communities. Contributions welcome.

### Areas of Need
- **Live validation** — Alpine 3.23 deployment on x86_64 and Raspberry Pi 4;
  smoke testing all 8 service nodes and globe interface
- **Hardware detection** — `ntari-hw-profile` implementation (Phase 10)
- **Contribution policy UI** — `ntari-node-policy` guided setup (Phase 10)
- **LBTAS-NIM** — behavioral scoring engine, nftables collector (Phase 13)
- **Globe interface** — Three.js migration for >80 node deployments
- **Documentation** — cooperative deployment guide, troubleshooting

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Submit a pull request

All contributions must be licensed AGPL-3.0 or compatible.

---

## Support

- **GitHub Issues:** https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os/issues
- **Email:** contact@ntari.org

---

## License

**AGPL-3.0** — See LICENSE file for details.

The AGPL-3.0 license requires that modifications to NTARI OS be shared when
the software is deployed as a network service. This is intentional: cooperative
infrastructure should remain cooperative.

---

## Acknowledgments

- Built on [Alpine Linux](https://alpinelinux.org/)
- ROS2 on Alpine made possible by [SEQSENSE](https://www.seqsense.org/alpine-ros)
  and the [alpine-ros](https://github.com/alpine-ros/alpine-ros) project
- DDS middleware by [Eclipse Cyclone DDS](https://github.com/eclipse-cyclonedds/cyclonedds)
- Built for the [Network Theory Applied Research Institute](https://ntari.org)

---

**Version:** 2.0-dev
**Last Updated:** 2026-02-27
