"""
NTARI OS — IXP Member Registry: PeeringDB API client (read-only)
packages/ixp-registry/peeringdb_client.py

Fetches ASN metadata and prefix data from the PeeringDB public API.
No API key required for public data.  Rate-limit: no more than 1 req/sec.
"""

import json
import time
import urllib.error
import urllib.request

BASE_URL = "https://www.peeringdb.com/api"
_last_request = 0.0
_MIN_INTERVAL = 1.0  # seconds between requests


def _get(path, params=None):
    global _last_request
    now = time.monotonic()
    wait = _MIN_INTERVAL - (now - _last_request)
    if wait > 0:
        time.sleep(wait)

    url = f"{BASE_URL}/{path}"
    if params:
        query = "&".join(f"{k}={v}" for k, v in params.items())
        url = f"{url}?{query}"

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "NTARI-OS-IXP-Registry/0.1 contact@ntari.org"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            _last_request = time.monotonic()
            return json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"PeeringDB HTTP {exc.code}: {url}") from exc
    except Exception as exc:
        raise RuntimeError(f"PeeringDB fetch failed: {exc}") from exc


def lookup_asn(asn):
    """Return org name, PeeringDB network ID, and policy info for an ASN."""
    data = _get("net", {"asn": asn})
    results = data.get("data", [])
    if not results:
        return None
    net = results[0]
    return {
        "asn": asn,
        "org_name": net.get("name", "Unknown"),
        "peeringdb_id": net.get("id"),
        "policy_general": net.get("policy_general", "unknown"),
        "info_prefixes4": net.get("info_prefixes4", 0),
        "info_prefixes6": net.get("info_prefixes6", 0),
        "website": net.get("website", ""),
    }


def fetch_prefixes(asn):
    """Return list of IPv4 and IPv6 prefixes announced by this ASN via PeeringDB."""
    data = _get("netpfx", {"net__asn": asn})
    prefixes = []
    for entry in data.get("data", []):
        prefixes.append({
            "prefix": entry.get("prefix"),
            "max_length": entry.get("length"),
            "protocol": entry.get("protocol", "IPv4"),
        })
    return prefixes


def fetch_ixp_members(ixp_id):
    """Return all networks peering at a given IXP (by PeeringDB IXP ID)."""
    data = _get("netixlan", {"ixlan__ix": ixp_id})
    members = []
    for entry in data.get("data", []):
        members.append({
            "asn": entry.get("asn"),
            "ipaddr4": entry.get("ipaddr4"),
            "ipaddr6": entry.get("ipaddr6"),
            "speed": entry.get("speed"),
        })
    return members


def sync_member(conn, asn, member_db):
    """Sync one member's org name and prefix policy from PeeringDB."""
    info = lookup_asn(asn)
    if not info:
        return False

    # Update org name in member record
    conn.execute(
        "UPDATE members SET org_name = ?, peeringdb_id = ? WHERE asn = ?",
        (info["org_name"], info["peeringdb_id"], asn)
    )
    conn.commit()

    # Refresh prefixes from PeeringDB
    prefixes = fetch_prefixes(asn)
    member_db.clear_prefixes(conn, asn, source="peeringdb")
    for p in prefixes:
        member_db.upsert_prefix(
            conn, asn, p["prefix"], p.get("max_length"), "peeringdb"
        )
    return True
