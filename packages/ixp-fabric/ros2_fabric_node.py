#!/usr/bin/python3
# NTARI OS — IXP Fabric Node (ixp_fabric_node)
# Phase 15: IXP Layer 2 Fabric Management
#
# ROS2 lifecycle node for managing the IXP peering LAN fabric.
# Detects the available switching backend (OVS or Linux bridge),
# creates the IXP peering bridge, assigns peering IPs to members,
# and publishes port/utilization data to the DDS graph.
#
# Lifecycle transitions:
#   on_configure  : detect backend; read ixp.conf; open SQLite DB
#   on_activate   : create bridge; assign peering LAN IP; start utilization loop
#   on_deactivate : stop utilization publishing; bridge is left up (live network)
#   on_cleanup    : close DB
#
# Published topics:
#   /ixp/fabric/ports        — JSON port inventory and VLAN assignments
#   /ixp/fabric/utilization  — JSON per-port tx/rx byte counters
#   /ixp/fabric/health       — healthy | degraded | failed
#
# ROS2 services:
#   /ixp/fabric/add_member_port    — assign a port to peering VLAN
#   /ixp/fabric/remove_member_port — remove and reset a port
#
# Subscribes:
#   /ixp/members/provisioned — auto-assign VLAN when member is activated

import configparser
import ipaddress
import json
import os
import sqlite3
import subprocess
import sys
import threading
import time

try:
    import rclpy
    from rclpy.lifecycle import LifecycleNode, TransitionCallbackReturn
    from std_msgs.msg import String
    _ROS2_AVAILABLE = True
except ImportError:
    _ROS2_AVAILABLE = False

IXP_CONF = "/etc/ntari/ixp.conf"
DRIVERS_DIR = "/usr/lib/ntari/ixp-fabric"
PUBLISH_INTERVAL = 30  # seconds


def _read_conf():
    cfg = configparser.ConfigParser()
    cfg.read(IXP_CONF)
    return cfg


def _load_driver(backend):
    """Return the switching backend module (OVS preferred over netlink)."""
    sys.path.insert(0, DRIVERS_DIR)
    if backend == "openvswitch":
        import openvswitch as drv
    elif backend == "linux_bridge":
        import netlink as drv
    else:
        try:
            import openvswitch as drv_ovs
            if drv_ovs.available():
                drv = drv_ovs
            else:
                import netlink as drv
        except ImportError:
            import netlink as drv
    return drv


def _init_db(db_path):
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS ip_pool (
            id      INTEGER PRIMARY KEY,
            ip      TEXT UNIQUE NOT NULL,
            asn     INTEGER,
            assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    return conn


def _populate_pool(conn, prefix):
    """Pre-populate pool with all usable host IPs from prefix (skip net/bcast)."""
    net = ipaddress.ip_network(prefix, strict=False)
    hosts = list(net.hosts())
    # Reserve first IP for the route server
    for host in hosts[1:]:
        conn.execute(
            "INSERT OR IGNORE INTO ip_pool (ip) VALUES (?)", (str(host),)
        )
    conn.commit()


def _assign_ip(conn, asn):
    """Assign next available IP from pool to an ASN; return IP string."""
    row = conn.execute(
        "SELECT ip FROM ip_pool WHERE asn IS NULL LIMIT 1"
    ).fetchone()
    if not row:
        raise RuntimeError("IP pool exhausted — add more prefixes to ixp.conf")
    ip = row[0]
    conn.execute("UPDATE ip_pool SET asn = ? WHERE ip = ?", (asn, ip))
    conn.commit()
    return ip


def _release_ip(conn, asn):
    conn.execute("UPDATE ip_pool SET asn = NULL WHERE asn = ?", (asn,))
    conn.commit()


class IxpFabricNode(LifecycleNode if _ROS2_AVAILABLE else object):

    def __init__(self):
        if _ROS2_AVAILABLE:
            super().__init__("ixp_fabric_node")
        self._cfg = None
        self._drv = None
        self._conn = None
        self._bridge = None
        self._pub_ports = None
        self._pub_util = None
        self._pub_health = None
        self._sub_provisioned = None
        self._stop_event = threading.Event()
        self._util_thread = None

    # ── Lifecycle ──────────────────────────────────────────────────────────────

    def on_configure(self, state):
        self._cfg = _read_conf()
        if not self._cfg.getboolean("ixp", "enabled", fallback=False):
            self._log("IXP disabled — fabric node configured but inactive")
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        backend = self._cfg.get("fabric", "backend", fallback="auto")
        self._drv = _load_driver(backend)
        self._log(f"Switching backend: {self._drv.__name__ if hasattr(self._drv, '__name__') else backend}")

        db_path = self._cfg.get("registry", "db_path",
                                fallback="/var/lib/ntari/ixp/fabric.db")
        self._conn = _init_db(db_path)

        prefix = self._cfg.get("bgp", "ixp_lan_ipv4", fallback="192.0.2.0/24")
        _populate_pool(self._conn, prefix)

        self._bridge = self._cfg.get("fabric", "peering_bridge", fallback="br-ixp")

        if _ROS2_AVAILABLE:
            self._pub_ports = self.create_publisher(
                String, "/ixp/fabric/ports", 10)
            self._pub_util = self.create_publisher(
                String, "/ixp/fabric/utilization", 10)
            self._pub_health = self.create_publisher(
                String, "/ixp/fabric/health", 10)
            self._sub_provisioned = self.create_subscription(
                String, "/ixp/members/provisioned",
                self._on_member_provisioned, 10)
            return TransitionCallbackReturn.SUCCESS

    def on_activate(self, state):
        if not self._cfg or not self._cfg.getboolean("ixp", "enabled", fallback=False):
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        # Create the peering bridge
        try:
            self._drv.create_bridge(self._bridge)
            self._log(f"Peering bridge {self._bridge} ready")
        except Exception as exc:
            self._log(f"Bridge creation failed: {exc}")
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.FAILURE
            return

        # Assign peering LAN prefix to bridge interface
        prefix = self._cfg.get("bgp", "ixp_lan_ipv4", fallback="192.0.2.0/24")
        net = ipaddress.ip_network(prefix, strict=False)
        rs_ip = str(list(net.hosts())[0])  # first host = route server
        try:
            subprocess.run(
                ["ip", "addr", "add", f"{rs_ip}/{net.prefixlen}",
                 "dev", self._bridge],
                capture_output=True, check=False
            )
            subprocess.run(
                ["ip", "link", "set", self._bridge, "up"],
                capture_output=True
            )
            self._log(f"Route server peering IP: {rs_ip}/{net.prefixlen}")
        except Exception as exc:
            self._log(f"IP assignment warning: {exc}")

        # Start utilization publishing loop
        self._stop_event.clear()
        self._util_thread = threading.Thread(
            target=self._util_loop, daemon=True
        )
        self._util_thread.start()

        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_deactivate(self, state):
        self._stop_event.set()
        if self._util_thread:
            self._util_thread.join(timeout=5)
        # Bridge is left up — removing it would disrupt live peering
        self._publish_health("failed", "reason=deactivated")
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_cleanup(self, state):
        if self._conn:
            self._conn.close()
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    # ── Utilization loop ──────────────────────────────────────────────────────

    def _util_loop(self):
        while not self._stop_event.is_set():
            try:
                self._publish_state()
            except Exception as exc:
                self._log(f"Utilization loop error: {exc}")
            self._stop_event.wait(PUBLISH_INTERVAL)

    def _publish_state(self):
        ports = self._drv.port_list(self._bridge)
        util = []
        for p in ports:
            stats = self._drv.port_stats(p["port"])
            util.append({
                "port": p["port"],
                "vlan": p.get("vlan"),
                "tx_bytes": stats.get("tx_bytes", 0),
                "rx_bytes": stats.get("rx_bytes", 0),
            })

        self._publish(self._pub_ports, json.dumps(ports))
        self._publish(self._pub_util, json.dumps(util))
        self._publish_health("healthy", f"ports={len(ports)}")

    # ── Member provisioning ───────────────────────────────────────────────────

    def _on_member_provisioned(self, msg):
        """Called when ixp-registry publishes a new activated member."""
        try:
            member = json.loads(msg.data)
            asn = member.get("asn")
            port = member.get("port_id")
            if asn and port:
                ip = _assign_ip(self._conn, asn)
                self._drv.add_member_port(self._bridge, port, vlan_tag=None)
                self._log(f"Provisioned AS{asn} on port {port} ip={ip}")
        except Exception as exc:
            self._log(f"Provisioning error: {exc}")

    def add_member_port(self, port_name, asn, vlan_tag=None):
        """Programmatic member port add (also callable from service handler)."""
        self._drv.add_member_port(self._bridge, port_name, vlan_tag)
        ip = _assign_ip(self._conn, asn)
        self._log(f"Added port {port_name} for AS{asn} peering_ip={ip}")
        return ip

    def remove_member_port(self, port_name, asn):
        """Remove a member port and release its peering IP."""
        self._drv.remove_member_port(self._bridge, port_name)
        _release_ip(self._conn, asn)
        self._log(f"Removed port {port_name} for AS{asn}")

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _publish(self, publisher, text):
        if _ROS2_AVAILABLE and publisher:
            msg = String()
            msg.data = text
            publisher.publish(msg)

    def _publish_health(self, state, detail=""):
        self._log(f"health={state} {detail}")
        self._publish(self._pub_health, f"{state} {detail}".strip())

    def _log(self, msg):
        print(f"[ixp_fabric_node] {msg}", flush=True)


def main():
    if not _ROS2_AVAILABLE:
        node = IxpFabricNode()
        node.on_configure(None)
        node.on_activate(None)
        try:
            while True:
                time.sleep(60)
        except KeyboardInterrupt:
            node.on_deactivate(None)
        return

    rclpy.init()
    node = IxpFabricNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
