# NTARI OS — IXP Setup Guide

**Phases:** 14 (BGP) → 15 (Fabric) → 16 (Registry) → 17 (Globe) → 18 (Looking Glass) → 19 (Settlement, optional)

This guide walks through deploying a community Internet Exchange Point on a
NTARI OS node. All IXP functionality is additive — existing NTARI OS services
(DNS, DHCP, NTP, etc.) are not modified.

---

## Prerequisites

- NTARI OS with Phase 12 complete (ntari-wan running, real ASN)
- A second or third NIC for the peering LAN (can be a VLAN on the WAN NIC)
- FRRouting (`apk add frr frr-bgpd`) and bgpq4 (`apk add bgpq4`)
- At least one other organization willing to peer with you

## Architecture Overview

```
Member ASes          NTARI IXP Node
 ┌─────┐            ┌──────────────────────────────────────┐
 │AS A │◄──eth2────►│ br-ixp (peering bridge)              │
 └─────┘            │   │                                  │
 ┌─────┐            │   ├── ntari-ixp-bgp  (FRR RS)        │
 │AS B │◄──eth3────►│   ├── ntari-ixp-fabric (VLAN mgmt)   │
 └─────┘            │   ├── ntari-ixp-registry (member DB) │
                    │   ├── ntari-ixp-lg  (looking glass)  │
                    │   └── ntari-ixp-settlement (optional) │
                    │                                      │
                    │  ROS2 DDS graph (domain 0)           │
                    │   /ixp/bgp/peers                     │
                    │   /ixp/fabric/utilization            │
                    │   /ixp/members/list                  │
                    └──────────────────────────────────────┘
```

---

## Step 1 — Configure /etc/ntari/ixp.conf

Copy the template and edit the required fields:

```sh
cp /usr/share/ntari/ixp-bgp/frr.conf.template /etc/frr/frr.conf
cp /etc/conf.d/ixp.conf.example /etc/ntari/ixp.conf   # or create from scratch
```

Minimum required changes in `/etc/ntari/ixp.conf`:

```ini
[ixp]
enabled = true
role = route_server

[bgp]
router_asn = 65000        # your real ASN
ixp_lan_ipv4 = 192.0.2.0/24   # your peering LAN prefix

[fabric]
backend = auto
peering_bridge = br-ixp
```

---

## Step 2 — Enable Phase 14 (BGP Route Server)

```sh
rc-update add ntari-ixp-bgp default
rc-service ntari-ixp-bgp start
```

Verify:
```sh
rc-service ntari-ixp-bgp status
vtysh -c "show bgp summary"
ros2 topic echo /ixp/bgp/health
```

The FRR config template is written to `/etc/frr/frr.conf` on first start.
Edit it to add real peer sessions, then reload:
```sh
vtysh -c "configure terminal" -c "end" -c "write"
# or: rc-service ntari-ixp-bgp reload
```

---

## Step 3 — Enable Phase 15 (Fabric)

```sh
rc-update add ntari-ixp-fabric default
rc-service ntari-ixp-fabric start
```

Verify the peering bridge exists:
```sh
ip link show br-ixp
ros2 topic echo /ixp/fabric/ports
```

---

## Step 4 — Enable Phase 16 (Member Registry)

```sh
rc-update add ntari-ixp-registry default
rc-service ntari-ixp-registry start
```

Add your first member:
```sh
ixp-registry-provision add --asn 64512
ixp-registry-provision activate --asn 64512 --ip4 192.0.2.2 --port eth2
```

Verify:
```sh
ixp-registry-provision list --status active
ros2 topic echo /ixp/members/list
```

---

## Step 5 — Enable Phase 18 (Looking Glass)

```sh
rc-update add ntari-ixp-lg default
rc-service ntari-ixp-lg start
```

The Looking Glass is now available at `http://ntari.local/lg/`.
Caddy is patched automatically to add the `/lg/*` reverse proxy.

---

## Step 6 — Globe IXP Mode (Phase 17)

If the NTARI OS Globe interface is deployed (SoHoLINK layer), include the
IXP extension in the globe's HTML:

```html
<script src="/ui/ixp_topics.js"></script>
```

A mode toggle button appears in the top-right corner of the globe.
Click "IXP Mode" to switch from the cooperative DDS node view to the
BGP peer ASN map.

---

## Step 7 — Lightning Settlement (Phase 19, optional)

Requires SoHoLINK to be running and configured.

```ini
# In /etc/ntari/ixp.conf:
[settlement]
enabled = true
soholink_api = http://localhost:8080
rate_per_gb_sats = 10
```

```sh
rc-update add ntari-ixp-settlement default
rc-service ntari-ixp-settlement start
```

---

## RPKI Setup

Enable RPKI origin validation:

1. Start gortr (included as a dependency):
   ```sh
   rc-service gortr start
   rc-update add gortr default
   ```

2. Set in `/etc/ntari/ixp.conf`:
   ```ini
   [bgp]
   rpki_enabled = true
   rtr_host = 127.0.0.1
   rtr_port = 8282
   ```

3. Uncomment the RPKI block in `/etc/frr/frr.conf` and reload FRR.

---

## Verification checklist

| Check | Command |
|---|---|
| FRR running | `vtysh -c "show bgp summary"` |
| Peering bridge up | `ip link show br-ixp` |
| DDS BGP health | `ros2 topic echo /ixp/bgp/health` |
| DDS member list | `ros2 topic echo /ixp/members/list` |
| Looking Glass | `curl http://localhost:5000/lg/health` |
| Integration test | `sh tests/ixp/test_bgp_node.sh` |

---

## Boot order (IXP services)

```
net → ros2-domain → ntari-wan → ntari-ixp-bgp → ntari-ixp-fabric
    → ntari-ixp-registry → ntari-web → ntari-ixp-lg
    → ntari-ixp-settlement  (optional, requires SoHoLINK)
```

For details on member onboarding, see [IXP_MEMBER_ONBOARDING.md](IXP_MEMBER_ONBOARDING.md).
For day-to-day operations, see [IXP_OPERATIONS.md](IXP_OPERATIONS.md).
