#!/usr/bin/python3
# NTARI OS — BGP State Monitor
# Phase 14: IXP BGP Route Server
#
# Standalone companion to ros2_bgp_node.py.
# Called by the OpenRC initd health loop to publish BGP state to DDS
# without requiring a full ROS2 lifecycle spin.
#
# Usage:
#   bgp_monitor.py [--interval N]
#
# Reads FRR state via vtysh and publishes to:
#   /ixp/bgp/peers
#   /ixp/bgp/prefix_count
#   /ixp/bgp/health

import json
import os
import subprocess
import sys
import time


VTYSH = "/usr/bin/vtysh"
ROS2_PUB = "/usr/local/bin/ros2-node-health"  # existing NTARI health tool


def _vtysh(cmd):
    result = subprocess.run(
        [VTYSH, "-c", cmd],
        capture_output=True, text=True, timeout=10
    )
    return result.stdout if result.returncode == 0 else ""


def _frr_running():
    result = subprocess.run(["pgrep", "-x", "zebra"], capture_output=True)
    return result.returncode == 0


def _peer_count():
    raw = _vtysh("show bgp summary json")
    try:
        data = json.loads(raw)
        peers = data.get("ipv4Unicast", {}).get("peers", {})
        established = sum(
            1 for p in peers.values() if p.get("bgpState") == "Established"
        )
        return len(peers), established
    except (json.JSONDecodeError, KeyError):
        return 0, 0


def publish(service, state, *tags):
    if os.path.isfile(ROS2_PUB) and os.access(ROS2_PUB, os.X_OK):
        subprocess.run(
            [ROS2_PUB, "publish", service, state] + list(tags),
            timeout=5
        )


def run(interval=30):
    while True:
        if not _frr_running():
            publish("bgp", "failed", "reason=frr_not_running")
        else:
            total, established = _peer_count()
            state = "healthy" if established > 0 or total == 0 else "degraded"
            publish(
                "bgp", state,
                f"peers_total={total}",
                f"peers_established={established}",
            )
        time.sleep(interval)


if __name__ == "__main__":
    interval = 30
    if "--interval" in sys.argv:
        try:
            interval = int(sys.argv[sys.argv.index("--interval") + 1])
        except (IndexError, ValueError):
            pass
    run(interval)
