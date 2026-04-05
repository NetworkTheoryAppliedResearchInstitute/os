"""
NTARI OS — IXP Member Registry: IRR prefix filter generator
packages/ixp-registry/irr_filter_gen.py

Uses bgpq4 to query Internet Routing Registries and generate per-member
FRR prefix-list configs.  Called after each member activation and on a
periodic sync schedule.
"""

import os
import subprocess
import tempfile


FRR_PREFIX_LIST_DIR = "/etc/frr/prefix-lists"
VTYSH = "/usr/bin/vtysh"


def _bgpq4(asn, family=4):
    """
    Run bgpq4 against AS-SET or ASN and return FRR prefix-list text.
    family: 4 (IPv4) or 6 (IPv6)
    """
    flag = "-4" if family == 4 else "-6"
    result = subprocess.run(
        ["bgpq4", flag, "-f", str(asn), f"AS{asn}"],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"bgpq4 failed for AS{asn} (v{family}): {result.stderr.strip()}"
        )
    return result.stdout


def generate_filters(asn, irr_sources=None):
    """
    Generate FRR prefix-list configs for an ASN using bgpq4.
    Writes files to /etc/frr/prefix-lists/AS<ASN>-v4.conf and -v6.conf.
    Returns (v4_path, v6_path).
    """
    os.makedirs(FRR_PREFIX_LIST_DIR, exist_ok=True)
    v4_path = os.path.join(FRR_PREFIX_LIST_DIR, f"AS{asn}-v4.conf")
    v6_path = os.path.join(FRR_PREFIX_LIST_DIR, f"AS{asn}-v6.conf")

    env = os.environ.copy()
    if irr_sources:
        env["IRRD_SOURCES"] = irr_sources

    try:
        v4_content = _bgpq4(asn, family=4)
        with open(v4_path, "w") as f:
            f.write(f"! IRR-generated prefix list for AS{asn} (IPv4)\n")
            f.write(f"! Source: {irr_sources or 'default'}\n")
            f.write(v4_content)
    except Exception as exc:
        # Write a deny-all fallback so FRR doesn't use stale filters
        with open(v4_path, "w") as f:
            f.write(f"! IRR filter generation failed for AS{asn}: {exc}\n")
            f.write(f"ip prefix-list AS{asn}-v4 seq 5 deny 0.0.0.0/0 le 32\n")

    try:
        v6_content = _bgpq4(asn, family=6)
        with open(v6_path, "w") as f:
            f.write(f"! IRR-generated prefix list for AS{asn} (IPv6)\n")
            f.write(f"! Source: {irr_sources or 'default'}\n")
            f.write(v6_content)
    except Exception as exc:
        with open(v6_path, "w") as f:
            f.write(f"! IRR filter generation failed for AS{asn}: {exc}\n")
            f.write(f"ipv6 prefix-list AS{asn}-v6 seq 5 deny ::/0 le 128\n")

    return v4_path, v6_path


def reload_peer_filters(peer_ip):
    """
    Tell FRR to perform a soft inbound reset for a peer so new prefix
    filters take effect without tearing down the BGP session.
    """
    if not os.path.exists(VTYSH):
        return
    subprocess.run(
        [VTYSH, "-c", f"clear ip bgp {peer_ip} soft in"],
        capture_output=True, timeout=10
    )
    subprocess.run(
        [VTYSH, "-c", f"clear ipv6 bgp {peer_ip} soft in"],
        capture_output=True, timeout=10
    )


def remove_filters(asn):
    """Remove prefix list files for a deprovisioned member."""
    for suffix in ("-v4.conf", "-v6.conf"):
        path = os.path.join(FRR_PREFIX_LIST_DIR, f"AS{asn}{suffix}")
        try:
            os.remove(path)
        except FileNotFoundError:
            pass
