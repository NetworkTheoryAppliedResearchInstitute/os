"""
NTARI OS — IXP Settlement: Traffic Meter
packages/ixp-settlement/traffic_meter.py

Reads /ixp/fabric/utilization topic snapshots and computes per-member
traffic deltas between settlement intervals.

Billing model: per-GB asymmetric — the heavier sender pays.
net_chargeable = max(tx_bytes, rx_bytes) - min(tx_bytes, rx_bytes)
"""

import json
import sqlite3
import os
from datetime import datetime

BYTES_PER_GB = 1_073_741_824


def open_ledger(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS traffic_snapshots (
            id          INTEGER PRIMARY KEY,
            asn         INTEGER NOT NULL,
            port        TEXT NOT NULL,
            tx_bytes    INTEGER NOT NULL,
            rx_bytes    INTEGER NOT NULL,
            recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS settlement_ledger (
            id              INTEGER PRIMARY KEY,
            asn             INTEGER NOT NULL,
            interval_start  DATETIME NOT NULL,
            interval_end    DATETIME NOT NULL,
            tx_delta        INTEGER NOT NULL,
            rx_delta        INTEGER NOT NULL,
            net_gb          REAL NOT NULL,
            amount_sats     INTEGER NOT NULL,
            invoice_id      TEXT,
            settled_at      DATETIME,
            status          TEXT DEFAULT 'pending'
        )
    """)
    conn.commit()
    return conn


def record_snapshot(conn, port_util_json, member_lookup):
    """
    Record a utilization snapshot.
    port_util_json: list of {port, tx_bytes, rx_bytes}
    member_lookup: callable(port) -> asn or None
    """
    now = datetime.utcnow().isoformat()
    for entry in port_util_json:
        asn = member_lookup(entry.get("port", ""))
        if asn is None:
            continue
        conn.execute(
            """INSERT INTO traffic_snapshots (asn, port, tx_bytes, rx_bytes, recorded_at)
               VALUES (?, ?, ?, ?, ?)""",
            (asn, entry["port"], entry.get("tx_bytes", 0),
             entry.get("rx_bytes", 0), now)
        )
    conn.commit()


def compute_deltas(conn, since_dt):
    """
    Compute tx/rx deltas per ASN since since_dt (ISO string).
    Returns list of {asn, port, tx_delta, rx_delta}.
    """
    # Get earliest snapshot per port after since_dt and latest overall
    rows = conn.execute("""
        SELECT asn, port,
               MAX(tx_bytes) - MIN(tx_bytes) AS tx_delta,
               MAX(rx_bytes) - MIN(rx_bytes) AS rx_delta
        FROM traffic_snapshots
        WHERE recorded_at >= ?
        GROUP BY asn, port
    """, (since_dt,)).fetchall()
    return [
        {"asn": r[0], "port": r[1], "tx_delta": r[2], "rx_delta": r[3]}
        for r in rows
    ]


def compute_charges(deltas, rate_per_gb_sats):
    """
    For each ASN's traffic delta, compute the chargeable amount in sats.
    Billing: heavier direction determines the billable byte count.
    Returns list of {asn, tx_delta, rx_delta, net_gb, amount_sats}.
    """
    # Aggregate across ports for same ASN
    by_asn = {}
    for d in deltas:
        asn = d["asn"]
        if asn not in by_asn:
            by_asn[asn] = {"tx": 0, "rx": 0}
        by_asn[asn]["tx"] += d["tx_delta"]
        by_asn[asn]["rx"] += d["rx_delta"]

    charges = []
    for asn, totals in by_asn.items():
        tx, rx = totals["tx"], totals["rx"]
        # Charge the heavier direction minus the lighter (asymmetric billing)
        net_bytes = max(tx, rx) - min(tx, rx)
        net_gb = net_bytes / BYTES_PER_GB
        amount_sats = int(net_gb * rate_per_gb_sats)
        charges.append({
            "asn": asn,
            "tx_delta": tx,
            "rx_delta": rx,
            "net_gb": net_gb,
            "amount_sats": amount_sats,
        })
    return charges


def record_settlement(conn, charge, interval_start, interval_end,
                      invoice_id=None, status="pending"):
    conn.execute(
        """INSERT INTO settlement_ledger
           (asn, interval_start, interval_end, tx_delta, rx_delta,
            net_gb, amount_sats, invoice_id, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (charge["asn"], interval_start, interval_end,
         charge["tx_delta"], charge["rx_delta"],
         charge["net_gb"], charge["amount_sats"],
         invoice_id, status)
    )
    conn.commit()


def mark_settled(conn, ledger_id, settled_at=None):
    if settled_at is None:
        settled_at = datetime.utcnow().isoformat()
    conn.execute(
        "UPDATE settlement_ledger SET status='settled', settled_at=? WHERE id=?",
        (settled_at, ledger_id)
    )
    conn.commit()
