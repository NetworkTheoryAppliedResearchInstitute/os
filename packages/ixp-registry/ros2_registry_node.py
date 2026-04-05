#!/usr/bin/python3
# NTARI OS — IXP Member Registry Node (ixp_registry_node)
# Phase 16: Member Registry + PeeringDB Integration
#
# ROS2 lifecycle node for IXP member management.
# Publishes member list and provisioning events to DDS.
# Syncs member data from PeeringDB on a configurable interval.
# Cross-references BGP session state to detect unauthorized sessions.
#
# Published topics:
#   /ixp/members/list        — JSON list of active members
#   /ixp/members/provisioned — fires when a new member is activated
#   /ixp/registry/health     — healthy | degraded | failed
#
# Subscribed topics:
#   /ixp/bgp/peers           — cross-reference for unauthorized session detection

import configparser
import json
import os
import sys
import threading
import time

LIB_DIR = "/usr/lib/ntari/ixp-registry"
sys.path.insert(0, LIB_DIR)

import member_db
import peeringdb_client
import irr_filter_gen

try:
    import rclpy
    from rclpy.lifecycle import LifecycleNode, TransitionCallbackReturn
    from std_msgs.msg import String
    _ROS2_AVAILABLE = True
except ImportError:
    _ROS2_AVAILABLE = False

IXP_CONF = "/etc/ntari/ixp.conf"
SYNC_INTERVAL_DEFAULT = 3600
PUBLISH_INTERVAL = 60


def _read_conf():
    cfg = configparser.ConfigParser()
    cfg.read(IXP_CONF)
    return cfg


class IxpRegistryNode(LifecycleNode if _ROS2_AVAILABLE else object):

    def __init__(self):
        if _ROS2_AVAILABLE:
            super().__init__("ixp_registry_node")
        self._cfg = None
        self._conn = None
        self._pub_list = None
        self._pub_provisioned = None
        self._pub_health = None
        self._sub_peers = None
        self._stop_event = threading.Event()
        self._sync_thread = None
        self._publish_thread = None

    # ── Lifecycle ──────────────────────────────────────────────────────────────

    def on_configure(self, state):
        self._cfg = _read_conf()
        if not self._cfg.getboolean("ixp", "enabled", fallback=False):
            self._log("IXP disabled — registry node configured but inactive")
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        db_path = self._cfg.get("registry", "db_path",
                                fallback="/var/lib/ntari/ixp/registry.db")
        self._conn = member_db.open_db(db_path)
        self._log(f"Member registry DB: {db_path}")

        if _ROS2_AVAILABLE:
            self._pub_list = self.create_publisher(
                String, "/ixp/members/list", 10)
            self._pub_provisioned = self.create_publisher(
                String, "/ixp/members/provisioned", 10)
            self._pub_health = self.create_publisher(
                String, "/ixp/registry/health", 10)
            self._sub_peers = self.create_subscription(
                String, "/ixp/bgp/peers",
                self._on_bgp_peers, 10)
            return TransitionCallbackReturn.SUCCESS

    def on_activate(self, state):
        if not self._cfg or not self._cfg.getboolean("ixp", "enabled", fallback=False):
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        self._stop_event.clear()

        # Publish thread
        self._publish_thread = threading.Thread(
            target=self._publish_loop, daemon=True
        )
        self._publish_thread.start()

        # PeeringDB sync thread
        if self._cfg.getboolean("registry", "peeringdb_sync", fallback=True):
            self._sync_thread = threading.Thread(
                target=self._sync_loop, daemon=True
            )
            self._sync_thread.start()

        self._log("Registry node active")
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_deactivate(self, state):
        self._stop_event.set()
        if self._publish_thread:
            self._publish_thread.join(timeout=5)
        if self._sync_thread:
            self._sync_thread.join(timeout=5)
        self._publish_health("failed", "reason=deactivated")
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_cleanup(self, state):
        if self._conn:
            self._conn.close()
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    # ── Loops ─────────────────────────────────────────────────────────────────

    def _publish_loop(self):
        while not self._stop_event.is_set():
            try:
                members = member_db.list_members(self._conn, status="active")
                self._publish(self._pub_list, json.dumps(members))
                self._publish_health("healthy",
                                     f"active_members={len(members)}")
            except Exception as exc:
                self._publish_health("degraded", f"error={exc}")
            self._stop_event.wait(PUBLISH_INTERVAL)

    def _sync_loop(self):
        interval = self._cfg.getint(
            "registry", "peeringdb_sync_interval",
            fallback=SYNC_INTERVAL_DEFAULT
        )
        while not self._stop_event.is_set():
            self._stop_event.wait(interval)
            if self._stop_event.is_set():
                break
            try:
                members = member_db.list_members(self._conn, status="active")
                for m in members:
                    try:
                        peeringdb_client.sync_member(
                            self._conn, m["asn"], member_db
                        )
                    except Exception as exc:
                        self._log(f"PeeringDB sync error AS{m['asn']}: {exc}")
                self._log(f"PeeringDB sync complete ({len(members)} members)")
            except Exception as exc:
                self._log(f"PeeringDB sync loop error: {exc}")

    # ── BGP peer cross-reference ──────────────────────────────────────────────

    def _on_bgp_peers(self, msg):
        """Detect BGP sessions from ASNs not in the member registry."""
        try:
            peers = json.loads(msg.data)
        except json.JSONDecodeError:
            return

        members = member_db.list_members(self._conn, status="active")
        registered_asns = {m["asn"] for m in members}

        for peer in peers:
            asn = peer.get("asn")
            if asn and asn not in registered_asns and peer.get("state") == "Established":
                self._log(
                    f"ALERT: unregistered BGP session from AS{asn} "
                    f"({peer.get('ip')}) — investigate or add to registry"
                )
                self._publish_health(
                    "degraded",
                    f"unauthorized_session=AS{asn} ip={peer.get('ip')}"
                )

    # ── Public provisioning API ───────────────────────────────────────────────

    def notify_member_activated(self, asn):
        """Called by provisioning wizard after activation to fire DDS event."""
        member = member_db.get_member(self._conn, asn)
        if member and _ROS2_AVAILABLE:
            self._publish(self._pub_provisioned, json.dumps(member))
            self._log(f"Published /ixp/members/provisioned for AS{asn}")

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
        print(f"[ixp_registry_node] {msg}", flush=True)


def main():
    if not _ROS2_AVAILABLE:
        node = IxpRegistryNode()
        node.on_configure(None)
        node.on_activate(None)
        try:
            while True:
                time.sleep(60)
        except KeyboardInterrupt:
            node.on_deactivate(None)
        return

    rclpy.init()
    node = IxpRegistryNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
