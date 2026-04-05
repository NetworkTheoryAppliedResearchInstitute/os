# NTARI OS — IXP Operations Guide

Day-to-day management of the NTARI IXP route server.

---

## Service Status

```sh
# Check all IXP services
rc-service ntari-ixp-bgp status
rc-service ntari-ixp-fabric status
rc-service ntari-ixp-registry status
rc-service ntari-ixp-lg status

# DDS health topics
ros2 topic echo /ixp/bgp/health
ros2 topic echo /ixp/fabric/health
ros2 topic echo /ixp/registry/health
ros2 topic echo /ixp/lg/health
```

---

## BGP Session Management

### View all sessions
```sh
vtysh -c "show bgp summary"
```

### View routes from a specific peer
```sh
vtysh -c "show ip bgp neighbors 192.0.2.2 received-routes"
```

### Reload FRR config without restart
```sh
vtysh -c "configure terminal" -c "end" -c "write"
# or:
birdc configure   # if using BIRD2 backend
```

### Soft reset a peer (reload filters)
```sh
vtysh -c "clear ip bgp 192.0.2.2 soft in"
```

### Hard reset (tears down session)
```sh
vtysh -c "clear ip bgp 192.0.2.2"
```

---

## Prefix Filter Management

### Regenerate filters for one member
```sh
ixp-registry-provision sync --asn 64512
```

### Regenerate filters for all active members
```sh
ixp-registry-provision sync
```

Filter files live in `/etc/frr/prefix-lists/`:
```sh
ls /etc/frr/prefix-lists/
cat /etc/frr/prefix-lists/AS64512-v4.conf
```

---

## Member Management

### List all members
```sh
ixp-registry-provision list
ixp-registry-provision list --status active
ixp-registry-provision list --status pending
```

### Show member detail
```sh
ixp-registry-provision show --asn 64512
```

### Sync member data from PeeringDB
```sh
ixp-registry-provision sync --asn 64512
ixp-registry-provision sync   # all active members
```

---

## Fabric Management

### View port inventory
```sh
ros2 topic echo /ixp/fabric/ports
```

### View traffic utilization
```sh
ros2 topic echo /ixp/fabric/utilization
```

### Check bridge status
```sh
ip link show br-ixp
bridge vlan show
```

### Add a port manually (if not using auto-provisioning)
Use the provisioning wizard — it calls the fabric node via DDS:
```sh
ixp-registry-provision activate --asn 64512 --ip4 192.0.2.2 --port eth2
```

---

## Looking Glass

Access: `http://ntari.local/lg/`

### API queries
```sh
# BGP summary
curl http://localhost:5000/lg/summary

# Route lookup
curl http://localhost:5000/lg/route/203.0.113.0%2F24

# Peer lookup by ASN
curl http://localhost:5000/lg/peer/64512

# Prefixes from ASN
curl http://localhost:5000/lg/prefixes/64512

# Health check
curl http://localhost:5000/lg/health
```

Rate limit: 10 requests per IP per minute (configurable in `ixp.conf`).

---

## RPKI

### Check RPKI validation status
```sh
vtysh -c "show bgp rpki prefix 203.0.113.0/24"
```

### Restart gortr (RPKI RTR server)
```sh
rc-service gortr restart
```

### Check RTR connection
```sh
vtysh -c "show rpki cache-connection"
vtysh -c "show rpki prefix-table"
```

---

## Logs

```sh
# BGP route server
tail -f /var/log/ntari/ixp-bgp.log

# Fabric node
tail -f /var/log/ntari/ixp-fabric.log

# Member registry
tail -f /var/log/ntari/ixp-registry.log

# Looking glass
tail -f /var/log/ntari/ixp-lg.log

# Settlement (if enabled)
tail -f /var/log/ntari/ixp-settlement.log
```

FRR logs go to syslog: `tail -f /var/log/messages | grep -i bgp`

---

## DDS Graph Reference

| Topic | Publisher | Content |
|---|---|---|
| `/ixp/bgp/peers` | ixp-bgp | JSON: active BGP sessions |
| `/ixp/bgp/prefix_count` | ixp-bgp | Total prefixes in RIB |
| `/ixp/bgp/alerts` | ixp-bgp | Session flaps, prefix violations |
| `/ixp/bgp/health` | ixp-bgp | `healthy` / `degraded` / `failed` |
| `/ixp/fabric/ports` | ixp-fabric | JSON: port inventory + VLANs |
| `/ixp/fabric/utilization` | ixp-fabric | JSON: per-port tx/rx counters |
| `/ixp/fabric/health` | ixp-fabric | `healthy` / `degraded` / `failed` |
| `/ixp/members/list` | ixp-registry | JSON: active member list |
| `/ixp/members/provisioned` | ixp-registry | Fires on member activation |
| `/ixp/registry/health` | ixp-registry | `healthy` / `degraded` / `failed` |
| `/ixp/lg/health` | ixp-lg | `healthy` / `failed` |
| `/ixp/settlement/invoices` | ixp-settlement | JSON: pending Lightning invoices |
| `/ixp/settlement/health` | ixp-settlement | `healthy` / `degraded` / `failed` |

---

## Settlement Operations (Phase 19 only)

### View pending invoices
```sh
ros2 topic echo /ixp/settlement/invoices
```

### View audit ledger
```sh
sqlite3 /var/lib/ntari/ixp/settlement.db \
    "SELECT asn, interval_end, net_gb, amount_sats, status FROM settlement_ledger ORDER BY id DESC LIMIT 20"
```

### Check SoHoLINK payouts
```sh
curl http://localhost:8080/api/revenue/payouts
```

---

## Troubleshooting

### BGP session won't establish
1. Check FRR config syntax: `vtysh -c "show running-config"`
2. Check firewall: `iptables -L INPUT -n | grep 179`
3. Check peering bridge: `ip link show br-ixp`
4. Check IRR filters: `cat /etc/frr/prefix-lists/AS<ASN>-v4.conf`

### Prefix not showing up from peer
1. Verify IRR records exist: `bgpq4 -4 -f <ASN> AS<ASN>`
2. Check prefix-list is not blocking: `vtysh -c "show ip bgp neighbors <peer_ip> received-routes"`
3. Soft reset: `vtysh -c "clear ip bgp <peer_ip> soft in"`

### Looking Glass returns errors
1. Check vtysh is accessible: `vtysh -c "show version"`
2. Check FRR socket: `ls -la /var/run/frr/`
3. Check lg server: `curl http://localhost:5000/lg/health`

### Fabric node fails to start
1. Check bridge tools: `command -v bridge && command -v ip`
2. Check OVS (if used): `ovs-vsctl show`
3. Check IXP config: `grep enabled /etc/ntari/ixp.conf`
