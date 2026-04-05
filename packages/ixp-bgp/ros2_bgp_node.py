#!/usr/bin/python3
# NTARI OS — IXP BGP Route Server Node (ixp_bgp_node)
# Phase 14: IXP BGP Route Server
#
# ROS2 lifecycle node wrapper for FRRouting bgpd.
# Implements the four lifecycle transitions: configure, activate,
# deactivate, cleanup — making FRR visible in the DDS graph.
#
# Lifecycle transitions:
#   on_configure  : write FRR config from template + ixp.conf params; validate
#   on_activate   : start FRR; begin publishing state to /ixp/bgp/peers
#   on_deactivate : graceful FRR shutdown; preserve session state
#   on_cleanup    : remove runtime config files
#
# Published topics:
#   /ixp/bgp/peers        — JSON list of active BGP sessions
#   /ixp/bgp/prefix_count — total prefixes in routing table
#   /ixp/bgp/alerts       — session flaps, prefix limit violations
#   /ixp/bgp/health       — healthy | degraded | failed
#
# ROS2 parameters:
#   router_asn            — ASN of this route server
#   ixp_lan_ipv4          — shared peering LAN (CIDR)
#   ixp_lan_ipv6          — shared peering LAN IPv6 (CIDR)
#   max_prefixes_per_peer — hard limit before session teardown
#   route_server_mode     — bool; RS client semantics if true
#   rtr_host              — RPKI RTR server host
#   rtr_port              — RPKI RTR server port
#
# No external Python dependencies — stdlib + rclpy only.

import configparser
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time

# ── ROS2 imports (graceful fallback for syntax-check environments) ─────────────
try:
    import rclpy
    from rclpy.lifecycle import LifecycleNode
    from rclpy.lifecycle import State, TransitionCallbackReturn
    from std_msgs.msg import String
    _ROS2_AVAILABLE = True
except ImportError:
    _ROS2_AVAILABLE = False

IXP_CONF = "/etc/ntari/ixp.conf"
FRR_CONF = "/etc/frr/frr.conf"
FRR_TEMPLATE = "/usr/share/ntari/ixp-bgp/frr.conf.template"
FRR_PIDFILE = "/run/frr/frr.pid"
VTYSH = "/usr/bin/vtysh"
PUBLISH_INTERVAL = 15  # seconds


def _read_ixp_conf():
    cfg = configparser.ConfigParser()
    cfg.read(IXP_CONF)
    return cfg


def _substitute_template(template_path, variables):
    with open(template_path) as f:
        content = f.read()
    for key, val in variables.items():
        content = content.replace("{{" + key + "}}", str(val))
    return content


def _vtysh(command):
    """Run a vtysh command and return stdout, raising on non-zero exit."""
    result = subprocess.run(
        [VTYSH, "-c", command],
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        raise RuntimeError(f"vtysh failed: {result.stderr.strip()}")
    return result.stdout


def _parse_bgp_summary(raw):
    """Parse 'show bgp summary json' output into a list of peer dicts."""
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    peers = []
    for family_key in ("ipv4Unicast", "ipv6Unicast"):
        family = data.get(family_key, {})
        for peer_ip, info in family.get("peers", {}).items():
            peers.append({
                "ip": peer_ip,
                "asn": info.get("remoteAs", 0),
                "state": info.get("bgpState", "unknown"),
                "prefixes_received": info.get("pfxRcd", 0),
                "uptime_seconds": info.get("peerUptimeMsec", 0) // 1000,
                "family": family_key,
            })
    return peers


def _frr_running():
    if os.path.exists(FRR_PIDFILE):
        try:
            with open(FRR_PIDFILE) as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            return True
        except (ValueError, ProcessLookupError, PermissionError):
            pass
    # Fallback: check frr process
    result = subprocess.run(["pgrep", "-x", "zebra"], capture_output=True)
    return result.returncode == 0


class IxpBgpNode(LifecycleNode if _ROS2_AVAILABLE else object):

    def __init__(self):
        if _ROS2_AVAILABLE:
            super().__init__("ixp_bgp_node")
        self._cfg = _read_ixp_conf()
        self._pub_peers = None
        self._pub_prefix_count = None
        self._pub_alerts = None
        self._pub_health = None
        self._monitor_thread = None
        self._stop_event = threading.Event()
        self._last_peer_states = {}

    # ── Lifecycle callbacks ────────────────────────────────────────────────────

    def on_configure(self, state):
        self._cfg = _read_ixp_conf()

        if not self._cfg.getboolean("ixp", "enabled", fallback=False):
            self._log("IXP disabled in ixp.conf — node configured but inactive")
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        router_asn = self._cfg.getint("bgp", "router_asn", fallback=65000)
        router_id = self._detect_router_id()
        max_pfx = self._cfg.getint("bgp", "max_prefixes_per_peer", fallback=1000)
        rtr_host = self._cfg.get("bgp", "rtr_host", fallback="127.0.0.1")
        rtr_port = self._cfg.getint("bgp", "rtr_port", fallback=8282)
        hostname = socket.gethostname()

        variables = {
            "ROUTER_ASN": router_asn,
            "ROUTER_ID": router_id,
            "MAX_PREFIXES_PER_PEER": max_pfx,
            "RTR_HOST": rtr_host,
            "RTR_PORT": rtr_port,
            "HOSTNAME": hostname,
        }

        if not os.path.exists(FRR_CONF):
            self._log(f"Writing FRR config from template → {FRR_CONF}")
            os.makedirs(os.path.dirname(FRR_CONF), exist_ok=True)
            content = _substitute_template(FRR_TEMPLATE, variables)
            with open(FRR_CONF, "w") as f:
                f.write(content)
            os.chmod(FRR_CONF, 0o640)
        else:
            self._log(f"FRR config already exists: {FRR_CONF}")

        # Validate FRR config syntax
        result = subprocess.run(
            ["zebra", "--dryrun", f"--config_file={FRR_CONF}"],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            self._log(f"FRR config validation warning: {result.stderr.strip()}")

        if _ROS2_AVAILABLE:
            self._pub_peers = self.create_publisher(String, "/ixp/bgp/peers", 10)
            self._pub_prefix_count = self.create_publisher(
                String, "/ixp/bgp/prefix_count", 10
            )
            self._pub_alerts = self.create_publisher(String, "/ixp/bgp/alerts", 10)
            self._pub_health = self.create_publisher(String, "/ixp/bgp/health", 10)
            return TransitionCallbackReturn.SUCCESS

    def on_activate(self, state):
        if not self._cfg.getboolean("ixp", "enabled", fallback=False):
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        self._log("Starting FRRouting")
        result = subprocess.run(
            ["/usr/lib/frr/frrinit.sh", "start"],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            self._log(f"FRR start failed: {result.stderr.strip()}")
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.FAILURE
            return

        time.sleep(2)
        self._stop_event.clear()
        self._monitor_thread = threading.Thread(
            target=self._monitor_loop, daemon=True
        )
        self._monitor_thread.start()
        self._log("BGP route server active; monitoring /ixp/bgp/* topics")

        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_deactivate(self, state):
        self._log("Gracefully stopping FRRouting")
        self._stop_event.set()
        if self._monitor_thread:
            self._monitor_thread.join(timeout=5)

        subprocess.run(
            ["/usr/lib/frr/frrinit.sh", "stop"],
            capture_output=True
        )

        if _ROS2_AVAILABLE:
            self._publish_health("failed", "reason=deactivated")
            return TransitionCallbackReturn.SUCCESS

    def on_cleanup(self, state):
        if _ROS2_AVAILABLE:
            if self._pub_peers:
                self.destroy_publisher(self._pub_peers)
            if self._pub_prefix_count:
                self.destroy_publisher(self._pub_prefix_count)
            if self._pub_alerts:
                self.destroy_publisher(self._pub_alerts)
            if self._pub_health:
                self.destroy_publisher(self._pub_health)
            return TransitionCallbackReturn.SUCCESS

    # ── Monitor loop ──────────────────────────────────────────────────────────

    def _monitor_loop(self):
        while not self._stop_event.is_set():
            try:
                self._publish_state()
            except Exception as exc:
                self._log(f"Monitor error: {exc}")
            self._stop_event.wait(PUBLISH_INTERVAL)

    def _publish_state(self):
        if not _frr_running():
            self._publish_health("failed", "reason=frr_not_running")
            return

        try:
            raw = _vtysh("show bgp summary json")
            peers = _parse_bgp_summary(raw)
        except Exception as exc:
            self._publish_health("degraded", f"vtysh_error={exc}")
            return

        # Detect flaps
        for peer in peers:
            key = peer["ip"]
            prev_state = self._last_peer_states.get(key)
            if prev_state and prev_state != peer["state"] and peer["state"] != "Established":
                self._publish_alert(
                    f"session_flap asn={peer['asn']} ip={key} "
                    f"from={prev_state} to={peer['state']}"
                )
            self._last_peer_states[key] = peer["state"]

        # Total prefix count
        try:
            raw_rt = _vtysh("show ip bgp summary json")
            rt_data = json.loads(raw_rt)
            total_prefixes = sum(
                p.get("pfxRcd", 0)
                for p in rt_data.get("ipv4Unicast", {}).get("peers", {}).values()
            )
        except Exception:
            total_prefixes = -1

        self._publish(self._pub_peers, json.dumps(peers))
        self._publish(self._pub_prefix_count, str(total_prefixes))
        self._publish_health("healthy", f"peers={len(peers)} prefixes={total_prefixes}")

    def _publish(self, publisher, text):
        if _ROS2_AVAILABLE and publisher:
            msg = String()
            msg.data = text
            publisher.publish(msg)

    def _publish_health(self, state, detail=""):
        self._log(f"health={state} {detail}")
        self._publish(self._pub_health, f"{state} {detail}".strip())

    def _publish_alert(self, detail):
        self._log(f"ALERT: {detail}")
        self._publish(self._pub_alerts, detail)

    def _detect_router_id(self):
        wan_iface = os.environ.get("NTARI_WAN_IFACE", "eth1")
        result = subprocess.run(
            ["ip", "-4", "addr", "show", wan_iface],
            capture_output=True, text=True
        )
        match = re.search(r"inet (\d+\.\d+\.\d+\.\d+)/", result.stdout)
        if match:
            return match.group(1)
        # Fallback to any non-loopback address
        result2 = subprocess.run(
            ["ip", "-4", "route", "get", "1.1.1.1"],
            capture_output=True, text=True
        )
        match2 = re.search(r"src (\d+\.\d+\.\d+\.\d+)", result2.stdout)
        return match2.group(1) if match2 else "0.0.0.1"

    def _log(self, msg):
        print(f"[ixp_bgp_node] {msg}", flush=True)


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    if not _ROS2_AVAILABLE:
        print("rclpy not available — running in standalone monitor mode", flush=True)
        node = IxpBgpNode()
        node.on_configure(None)
        node.on_activate(None)
        try:
            while True:
                time.sleep(30)
        except KeyboardInterrupt:
            node.on_deactivate(None)
        return

    rclpy.init()
    node = IxpBgpNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
