# NTARI OS — Version History Archive

This directory contains historical specification documents and change records
from the pre-v1.5 development phases (v1.0 through v1.4).

For the canonical version history, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Version Timeline

| Version | Date | Key Development |
|---------|------|----------------|
| v1.0 | Early 2026 | Initial concept: cooperative OS, Alpine base, RADIUS/SoHoLINK focus |
| v1.1 | Feb 2026 | Architecture expanded; three-edition model (Server, Desktop, Lite) |
| v1.2 | Feb 2026 | Cooperative economics layer, job marketplace concept, LBTAS reputation |
| v1.3 | Feb 2026 | Democratic governance, P2P networking (libp2p), multi-architecture |
| v1.4 | Feb 16, 2026 | CompTIA A+ alignment; added hardware compatibility, BIOS guides, troubleshooting; 28-month timeline |
| v1.5 | Feb 17, 2026 | **Current.** Network-first OS paradigm; ROS2 Jazzy + Cyclone DDS middleware; globe interface; WireGuard federation |

---

## Key Design Decisions by Version

### v1.0 — Foundation
- Alpine Linux base (3.19)
- SoHoLINK (RADIUS/AAA) as the core identity layer
- OpenRC init system
- Server-only edition

### v1.1 — Three Editions
- Server Edition (~180MB): headless, Raspberry Pi
- Desktop Edition (~1.2GB): XFCE, family/small business
- Lite Edition (~400MB): LXQt, repurposed old hardware
- USB installer concept introduced (Electron + React)

### v1.2 — Cooperative Economics
- Job marketplace (skills + hardware)
- LBTAS (Location-Based Token Accounting System) reputation
- Tiered storage: SQLite / Files / IPFS
- Token payments (v1.1 plan)

### v1.3 — Governance and Federation
- Community voting and policy engine
- P2P networking: libp2p + Kademlia DHT (later superseded)
- Android app in roadmap (Phase 6)
- 24-month original timeline

### v1.4 — CompTIA Alignment (Gap Analysis)
- Added 6 new sections (112 pages): Hardware Compatibility, Troubleshooting,
  BIOS/UEFI Guide, Network Config, Driver Matrix, Dual-Boot
- Adjusted timeline to 28 months (realistic)
- Build environment implemented: Docker-based Alpine ISO builder
- First actual build: 906MB ISO (boot issue documented in QEMU_BOOT_ISSUES.md)

### v1.5 — Network-First OS (Current)
- Architectural inversion: ROS2 DDS graph is the primary abstraction
- Four-layer architecture: Base → Middleware → Services → Interface
- ROS2 Jazzy + Cyclone DDS on Alpine 3.23 (musl libc)
- Services layer: composable ROS2 lifecycle node packages
- Globe interface: live DDS graph visualization (no geography)
- WireGuard federation replaces libp2p/DHT
- AGPL-3.0 throughout

---

## Archived Files

The following files from the pre-v1.5 development sessions are preserved here
for reference. They are **not the canonical specification** — see the current
`docs/ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`, and `CHANGELOG.md` instead.

### Specification Documents
- `NTARI_OS_Specification_v1.1.txt` — Full v1.1 spec text
- `NTARI_OS_Specification_v1.2.txt` — Full v1.2 spec text
- `NTARI_OS_Specification_v1.3.txt` — Full v1.3 spec text
- `NTARI_OS_Specification_v1.4.txt` — Full v1.4 spec text (with CompTIA sections)

### Changelogs and Summaries
- `NTARI_OS_v1.1_CHANGES.md` — v1.0 → v1.1 changes
- `NTARI_OS_v1.2_CHANGES.md` — v1.1 → v1.2 changes
- `NTARI_OS_v1.3_CHANGES.md` — v1.2 → v1.3 changes
- `NTARI_OS_v1.4_CHANGES.md` — v1.3 → v1.4 changes (CompTIA alignment)
- `NTARI_OS_v1.4_SUMMARY.md` — Executive summary of v1.4

### Analysis Documents
- `SPEC_GAP_ANALYSIS.md` — NTARI v1.3 vs CompTIA A+ gap analysis
- `SPEC_GAP_SUMMARY.md` — Summary of gap analysis findings
- `COMPTIA_COMPARISON_ANALYSIS.md` — Detailed CompTIA comparison
- `COMPTIA_SUMMARY.md` — CompTIA alignment summary
- `ROADMAP_v1.4_UPDATES.md` — Timeline adjustments for v1.4
- `v1.4_IMPLEMENTATION_CHECKLIST.md` — Week-by-week v1.4 implementation plan
- `v1.4_FILES_CREATED.md` — Files created in the v1.4 session
- `NTARI_OS_v1.4_NEW_SECTIONS.txt` — Full text of new Sections 13-18

### Development Progress
- `DEVELOPMENT_PROGRESS.md` — Feb 16, 2026 build session progress
- `DEVELOPMENT_STATUS.md` — Project status at v1.4

---

## Source Files (from Build Session)

These files were produced during the Feb 16-17, 2026 build session and have
been integrated into the canonical project structure:

| Original Location | Current Location |
|------------------|-----------------|
| `ntari-os/core/ntari-init.sh` | `scripts/ntari-init.sh` |
| `ntari-os/core/ntari-cli.sh` | `scripts/ntari-cli.sh` |
| `ntari-os/build/build-alpine.sh` | `build/build-alpine.sh` |
| `ntari-os/build/build-iso.sh` | `build/build-iso.sh` (v1.5 supersedes) |
| `ntari-os/build/docker-build.sh` | `build/docker-build.sh` |
| `ntari-os/installer/package.json` | `installer/package.json` |
| `ntari-os/build/build-output/rootfs-server/` | `build/build-output/rootfs-server/` |

---

*Note: The original NTARIOS folder at `C:\Users\Jodson Graves\Documents\NTARIOS\`
has been consolidated into this canonical project folder (`NTARI OS\`).*
