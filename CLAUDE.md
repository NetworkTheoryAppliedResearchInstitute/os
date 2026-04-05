# NTARI OS — Claude Code Context

## Project
Custom Alpine Linux 3.23 OS for Network Theory Applied Research Institute.
ROS2 Jazzy + Cyclone DDS as foundational abstraction (not an add-on).
Two build editions: `server` (headless) and `ros2` (Jazzy + Cyclone DDS).

## Phase Status (2026-02-28)
- Phases 1–5 (v1.0): Complete
- Phase 6 (ROS2 middleware): **VALIDATED** — Alpine ROS2 installs to /usr/ros/jazzy (not /opt), Python 3.12 (not 3.11)
- Phase 7 (Services layer): **VALIDATED** — 6/8 services start+healthy; ntari-vpn expected-fail (needs WireGuard config); ntari-identity redesigned (OpenLDAP slapd)
- Phase 8 (Globe interface): **VALIDATED** — WebSocket bridge active at ws://ntari.local/ws/graph; Globe UI moved to SoHoLINK (ui/globe-interface/)
- Phase 9 (Federation): Bridge script + OpenRC service + FEDERATION.md complete; ntari-federation NOT auto-enabled
- Phase 0 (Live Validation): **COMPLETE** — DDS graph live, 9 health topics publishing, WebSocket bridge active
- Phase 10 (Hardware Config): **COMPLETE** — ntari-hw-profile + ntari-node-policy + ntari-modloop implemented
- Phase 11 (Contribution Policy): **COMPLETE** — ntari-scheduler (role assignment → /ntari/scheduler/roles, port 8092)
- Phase 12 (Internet/Broadcast): **COMPLETE** — ntari-wan (DHCP/static WAN + iptables NAT) + ntari-bgp (optional Bird2 BGP, not auto-enabled)
- **Roadmap complete.** LBTAS-NIM behavioral scoring is SoHoLINK-layer scope, not NTARI OS scope.
- **SoHoLINK expanded scope specced (2026-03-01)** — SoHoLINK/docs/ARCHITECTURE.md now covers: Platform Model, Desktop Client (fedaaa-gui), Hardware Contribution Layer (cross-platform), Cooperative Network Client (mDNS discovery + service consumption), LBTAS-NIM.

## Scope Boundary
NTARI OS is an independent OS — not a cooperative cloud platform. SoHoLINK and
similar platforms are downstream projects that run ON NTARI OS. Roadmap ends at
Phase 12. Do not scope-creep into distributed compute, object storage, ML
pipelines, network graph UIs, behavioral scoring, or other SoHoLINK-tier services.

## Key Files
- `build/build-iso.sh` — Main ISO builder (lines ~130–270: mkimage profile heredoc; ~280–700: overlay logic)
- `build/Dockerfile` — Alpine 3.23 build container (must run inside Alpine, not Windows)
- `build/Makefile` — make targets: `iso` (default), `docker-build`, `docker-run`, `vbox-test`, `clean`, `clean-all`; pass `EDITION=ros2` for ROS2 build; Alpine 3.23, server edition default
- `scripts/ntari-init.sh` — First-boot init; edition-aware (server vs ros2)
- `scripts/setup-ros2.sh` — ROS2 APK repo trust + install
- `scripts/ros2-node-health.sh` — Shared health publisher used by all Phase 7+ nodes
- `scripts/ntari-federation.sh` — DDS domain 0 ↔ domain 1 bridge over WireGuard
- `scripts/ntari-hw-profile.sh` — Hardware detection → /ntari/node/capabilities (JSON)
- `scripts/ntari-node-policy.sh` — Python HTTP server; policy UI at /node/policy; port 8091
- `scripts/ntari-scheduler.sh` — Python scheduler daemon; role assignment from policy; UI at /scheduler; port 8092
- `config/services/ros2-domain.initd` — ROS2 daemon; boots before ALL ntari-* services
- `config/services/ntari-modloop.initd` — Sysinit service; fixes Alpine modloop nesting before networking
- `config/services/ntari-*.initd` — One per service node; all follow the same pattern (see below)
  - Each `ntari-*.initd` has a companion `*.confd` for env var overrides (e.g. `ROS_DOMAIN_ID`, interface names) — standard Alpine OpenRC companion files; not listed individually
  - `config/services/chrony.conf` — Chrony config for ntari-ntp; `daemonize no` (OpenRC manages process)
  - `config/network/interfaces` — standard Alpine ifupdown config; eth0 DHCP by default
- `packages/cyclonedds/APKBUILD` — Cyclone DDS with musl thread stack patch
- `packages/cyclonedds/0001-musl-thread-stack-size.patch` — `pthread_attr_setstacksize(4MB)` fix
- `docs/FEDERATION.md` — Federation setup guide and governance
- **Globe UI + WebSocket bridge** — moved to SoHoLINK (`ui/globe-interface/`). NTARI OS exposes the ROS2 DDS graph; visualisation is an application concern.

### Utilities
- `scripts/ntari-admin.sh` — interactive TUI admin menu; baked into ISO overlay; options: restart services, add users, tail logs, apk upgrade, reboot/poweroff
- `scripts/check-updates.sh` — APK update checker; runs max once per 24h; caches result in `/var/cache/ntari/`; logs outdated package count via `logger`; no NTARI-specific dependencies

## Build & Syntax Check
- `sh -n <file>` — POSIX syntax check; works on Windows via Git Bash; validates both `.sh` and `.initd` files
- Build ISO: must run inside Alpine 3.23 Docker container — `build/docker-build.sh` is the Windows wrapper
- `MSYS_NO_PATHCONV=1` required for Docker volume mounts from Windows/Git Bash

## Critical Patterns

### Edit Tool
- **Read before Edit** — Edit tool always requires a prior Read of the file in the same session
- **old_string must be unique** — include enough surrounding context; heredoc content especially needs extra lines
- **Markdown list items** — match `-` exactly (not `--`); a single wrong character causes a mismatch

### build-iso.sh Structure
- Profile heredoc: `create_profile()` function, lines ~130–270; ends with `PROFILE` marker
- Overlay logic: `create_overlay()` function, lines ~280–700
- ros2 edition block: `if [ "$EDITION" = "ros2" ]` around line 468
- Script copy loop: `for script in ntari-admin.sh ntari-init.sh ...` — add new scripts here + add symlink below it
- Phase 7 service loop: `for svc in ntari-dns ntari-ntp ...` — add new services here to auto-install

### Python HTTP Service Pattern (Phases 10–11)
For Python-based HTTP services (ntari-node-policy, ntari-scheduler):
- `command="/usr/bin/python3"`, `command_args="/usr/local/bin/<service>.sh"`, `command_background="yes"`
- Health loop uses `pgrep -f <service>.sh` (NOT `pgrep -x python3` — would match all Python processes)
  → Custom `/bin/sh -c "while pgrep -f ... ; do ros2-node-health publish ... ; sleep N ; done"` via `start-stop-daemon`
- Caddyfile patching in `start_pre()` with `awk` to insert `handle /<path>* { reverse_proxy localhost:<port> }` before closing `}`
  → Guard: `grep -q "reverse_proxy.*<port>"` to skip if already patched (idempotent)
- Ports: ntari-node-policy=8091, ntari-scheduler=8092

### OpenRC initd Pattern (Phases 7–9)
All service initd files follow this structure:
1. Set ROS2 env vars explicitly (OpenRC does NOT source `/etc/profile.d`)
2. `depend()` — `need net ros2-domain` + appropriate `before`/`after` ordering
3. `start_pre()` — write default config if absent, verify binary, validate config syntax
4. `start_post()` — publish initial health to DDS, start `ros2-node-health loop` via `start-stop-daemon`
5. `stop_pre()` — publish `failed` state to DDS, kill health loop pidfile

### ROS2 Env Vars (required in every initd and script that calls ros2)
**NOTE**: Alpine-native ROS2 installs to `/usr/ros/jazzy/` (NOT `/opt/ros/jazzy/`) with Python 3.12 (NOT 3.11).
```sh
export AMENT_PREFIX_PATH="/usr/ros/jazzy"
export LD_LIBRARY_PATH="/usr/ros/jazzy/lib:/usr/ros/jazzy/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="/usr/ros/jazzy/bin:${PATH}"
export PYTHONPATH="/usr/ros/jazzy/lib/python3.12/site-packages${PYTHONPATH:+:$PYTHONPATH}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
export ROS_DISTRO="jazzy"
```

## Service Boot Order
```
sysinit: ntari-modloop   (modloop nesting fix + NIC drivers; before net; all editions)
net → ros2-domain → ntari-ntp → ntari-dhcp → ntari-dns → ntari-cache
    → ntari-vpn → ntari-identity → ntari-files → ntari-hw-profile
    → ntari-node-policy → ntari-scheduler → ntari-web
    → ntari-wan  (after all local services; provides internet + NAT)
```
- `ntari-federation` starts after `ntari-vpn` — manual `rc-update add` only (explicit opt-in)
- `ntari-bgp` starts after `ntari-wan` — manual `rc-update add` only; requires ASN + peer config
- `ntari-modloop` is in sysinit (not default runlevel) — runs on both `server` and `ros2` editions
- `ntari-node-policy` + `ntari-scheduler` run before `ntari-web` to ensure Caddyfile is patched before Caddy starts
- `ntari-scheduler` reads /ntari/node/policy + /ntari/node/capabilities; re-evaluates roles on file mtime change
- `ntari-wan` fails gracefully if no second NIC (eth1) — expected on single-NIC nodes

## DDS Domain Model
- Domain 0: local LAN (multicast) — all ntari-* services publish here
- Domain 1: federation overlay (WireGuard unicast, no multicast) — `ntari-federation` bridge
- `cyclonedds.xml` — domain 0 config (multicast enabled)
- `cyclonedds-federation.xml` — domain 1 config (auto-generated; unicast peers only, bound to `wg-ntari`)

## Known Gotchas
- `$._ntari_base_apks` (dot-underscore) is a silent empty-string bug in shell heredocs — always `$_ntari_base_apks`
- Grep with multi-token alternation patterns can fail silently on Windows paths; use `Read` + line offset instead
- `wc -l` a large file before editing to target the right line range without reading the whole file
- Inline config writing into `start_pre()` rather than a separate function — avoids undefined-function runtime bugs
- `ntari-federation` installs to ISO but is NOT auto-enabled in runlevel; requires WireGuard peer config first
- alpine-ros APK key: `alpine-ros@github.com-5fad27d9.rsa.pub` at `https://packages.alpine-ros.org/`
- Cyclone DDS musl patch target: `src/core/os/src/posix/os_thread_posix.c`, function `create_thread_with_properties()`
- Globe source is tracked at `ui/globe-interface/index.html` — `build-iso.sh` copies from there (`GLOBE_SRC` variable, Phase 8 block). Do not edit the copy in `build-output/`; it is gitignored and will be overwritten on next build.
- `scripts/ntari-cli.sh` was a duplicate of `core/ntari-cli.sh` — removed in commit `d361c74`. Canonical copy is `core/ntari-cli.sh`.

## Phase 0 Validation Findings (2026-02-28)
- **ROS2 install path**: Alpine-native packages install to `/usr/ros/jazzy/` NOT `/opt/ros/jazzy/`; Python 3.12 NOT 3.11
- **Missing package**: `ros-jazzy-rosidl-generator-py` is required for `rclpy` to work (provides `import_type_support`); without it, `rclpy.create_node()` throws `NoTypeSupportImportedException`
- **kanidm not in Alpine 3.23**: `ntari-identity` needs redesign; kanidm is not packaged for Alpine — use OpenLDAP (slapd) instead
- **ros2-domain OpenRC pattern**: `ros2 daemon start` is one-shot (exits after launching daemon) — use custom `start()`/`stop()` functions, NOT `command_background="yes"` which marks it as crashed
- **ntari-cache OpenRC pattern**: Redis config must have `daemonize no` (OpenRC manages the process) and no `pidfile` directive in redis.conf — otherwise pidfiles conflict
- **ntari-dhcp OpenRC pattern**: kea-dhcp4 self-daemonizes; omit `command_background="yes"` and let kea write its own pidfile at `/run/kea/kea-dhcp4.pid`
- **Modloop extra nesting**: Alpine live ISO modloop squashfs has `modules/KVER/` at root; after mounting at `/lib/modules/`, path becomes `/lib/modules/modules/KVER/` — modprobe can't find drivers; fix with bind-mount in ntari-init.sh
- **ntari-vpn expected failure**: WireGuard interface fails on first boot without peer config — this is by design; admin must configure peers manually
- **Caddy startup delay**: Caddy takes ~90s to start when checking for TLS cert; `rc-service ntari-web start` blocks until Caddy is ready — not a bug
