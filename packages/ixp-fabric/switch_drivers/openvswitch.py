"""
NTARI OS — IXP Fabric: Open vSwitch backend
packages/ixp-fabric/switch_drivers/openvswitch.py

Used when OVS is installed (VM/software testing).
Provides: create_bridge, add_member_port, remove_member_port, port_list.
"""

import subprocess


def _ovs(*args):
    result = subprocess.run(
        ["ovs-vsctl"] + list(args),
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        raise RuntimeError(f"ovs-vsctl failed: {result.stderr.strip()}")
    return result.stdout.strip()


def available():
    """Return True if OVS is installed and the daemon is running."""
    result = subprocess.run(
        ["ovs-vsctl", "show"],
        capture_output=True, timeout=5
    )
    return result.returncode == 0


def create_bridge(bridge_name, fail_mode="standalone"):
    """Create OVS bridge if it does not already exist."""
    existing = _ovs("list-br").splitlines()
    if bridge_name not in existing:
        _ovs("add-br", bridge_name)
        _ovs("set", "bridge", bridge_name, f"fail_mode={fail_mode}")
    return bridge_name


def add_member_port(bridge_name, port_name, vlan_tag=None):
    """Add a port to the OVS bridge, optionally with a VLAN access tag."""
    existing = _ovs("list-ports", bridge_name).splitlines()
    if port_name not in existing:
        _ovs("add-port", bridge_name, port_name)
    if vlan_tag is not None:
        _ovs("set", "port", port_name, f"tag={vlan_tag}")


def remove_member_port(bridge_name, port_name):
    """Remove a port from the OVS bridge and reset it."""
    existing = _ovs("list-ports", bridge_name).splitlines()
    if port_name in existing:
        _ovs("del-port", bridge_name, port_name)
    # Bring the port back up clean
    subprocess.run(["ip", "link", "set", port_name, "up"],
                   capture_output=True)


def port_list(bridge_name):
    """Return list of ports on the bridge with their VLAN tags."""
    ports = _ovs("list-ports", bridge_name).splitlines()
    result = []
    for port in ports:
        try:
            tag = _ovs("get", "port", port, "tag").strip()
            tag = int(tag) if tag and tag != "[]" else None
        except Exception:
            tag = None
        result.append({"port": port, "vlan": tag})
    return result


def port_stats(port_name):
    """Return tx/rx byte counters for a port via OVS interface stats."""
    try:
        raw = _ovs("get", "interface", port_name,
                   "statistics:tx_bytes", "statistics:rx_bytes")
        parts = raw.strip().splitlines()
        tx = int(parts[0]) if parts else 0
        rx = int(parts[1]) if len(parts) > 1 else 0
        return {"tx_bytes": tx, "rx_bytes": rx}
    except Exception:
        return {"tx_bytes": 0, "rx_bytes": 0}
