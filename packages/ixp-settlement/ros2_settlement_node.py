#!/usr/bin/python3
"""
NTARI OS — IXP Settlement Node (ixp_settlement_node)
packages/ixp-settlement/ros2_settlement_node.py

ROS2 lifecycle node for Lightning-settled paid peering.
Subscribes to /ixp/fabric/utilization, computes per-member traffic
deltas on a configurable interval, and generates Lightning invoices
via SoHoLINK's API for members exceeding the dust limit.

This is entirely optional — the IXP operates fully without it.
Requires: SoHoLINK running at the configured soholink_api URL.

Published topics:
  /ixp/settlement/invoices  — JSON list of pending invoices
  /ixp/settlement/health    — healthy | degraded | failed

Subscribed topics:
  /ixp/fabric/utilization   — per-port traffic counters
"""

import configparser
import json
import os
import sys
import threading
import time
from datetime import datetime

LIB_DIR = "/usr/lib/ntari/ixp-settlement"
sys.path.insert(0, LIB_DIR)

import traffic_meter
import lightning_settler

try:
    import rclpy
    from rclpy.lifecycle import LifecycleNode, TransitionCallbackReturn
    from std_msgs.msg import String
    _ROS2_AVAILABLE = True
except ImportError:
    _ROS2_AVAILABLE = False

IXP_CONF = "/etc/ntari/ixp.conf"


def _read_conf():
    cfg = configparser.ConfigParser()
    cfg.read(IXP_CONF)
    return cfg


def _member_for_port(port, registry_db_path):
    """Look up ASN for a port from the member registry."""
    if not registry_db_path or not os.path.exists(registry_db_path):
        return None
    try:
        import sqlite3
        conn = sqlite3.connect(registry_db_path)
        row = conn.execute(
            "SELECT asn FROM members WHERE port_id = ? AND status = 'active'",
            (port,)
        ).fetchone()
        conn.close()
        return row[0] if row else None
    except Exception:
        return None


class IxpSettlementNode(LifecycleNode if _ROS2_AVAILABLE else object):

    def __init__(self):
        if _ROS2_AVAILABLE:
            super().__init__("ixp_settlement_node")
        self._cfg = None
        self._ledger = None
        self._settler = None
        self._pub_invoices = None
        self._pub_health = None
        self._sub_util = None
        self._stop_event = threading.Event()
        self._settle_thread = None
        self._interval_start = None
        self._registry_db = None
        self._latest_util = []

    # ── Lifecycle ──────────────────────────────────────────────────────────────

    def on_configure(self, state):
        self._cfg = _read_conf()
        if not self._cfg.getboolean("settlement", "enabled", fallback=False):
            self._log("Settlement disabled in ixp.conf — node inactive")
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        ledger_path = self._cfg.get("settlement", "ledger_path",
                                    fallback="/var/lib/ntari/ixp/settlement.db")
        self._ledger = traffic_meter.open_ledger(ledger_path)

        api_base = self._cfg.get("settlement", "soholink_api",
                                 fallback="http://localhost:8080")
        self._settler = lightning_settler.LightningSettler(api_base)

        self._registry_db = self._cfg.get("registry", "db_path",
                                           fallback="/var/lib/ntari/ixp/registry.db")

        if not self._settler.health_check():
            self._log(f"WARNING: SoHoLINK not reachable at {api_base}")

        if _ROS2_AVAILABLE:
            self._pub_invoices = self.create_publisher(
                String, "/ixp/settlement/invoices", 10)
            self._pub_health = self.create_publisher(
                String, "/ixp/settlement/health", 10)
            self._sub_util = self.create_subscription(
                String, "/ixp/fabric/utilization",
                self._on_utilization, 10)
            return TransitionCallbackReturn.SUCCESS

    def on_activate(self, state):
        if not self._cfg or not self._cfg.getboolean("settlement", "enabled", fallback=False):
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        self._interval_start = datetime.utcnow().isoformat()
        self._stop_event.clear()
        self._settle_thread = threading.Thread(
            target=self._settle_loop, daemon=True
        )
        self._settle_thread.start()
        self._log("Settlement node active")

        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_deactivate(self, state):
        self._stop_event.set()
        if self._settle_thread:
            self._settle_thread.join(timeout=10)
        self._publish_health("failed", "reason=deactivated")
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_cleanup(self, state):
        if self._ledger:
            self._ledger.close()
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    # ── Utilization subscription ──────────────────────────────────────────────

    def _on_utilization(self, msg):
        try:
            util = json.loads(msg.data)
        except json.JSONDecodeError:
            return
        self._latest_util = util

        def port_to_asn(port):
            return _member_for_port(port, self._registry_db)

        traffic_meter.record_snapshot(self._ledger, util, port_to_asn)

    # ── Settlement loop ───────────────────────────────────────────────────────

    def _settle_loop(self):
        interval = self._cfg.getint(
            "settlement", "settlement_interval_seconds", fallback=3600
        )
        dust_limit = self._cfg.getint(
            "settlement", "dust_limit_sats", fallback=1000
        )
        rate = self._cfg.getint(
            "settlement", "rate_per_gb_sats", fallback=10
        )

        while not self._stop_event.is_set():
            self._stop_event.wait(interval)
            if self._stop_event.is_set():
                break
            try:
                self._run_settlement(rate, dust_limit)
            except Exception as exc:
                self._log(f"Settlement error: {exc}")
                self._publish_health("degraded", f"error={exc}")

    def _run_settlement(self, rate_per_gb, dust_limit):
        interval_end = datetime.utcnow().isoformat()
        deltas = traffic_meter.compute_deltas(self._ledger, self._interval_start)
        charges = traffic_meter.compute_charges(deltas, rate_per_gb)

        invoices = []
        for charge in charges:
            if charge["amount_sats"] < dust_limit:
                self._log(
                    f"AS{charge['asn']}: {charge['amount_sats']} sats < "
                    f"dust limit {dust_limit} — skipping"
                )
                continue

            self._log(
                f"Settling AS{charge['asn']}: {charge['net_gb']:.3f} GB "
                f"→ {charge['amount_sats']} sats"
            )
            try:
                invoice_id = self._settler.request_payout(
                    charge["asn"],
                    charge["amount_sats"],
                    description=(
                        f"IXP peering settlement AS{charge['asn']} "
                        f"{self._interval_start[:10]}"
                    )
                )
                traffic_meter.record_settlement(
                    self._ledger, charge,
                    self._interval_start, interval_end,
                    invoice_id=invoice_id, status="invoiced"
                )
                invoices.append({
                    "asn": charge["asn"],
                    "amount_sats": charge["amount_sats"],
                    "invoice_id": invoice_id,
                })
            except Exception as exc:
                self._log(f"Invoice generation failed for AS{charge['asn']}: {exc}")
                traffic_meter.record_settlement(
                    self._ledger, charge,
                    self._interval_start, interval_end,
                    status="failed"
                )

        self._publish(self._pub_invoices, json.dumps(invoices))
        self._publish_health("healthy",
                             f"invoices={len(invoices)} interval={interval_end[:16]}")
        self._interval_start = interval_end

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
        print(f"[ixp_settlement_node] {msg}", flush=True)


def main():
    if not _ROS2_AVAILABLE:
        node = IxpSettlementNode()
        node.on_configure(None)
        node.on_activate(None)
        try:
            while True:
                time.sleep(60)
        except KeyboardInterrupt:
            node.on_deactivate(None)
        return

    rclpy.init()
    node = IxpSettlementNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
