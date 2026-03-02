# NTARI OS — Development Status

**Date:** 2026-02-27
**Version:** 2.0-dev
**Current Phase:** Phase 0 — Live Validation

---

## Summary

All Phase 1–9 code is written and syntactically validated. No production
deployment exists yet. Live Alpine 3.23 validation is the immediate next
step and the gate before any new development begins.

---

## Phase Status

| Phase | Description | Status |
|---|---|---|
| 1–5 | Foundation, hardening, build system, SoHoLINK v1.0 | ✅ Complete |
| 6 | ROS2 Jazzy + Cyclone DDS middleware | ✅ Code complete; awaiting live validation |
| 7 | Services layer — 8 nodes (dns/ntp/web/cache/dhcp/vpn/identity/files) | ✅ Code complete; awaiting live validation |
| 8 | Globe interface + WebSocket bridge | ✅ Code complete; awaiting live validation |
| 9 | WireGuard + DDS federation | ✅ Code complete; awaiting live validation |
| **0** | **Live validation (boot + full stack test)** | **⚠️ Current gate** |
| 10 | Hardware detection + easy configuration | 📋 Planned |
| 11 | Contribution policy model + node role assignment | 📋 Planned |
| 12 | Internet/broadcast configuration | 📋 Planned |
| 13 | LBTAS-NIM behavioral security | 📋 Planned |

---

## What's Built

### Build system (Phases 1–6)

- `build/build-iso.sh` — Alpine mkimage ISO builder, 948 lines, edition-aware
- `build/Dockerfile` — Alpine 3.23 build container
- `build/docker-build.sh` — Windows/Git Bash wrapper (`MSYS_NO_PATHCONV=1`)
- `packages/cyclonedds/APKBUILD` — Cyclone DDS with musl thread stack patch
- `packages/cyclonedds/0001-musl-thread-stack-size.patch`

### Services layer (Phase 7)

Eight OpenRC-managed ROS2 lifecycle nodes, all code-complete:

| Node | Backend | Publishes |
|---|---|---|
| `ntari-dns` | dnsmasq | `/ntari/dns/health`, `/ntari/dns/status` |
| `ntari-ntp` | Chrony | `/ntari/ntp/health`, `/ntari/ntp/status` |
| `ntari-web` | Caddy | `/ntari/web/health`, `/ntari/web/status` |
| `ntari-cache` | Redis | `/ntari/cache/health`, `/ntari/cache/status` |
| `ntari-dhcp` | Kea DHCP | `/ntari/dhcp/health`, `/ntari/dhcp/status` |
| `ntari-vpn` | WireGuard | `/ntari/vpn/health`, `/ntari/vpn/status` |
| `ntari-identity` | FreeIPA | `/ntari/identity/health`, `/ntari/identity/status` |
| `ntari-files` | Samba/NFS | `/ntari/files/health`, `/ntari/files/status` |

Each node follows the shared OpenRC pattern: explicit ROS2 env vars, correct
`depend()` boot ordering, `start_post()` health loop, `stop_pre()` DDS shutdown.

Boot order: `net → ros2-domain → ntari-ntp → ntari-dhcp → ntari-dns →
ntari-cache → ntari-vpn → ntari-identity → ntari-files → ntari-web →
ntari-globe-bridge`

### Globe interface (Phase 8)

- `docs/globe-interface/ntarios-globe.html` — 1366-line single-file Canvas 2D globe
- Live WebSocket bridge (RFC 6455, dual endpoint: Caddy proxy + direct `localhost:9090`)
- Full DDS graph reconciliation: nodes, edges, health states, latency
- Exponential backoff reconnect; graceful demo mode fallback if bridge unavailable
- `scripts/ntari-globe-bridge.sh` — pure POSIX sh WebSocket server (socat + ros2 CLI)
- `config/services/ntari-globe-bridge.initd` — OpenRC service

### Federation (Phase 9)

- `scripts/ntari-federation.sh` — DDS domain 0 ↔ domain 1 bridge over WireGuard
- `config/services/ntari-federation.initd` — OpenRC service
- Installed to ISO but **not auto-enabled** — requires WireGuard peer config first
- `docs/FEDERATION.md` — setup guide and cooperative governance

---

## What's Blocking Production

Single gate: live Alpine 3.23 validation.

| Requirement | Notes |
|---|---|
| Alpine 3.23 Docker container | Build tooling ready (`build/Dockerfile`); not yet executed |
| alpine-ros APK repo accessible | Network dependency during build (`setup-ros2.sh` lines 62–97) |
| QEMU or physical x86_64 hardware | Not yet provisioned for boot test |
| Full stack smoke test | All 8 nodes + globe + DDS graph |

---

## Scope Boundary

NTARI OS is an independent OS. It is not a cloud platform.

SoHoLINK and similar cooperative cloud platforms are downstream projects
that deploy on NTARI OS nodes. They are not phases of NTARI OS. The NTARI OS
roadmap ends at Phase 13 (LBTAS-NIM behavioral security).

---

*Last updated: 2026-02-27*
*Maintained by the Network Theory Applied Research Institute — https://ntari.org*
