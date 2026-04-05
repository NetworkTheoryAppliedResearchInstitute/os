#!/usr/bin/python3
"""
NTARI OS — IXP Member Provisioning Wizard
packages/ixp-registry/provisioning_wizard.py

CLI tool for onboarding new IXP members.
Installed as: /usr/local/bin/ixp-registry-provision

Usage:
  ixp-registry-provision add --asn 64512 --org "Example Corp" [--port eth2]
  ixp-registry-provision activate --asn 64512
  ixp-registry-provision suspend --asn 64512
  ixp-registry-provision list [--status active]
  ixp-registry-provision show --asn 64512
  ixp-registry-provision sync --asn 64512
"""

import argparse
import configparser
import json
import os
import sys

LIB_DIR = "/usr/lib/ntari/ixp-registry"
sys.path.insert(0, LIB_DIR)

import member_db
import peeringdb_client
import irr_filter_gen

IXP_CONF = "/etc/ntari/ixp.conf"


def _load_cfg():
    cfg = configparser.ConfigParser()
    cfg.read(IXP_CONF)
    return cfg


def _open_db(cfg):
    db_path = cfg.get("registry", "db_path",
                      fallback="/var/lib/ntari/ixp/registry.db")
    return member_db.open_db(db_path)


def _irr_sources(cfg):
    return cfg.get("bgp", "irr_sources", fallback=None)


# ── Commands ───────────────────────────────────────────────────────────────────

def cmd_add(args):
    cfg = _load_cfg()
    conn = _open_db(cfg)

    # Try PeeringDB lookup for org name if not provided
    org_name = args.org
    peeringdb_id = None
    if not org_name:
        print(f"Looking up AS{args.asn} on PeeringDB...", flush=True)
        try:
            info = peeringdb_client.lookup_asn(args.asn)
            if info:
                org_name = info["org_name"]
                peeringdb_id = info["peeringdb_id"]
                print(f"Found: {org_name} (PeeringDB ID: {peeringdb_id})")
            else:
                print("Not found on PeeringDB — use --org to set manually")
                sys.exit(1)
        except Exception as exc:
            print(f"PeeringDB lookup failed: {exc}")
            if not org_name:
                print("Use --org to set org name manually")
                sys.exit(1)

    member_db.add_member(conn, args.asn, org_name,
                         peeringdb_id=peeringdb_id,
                         notes=args.notes)
    print(f"Added member: AS{args.asn} — {org_name} (status: pending)")
    print(f"Next: ixp-registry-provision activate --asn {args.asn}")


def cmd_activate(args):
    cfg = _load_cfg()
    conn = _open_db(cfg)
    irr_sources = _irr_sources(cfg)

    member = member_db.get_member(conn, args.asn)
    if not member:
        print(f"Member AS{args.asn} not found — run 'add' first")
        sys.exit(1)

    # Generate IRR filters before activating BGP session
    print(f"Generating IRR prefix filters for AS{args.asn}...")
    try:
        v4, v6 = irr_filter_gen.generate_filters(args.asn, irr_sources)
        print(f"  IPv4 filter: {v4}")
        print(f"  IPv6 filter: {v6}")
    except Exception as exc:
        print(f"  IRR filter generation warning: {exc}")

    member_db.activate_member(
        conn, args.asn,
        peering_ip4=args.ip4,
        peering_ip6=args.ip6,
        port_id=args.port,
    )

    # Reload FRR filters if peer IP is known
    if args.ip4:
        irr_filter_gen.reload_peer_filters(args.ip4)
        print(f"FRR soft-reset for {args.ip4}")

    print(f"Activated AS{args.asn}")

    # Print welcome template
    welcome_path = "/usr/share/ntari/ixp-registry/templates/member_welcome.txt"
    if os.path.exists(welcome_path):
        with open(welcome_path) as f:
            welcome = f.read()
        welcome = welcome.replace("{{ASN}}", str(args.asn))
        welcome = welcome.replace("{{ORG}}", member["org_name"])
        welcome = welcome.replace("{{PEERING_IP4}}", args.ip4 or "TBD")
        print("\n" + "="*60)
        print(welcome)
        print("="*60)


def cmd_suspend(args):
    cfg = _load_cfg()
    conn = _open_db(cfg)
    member_db.suspend_member(conn, args.asn)
    irr_filter_gen.remove_filters(args.asn)
    print(f"Suspended AS{args.asn} — prefix filters removed")


def cmd_list(args):
    cfg = _load_cfg()
    conn = _open_db(cfg)
    members = member_db.list_members(conn, status=args.status)
    if not members:
        print("No members found")
        return
    print(f"{'ASN':<10} {'Org':<40} {'Status':<12} {'Peering IP'}")
    print("-" * 80)
    for m in members:
        print(f"AS{m['asn']:<8} {m['org_name']:<40} {m['status']:<12} "
              f"{m.get('peering_ip4') or '-'}")


def cmd_show(args):
    cfg = _load_cfg()
    conn = _open_db(cfg)
    member = member_db.get_member(conn, args.asn)
    if not member:
        print(f"AS{args.asn} not found")
        sys.exit(1)
    print(json.dumps(member, indent=2, default=str))

    prefixes = member_db.list_prefixes(conn, args.asn)
    if prefixes:
        print(f"\nPrefix policy ({len(prefixes)} entries):")
        for p in prefixes[:20]:
            print(f"  {p['prefix']} (max /{p.get('max_length', '?')}) [{p['source']}]")
        if len(prefixes) > 20:
            print(f"  ... and {len(prefixes) - 20} more")


def cmd_sync(args):
    cfg = _load_cfg()
    conn = _open_db(cfg)

    if args.asn:
        asns = [args.asn]
    else:
        members = member_db.list_members(conn, status="active")
        asns = [m["asn"] for m in members]

    for asn in asns:
        print(f"Syncing AS{asn} from PeeringDB...", end=" ", flush=True)
        try:
            ok = peeringdb_client.sync_member(conn, asn, member_db)
            print("ok" if ok else "not found")
        except Exception as exc:
            print(f"error: {exc}")


# ── Argument parser ────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="ixp-registry-provision",
        description="NTARI OS IXP Member Provisioning Wizard"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_add = sub.add_parser("add", help="Add a new member (status: pending)")
    p_add.add_argument("--asn", type=int, required=True)
    p_add.add_argument("--org", help="Org name (auto-fetched from PeeringDB if omitted)")
    p_add.add_argument("--notes", help="Internal notes")

    p_act = sub.add_parser("activate", help="Activate a pending member")
    p_act.add_argument("--asn", type=int, required=True)
    p_act.add_argument("--ip4", help="Assigned peering IPv4 address")
    p_act.add_argument("--ip6", help="Assigned peering IPv6 address")
    p_act.add_argument("--port", help="Physical port ID (e.g. eth2)")

    p_sus = sub.add_parser("suspend", help="Suspend an active member")
    p_sus.add_argument("--asn", type=int, required=True)

    p_list = sub.add_parser("list", help="List members")
    p_list.add_argument("--status", help="Filter by status (pending/active/suspended)")

    p_show = sub.add_parser("show", help="Show member detail")
    p_show.add_argument("--asn", type=int, required=True)

    p_sync = sub.add_parser("sync", help="Sync from PeeringDB")
    p_sync.add_argument("--asn", type=int, help="Sync one ASN (omit for all active)")

    args = parser.parse_args()
    dispatch = {
        "add": cmd_add,
        "activate": cmd_activate,
        "suspend": cmd_suspend,
        "list": cmd_list,
        "show": cmd_show,
        "sync": cmd_sync,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
