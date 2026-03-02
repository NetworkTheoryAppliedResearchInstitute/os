#!/bin/sh
# NTARI OS — ROS2 Node Health Publisher
# Shared script sourced (or exec'd) by every NTARI service OpenRC init.
#
# Usage (from an OpenRC start_post or a supervision loop):
#   ros2-node-health publish <service> <status> [extra_key=value ...]
#   ros2-node-health loop    <service> <interval_seconds>
#
# Topics published:
#   /ntari/<service>/health   — std_msgs/String : "healthy" | "degraded" | "failed"
#   /ntari/<service>/status   — std_msgs/String : JSON blob with detail fields
#
# The "loop" subcommand runs as a background daemon that re-publishes at
# <interval_seconds> frequency by re-reading the service state.  Each service's
# OpenRC init script calls this with ssd (start-stop-daemon) in start_post().
#
# Design note: We publish via `ros2 topic pub --once` rather than maintaining
# a long-running Python node.  This keeps each "publication event" stateless
# and avoids adding a persistent process per service.  The DDS graph cache
# (ros2 daemon) retains the last message, so subscribers that join later still
# see the most recent health state via "transient local" QoS durability.
#
# musl / Alpine compatibility:
#   - Uses /bin/sh (busybox ash), not bash
#   - date +%s is available in busybox
#   - jq is NOT assumed; JSON is hand-built with printf

set -e

ROS2_BIN="/usr/ros/jazzy/bin/ros2"
ROS2_ENV_SETUP="/usr/ros/jazzy/setup.sh"

# ── ROS2 environment (OpenRC does not source /etc/profile.d) ───────────────
_setup_ros2_env() {
    export AMENT_PREFIX_PATH="/usr/ros/jazzy"
    export CMAKE_PREFIX_PATH="/usr/ros/jazzy"
    export LD_LIBRARY_PATH="/usr/ros/jazzy/lib:/usr/ros/jazzy/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export PATH="/usr/ros/jazzy/bin:${PATH}"
    export PYTHONPATH="/usr/ros/jazzy/lib/python3.12/site-packages${PYTHONPATH:+:$PYTHONPATH}"
    export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}"
    export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
    export ROS_VERSION="2"
    export ROS_PYTHON_VERSION="3"
    export ROS_DISTRO="jazzy"
    if [ -f /etc/ntari/cyclonedds.xml ]; then
        export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds.xml"
    fi
}

# ── Validate inputs ─────────────────────────────────────────────────────────
_validate() {
    SERVICE="$1"
    HEALTH_STATE="$2"

    if [ -z "${SERVICE}" ]; then
        echo "[ros2-node-health] ERROR: service name required" >&2
        exit 1
    fi
    if [ -z "${HEALTH_STATE}" ]; then
        echo "[ros2-node-health] ERROR: health state required (healthy|degraded|failed)" >&2
        exit 1
    fi
    case "${HEALTH_STATE}" in
        healthy|degraded|failed) ;;
        *)
            echo "[ros2-node-health] WARN: unknown state '${HEALTH_STATE}'; using 'degraded'" >&2
            HEALTH_STATE="degraded"
            ;;
    esac
}

# ── Build a compact JSON status blob ───────────────────────────────────────
# Extra key=value pairs beyond the standard fields are appended.
_build_status_json() {
    SERVICE="$1"
    HEALTH_STATE="$2"
    shift 2
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
    HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
    NODE_UUID=""
    if [ -f /var/lib/ntari/identity/node-uuid ]; then
        NODE_UUID=$(cat /var/lib/ntari/identity/node-uuid)
    fi

    # Base fields
    JSON="{\"service\":\"${SERVICE}\",\"health\":\"${HEALTH_STATE}\",\"timestamp\":\"${TIMESTAMP}\",\"hostname\":\"${HOSTNAME}\",\"node_uuid\":\"${NODE_UUID}\""

    # Append any extra key=value pairs passed as positional args
    for pair in "$@"; do
        KEY="${pair%%=*}"
        VAL="${pair#*=}"
        # Minimal JSON escaping: replace " with \" and \ with \\
        VAL=$(printf '%s' "${VAL}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        JSON="${JSON},\"${KEY}\":\"${VAL}\""
    done

    JSON="${JSON}}"
    echo "${JSON}"
}

# ── Publish a single health message ────────────────────────────────────────
_publish_once() {
    SERVICE="$1"
    HEALTH_STATE="$2"
    shift 2

    _setup_ros2_env

    if [ ! -f "${ROS2_BIN}" ]; then
        echo "[ros2-node-health] WARN: ros2 binary not found at ${ROS2_BIN} — skipping publish" >&2
        return 0
    fi

    HEALTH_TOPIC="/ntari/${SERVICE}/health"
    STATUS_TOPIC="/ntari/${SERVICE}/status"

    STATUS_JSON=$(_build_status_json "${SERVICE}" "${HEALTH_STATE}" "$@")

    # Publish health string (simple, human-readable)
    "${ROS2_BIN}" topic pub --once \
        "${HEALTH_TOPIC}" \
        std_msgs/msg/String \
        "{data: '${HEALTH_STATE}'}" \
        >/dev/null 2>&1 || true

    # Publish status JSON (machine-readable detail)
    # Single-quote the JSON and escape any single quotes within it.
    SAFE_JSON=$(printf '%s' "${STATUS_JSON}" | sed "s/'/'\\\\''/g")
    "${ROS2_BIN}" topic pub --once \
        "${STATUS_TOPIC}" \
        std_msgs/msg/String \
        "{data: '${SAFE_JSON}'}" \
        >/dev/null 2>&1 || true

    echo "[ros2-node-health] Published ${HEALTH_STATE} → ${HEALTH_TOPIC}" >&2
}

# ── Determine health by checking if a process is running ───────────────────
# Returns: "healthy" if process running, "failed" otherwise.
_check_process_health() {
    PROCESS_NAME="$1"
    if pgrep -x "${PROCESS_NAME}" >/dev/null 2>&1; then
        echo "healthy"
    else
        echo "failed"
    fi
}

# ── Loop subcommand ─────────────────────────────────────────────────────────
# Runs as a daemon.  Publishes health at each interval by re-checking the
# target process and publishing the current state.
# Called from OpenRC start_post via start-stop-daemon.
_loop() {
    SERVICE="$1"
    INTERVAL="${2:-30}"
    PROCESS="${3:-${SERVICE}}"    # Process name to check; defaults to service name

    while true; do
        HEALTH_STATE=$(_check_process_health "${PROCESS}")
        _publish_once "${SERVICE}" "${HEALTH_STATE}" "check=process" "process=${PROCESS}"
        sleep "${INTERVAL}"
    done
}

# ── Main dispatch ───────────────────────────────────────────────────────────
SUBCOMMAND="${1:-help}"
shift || true

case "${SUBCOMMAND}" in
    publish)
        # ros2-node-health publish <service> <state> [key=value ...]
        SERVICE="$1"; shift
        HEALTH_STATE="$1"; shift
        _validate "${SERVICE}" "${HEALTH_STATE}"
        _publish_once "${SERVICE}" "${HEALTH_STATE}" "$@"
        ;;

    loop)
        # ros2-node-health loop <service> <interval> [process_name]
        SERVICE="$1"
        INTERVAL="${2:-30}"
        PROCESS="${3:-$1}"
        _loop "${SERVICE}" "${INTERVAL}" "${PROCESS}"
        ;;

    check)
        # ros2-node-health check <process_name>
        # Returns healthy/failed and exits 0/1 accordingly
        PROCESS="$1"
        HEALTH_STATE=$(_check_process_health "${PROCESS}")
        echo "${HEALTH_STATE}"
        [ "${HEALTH_STATE}" = "healthy" ]
        ;;

    help|--help|-h)
        cat <<'HELP'
ros2-node-health — NTARI OS shared ROS2 health publisher

Usage:
  ros2-node-health publish <service> <state> [key=value ...]
      Publish a single health/status message pair.
      state: healthy | degraded | failed
      Extra key=value pairs are included in the JSON status topic.

  ros2-node-health loop <service> <interval_seconds> [process_name]
      Run a background publish loop.  Checks whether <process_name> is
      running (via pgrep); publishes health at every <interval_seconds>.
      Defaults: interval=30, process_name=service_name.

  ros2-node-health check <process_name>
      Print "healthy" or "failed" and exit 0/1 based on whether
      process_name is currently running.

Topics:
  /ntari/<service>/health  — std_msgs/String : healthy | degraded | failed
  /ntari/<service>/status  — std_msgs/String : JSON detail blob

Examples:
  ros2-node-health publish dns healthy queries=1024
  ros2-node-health loop ntp 30 chronyd
  ros2-node-health check dnsmasq && echo "DNS is up"
HELP
        ;;

    *)
        echo "[ros2-node-health] Unknown subcommand: ${SUBCOMMAND}" >&2
        echo "Run: ros2-node-health help" >&2
        exit 1
        ;;
esac
