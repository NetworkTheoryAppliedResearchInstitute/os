# NTARI OS — Cooperative Federation

**Phase 9: Inter-Cooperative Network Graph Federation**

This document covers the architecture, setup procedure, and governance model
for connecting two or more NTARI OS cooperative deployments into a federated
network graph.

---

## Overview

Each NTARI OS deployment maintains a **local DDS domain (domain 0)** on its
LAN using multicast discovery. Services publish health and status topics into
this domain; the globe interface visualizes it.

Federation extends this to a **cross-cooperative graph**: each cooperative's
services become visible as a subgraph in every other cooperative's globe
interface, connected by a WireGuard overlay network.

```
Cooperative A (domain 0, LAN)          Cooperative B (domain 0, LAN)
  /ntari/dns/health                       /ntari/dns/health
  /ntari/ntp/health          WireGuard    /ntari/ntp/health
  /ntari/web/health  ═══════════════════  /ntari/web/health
  ...                  tunnel             ...
         │                                        │
  Domain 1 (federation)              Domain 1 (federation)
  /ntari/cooperative/<uuid-A>/*       /ntari/cooperative/<uuid-B>/*

  Globe shows both:
    ● Local nodes (domain 0)
    ○ Peer nodes  (/ntari/peers/<uuid-B>/*)
```

---

## Architecture

### Domain model

| Domain | Purpose | Transport | Discovery |
|--------|---------|-----------|-----------|
| 0 | Local cooperative services | LAN multicast | Cyclone DDS multicast |
| 1 | Federation overlay | WireGuard unicast | Cyclone DDS static peers |

Domain 1 uses a separate `cyclonedds-federation.xml` with:
- Multicast **disabled** (WireGuard is point-to-point)
- Peers are **explicit WireGuard overlay IPs** (10.99.0.x/24)
- Interface bound to `wg-ntari` only

### Topic namespace

Topics are bridged between domains with namespace translation:

| Direction | Local topic | Federation topic |
|-----------|-------------|-----------------|
| Outbound (local → fed) | `/ntari/<svc>/health` | `/ntari/cooperative/<uuid>/<svc>/health` |
| Inbound (fed → local) | `/ntari/peers/<uuid>/<svc>/health` | `/ntari/cooperative/<uuid>/<svc>/health` |

The `<uuid>` is this node's UUID, generated at first boot and stored at
`/var/lib/ntari/identity/node-uuid`.

The globe bridge (Phase 8) on each cooperative reads `/ntari/peers/*` topics
from its local domain 0 and renders peer cooperative nodes distinctly on the
globe (lower opacity, dotted connection lines).

### Services involved

| Service | Role in federation |
|---------|--------------------|
| `ntari-vpn` | WireGuard tunnel — the physical layer |
| `ntari-federation` | DDS bridge — the logic layer |
| `ntari-globe-bridge` | WebSocket streamer — includes peers in globe data |
| `ros2-domain` | Domain 0 daemon (local LAN) |
| `ntari-federation` | Also starts domain 1 daemon (federation overlay) |

---

## Setup

### Prerequisites

Both cooperatives need:
- NTARI OS ros2 edition booted and running
- `ntari-vpn` configured with a WireGuard keypair
- Outbound UDP 51820 reachable between cooperatives (firewall/NAT)
- Synchronized clocks (ntari-ntp / chronyd) — DDS QoS is time-sensitive

### Step 1 — Exchange WireGuard public keys

On each cooperative node, find your WireGuard public key:
```sh
wg show wg-ntari public-key
```

Share this value with the peer cooperative's administrator via a secure
out-of-band channel (Signal, encrypted email, in-person).

### Step 2 — Assign federation overlay IPs

Choose a federation overlay subnet (default: `10.99.0.0/24`).
Assign each cooperative node a unique IP:

| Cooperative | Node | WireGuard IP |
|-------------|------|--------------|
| Coop A | node-1 | 10.99.0.1/24 |
| Coop B | node-1 | 10.99.0.2/24 |
| Coop C | node-1 | 10.99.0.3/24 |

Update `/etc/conf.d/ntari-vpn`:
```sh
NTARI_VPN_SUBNET="10.99.0.0/24"
```

### Step 3 — Configure WireGuard peers

Edit `/etc/ntari/wireguard/wg-ntari.conf` on each node.

**Cooperative A (`10.99.0.1`):**
```ini
[Interface]
PrivateKey = <Coop A private key>
Address = 10.99.0.1/24
ListenPort = 51820

[Peer]
# Cooperative B
PublicKey = <Coop B public key>
Endpoint = coop-b.example.org:51820
AllowedIPs = 10.99.0.2/32
PersistentKeepalive = 25
```

**Cooperative B (`10.99.0.2`):**
```ini
[Interface]
PrivateKey = <Coop B private key>
Address = 10.99.0.2/24
ListenPort = 51820

[Peer]
# Cooperative A
PublicKey = <Coop A public key>
Endpoint = coop-a.example.org:51820
AllowedIPs = 10.99.0.1/32
PersistentKeepalive = 25
```

Restart ntari-vpn on both sides:
```sh
rc-service ntari-vpn restart
```

Verify connectivity:
```sh
ping -c 3 10.99.0.2     # from Coop A → Coop B
wg show wg-ntari        # should show latest handshake within ~30s
```

### Step 4 — Start the federation bridge

```sh
rc-service ntari-federation start
rc-update add ntari-federation default
```

This will:
1. Start a ROS2 daemon on federation domain 1
2. Write `/etc/ntari/cyclonedds-federation.xml` with WireGuard peer IPs
3. Begin bridging `/ntari/*` health topics across the WireGuard tunnel

### Step 5 — Verify federation

Check federation status:
```sh
ntari-federation status
```

Check that peer cooperative topics are visible locally:
```sh
ros2 topic list | grep /ntari/peers/
```

Check that your cooperative's topics are visible from the peer:
```sh
# On the peer cooperative:
export ROS_DOMAIN_ID=1
ros2 topic list | grep /ntari/cooperative/
```

The globe interface at `http://ntari.local` will now show peer cooperative
nodes as distinct visual elements once `/ntari/peers/*` topics appear.

---

## Governance

### Federation is opt-in

No cooperative can join the federation without explicit configuration on
**both sides**. WireGuard requires peer public keys to be added manually;
DDS discovery on domain 1 requires static peer IPs. There is no automatic
discovery across cooperative boundaries.

### What is shared

The federation bridge publishes only:
- `/ntari/<svc>/health` — service health state (healthy/degraded/failed)
- `/ntari/<svc>/status` — service status JSON (includes hostname, UUID, timestamp)

What is **not** shared:
- File contents (ntari-files / Samba shares are not exposed across domains)
- Identity data (Kanidm/FreeIPA user databases remain local)
- DHCP lease data
- Internal application data

### Cooperative UUID

Each NTARI OS node generates a UUID at first boot (`ntari-init.sh`). This UUID:
- Identifies the cooperative in federation namespace: `/ntari/cooperative/<uuid>/`
- Is not secret (it is broadcast on the federation domain)
- Can be regenerated by deleting `/var/lib/ntari/identity/node-uuid` and running `ntari-init`

### Removing a peer cooperative

Remove the `[Peer]` section from `/etc/ntari/wireguard/wg-ntari.conf` and
restart `ntari-vpn`. The federation bridge will stop receiving that peer's
topics within one bridge cycle (default 5s). Topics under `/ntari/peers/<uuid>/`
will vanish from the local domain and disappear from the globe.

---

## Multi-domain Globe Representation

The globe bridge (Phase 8) is federation-aware:

- **Local nodes** (domain 0, `/ntari/*`) — full brightness, white glow
- **Peer cooperative nodes** (`/ntari/peers/<uuid>/*`) — reduced brightness, distinct
  color per cooperative UUID (derived from first 3 bytes of UUID → HSL hue), dotted
  connection lines between cooperatives
- **Federation link node** (`/ntari/federation/health`) — rendered at globe equator,
  connecting local cluster to peer cluster

The globe does not yet show geographic position of peer cooperatives (Phase 10
consideration). Peer nodes are currently placed at the antipodal hemisphere
from the local node cluster.

---

## Troubleshooting

### Federation daemon not starting

```sh
# Check WireGuard is up
ip link show wg-ntari
wg show wg-ntari

# Check ros2 daemon on domain 1
export ROS_DOMAIN_ID=1
ros2 daemon status

# Check logs
tail -50 /var/log/ntari/federation.log
```

### No peer topics visible

```sh
# Verify tunnel has active handshake
wg show wg-ntari latest-handshakes

# Verify peer is running federation bridge
# (Ask peer cooperative to check: rc-service ntari-federation status)

# Verify cyclonedds-federation.xml has correct peer IPs
cat /etc/ntari/cyclonedds-federation.xml | grep Peer
```

### Clock skew warnings

```sh
# Check NTP sync
chronyc tracking
chronyc sources

# Restart ntari-ntp if needed
rc-service ntari-ntp restart
```

### Rebuilding federation config

If the Cyclone DDS federation config has wrong peer IPs (e.g., after adding
more peers):
```sh
rm /etc/ntari/cyclonedds-federation.xml
rc-service ntari-federation restart
# The service will regenerate the config with current WireGuard peer IPs
```

---

## Phase 9 Status

- [x] Architecture defined (domain 0 ↔ domain 1 via WireGuard)
- [x] Federation bridge script (`scripts/ntari-federation.sh`)
- [x] OpenRC service (`config/services/ntari-federation.initd/.confd`)
- [x] Federation Cyclone DDS config (auto-generated at first start)
- [x] Federation governance documentation (this document)
- [ ] Validated with two running NTARI OS nodes
- [ ] Globe multi-cooperative rendering implemented
- [ ] Federation peer discovery UI (see peer cooperative status in admin dashboard)
