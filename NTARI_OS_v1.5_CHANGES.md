# NTARI OS v1.5 Changes

**Release:** 1.5.0
**Date:** 2026-02-18 (last updated)
**Type:** Major Architectural Expansion

---

## Summary

Version 1.5 represents a major architectural evolution from NTARI OS as a
federated AAA platform (SoHoLINK-centric) to a full **network-first cooperative
operating system** grounded in ROS2 middleware, a graph-native user interface,
a prosumer payment economy, and a cooperative trust/reputation system.

This is not a breaking change to the base Alpine/OpenRC foundation — it is an
architectural expansion. All v1.0 work remains valid and is subsumed into the
new layer model.

---

## Added

### Architectural Concept

- **Network-first OS paradigm formally adopted.** The network communication
  graph is the primary abstraction; local computation is a node within that graph.
- **Four-layer architecture defined:**
  1. **Base Layer** — Hardened Alpine Linux 3.23, OpenRC, network drivers.
  2. **Middleware Layer** — ROS2 (Jazzy LTS) + Cyclone DDS on musl libc.
  3. **Services Layer** — Functional capabilities as composable ROS2 node packages.
  4. **Interface Layer** — Graph-native globe visualization; no desktop environment.

### ROS2 Middleware Integration

- **ROS2 Jazzy** selected as middleware distribution (current LTS).
- **Cyclone DDS** selected as the exclusive DDS implementation (EPL-2.0).
- **Alpine Linux 3.23** selected as base (superseding 3.19 from v1.0).
- **SEQSENSE `aports-ros-experimental`** adopted as basis for NTARI's Alpine ROS2 APK repo.
- **Technical compatibility research** completed — documented in `docs/ROS2_MUSL_COMPATIBILITY.md`.
  - musl thread stack size defaults require targeted Cyclone DDS patch (priority issue).
  - `dlclose()` no-op is a permanent musl limitation; plugin lifecycle must account for this.
  - Python `musllinux` wheel ecosystem incomplete; source compilation required.

### Filesystem Policy (§3.5)

- **NTFS removed as default.** Available as mount-only interoperability option only.
- **Btrfs** (zstd compression, level 3) — default for x86_64 and ARM64 data volumes.
  - Transparent compression = direct revenue multiplier (billing on logical bytes).
  - Subvolumes: `@root`, `@varntari`, `@coopstorage`, `@snapshots` with qgroup quotas.
  - Copy-on-Write protects payment database on power loss.
- **F2FS** — default for flash boot volumes (Raspberry Pi SD card / eMMC).
- **ZFS** — opt-in for research/NAS nodes (dedup, ARC cache, large pool management).

### Services Layer — Core Tier

| ROS2 Node | Implementation | Notes |
|---|---|---|
| `ntari_dns_node` | dnsmasq | Local mesh-aware DNS |
| `ntari_dhcp_node` | Kea DHCP | Dynamic IP assignment |
| `ntari_ntp_node` | Chrony | Time sync |
| `ntari_web_node` | Caddy | Globe interface + HTTPS |
| `ntari_cache_node` | Redis | Session and data cache |
| `ntari_container_node` | Podman/LXC | Rootless OCI containers |
| `ntari_monitor_node` | custom (procfs) | Resource telemetry → Globe overlay (§6.7) |
| `ntari_clipboard_node` | custom | Cooperative network clipboard (§5.9) |
| `ntari_lbtas_node` | LBTAS Go binary | Transaction reputation scoring (§5.11) |

### Services Layer — High Priority Tier

| ROS2 Node | Implementation | Notes |
|---|---|---|
| `ntari_vpn_node` | WireGuard | VPN + federation transport |
| `ntari_identity_node` | FreeIPA | Kerberos, LDAP, cross-coop identity |
| `ntari_files_node` | Samba/NFS | Shared file storage |
| `ntari_payment_node` | LNbits + Cyclos CE | Payment settlement + escrow (§5.7) |
| `ntari_bastion_node` | OpenSSH ProxyJump | Zero-trust jump server (§5.8) |
| `ntari_failover_node` | CRIU + custom | Process migration, standby market (§5.10) |

### Services Layer — Community Tier

| ROS2 Node | Implementation | Notes |
|---|---|---|
| `ntari_chat_node` | Matrix (Synapse) | Federated chat |
| `ntari_voip_node` | FreeSWITCH | SIP/VoIP |
| `ntari_mail_node` | Postfix + Dovecot | Full mail stack |
| `ntari_backup_node` | rsync + Bacula | Cooperative backup |
| `ntari_media_node` | Jellyfin | AGPL-3.0 media server |

### New Nodes — This Session (2026-02-18)

| ROS2 Node | Section | Purpose |
|---|---|---|
| `ntari_snapshot_node` | §5.12 | Btrfs pre-op snapshots, retention, boot rollback, cooperative witness sync |
| `ntari_witness_node` | §5.13 | Snapshot hosting + LBTAS dispute arbitration (dual revenue) |

### Payment & Escrow (§5.7)

- **LNbits** (MIT) — Lightning micropayments with HODL invoice escrow (cryptographic hold).
- **Cyclos Community Edition** (AGPL-3.0) — Native fiat/credit escrow, cooperative banking model.
- **GNU Taler** (GPL-3.0+) — Optional Layer 3 privacy e-cash; deferred pending musl validation.
- **5-layer Atomic Escrow Safety** — protocol-level cryptographic hold, ROS2 lifecycle
  block, PostgreSQL WAL, AppArmor deletion protection, watchdog Globe alert.
- **Compression billing credit** — operators billed on logical bytes; Btrfs compression
  ratio is a direct revenue multiplier.

### LBTAS Reputation System (§5.11)

- **Source**: `https://github.com/NTARI-RAND/Leveson-Based-Trade-Assessment-Scale`
- **License**: AGPL-3.0 — perfect match.
- **Scale**: −1 to +4 (No Trust → Cynical → Basic Promise → Satisfaction → No Negative Consequences → Delight).
- **Bidirectional** — every transaction rates both producer AND consumer.
- **Auto-rated** from telemetry (monitor, failover, payment nodes) — no manual input required.
- **Pricing multiplier**: Delight-tier ×1.30 → No-Trust suspended from market.
- **Go implementation** selected for ROS2 wrapper — musl-compatible single binary.
- **Recency weighting**: last 30 days = 3× weight.

### Failover & Process Migration (§5.10)

- **CRIU** (Apache-2.0) — Checkpoint/Restore In Userspace; process snapshot + migration.
- **4 SLA tiers**: Best Effort (+5%), Standard (+15%, <30s), Hot (+35%, <5s), Mirror (+80%, <500ms).
- **Standby market** — idle nodes earn NTARI_CREDITS by holding live checkpoints.
- **SLA bond** — standby node puts credits in escrow; penalty paid to consumer if SLA missed.
- **Per-resource failover mechanisms**: CRIU (compute), shadow pages (RAM), WireGuard peer
  failover (relay), Btrfs send/receive (storage), buffer replay (streams).

### Snapshot & Restore (§5.12)

- **Pre-operation auto-snapshot** before every APK install/upgrade, service config change,
  governance vote execution.
- **Boot-time rollback menu** — numbered list of restore points when boot fails.
- **Retention policy**: 10 pre-op, 7 daily, 4 weekly, 3 monthly.
- **Cooperative witness sync** — daily snapshot shipped via `btrfs send | receive` over
  WireGuard to a designated witness node; enables restoration after physical disk failure.

### Witness Node (§5.13)

- **Dual revenue**: snapshot hosting fees + dispute arbitration fees.
- **Dispute lifecycle**: FILED → QUEUED → CLAIMED → EVIDENCE → DELIBERATION → DECIDED → [APPEAL] → CLOSED.
- **Fee budget Phase 1**: `max(0.5cr, 2% × transaction_value)`.
- **Fee budget Phase 2**: historical calibration — `arbitrator_cost × (1 + frivolous_rate × 2.0)`.
- **System dispute reserve**: 0.1% per-transaction levy; injured party pays nothing for redress.
- **Full Witness Dashboard** (§5.13.4) — dispute queue, evidence view, earnings ledger.

### Globe Interface (§6.x)

- **Graph-native globe interface designed and prototyped.**
- **Node performance monitoring overlay** (§6.7) — resmon-style hover panel:
  CPU/GPU/RAM/Disk/Network/Escrow/LBTAS/Failover tier — all user-configurable.
- **EEG-style sparklines** for CPU and GPU (30-second scrolling history).
- **LBTAS color tints** on node dots — gold (Delight), red pulse (No-Trust) — visible without hover.
- **Performance threshold glow** — nodes turn amber/red at 61%/86% utilization.
- **Globe Admin view** (§6.7.5) — resmon.exe-style multi-panel with tabs:
  Globe / Admin / Processes / Federation / Payment / LBTAS / Failover / Snapshots / Witness.
- **Globe Event Feed** (§6.7.6) — live scrolling verbose status panel; filterable,
  pausable, click-to-select-node; mirrors `/var/log/ntari/events.log`.

### Verbose Status Standard (§5.1 + Appendix 14.5)

- **All nodes must publish verbose status** conforming to the format:
  `[HH:MM:SS] <node> <STATE> <action> — <key:value ...>`
- **6 STATE values**: `ACTIVE | PENDING | COMPLETE | WARN | ERROR | RECOVER`
- **New `/ntari/<service>/event` topic** — fires immediately on any state transition.
- **Appendix 14.5** — complete ACTION verb reference for all 24 nodes.
- **Verbose boot sequence** — every `ntari-init` step prints a conforming status line.

### Cooperative Network Clipboard (§5.9)

- Cross-node clipboard — push entries to other cooperative nodes; Globe arc animation confirms.
- 500-entry persistent history; accessibility-first (screen reader, keyboard-only, high-contrast).
- SQLCipher AES-256 at rest; sensitive-mode auto-clears after 60 seconds.

### Bastion / Jump Node (§5.8)

- SSH `ProxyJump` — no external connection reaches member node SSH ports directly.
- FreeIPA Kerberos auth; full audit log (AppArmor append-only); DDS-graph-aware session blocking.
- Active sessions visible in Globe as dashed orange edges.

---

## Changed

- **Alpine Linux:** 3.19 → **3.23**
- **Federation transport:** libp2p/DHT → **WireGuard + DDS domain bridging**
- **Default filesystem:** (unspecified) → **Btrfs** (zstd, subvolumes, qgroups)
- **Payment stack:** unimplemented → **LNbits + Cyclos CE** (dual layer)
- **Payment node label in tables:** "GNU Taler + BTCPay" → **"LNbits + Cyclos CE"**
- **§5.1 Design Contract:** added verbose status format requirement and `event` topic
- **§3 Base Layer APK list:** added `btrfs-progs`, `f2fs-tools`, `cryptsetup`, `criu`, `postgresql16`
- **Globe hover:** "no tooltip" → **performance overlay panel (§6.7)**
- **Globe Admin tabs:** 5 tabs → **9 tabs** (added LBTAS, Failover, Snapshots, Witness)
- **System Principle 7:** updated to include LBTAS as governance enforcement mechanism

---

## Deprecated

- **libp2p as primary federation transport** — superseded by WireGuard + DDS domain bridging.
- **NTFS as any default or recommended format** — mount-only interoperability only.
- **GNU Taler as primary payment layer** — demoted to optional Layer 3; LNbits + Cyclos CE are primary.
- **BTCPay Server** — replaced by LNbits as Lightning layer (cleaner HODL escrow, lighter footprint).

---

## Known Limitations (Technical Debt)

| Item | Severity | Status | Resolution Path |
|---|---|---|---|
| musl thread stack defaults (128 KB) | High | Open | Patch Cyclone DDS thread spawning |
| `dlclose()` no-op in musl | Medium | Open | Plugin lifecycle design |
| Python `musllinux` wheel gaps | Medium | Open | Contribute upstream / compile from source |
| Globe at >80 nodes | Medium | Deferred | Three.js migration (v1.6+) |
| SEQSENSE aports dependency | High | Open | Fork as NTARI-maintained repo |
| No live ROS2 → globe bridge | High | Planned | WebSocket bridge node (v1.6) |
| GNU Taler musl compatibility | Medium | Unvalidated | Test C exchange daemon on Alpine 3.23 |
| ZFS CDDL license | Low | Open | Advisory note; ships via `edge/testing` |
| Cyclos CE JVM in Podman | Low | Unvalidated | Test on Raspberry Pi 4 (may be too heavy) |

---

*See also: `NTARI_OS_Specification_v1.5.txt` for full specification (2,906 lines, 24 nodes).*
*See `CHANGELOG.md` for complete version history.*
*See `Leveson-Based-Trade-Assessment-Scale/` for LBTAS source repository.*
