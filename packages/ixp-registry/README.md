# ixp-registry — NTARI OS IXP Member Registry

Phase 16 of the NTARI OS IXP Extension.

Manages IXP membership: onboarding, prefix policy via IRR/PeeringDB,
and cross-referencing BGP session state with the member database.

## Files

| File | Purpose |
|---|---|
| `APKBUILD` | Alpine package definition |
| `ros2_registry_node.py` | ROS2 lifecycle node |
| `member_db.py` | SQLite schema and query layer |
| `peeringdb_client.py` | PeeringDB REST API (read-only) |
| `irr_filter_gen.py` | bgpq4 wrapper — generates FRR prefix-list files |
| `provisioning_wizard.py` | CLI: `ixp-registry-provision` |
| `templates/member_welcome.txt` | Welcome message shown on activation |
| `templates/peering_policy.txt.template` | Peering policy document template |

## CLI Usage

```
# Add a new member (fetches org name from PeeringDB automatically)
ixp-registry-provision add --asn 64512

# Add with explicit org name
ixp-registry-provision add --asn 64512 --org "Example Corp"

# Activate (generates IRR filters, updates FRR, fires DDS event)
ixp-registry-provision activate --asn 64512 --ip4 192.0.2.2 --port eth2

# List all active members
ixp-registry-provision list --status active

# Show one member + prefix policy
ixp-registry-provision show --asn 64512

# Sync one member's prefixes from PeeringDB
ixp-registry-provision sync --asn 64512

# Sync all active members
ixp-registry-provision sync
```

## DDS Topics

| Topic | Content |
|---|---|
| `/ixp/members/list` | JSON list of active members |
| `/ixp/members/provisioned` | Fires when a member is activated (consumed by fabric node) |
| `/ixp/registry/health` | `healthy` / `degraded` / `failed` |

## Database schema

```sql
members(id, org_name, asn, peering_ip4, peering_ip6,
        port_id, peeringdb_id, status, joined_at, notes)

prefix_policy(id, asn, prefix, max_length, source, updated_at)
```

Stored at `/var/lib/ntari/ixp/registry.db` (configurable in `ixp.conf`).
