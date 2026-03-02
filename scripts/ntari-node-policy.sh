#!/usr/bin/python3
# NTARI OS — Node Policy Server (ntari_node_policy_node)
# Phase 10: Hardware Config
#
# Lightweight HTTP server (Python stdlib only) that:
#   - Reads /ntari/node/capabilities (hardware profile)
#   - Manages /ntari/node/policy (admin-configurable contribution policy)
#   - Serves a web UI at GET /node/policy
#   - Handles POST /node/policy to update policy + publish to DDS
#   - Listens on 0.0.0.0:8091 (Caddy reverse-proxies /node/policy/)
#
# No external dependencies — only Python stdlib.

import http.server
import json
import os
import subprocess
import sys
import urllib.parse
import signal

PORT = int(os.environ.get("NTARI_POLICY_PORT", "8091"))
CAPABILITIES_FILE = os.environ.get("NTARI_HW_CAPABILITIES", "/ntari/node/capabilities")
POLICY_FILE       = os.environ.get("NTARI_NODE_POLICY", "/ntari/node/policy")
LOG_FILE          = "/var/log/ntari/policy.log"

# ── ROS2 environment for DDS publish ─────────────────────────────────────────
ROS2_ENV = {
    **os.environ,
    "AMENT_PREFIX_PATH":   "/usr/ros/jazzy",
    "CMAKE_PREFIX_PATH":   "/usr/ros/jazzy",
    "LD_LIBRARY_PATH":     "/usr/ros/jazzy/lib:/usr/ros/jazzy/lib/x86_64-linux-gnu"
                           + (":" + os.environ.get("LD_LIBRARY_PATH", "") if os.environ.get("LD_LIBRARY_PATH") else ""),
    "PATH":                "/usr/ros/jazzy/bin:" + os.environ.get("PATH", "/usr/bin:/bin"),
    "PYTHONPATH":          "/usr/ros/jazzy/lib/python3.12/site-packages"
                           + (":" + os.environ.get("PYTHONPATH", "") if os.environ.get("PYTHONPATH") else ""),
    "RMW_IMPLEMENTATION":  os.environ.get("RMW_IMPLEMENTATION", "rmw_cyclonedds_cpp"),
    "ROS_DOMAIN_ID":       os.environ.get("ROS_DOMAIN_ID", "0"),
    "ROS_DISTRO":          "jazzy",
}

DEFAULT_POLICY = {
    "cpu_pct":     25,
    "ram_pct":     20,
    "storage_gb":   0,
    "net_enabled": True,
    "schema_version": "1.0",
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_json_file(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default

def save_json_file(path, data):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)

def publish_policy_to_dds(policy_data):
    """Publish the policy JSON to /ntari/node/policy via ros2 topic pub."""
    try:
        payload = json.dumps(policy_data, separators=(",", ":")).replace("'", "\\'")
        subprocess.run(
            ["ros2", "topic", "pub", "--once",
             "/ntari/node/policy", "std_msgs/msg/String",
             "{data: '" + payload + "'}"],
            env=ROS2_ENV, capture_output=True, timeout=10
        )
    except Exception:
        pass  # DDS publish is best-effort

def get_caps_summary(caps):
    """Extract a brief human-readable hardware summary from capabilities JSON."""
    hw = caps.get("hardware", {})
    cpu = hw.get("cpu", {})
    ram = hw.get("ram", {})
    storage = hw.get("storage", [])
    net = hw.get("network", [])

    total_storage = sum(d.get("size_gb", 0) for d in storage)
    active_nics = len([n for n in net if n.get("state") == "up"])

    return {
        "cpu_model":     cpu.get("model", "unknown"),
        "cpu_cores":     cpu.get("cores", 0),
        "cpu_mhz":       cpu.get("mhz", 0),
        "ram_total_mb":  ram.get("total_mb", 0),
        "ram_avail_mb":  ram.get("available_mb", 0),
        "storage_total_gb": total_storage,
        "disk_count":    len(storage),
        "nic_count":     len(net),
        "nic_up_count":  active_nics,
    }


# ── HTML template ─────────────────────────────────────────────────────────────

def render_policy_html(caps, policy, node_uuid, hostname):
    summary = get_caps_summary(caps)
    cpu_pct     = int(policy.get("cpu_pct", 25))
    ram_pct     = int(policy.get("ram_pct", 20))
    storage_gb  = int(policy.get("storage_gb", 0))
    net_checked = "checked" if policy.get("net_enabled", True) else ""

    max_storage = max(summary["storage_total_gb"], 0)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>NTARI OS — Node Policy</title>
<style>
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: #0a0a0f;
    color: #c8d8e8;
    font-family: 'JetBrains Mono', 'Courier New', monospace;
    font-size: 14px;
    min-height: 100vh;
    padding: 2rem 1rem;
  }}
  .container {{ max-width: 680px; margin: 0 auto; }}
  header {{ margin-bottom: 2rem; border-bottom: 1px solid #1a2a3a; padding-bottom: 1rem; }}
  header h1 {{ color: #7ecfff; font-size: 1.1rem; letter-spacing: 0.1em; }}
  header p  {{ color: #4a6a8a; font-size: 0.8rem; margin-top: 0.3rem; }}
  .section {{ background: #0f1520; border: 1px solid #1a2a3a; border-radius: 4px;
              padding: 1.2rem; margin-bottom: 1.5rem; }}
  .section h2 {{ color: #5aa0c8; font-size: 0.85rem; letter-spacing: 0.08em;
                 text-transform: uppercase; margin-bottom: 1rem; }}
  .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 0.7rem; }}
  .stat {{ background: #0a0f1a; padding: 0.6rem 0.8rem; border-radius: 3px; }}
  .stat-label {{ color: #3a5a7a; font-size: 0.7rem; text-transform: uppercase;
                 letter-spacing: 0.06em; margin-bottom: 0.2rem; }}
  .stat-value {{ color: #7ecfff; font-size: 0.9rem; }}
  .field {{ margin-bottom: 1.2rem; }}
  .field label {{ display: block; color: #7ecfff; font-size: 0.8rem;
                  margin-bottom: 0.4rem; }}
  .field .desc {{ color: #3a5a7a; font-size: 0.72rem; margin-top: 0.3rem; }}
  input[type=range] {{
    width: 100%; height: 4px; cursor: pointer;
    accent-color: #5aa0c8; background: #1a2a3a;
    border-radius: 2px;
  }}
  input[type=number] {{
    background: #0a0f1a; border: 1px solid #1a2a3a;
    color: #c8d8e8; padding: 0.3rem 0.6rem; border-radius: 3px;
    width: 100px; font-family: inherit;
  }}
  input[type=checkbox] {{ accent-color: #5aa0c8; width: 16px; height: 16px;
                          cursor: pointer; vertical-align: middle; margin-right: 0.4rem; }}
  .range-row {{ display: flex; align-items: center; gap: 0.8rem; }}
  .range-val {{ color: #5aa0c8; min-width: 3em; font-size: 0.9rem; }}
  button[type=submit] {{
    background: #1a3a5a; border: 1px solid #3a6a9a;
    color: #7ecfff; padding: 0.6rem 1.8rem;
    font-family: inherit; font-size: 0.85rem;
    border-radius: 3px; cursor: pointer;
    letter-spacing: 0.06em;
    transition: background 0.15s;
  }}
  button[type=submit]:hover {{ background: #1f4a70; }}
  .saved-notice {{
    background: #0f2a1a; border: 1px solid #1a4a2a;
    color: #5ad88a; padding: 0.5rem 1rem; border-radius: 3px;
    margin-bottom: 1rem; font-size: 0.82rem; display: none;
  }}
  .tag {{ display: inline-block; background: #0a1a2a; color: #3a7aaa;
          padding: 0.1rem 0.4rem; border-radius: 2px; font-size: 0.72rem;
          margin-left: 0.4rem; }}
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>⬡ NTARI OS — Node Policy</h1>
    <p>Node <strong style="color:#5aa0c8">{hostname}</strong>
       &nbsp;·&nbsp; UUID: <code style="color:#3a6a8a">{node_uuid[:8]}…</code></p>
  </header>

  <div class="section">
    <h2>Hardware Summary</h2>
    <div class="grid">
      <div class="stat">
        <div class="stat-label">CPU</div>
        <div class="stat-value">{summary['cpu_cores']} cores
          <span class="tag">{summary['cpu_mhz']} MHz</span></div>
      </div>
      <div class="stat">
        <div class="stat-label">RAM</div>
        <div class="stat-value">{summary['ram_total_mb']:,} MB
          <span class="tag">{summary['ram_avail_mb']:,} avail</span></div>
      </div>
      <div class="stat">
        <div class="stat-label">Storage</div>
        <div class="stat-value">{summary['storage_total_gb']} GB
          <span class="tag">{summary['disk_count']} disk(s)</span></div>
      </div>
      <div class="stat">
        <div class="stat-label">Network</div>
        <div class="stat-value">{summary['nic_count']} NIC(s)
          <span class="tag">{summary['nic_up_count']} up</span></div>
      </div>
    </div>
    <p class="desc" style="margin-top:0.8rem">
      Full profile: <code style="color:#3a6a8a">/ntari/node/capabilities</code>
      &nbsp;·&nbsp; DDS topic: <code style="color:#3a6a8a">/ntari/node/capabilities</code>
    </p>
  </div>

  <form method="POST" action="/node/policy">
    <div class="section">
      <h2>Contribution Policy</h2>
      <p class="desc" style="margin-bottom:1rem">
        Configure how much of this node's resources to contribute to the cooperative network.
        Changes are written to <code style="color:#3a6a8a">/ntari/node/policy</code>
        and published to DDS topic <code style="color:#3a6a8a">/ntari/node/policy</code>.
      </p>

      <div class="field">
        <label for="cpu_pct">CPU Contribution: <span id="cpu_pct_val">{cpu_pct}%</span></label>
        <div class="range-row">
          <input type="range" id="cpu_pct" name="cpu_pct"
                 min="0" max="80" value="{cpu_pct}"
                 oninput="document.getElementById('cpu_pct_val').textContent=this.value+'%'">
        </div>
        <p class="desc">Max % of CPU cores offered to cooperative workloads (0–80%).</p>
      </div>

      <div class="field">
        <label for="ram_pct">RAM Contribution: <span id="ram_pct_val">{ram_pct}%</span></label>
        <div class="range-row">
          <input type="range" id="ram_pct" name="ram_pct"
                 min="0" max="50" value="{ram_pct}"
                 oninput="document.getElementById('ram_pct_val').textContent=this.value+'%'">
        </div>
        <p class="desc">Max % of total RAM offered to cooperative workloads (0–50%).</p>
      </div>

      <div class="field">
        <label for="storage_gb">Storage Contribution (GB)</label>
        <input type="number" id="storage_gb" name="storage_gb"
               min="0" max="{max_storage}" value="{storage_gb}" step="1">
        <p class="desc">GB of local storage offered. Available: {max_storage} GB.</p>
      </div>

      <div class="field">
        <label>
          <input type="checkbox" name="net_enabled" value="1" {net_checked}>
          Enable Network Contribution
        </label>
        <p class="desc">Allow cooperative routing and bandwidth sharing via WireGuard.</p>
      </div>

      <button type="submit">Save Policy</button>
    </div>
  </form>

  <div class="section">
    <h2>Current Policy</h2>
    <pre style="color:#3a6a8a;font-size:0.78rem;white-space:pre-wrap">{json.dumps(policy, indent=2)}</pre>
  </div>
</div>
</body>
</html>"""


# ── HTTP Handler ──────────────────────────────────────────────────────────────

class PolicyHandler(http.server.BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        """Redirect access log to file."""
        try:
            with open(LOG_FILE, "a") as f:
                f.write(f"[policy] {self.address_string()} - {fmt % args}\n")
        except Exception:
            pass

    def send_json(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_html(self, html):
        body = html.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/")
        if path in ("/node/policy", ""):
            caps    = load_json_file(CAPABILITIES_FILE, {})
            policy  = load_json_file(POLICY_FILE, DEFAULT_POLICY)
            uuid    = caps.get("node_uuid", "unknown")
            host    = caps.get("hostname", "ntari-node")
            self.send_html(render_policy_html(caps, policy, uuid, host))
        elif path == "/node/policy/health":
            self.send_json(200, {"status": "ok", "service": "ntari-node-policy"})
        else:
            self.send_json(404, {"error": "not found"})

    def do_POST(self):
        path = self.path.split("?")[0].rstrip("/")
        if path != "/node/policy":
            self.send_json(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", 0))
        body   = self.rfile.read(length).decode(errors="replace")
        params = urllib.parse.parse_qs(body, keep_blank_values=True)

        def _int(key, default, lo, hi):
            try:
                v = int(params.get(key, [str(default)])[0])
                return max(lo, min(hi, v))
            except Exception:
                return default

        caps = load_json_file(CAPABILITIES_FILE, {})
        max_storage = max(
            sum(d.get("size_gb", 0)
                for d in caps.get("hardware", {}).get("storage", [])),
            0
        )

        new_policy = {
            "schema_version": "1.0",
            "cpu_pct":     _int("cpu_pct",    25,  0, 80),
            "ram_pct":     _int("ram_pct",    20,  0, 50),
            "storage_gb":  _int("storage_gb",  0,  0, max_storage),
            "net_enabled": "net_enabled" in params,
        }

        save_json_file(POLICY_FILE, new_policy)
        publish_policy_to_dds(new_policy)

        # Redirect back to the policy page (POST-redirect-GET pattern)
        self.send_response(303)
        self.send_header("Location", "/node/policy?saved=1")
        self.send_header("Content-Length", "0")
        self.end_headers()


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    os.makedirs(os.path.dirname(POLICY_FILE) or ".", exist_ok=True)
    os.makedirs(os.path.dirname(LOG_FILE)    or ".", exist_ok=True)

    # Write default policy if absent
    if not os.path.exists(POLICY_FILE):
        save_json_file(POLICY_FILE, DEFAULT_POLICY)

    server = http.server.HTTPServer(("0.0.0.0", PORT), PolicyHandler)

    def _shutdown(signum, frame):
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT,  _shutdown)

    print(f"[ntari-node-policy] Listening on 0.0.0.0:{PORT}", flush=True)
    print(f"[ntari-node-policy] Policy file: {POLICY_FILE}",   flush=True)
    print(f"[ntari-node-policy] Capabilities: {CAPABILITIES_FILE}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
