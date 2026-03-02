#!/usr/bin/python3
# NTARI OS — Node Scheduler (ntari_scheduler_node)
# Phase 11: Contribution Policy
#
# Background scheduler that reads hardware capabilities + contribution policy,
# computes cooperative role assignments for this node, and publishes to DDS.
#
# Roles computed:
#   compute  — CPU + RAM available for cooperative tasks
#   storage  — Disk space available for cooperative storage
#   relay    — Network relay enabled for DDS federation
#
# HTTP endpoints (Caddy proxies /scheduler/ → localhost:8092):
#   GET /scheduler         — Web UI showing current role assignments
#   GET /scheduler/health  — JSON health check
#   GET /scheduler/roles   — JSON role assignment document
#
# Publishes to DDS:
#   /ntari/scheduler/roles  — std_msgs/String : JSON role assignment document
#
# Watches /ntari/node/policy and /ntari/node/capabilities for changes;
# re-evaluates role assignments automatically when either file is modified.
#
# No external dependencies — Python stdlib only.

import http.server
import json
import math
import os
import signal
import subprocess
import sys
import threading
import time
import urllib.parse

PORT              = int(os.environ.get("NTARI_SCHEDULER_PORT",          "8092"))
CAPABILITIES_FILE = os.environ.get("NTARI_HW_CAPABILITIES",    "/ntari/node/capabilities")
POLICY_FILE       = os.environ.get("NTARI_NODE_POLICY",         "/ntari/node/policy")
ROLES_FILE        = os.environ.get("NTARI_SCHEDULER_ROLES",     "/ntari/scheduler/roles")
EVAL_INTERVAL     = int(os.environ.get("NTARI_SCHEDULER_EVAL_INTERVAL", "30"))
LOG_FILE          = "/var/log/ntari/scheduler.log"

# ── ROS2 environment for DDS publish ─────────────────────────────────────────
ROS2_ENV = {
    **os.environ,
    "AMENT_PREFIX_PATH":  "/usr/ros/jazzy",
    "CMAKE_PREFIX_PATH":  "/usr/ros/jazzy",
    "LD_LIBRARY_PATH":    (
        "/usr/ros/jazzy/lib:/usr/ros/jazzy/lib/x86_64-linux-gnu"
        + (":" + os.environ["LD_LIBRARY_PATH"] if "LD_LIBRARY_PATH" in os.environ else "")
    ),
    "PATH": (
        "/usr/ros/jazzy/bin:/usr/local/sbin:/usr/sbin:/sbin:"
        + os.environ.get("PATH", "")
    ),
    "PYTHONPATH": (
        "/usr/ros/jazzy/lib/python3.12/site-packages"
        + (":" + os.environ["PYTHONPATH"] if "PYTHONPATH" in os.environ else "")
    ),
    "RMW_IMPLEMENTATION": os.environ.get("RMW_IMPLEMENTATION", "rmw_cyclonedds_cpp"),
    "ROS_DOMAIN_ID":      os.environ.get("ROS_DOMAIN_ID", "0"),
    "ROS_VERSION":        "2",
    "ROS_PYTHON_VERSION": "3",
    "ROS_DISTRO":         "jazzy",
}
if os.path.isfile("/etc/ntari/cyclonedds.xml"):
    ROS2_ENV["CYCLONEDDS_URI"] = "file:///etc/ntari/cyclonedds.xml"

# ── Logging ───────────────────────────────────────────────────────────────────
def _log(prefix, msg):
    line = "[ntari-scheduler] {}: {}\n".format(prefix, msg)
    sys.stdout.write(line)
    sys.stdout.flush()
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line)
    except OSError:
        pass

def log(msg):  _log("INFO",  msg)
def warn(msg): _log("WARN",  msg)
def err(msg):  _log("ERROR", msg)

# ── File helpers ──────────────────────────────────────────────────────────────
def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        warn("Cannot read {}: {}".format(path, e))
        return None

def write_json(path, data):
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    os.chmod(path, 0o644)

# ── Default policy ────────────────────────────────────────────────────────────
DEFAULT_POLICY = {
    "schema_version": "1.0",
    "cpu_pct":     25,
    "ram_pct":     20,
    "storage_gb":  0,
    "net_enabled": True,
}

# ── Role assignment ───────────────────────────────────────────────────────────
def assign_roles(caps, policy):
    """Compute cooperative role assignments from hardware capabilities + policy bounds.

    Returns a JSON-serialisable dict describing what cooperative work this
    node will accept, within the limits set by the admin's contribution policy.
    """
    now   = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    caps  = caps or {}
    hw    = caps.get("hardware", {})
    cpu   = hw.get("cpu",     {})
    ram   = hw.get("ram",     {})
    stor  = hw.get("storage", [])
    nets  = hw.get("network", [])

    # ── Hardware facts ────────────────────────────────────────────────────────
    cpu_cores     = int(cpu.get("cores", 1))
    cpu_mhz       = int(cpu.get("mhz",   0))
    ram_total_mb  = int(ram.get("total_mb", 0))
    stor_total_gb = sum(int(d.get("size_gb", 0)) for d in stor)
    net_has_link  = any(i.get("state") == "up" for i in nets)

    # ── Policy limits (validated + clamped) ───────────────────────────────────
    cpu_pct    = max(0, min(80, int(policy.get("cpu_pct",    DEFAULT_POLICY["cpu_pct"]))))
    ram_pct    = max(0, min(50, int(policy.get("ram_pct",    DEFAULT_POLICY["ram_pct"]))))
    storage_gb = max(0, min(stor_total_gb,
                            int(policy.get("storage_gb", DEFAULT_POLICY["storage_gb"]))))
    net_enabled = bool(policy.get("net_enabled", DEFAULT_POLICY["net_enabled"]))

    roles = []

    # ── Compute role: CPU + RAM ───────────────────────────────────────────────
    cores_alloc = int(math.floor(cpu_cores * cpu_pct / 100.0))
    # Always reserve at least 1 core for the OS itself
    if cores_alloc >= cpu_cores:
        cores_alloc = max(0, cpu_cores - 1)
    mhz_alloc = int(cpu_mhz * cpu_pct / 100.0)
    ram_alloc  = int(ram_total_mb * ram_pct / 100.0)
    if cores_alloc > 0 and ram_alloc > 0:
        roles.append({
            "role":                "compute",
            "cpu_cores_allocated": cores_alloc,
            "cpu_mhz_allocated":   mhz_alloc,
            "ram_mb_allocated":    ram_alloc,
        })

    # ── Storage role ──────────────────────────────────────────────────────────
    if storage_gb > 0:
        roles.append({
            "role":                 "storage",
            "storage_gb_allocated": storage_gb,
        })

    # ── Relay role: network bridge for DDS federation ─────────────────────────
    if net_enabled and net_has_link:
        roles.append({
            "role":              "relay",
            "bandwidth_enabled": True,
        })

    summary = " ".join(r["role"] for r in roles) if roles else "none"

    return {
        "schema_version": "1.0",
        "node_uuid":      caps.get("node_uuid", "unknown"),
        "hostname":       caps.get("hostname",  "unknown"),
        "timestamp":      now,
        "policy": {
            "cpu_pct":     cpu_pct,
            "ram_pct":     ram_pct,
            "storage_gb":  storage_gb,
            "net_enabled": net_enabled,
        },
        "hardware_summary": {
            "cpu_cores":        cpu_cores,
            "cpu_mhz":          cpu_mhz,
            "ram_total_mb":     ram_total_mb,
            "storage_total_gb": stor_total_gb,
            "net_link":         net_has_link,
        },
        "roles":   roles,
        "summary": summary,
    }

# ── DDS publish ───────────────────────────────────────────────────────────────
def dds_publish(topic, payload_str):
    """Publish a string payload to a DDS topic via the ros2 CLI."""
    escaped = payload_str.replace("'", "'\\''")
    try:
        subprocess.run(
            ["ros2", "topic", "pub", "--once", topic,
             "std_msgs/msg/String", "{data: '" + escaped + "'}"],
            env=ROS2_ENV, timeout=15,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except Exception as e:
        warn("DDS publish to {} failed: {}".format(topic, e))

# ── Shared state (HTTP thread + eval thread) ──────────────────────────────────
_lock         = threading.Lock()
_roles        = None
_policy_mtime = 0.0
_caps_mtime   = 0.0

def get_roles():
    with _lock:
        return _roles

def set_roles(r):
    global _roles
    with _lock:
        _roles = r

# ── Evaluation loop ───────────────────────────────────────────────────────────
def eval_loop():
    global _policy_mtime, _caps_mtime
    log("Evaluation loop started (interval={}s)".format(EVAL_INTERVAL))
    while True:
        try:
            p_mt = os.path.getmtime(POLICY_FILE)       if os.path.exists(POLICY_FILE)       else 0.0
            c_mt = os.path.getmtime(CAPABILITIES_FILE) if os.path.exists(CAPABILITIES_FILE) else 0.0
            if p_mt != _policy_mtime or c_mt != _caps_mtime:
                _policy_mtime = p_mt
                _caps_mtime   = c_mt
                caps   = read_json(CAPABILITIES_FILE) or {}
                policy = read_json(POLICY_FILE)       or DEFAULT_POLICY
                roles  = assign_roles(caps, policy)
                write_json(ROLES_FILE, roles)
                set_roles(roles)
                payload = json.dumps(roles, separators=(",", ":"))
                dds_publish("/ntari/scheduler/roles", payload)
                log("Roles updated: {}".format(roles["summary"]))
        except Exception as e:
            err("Eval loop error: {}".format(e))
        time.sleep(EVAL_INTERVAL)

# ── HTML rendering ────────────────────────────────────────────────────────────
_ROLE_COLORS = {
    "compute": "#5cb85c",
    "storage": "#f0ad4e",
    "relay":   "#5bc0de",
}

def _role_card(r):
    name  = r.get("role", "?")
    color = _ROLE_COLORS.get(name, "#888888")
    lines = []
    if name == "compute":
        lines = [
            "cores: {}".format(r.get("cpu_cores_allocated", 0)),
            "MHz:   {}".format(r.get("cpu_mhz_allocated",   0)),
            "RAM:   {} MB".format(r.get("ram_mb_allocated",  0)),
        ]
    elif name == "storage":
        lines = ["disk: {} GB".format(r.get("storage_gb_allocated", 0))]
    elif name == "relay":
        lines = ["network relay: enabled"]
    rows = "".join("<div class='det'>{}</div>".format(l) for l in lines)
    return (
        "<div class='card' style='border-top:3px solid {c}'>"
        "<div class='rname' style='color:{c}'>{n}</div>"
        "{rows}</div>"
    ).format(c=color, n=name.upper(), rows=rows)

def render_html(roles):
    if roles is None:
        body  = "<p class='warn'>Waiting for initial role evaluation\u2026</p>"
        title = "starting"
        host  = "ntari-node"
    else:
        role_list = roles.get("roles", [])
        policy    = roles.get("policy", {})
        hw        = roles.get("hardware_summary", {})
        ts        = roles.get("timestamp", "unknown")
        summary   = roles.get("summary", "none")
        host      = roles.get("hostname", "ntari-node")

        if role_list:
            cards = "<div class='cards'>{}</div>".format(
                "".join(_role_card(r) for r in role_list)
            )
        else:
            cards = (
                "<p class='warn'>No cooperative roles assigned. "
                "<a href='/node/policy'>Edit contribution policy</a> to enable roles.</p>"
            )

        body = (
            "<div class='sec'><h2>Active Roles</h2>"
            "<p class='sub'>Last evaluated: {ts}</p>"
            "{cards}</div>"
            "<div class='sec'><h2>Policy Bounds</h2>"
            "<div class='grid'>"
            "<div class='kv'><span>CPU</span><span class='val'>{cpu}%</span></div>"
            "<div class='kv'><span>RAM</span><span class='val'>{ram}%</span></div>"
            "<div class='kv'><span>Storage</span><span class='val'>{stor} GB</span></div>"
            "<div class='kv'><span>Network</span><span class='val'>{net}</span></div>"
            "</div>"
            "<p class='sub'><a href='/node/policy'>Edit contribution policy \u2192</a></p>"
            "</div>"
            "<div class='sec'><h2>Hardware</h2>"
            "<div class='grid'>"
            "<div class='kv'><span>CPU cores</span><span class='val'>{cores}</span></div>"
            "<div class='kv'><span>CPU MHz</span><span class='val'>{mhz}</span></div>"
            "<div class='kv'><span>RAM total</span><span class='val'>{ram_t} MB</span></div>"
            "<div class='kv'><span>Storage</span><span class='val'>{stor_t} GB</span></div>"
            "<div class='kv'><span>Net link</span><span class='val'>{link}</span></div>"
            "</div></div>"
        ).format(
            ts=ts,
            cards=cards,
            cpu=policy.get("cpu_pct",    "?"),
            ram=policy.get("ram_pct",    "?"),
            stor=policy.get("storage_gb","?"),
            net="enabled" if policy.get("net_enabled") else "disabled",
            cores=hw.get("cpu_cores",        "?"),
            mhz=hw.get("cpu_mhz",            "?"),
            ram_t=hw.get("ram_total_mb",     "?"),
            stor_t=hw.get("storage_total_gb","?"),
            link="up" if hw.get("net_link") else "down/unknown",
        )
        title = summary

    # NOTE: literal CSS braces doubled ({{...}}) due to str.format() escaping
    return """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>NTARI OS \u2014 Scheduler [{host}]</title>
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:#0a0a0f;color:#c8c8d4;font:14px/1.6 monospace;padding:2rem}}
h1{{color:#7ec8e3;font-size:1.4rem;margin-bottom:.3rem}}
h2{{color:#aaa;font-size:.9rem;text-transform:uppercase;letter-spacing:.1em;margin-bottom:.8rem}}
a{{color:#7ec8e3}}
.sub{{color:#666;font-size:.85rem;margin-bottom:1rem}}
.warn{{color:#f0ad4e;margin:.5rem 0}}
.sec{{margin-bottom:2rem}}
.cards{{display:flex;flex-wrap:wrap;gap:1rem;margin-bottom:.5rem}}
.card{{background:#12121a;border:1px solid #2a2a3a;border-radius:4px;padding:.8rem 1.2rem;min-width:140px}}
.rname{{font-size:1rem;font-weight:bold;margin-bottom:.3rem}}
.det{{color:#8888a0;font-size:.85rem}}
.grid{{display:grid;grid-template-columns:repeat(2,1fr);gap:.3rem 2rem}}
.kv{{display:flex;justify-content:space-between;padding:.25rem 0;border-bottom:1px solid #1a1a2a}}
.val{{color:#7ec8e3}}
.hdr{{margin-bottom:1.8rem;padding-bottom:1rem;border-bottom:1px solid #1a1a2a}}
.badge{{background:#1a2a1a;color:#5cb85c;border:1px solid #3a5a3a;border-radius:3px;
        padding:.1rem .4rem;font-size:.75rem;margin-left:.6rem}}
</style>
</head>
<body>
<div class="hdr">
  <h1>NTARI OS \u2014 Scheduler <span class="badge">Phase 11</span></h1>
  <p class="sub">Roles: {title}&nbsp;&nbsp;|&nbsp;&nbsp;<a href="/scheduler/roles">JSON</a>&nbsp;&nbsp;|&nbsp;&nbsp;<a href="/scheduler/health">health</a></p>
</div>
{body}
</body>
</html>""".format(host=host, title=title, body=body)

# ── HTTP handler ──────────────────────────────────────────────────────────────
class SchedulerHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        log("HTTP {} {}".format(self.address_string(), fmt % args))

    def _send(self, code, ctype, data):
        body = data.encode("utf-8") if isinstance(data, str) else data
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path.rstrip("/") or "/"

        if path in ("/scheduler", "/scheduler/"):
            self._send(200, "text/html; charset=utf-8", render_html(get_roles()))

        elif path == "/scheduler/health":
            roles = get_roles()
            if roles:
                data = {
                    "status":    "healthy",
                    "roles":     roles.get("summary", "none"),
                    "timestamp": roles.get("timestamp", "unknown"),
                }
                code = 200
            else:
                data = {"status": "starting", "roles": "none"}
                code = 503
            self._send(code, "application/json", json.dumps(data))

        elif path == "/scheduler/roles":
            roles = get_roles()
            if roles:
                self._send(200, "application/json", json.dumps(roles, indent=2))
            else:
                self._send(503, "application/json", '{"error":"not yet evaluated"}')

        else:
            self._send(404, "text/plain", "Not Found\n")

# ── Signal handling ───────────────────────────────────────────────────────────
def _handle_signal(signum, frame):
    log("Signal {}; shutting down".format(signum))
    sys.exit(0)

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    os.makedirs("/ntari/scheduler", exist_ok=True)
    os.makedirs("/var/log/ntari",   exist_ok=True)

    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT,  _handle_signal)

    log("ntari-scheduler starting on port {}".format(PORT))
    log("Policy:       {}".format(POLICY_FILE))
    log("Capabilities: {}".format(CAPABILITIES_FILE))
    log("Roles file:   {}".format(ROLES_FILE))

    # Initial evaluation (best-effort; hw-profile may not have run yet)
    try:
        caps   = read_json(CAPABILITIES_FILE) or {}
        policy = read_json(POLICY_FILE)       or DEFAULT_POLICY
        roles  = assign_roles(caps, policy)
        write_json(ROLES_FILE, roles)
        set_roles(roles)
        dds_publish("/ntari/scheduler/roles",
                    json.dumps(roles, separators=(",", ":")))
        log("Initial role assignment: {}".format(roles["summary"]))
    except Exception as e:
        warn("Initial evaluation failed (will retry in loop): {}".format(e))

    # Background eval thread — watches for policy/capabilities file changes
    threading.Thread(target=eval_loop, daemon=True).start()

    # HTTP server — blocks main thread
    server = http.server.HTTPServer(("0.0.0.0", PORT), SchedulerHandler)
    log("HTTP server listening on 0.0.0.0:{}".format(PORT))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        log("ntari-scheduler stopped")

if __name__ == "__main__":
    main()
