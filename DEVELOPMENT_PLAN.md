# NTARI OS — Development Plan

**Network Theory Applied Research Institute Operating System**
*A Network-First Cooperative Infrastructure OS*

**Version:** 2.0-dev
**Date:** 2026-02-27
**License:** AGPL-3.0

---

## What NTARI OS Is

NTARI OS is an independent operating system for cooperative networking
infrastructure. It runs on cooperative hardware nodes, configures them for
network participation, provides core networking services, and makes the
cooperative mesh visible and auditable.

**NTARI OS scope:**
- OS layer, hardware configuration, cooperative networking services
- Behavioral security (LBTAS-NIM)
- Globe network visualization
- Inter-cooperative federation

**Not NTARI OS scope:**
- Distributed cloud services (compute clusters, object storage, ML pipelines)
- Those are downstream projects (e.g. SoHoLINK) that deploy on NTARI OS nodes.
  NTARI OS is the OS they run on — not the platform itself.

---

## Current State (2026-02-27)

Phases 1–9 are code-complete and syntactically validated. No production
deployment exists yet. Live Alpine validation (Phase 0) is the only gate
before Phase 10 development begins.

| Phase | Description | Status |
|---|---|---|
| 1–5 | Foundation, hardening, build system, SoHoLINK v1.0 | ✅ Complete |
| 6 | ROS2 Jazzy + Cyclone DDS middleware | ✅ Code complete |
| 7 | Services layer — 8 nodes (dns/ntp/web/cache/dhcp/vpn/identity/files) | ✅ Code complete |
| 8 | Globe interface + WebSocket bridge | ✅ Code complete |
| 9 | WireGuard + DDS federation | ✅ Code complete (opt-in) |
| **0** | **Live validation — current gate** | **⚠️ In progress** |
| 10 | Hardware detection + easy configuration | 📋 Planned |
| 11 | Contribution policy model + node role assignment | 📋 Planned |
| 12 | Internet/broadcast configuration | 📋 Planned |
| 13 | LBTAS-NIM behavioral security | 📋 Planned |

---

## Phase 0 — Live Validation

**Gate for all further development. Nothing else starts until this passes.**

### Objective

Boot a working NTARI OS node in a live Alpine 3.23 environment. Confirm the
full Phase 6–9 stack operates correctly.

### Steps

**1. Build environment**
```sh
MSYS_NO_PATHCONV=1 docker build -t ntari-build build/
```

**2. Build ISO (ros2 edition)**
```sh
./build/docker-build.sh ros2
# Output: build-output/ntari-os-2.0.0-x86_64.iso
```

**3. Boot in QEMU**
```sh
qemu-system-x86_64 -m 2048 -cdrom build-output/ntari-os-*.iso -boot d
```

**4. Validation checklist**
- [ ] OpenRC boots without errors
- [ ] `ros2-domain` service starts; DDS domain 0 initialises
- [ ] All 8 `ntari-*` service nodes reach `started` state
- [ ] `ros2 node list` shows all nodes in the graph
- [ ] Globe interface loads at `http://ntari.local`
- [ ] Live DDS data populates globe (nodes, edges, health states)
- [ ] `ntari-federation` opt-in flow works with a test WireGuard config

### Pass criteria

All checklist items pass on a clean boot from the built ISO.

---

## Phase 10 — Hardware Detection + Easy Configuration

**Objective:** When hardware is connected, NTARI OS detects its capabilities
and presents a simple setup. No technical expertise required beyond answering
"what are you willing to share with the cooperative?"

### `ntari-hw-profile` (new OpenRC service)

Runs before `ntari-init`. Detects and records:

| Hardware | Detected properties |
|---|---|
| Network interfaces | Count, type (Ethernet/WiFi/Cellular), max speed |
| Memory | Total RAM capacity |
| CPU | Core count, architecture, clock speed |
| Storage | Device count, capacity per device, type (SSD/HDD/NVMe) |
| GPU | Presence, VRAM (if present) |

- Writes `/etc/ntari/hardware.conf`
- Publishes to `/ntari/node/capabilities` (DDS latched topic)

### `ntari-node-policy` (first-boot guided setup)

A 2-minute checklist. Five policy dimensions:

| Dimension | Question | Default |
|---|---|---|
| Networking | Route cooperative traffic? | yes, 100 Mbps cap |
| Storage | Contribute disk space? | no |
| Compute | Run containers/VMs? | no |
| GPU | Offer GPU workloads? | no |
| Uptime | Availability commitment | always |

- Writes `/etc/ntari/policy.conf` (signed with node's ed25519 key)
- Publishes to `/ntari/node/policy` (DDS latched topic)
- Live reload without restart: `rc-service ntari-node-policy reload`

### Policy schema

```sh
POLICY_NETWORKING=yes
POLICY_NETWORKING_BW_CAP=100mbps
POLICY_STORAGE=no
POLICY_STORAGE_CAP_GB=0
POLICY_STORAGE_TIER=hot
POLICY_COMPUTE=no
POLICY_GPU=no
POLICY_UPTIME=always          # or schedule:HH:MM-HH:MM
POLICY_VERSION=1
POLICY_SIGNED=<ed25519 sig>   # node signs its own policy
```

### Globe UI extension

- Node detail panel shows hardware capabilities + declared policy
- Policy limits visible in real-time via DDS

---

## Phase 11 — Contribution Policy + Node Role Assignment

**Objective:** Within a member's declared policy, the cooperative mesh assigns
node roles and auto-configures the appropriate services.

### `ntari-scheduler` (new DDS node, runs on hub nodes)

- Subscribes to `/ntari/node/capabilities` + `/ntari/node/policy` from all peers
- Reads cooperative demand from `/ntari/cooperative/demand`
- Assigns roles within policy limits only — never exceeds declared constraints
- Publishes assignments to `/ntari/node/assignment`

### Node roles

| Role | Trigger conditions | Auto-deployed services |
|---|---|---|
| `router` | 2+ NICs, `POLICY_NETWORKING=yes` | Full Phase 7 stack |
| `server` | `POLICY_COMPUTE=yes` | Subset of Phase 7 |
| `edge` | ARM64 or <2 GB RAM | Minimal — mesh relay only |
| `hub` | router + server capabilities | Full stack + scheduler |

A node holds exactly one role at a time. Role is published to DDS and
displayed on the globe.

### Globe UI extension

- Node role badge on globe visualization
- Scheduler assignment panel (hub nodes only)
- Per-node utilization vs. policy limit display

---

## Phase 12 — Internet/Broadcast Configuration

**Objective:** A cooperative node facing the internet can be configured
simply — WAN interface, NAT, routing. No networking expertise required.

### `ntari-wan` (new OpenRC service)

- Detects which NIC faces the internet (or prompts if ambiguous)
- Configures WAN interface via DHCP or static IP
- Manages NAT (`iptables MASQUERADE` for LAN → WAN)
- Validates upstream ISP connectivity after setup
- Publishes `/ntari/node/internet` to DDS (is this node internet-facing?)

### `ntari-bgp` (optional, major nodes)

- BIRD2 BGP daemon for IXP participation
- Anycast prefix advertisement (DNS/CDN nodes)
- Cooperative BGP peer registry via DDS topics

### Globe UI extension

- Internet-facing nodes visually distinct on globe
- WAN latency displayed alongside LAN latency

---

## Phase 13 — LBTAS-NIM Behavioral Security

**Objective:** Implement the Leveson-Based Trade Assessment Scale —
Network Infrastructure Manager (LBTAS-NIM). Continuous behavioral scoring
of network devices, graduated automated response, and full subscriber
transparency and contestability.

Reference: `docs/LBTAS-NIM.md` (specification document)

### Architecture

```
Network traffic
      │
      ▼
ntari-nim-collector
  nftables/conntrack → /ntari/nim/flows (DDS)
      │
      ▼
ntari-nim-scorer
  4-dimension LBTAS scoring
  Trajectory-weighted aggregates
  → /ntari/nim/<device_id>/score
  → /ntari/nim/<device_id>/trajectory
      │
      ├──→ ntari-nim-enforcer
      │      Graduated iptables/tc response:
      │        Score 0  (Cynical)      → tc rate limit + subscriber alert
      │        Trending -1             → partial isolation
      │        Confirmed -1            → full isolation + human review flag
      │        Score recovers          → automatic rule removal (reversible)
      │
      └──→ ntari-nim-ai  (Ollama — local LLM)
             Communication tool only.
             Receives structured anomaly report from scorer.
             Produces plain-language remediation guidance for subscriber.
             Has no role in scoring or enforcement decisions.
```

### Four scoring dimensions

| Dimension | Measures |
|---|---|
| Reliability | Connection pattern consistency with declared device role |
| Compliance | Rate limit adherence, protocol standards conformance |
| Integrity | Absence of probing, spoofing, port scanning |
| Reciprocity | Bandwidth consumption vs. contribution to mesh health |

### Six-point scale

| Score | Label | Automated response |
|---|---|---|
| +4 | Delight | None — proactively supports network health |
| +3 | No Negative Consequences | None — target steady state |
| +2 | Basic Satisfaction | None — minor self-correcting deviations |
| +1 | Basic Promise | Increased monitoring only |
| 0 | Cynical Satisfaction | Rate limit + subscriber notification |
| -1 | No Trust | Partial/full isolation + human review flag |

### Globe UI extension

- Per-device LBTAS score ring on node visualization
- Score history panel per device
- Subscriber contestation interface (member can dispute automated responses)
- Active graduated responses shown with plain-language explanation (from nim-ai)

### Calibration note

The behavioral rubric (what signals map to which scale levels) requires
empirical validation against real traffic. Phase 13 ships with conservative
initial thresholds. Rubric calibration is an ongoing community process,
not a prerequisite for deployment.

---

## Dependency Order

```
Phase 0   Live validation
    │
    ├── Phase 10  Hardware detection + easy config
    │       │
    │       ├── Phase 11  Contribution policy + role assignment
    │       │
    │       └── Phase 12  Internet/broadcast configuration
    │
    └── Phase 13  LBTAS-NIM  (parallel with 10–12 after Phase 0)
```

---

## Key Files

| File | Purpose |
|---|---|
| `build/build-iso.sh` | Main ISO builder (948 lines) |
| `build/Dockerfile` | Alpine 3.23 build container |
| `build/docker-build.sh` | Windows wrapper for Docker build |
| `scripts/ntari-init.sh` | First-boot init, edition-aware |
| `scripts/setup-ros2.sh` | ROS2 APK repo trust + install |
| `scripts/ros2-node-health.sh` | Shared DDS health publisher |
| `scripts/ntari-globe-bridge.sh` | WebSocket bridge: DDS → browser |
| `scripts/ntari-federation.sh` | DDS domain 0 ↔ domain 1 bridge |
| `config/services/ros2-domain.initd` | ROS2 OpenRC service |
| `config/services/ntari-*.initd` | Phase 7–9 service nodes |
| `packages/cyclonedds/APKBUILD` | Cyclone DDS with musl patch |
| `docs/globe-interface/ntarios-globe.html` | Globe UI (1366 lines) |
| `docs/ARCHITECTURE.md` | Full system architecture |
| `docs/FEDERATION.md` | Federation setup and governance |
| `docs/LBTAS-NIM.md` | Behavioral security specification (Phase 13) |

---

*NTARI OS is licensed AGPL-3.0.*
*Maintained by the Network Theory Applied Research Institute — https://ntari.org*
