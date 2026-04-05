#!/usr/bin/python3
"""
NTARI OS — IXP Looking Glass HTTP Server
packages/ixp-looking-glass/lg_server.py

Read-only BGP visibility tool served via Caddy reverse proxy (/lg/*).
Executes vtysh commands in a subprocess and sanitizes all input.
Rate-limited to 10 requests per IP per minute.

Endpoints:
  GET /lg/                    — HTML UI
  GET /lg/summary             — show bgp summary
  GET /lg/route/{prefix}      — show ip bgp {prefix}
  GET /lg/peer/{asn}          — show ip bgp neighbors {peer_ip}
  GET /lg/prefixes/{asn}      — show ip bgp regexp ^{asn}$
  GET /lg/health              — JSON health check

Run as: python3 /usr/local/bin/ixp-lg-server.py --port 5000
"""

import configparser
import html
import http.server
import ipaddress
import json
import os
import re
import subprocess
import sys
import time
from collections import defaultdict
from urllib.parse import urlparse, parse_qs

VTYSH = "/usr/bin/vtysh"
IXP_CONF = "/etc/ntari/ixp.conf"
TEMPLATE_PATH = "/usr/share/ntari/ixp-lg/looking_glass.html"

_rate_store = defaultdict(list)  # ip → [timestamp, ...]
_RATE_LIMIT = 10
_RATE_WINDOW = 60  # seconds


def _load_cfg():
    cfg = configparser.ConfigParser()
    cfg.read(IXP_CONF)
    return cfg


def _vtysh(command):
    """Execute a vtysh read-only command; return text output."""
    result = subprocess.run(
        [VTYSH, "-c", command],
        capture_output=True, text=True, timeout=10
    )
    return result.stdout if result.returncode == 0 else f"Error: {result.stderr.strip()}"


def _rate_check(client_ip):
    """Return True if the client is within the rate limit."""
    now = time.monotonic()
    timestamps = _rate_store[client_ip]
    # Remove entries older than the window
    _rate_store[client_ip] = [t for t in timestamps if now - t < _RATE_WINDOW]
    if len(_rate_store[client_ip]) >= _RATE_LIMIT:
        return False
    _rate_store[client_ip].append(now)
    return True


def _validate_prefix(prefix):
    """Validate an IPv4 or IPv6 prefix string. Raise ValueError if invalid."""
    prefix = prefix.strip()
    try:
        ipaddress.ip_network(prefix, strict=False)
    except ValueError:
        raise ValueError(f"Invalid prefix: {prefix!r}")
    # Reject too-specific inputs (defense in depth)
    if len(prefix) > 50:
        raise ValueError("Prefix too long")
    return prefix


def _validate_asn(asn_str):
    """Validate an ASN string. Return int. Raise ValueError if invalid."""
    try:
        asn = int(asn_str)
    except ValueError:
        raise ValueError(f"Invalid ASN: {asn_str!r}")
    if asn < 1 or asn > 4294967295:
        raise ValueError(f"ASN out of range: {asn}")
    return asn


def _member_peering_ip(asn):
    """Look up peering IP for an ASN from the member registry DB."""
    db_path = _load_cfg().get("registry", "db_path",
                               fallback="/var/lib/ntari/ixp/registry.db")
    if not os.path.exists(db_path):
        return None
    try:
        import sqlite3
        conn = sqlite3.connect(db_path)
        row = conn.execute(
            "SELECT peering_ip4 FROM members WHERE asn = ? AND status = 'active'",
            (asn,)
        ).fetchone()
        conn.close()
        return row[0] if row else None
    except Exception:
        return None


class LGHandler(http.server.BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        print(f"[lg_server] {self.address_string()} — " + fmt % args, flush=True)

    def _client_ip(self):
        # Respect X-Forwarded-For if Caddy sets it
        xff = self.headers.get("X-Forwarded-For", "")
        if xff:
            return xff.split(",")[0].strip()
        return self.client_address[0]

    def do_GET(self):
        client_ip = self._client_ip()
        if not _rate_check(client_ip):
            self._respond(429, "text/plain", "Rate limit exceeded — 10 req/min")
            return

        path = urlparse(self.path).path.rstrip("/")

        if path in ("/lg", ""):
            self._serve_ui()

        elif path == "/lg/health":
            self._json({"status": "ok", "vtysh": os.path.exists(VTYSH)})

        elif path == "/lg/summary":
            out = _vtysh("show bgp summary")
            self._html_result("BGP Summary", out)

        elif path.startswith("/lg/route/"):
            raw = path[len("/lg/route/"):]
            try:
                prefix = _validate_prefix(raw)
            except ValueError as exc:
                self._respond(400, "text/plain", str(exc))
                return
            out = _vtysh(f"show ip bgp {prefix}")
            self._html_result(f"BGP route: {prefix}", out)

        elif path.startswith("/lg/peer/"):
            raw = path[len("/lg/peer/"):]
            try:
                asn = _validate_asn(raw)
            except ValueError as exc:
                self._respond(400, "text/plain", str(exc))
                return
            peer_ip = _member_peering_ip(asn)
            if not peer_ip:
                self._respond(404, "text/plain",
                              f"AS{asn} not found in member registry")
                return
            out = _vtysh(f"show ip bgp neighbors {peer_ip}")
            self._html_result(f"BGP neighbor: AS{asn} ({peer_ip})", out)

        elif path.startswith("/lg/prefixes/"):
            raw = path[len("/lg/prefixes/"):]
            try:
                asn = _validate_asn(raw)
            except ValueError as exc:
                self._respond(400, "text/plain", str(exc))
                return
            out = _vtysh(f"show ip bgp regexp ^{asn}$")
            self._html_result(f"Prefixes from AS{asn}", out)

        else:
            self._respond(404, "text/plain", "Not found")

    def _serve_ui(self):
        if os.path.exists(TEMPLATE_PATH):
            with open(TEMPLATE_PATH) as f:
                body = f.read()
        else:
            body = _minimal_ui()
        self._respond(200, "text/html", body)

    def _html_result(self, title, content):
        safe = html.escape(content)
        body = (
            f'<!doctype html><html><head><meta charset="utf-8">'
            f'<title>{html.escape(title)} — NTARI IXP Looking Glass</title>'
            f'<style>body{{font-family:monospace;background:#0a0a1e;color:#e0e0e0;'
            f'padding:24px}}pre{{background:#111;padding:16px;border-radius:4px;'
            f'overflow-x:auto}}a{{color:#448aff}}</style></head><body>'
            f'<a href="/lg/">&larr; Back</a><h2>{html.escape(title)}</h2>'
            f'<pre>{safe}</pre></body></html>'
        )
        self._respond(200, "text/html", body)

    def _json(self, obj):
        self._respond(200, "application/json", json.dumps(obj))

    def _respond(self, code, content_type, body):
        encoded = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.end_headers()
        self.wfile.write(encoded)


def _minimal_ui():
    return """<!doctype html>
<html><head><meta charset="utf-8">
<title>NTARI IXP Looking Glass</title>
<style>
  body { font-family: sans-serif; background: #0a0a1e; color: #e0e0e0;
         max-width: 800px; margin: 40px auto; padding: 0 20px; }
  h1 { color: #448aff; }
  form { margin: 16px 0; }
  input, select { background: #1a1a2e; color: #e0e0e0; border: 1px solid #448aff;
                  padding: 6px 10px; border-radius: 4px; }
  button { background: #1a237e; color: #fff; border: none; padding: 8px 18px;
           border-radius: 4px; cursor: pointer; }
  .links a { display: inline-block; margin: 6px 8px 6px 0; color: #448aff; }
</style>
</head><body>
<h1>NTARI IXP Looking Glass</h1>
<div class="links">
  <a href="/lg/summary">BGP Summary</a>
</div>
<form onsubmit="event.preventDefault();
  const t=document.getElementById('qtype').value;
  const v=document.getElementById('qval').value.trim();
  if(v) window.location='/lg/'+t+'/'+encodeURIComponent(v);">
  <select id="qtype">
    <option value="route">Route lookup</option>
    <option value="peer">Peer (ASN)</option>
    <option value="prefixes">Prefixes from AS</option>
  </select>
  <input id="qval" placeholder="prefix or ASN" style="width:240px">
  <button type="submit">Query</button>
</form>
<p style="font-size:12px;color:#888">Read-only. Rate limited to 10 req/min per IP.
   Powered by NTARI OS IXP Extension.</p>
</body></html>"""


def run(port=5000):
    cfg = _load_cfg()
    rate = cfg.getint("looking_glass", "rate_limit", fallback=10)
    global _RATE_LIMIT
    _RATE_LIMIT = rate

    server = http.server.HTTPServer(("127.0.0.1", port), LGHandler)
    print(f"[lg_server] Listening on 127.0.0.1:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    port = 5000
    if "--port" in sys.argv:
        try:
            port = int(sys.argv[sys.argv.index("--port") + 1])
        except (IndexError, ValueError):
            pass
    run(port)
