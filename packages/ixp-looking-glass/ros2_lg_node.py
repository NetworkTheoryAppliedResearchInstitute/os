#!/usr/bin/python3
"""
NTARI OS — IXP Looking Glass Node (ixp_lg_node)
packages/ixp-looking-glass/ros2_lg_node.py

ROS2 lifecycle node wrapper for the Looking Glass HTTP service.
Starts lg_server.py in a subprocess, patches Caddyfile to expose
/lg/* via the reverse proxy, and publishes health to DDS.

Lifecycle transitions:
  on_configure : read ixp.conf; check if lg is enabled; patch Caddyfile
  on_activate  : start lg_server.py subprocess
  on_deactivate: stop lg_server subprocess
  on_cleanup   : (no-op)

Published topics:
  /ixp/lg/health  — healthy | failed
"""

import configparser
import os
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
LG_SERVER = "/usr/local/bin/ixp-lg-server.py"
CADDYFILE = "/etc/ntari/Caddyfile"


def _read_conf():
    cfg = configparser.ConfigParser()
    cfg.read(IXP_CONF)
    return cfg


def _patch_caddyfile(port):
    """Add /lg/* reverse proxy block to Caddyfile if not already present."""
    if not os.path.exists(CADDYFILE):
        return
    with open(CADDYFILE) as f:
        content = f.read()
    if f"reverse_proxy localhost:{port}" in content:
        return  # idempotent guard
    import tempfile
    tmp = tempfile.mktemp()
    with open(tmp, "w") as f:
        for line in content.splitlines(keepends=True):
            f.write(line)
            if line.strip() == '}' and 'inserted_lg' not in content:
                f.write(f'    # Phase 18: Looking Glass\n')
                f.write(f'    handle /lg* {{\n')
                f.write(f'        reverse_proxy localhost:{port}\n')
                f.write(f'    }}\n')
                content += 'inserted_lg'  # prevent double-insert
    os.replace(tmp, CADDYFILE)


class IxpLgNode(LifecycleNode if _ROS2_AVAILABLE else object):

    def __init__(self):
        if _ROS2_AVAILABLE:
            super().__init__("ixp_lg_node")
        self._cfg = None
        self._proc = None
        self._pub_health = None
        self._health_thread = None
        self._stop_event = threading.Event()

    def on_configure(self, state):
        self._cfg = _read_conf()
        if not self._cfg.getboolean("looking_glass", "enabled", fallback=True):
            self._log("Looking Glass disabled in ixp.conf")
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        port = self._cfg.getint("looking_glass", "port", fallback=5000)
        _patch_caddyfile(port)
        self._log(f"Caddyfile patched for /lg/* → localhost:{port}")

        if _ROS2_AVAILABLE:
            self._pub_health = self.create_publisher(
                String, "/ixp/lg/health", 10)
            return TransitionCallbackReturn.SUCCESS

    def on_activate(self, state):
        if not self._cfg:
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        if not self._cfg.getboolean("looking_glass", "enabled", fallback=True):
            if _ROS2_AVAILABLE:
                return TransitionCallbackReturn.SUCCESS
            return

        port = self._cfg.getint("looking_glass", "port", fallback=5000)
        self._proc = subprocess.Popen(
            [sys.executable, LG_SERVER, "--port", str(port)],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT
        )
        self._log(f"Looking Glass server started (pid={self._proc.pid}, port={port})")

        self._stop_event.clear()
        self._health_thread = threading.Thread(
            target=self._health_loop, daemon=True
        )
        self._health_thread.start()

        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_deactivate(self, state):
        self._stop_event.set()
        if self._proc:
            self._proc.terminate()
            try:
                self._proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._proc.kill()
        if self._health_thread:
            self._health_thread.join(timeout=5)
        self._publish_health("failed", "reason=deactivated")
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def on_cleanup(self, state):
        if _ROS2_AVAILABLE:
            return TransitionCallbackReturn.SUCCESS

    def _health_loop(self):
        interval = 30
        while not self._stop_event.is_set():
            if self._proc and self._proc.poll() is not None:
                self._publish_health("failed", "reason=server_exited")
            else:
                self._publish_health("healthy", "port=5000")
            self._stop_event.wait(interval)

    def _publish(self, publisher, text):
        if _ROS2_AVAILABLE and publisher:
            msg = String()
            msg.data = text
            publisher.publish(msg)

    def _publish_health(self, state, detail=""):
        self._log(f"health={state} {detail}")
        self._publish(self._pub_health, f"{state} {detail}".strip())

    def _log(self, msg):
        print(f"[ixp_lg_node] {msg}", flush=True)


def main():
    if not _ROS2_AVAILABLE:
        node = IxpLgNode()
        node.on_configure(None)
        node.on_activate(None)
        try:
            while True:
                time.sleep(30)
        except KeyboardInterrupt:
            node.on_deactivate(None)
        return

    rclpy.init()
    node = IxpLgNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
