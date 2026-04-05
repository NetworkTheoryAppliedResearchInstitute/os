"""
NTARI OS — IXP Member Registry: SQLite database layer
packages/ixp-registry/member_db.py

Schema:
  members        — ASN, org name, peering IPs, port, status
  prefix_policy  — per-ASN prefix allowlists (from IRR / PeeringDB / manual)
"""

import os
import sqlite3
from datetime import datetime

SCHEMA = """
CREATE TABLE IF NOT EXISTS members (
    id              INTEGER PRIMARY KEY,
    org_name        TEXT    NOT NULL,
    asn             INTEGER UNIQUE NOT NULL,
    peering_ip4     TEXT,
    peering_ip6     TEXT,
    port_id         TEXT,
    peeringdb_id    INTEGER,
    status          TEXT    DEFAULT 'pending',
    joined_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    notes           TEXT
);

CREATE TABLE IF NOT EXISTS prefix_policy (
    id          INTEGER PRIMARY KEY,
    asn         INTEGER NOT NULL REFERENCES members(asn),
    prefix      TEXT    NOT NULL,
    max_length  INTEGER,
    source      TEXT    NOT NULL,
    updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(asn, prefix)
);

CREATE INDEX IF NOT EXISTS idx_members_asn    ON members(asn);
CREATE INDEX IF NOT EXISTS idx_members_status ON members(status);
CREATE INDEX IF NOT EXISTS idx_prefix_asn     ON prefix_policy(asn);
"""


def open_db(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    conn.commit()
    return conn


def add_member(conn, asn, org_name, peeringdb_id=None, notes=None):
    conn.execute(
        """INSERT OR IGNORE INTO members
           (asn, org_name, peeringdb_id, notes, status)
           VALUES (?, ?, ?, ?, 'pending')""",
        (asn, org_name, peeringdb_id, notes)
    )
    conn.commit()


def activate_member(conn, asn, peering_ip4=None, peering_ip6=None,
                    port_id=None):
    conn.execute(
        """UPDATE members SET
               status = 'active',
               peering_ip4 = COALESCE(?, peering_ip4),
               peering_ip6 = COALESCE(?, peering_ip6),
               port_id = COALESCE(?, port_id)
           WHERE asn = ?""",
        (peering_ip4, peering_ip6, port_id, asn)
    )
    conn.commit()


def suspend_member(conn, asn):
    conn.execute(
        "UPDATE members SET status = 'suspended' WHERE asn = ?", (asn,)
    )
    conn.commit()


def get_member(conn, asn):
    row = conn.execute(
        "SELECT * FROM members WHERE asn = ?", (asn,)
    ).fetchone()
    return dict(row) if row else None


def list_members(conn, status=None):
    if status:
        rows = conn.execute(
            "SELECT * FROM members WHERE status = ? ORDER BY asn", (status,)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM members ORDER BY asn"
        ).fetchall()
    return [dict(r) for r in rows]


def upsert_prefix(conn, asn, prefix, max_length, source):
    conn.execute(
        """INSERT OR REPLACE INTO prefix_policy
           (asn, prefix, max_length, source, updated_at)
           VALUES (?, ?, ?, ?, ?)""",
        (asn, prefix, max_length, source, datetime.utcnow().isoformat())
    )
    conn.commit()


def list_prefixes(conn, asn):
    rows = conn.execute(
        "SELECT * FROM prefix_policy WHERE asn = ? ORDER BY prefix", (asn,)
    ).fetchall()
    return [dict(r) for r in rows]


def clear_prefixes(conn, asn, source=None):
    if source:
        conn.execute(
            "DELETE FROM prefix_policy WHERE asn = ? AND source = ?",
            (asn, source)
        )
    else:
        conn.execute(
            "DELETE FROM prefix_policy WHERE asn = ?", (asn,)
        )
    conn.commit()
