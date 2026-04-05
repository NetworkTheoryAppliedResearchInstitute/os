"""
NTARI OS — IXP Fabric: Linux bridge + VLAN filtering backend
packages/ixp-fabric/switch_drivers/netlink.py

Used on physical hardware when OVS is not present.
Implements VLAN-aware Linux bridge via iproute2.
"""

import re
import subprocess


def _ip(*args):
    result = subprocess.run(
        ["ip"] + list(args),
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        raise RuntimeError(f"ip command failed: {result.stderr.strip()}")
    return result.stdout.strip()


def _bridge(*args):
    result = subprocess.run(
        ["bridge"] + list(args),
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        raise RuntimeError(f"bridge command failed: {result.stderr.strip()}")
    return result.stdout.strip()


def available():
    """Always available — Linux bridge is in-kernel."""
    result = subprocess.run(["ip", "link", "help"],
                            capture_output=True, timeout=5)
    return True


def create_bridge(bridge_name, fail_mode=None):
    """Create a VLAN-filtering Linux bridge if it does not exist."""
    existing = _ip("link", "show", "type", "bridge")
    if bridge_name not in existing:
        _ip("link", "add", "name", bridge_name, "type", "bridge",
            "vlan_filtering", "1")
    _ip("link", "set", bridge_name, "up")
    return bridge_name


def add_member_port(bridge_name, port_name, vlan_tag=None):
    """Add a physical port to the bridge with VLAN access mode."""
    # Attach port to bridge
    try:
        _ip("link", "set", port_name, "master", bridge_name)
    except RuntimeError:
        pass  # Already attached
    _ip("link", "set", port_name, "up")

    if vlan_tag is not None:
        # Access port: allow only this VLAN, set PVID
        # Remove default VLAN 1 first
        try:
            _bridge("vlan", "del", "dev", port_name, "vid", "1")
        except RuntimeError:
            pass
        _bridge("vlan", "add", "dev", port_name, "vid", str(vlan_tag),
                "pvid", "untagged")


def remove_member_port(bridge_name, port_name):
    """Detach a port from the bridge and reset its VLAN config."""
    try:
        _ip("link", "set", port_name, "nomaster")
    except RuntimeError:
        pass
    # Restore default VLAN 1
    try:
        _bridge("vlan", "add", "dev", port_name, "vid", "1",
                "pvid", "untagged")
    except RuntimeError:
        pass


def port_list(bridge_name):
    """Return list of ports attached to this bridge with VLAN info."""
    raw = _bridge("vlan", "show", "dev")
    ports = []
    current_port = None
    for line in raw.splitlines():
        # Lines starting without whitespace are port names
        m = re.match(r"^(\S+)\s+(\d+)", line)
        if m:
            current_port = m.group(1)
            vlan = int(m.group(2))
            if current_port != bridge_name:
                ports.append({"port": current_port, "vlan": vlan})
    return ports


def port_stats(port_name):
    """Return tx/rx byte counters via /sys/class/net."""
    def read_counter(name):
        path = f"/sys/class/net/{port_name}/statistics/{name}"
        try:
            with open(path) as f:
                return int(f.read().strip())
        except (FileNotFoundError, ValueError):
            return 0
    return {
        "tx_bytes": read_counter("tx_bytes"),
        "rx_bytes": read_counter("rx_bytes"),
    }
