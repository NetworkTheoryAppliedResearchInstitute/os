#!/bin/sh
# NTARI OS — Cooperative Federation Bridge
# Phase 9: Cooperative Federation
#
# Bridges two ROS2 DDS domains across a WireGuard tunnel:
#
#   Domain 0 (local, LAN multicast)    ←→    Domain 1 (federation, WireGuard unicast)
#   ──────────────────────────────────        ─────────────────────────────────────────
#   /ntari/dns/health                          /ntari/cooperative/<uuid>/dns/health
#   /ntari/ntp/health                          /ntari/cooperative/<uuid>/ntp/health
#   /ntari/web/health                          /ntari/cooperative/<uuid>/web/health
#   ... all /ntari/* health topics             namespaced under /ntari/cooperative/<uuid>/
#
# Federation topology:
#   Each cooperative runs domain 0 for its own services (local LAN multicast).
#   Domain 1 is a unicast DDS domain that spans the WireGuard mesh.
#   This bridge script:
#     1. Starts a second ros2 daemon on domain 1 (federation domain)
#     2. Subscribes to /ntari/* health/status topics on domain 0
#     3. Re-publishes them as /ntari/cooperative/<local-uuid>/* on domain 1
#     4. Subscribes to /ntari/cooperative/* on domain 1
#     5. Re-publishes peer cooperative data as /ntari/peers/<peer-uuid>/* on domain 0
#   The globe bridge (Phase 8) then shows all cooperative nodes in one view.
#
# Design constraints (musl / Alpine / busybox):
#   - All bridging uses `ros2 topic echo` + `ros2 topic pub` shell pipelines
#   - No Python node dependencies at this layer (pure sh + ros2 CLI)
#   - One bridge process per topic (supervised by this script)
#   - topic pub uses --once to avoid long-lived processes that could leak memory
#     instead, each bridge loop re-publishes at BRIDGE_INTERVAL
#
# Dependencies:
#   - wireguard-tools (wg, wg-quick)
#   - ros2 CLI + ros2 daemon (both domains)
#   - ntari-vpn service (WireGuard interface wg-ntari must be up)

set -e

# ── Configuration ─────────────────────────────────────────────────────────────
FEDERATION_DOMAIN="${NTARI_FED_DOMAIN:-1}"       # DDS domain for federation
LOCAL_DOMAIN="${ROS_DOMAIN_ID:-0}"               # DDS domain for local services
BRIDGE_INTERVAL="${NTARI_FED_INTERVAL:-5}"       # seconds between bridge cycles
WG_IFACE="${NTARI_VPN_IFACE:-wg-ntari}"
LOG_FILE="${NTARI_FED_LOG:-/var/log/ntari/federation.log}"
PID_DIR="/run/ntari-federation"

# Topics to bridge from local → federation (namespaced under cooperative UUID)
# Each entry is a topic name; health + status variants are bridged automatically.
BRIDGE_TOPICS="
    /ntari/dns/health
    /ntari/dns/status
    /ntari/ntp/health
    /ntari/ntp/status
    /ntari/web/health
    /ntari/web/status
    /ntari/cache/health
    /ntari/cache/status
    /ntari/dhcp/health
    /ntari/dhcp/status
    /ntari/vpn/health
    /ntari/vpn/status
    /ntari/identity/health
    /ntari/identity/status
    /ntari/files/health
    /ntari/files/status
"

log()  { echo "[federation] $(date -u +%H:%M:%S) $*" | tee -a "${LOG_FILE}" >&2; }
ts()   { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown"; }

# ── ROS2 environment ─────────────────────────────────────────────────────────
_setup_ros2_env() {
    export AMENT_PREFIX_PATH="/usr/ros/jazzy"
    export CMAKE_PREFIX_PATH="/usr/ros/jazzy"
    export LD_LIBRARY_PATH="/usr/ros/jazzy/lib:/usr/ros/jazzy/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export PATH="/usr/ros/jazzy/bin:/usr/local/sbin:/usr/sbin:/sbin:${PATH}"
    export PYTHONPATH="/usr/ros/jazzy/lib/python3.12/site-packages${PYTHONPATH:+:$PYTHONPATH}"
    export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}"
    export ROS_VERSION="2"
    export ROS_PYTHON_VERSION="3"
    export ROS_DISTRO="jazzy"
    if [ -f /etc/ntari/cyclonedds.xml ]; then
        export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds.xml"
    fi
}

# ── Read local cooperative UUID ────────────────────────────────────────────────
_local_uuid() {
    if [ -f /var/lib/ntari/identity/node-uuid ]; then
        cat /var/lib/ntari/identity/node-uuid
    else
        # Generate and persist one
        mkdir -p /var/lib/ntari/identity
        UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null \
               || dd if=/dev/urandom bs=16 count=1 2>/dev/null \
                  | od -An -tx1 | tr -d ' \n' \
                  | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')
        echo "${UUID}" > /var/lib/ntari/identity/node-uuid
        echo "${UUID}"
    fi
}

# ── Start federation-domain ROS2 daemon ──────────────────────────────────────
_start_federation_daemon() {
    log "Starting ROS2 daemon on federation domain ${FEDERATION_DOMAIN}"
    _setup_ros2_env
    export ROS_DOMAIN_ID="${FEDERATION_DOMAIN}"

    # Use a separate Cyclone DDS config for the federation domain:
    # - No multicast (WireGuard is point-to-point)
    # - Peers are WireGuard IPs from the federation overlay
    FED_CYCLONE="/etc/ntari/cyclonedds-federation.xml"
    if [ -f "${FED_CYCLONE}" ]; then
        export CYCLONEDDS_URI="file://${FED_CYCLONE}"
    fi

    ros2 daemon start >> "${LOG_FILE}" 2>&1 &
    FED_DAEMON_PID=$!
    echo "${FED_DAEMON_PID}" > "${PID_DIR}/fed-daemon.pid"
    sleep 2
    if ros2 daemon status >> "${LOG_FILE}" 2>&1; then
        log "Federation domain daemon started (PID ${FED_DAEMON_PID})"
    else
        log "WARN: Federation daemon status check failed — may still be starting"
    fi
}

# ── Stop federation-domain ROS2 daemon ───────────────────────────────────────
_stop_federation_daemon() {
    _setup_ros2_env
    export ROS_DOMAIN_ID="${FEDERATION_DOMAIN}"
    ros2 daemon stop >> "${LOG_FILE}" 2>&1 || true
    if [ -f "${PID_DIR}/fed-daemon.pid" ]; then
        kill "$(cat "${PID_DIR}/fed-daemon.pid")" 2>/dev/null || true
        rm -f "${PID_DIR}/fed-daemon.pid"
    fi
}

# ── Bridge a single topic: local domain → federation domain ──────────────────
# Reads most-recent message from local domain, re-publishes under cooperative
# namespace on federation domain.
_bridge_topic_out() {
    LOCAL_TOPIC="$1"
    UUID="$2"

    # Compute federation topic name:
    # /ntari/dns/health → /ntari/cooperative/<uuid>/dns/health
    SUFFIX=$(echo "${LOCAL_TOPIC}" | sed 's|^/ntari/||')
    FED_TOPIC="/ntari/cooperative/${UUID}/${SUFFIX}"

    _setup_ros2_env

    # Read latest message from local domain
    export ROS_DOMAIN_ID="${LOCAL_DOMAIN}"
    MSG=$(timeout 2 ros2 topic echo --once "${LOCAL_TOPIC}" 2>/dev/null \
          | awk '/data:/{found=1} found{print}' | head -5 || echo "")

    if [ -z "${MSG}" ]; then
        return 0  # no message yet, skip
    fi

    # Extract data value (handles both string and numeric)
    DATA=$(echo "${MSG}" | awk '/^data:/{print substr($0, index($0,$2))}' | head -1)
    if [ -z "${DATA}" ]; then
        return 0
    fi

    # Publish to federation domain
    export ROS_DOMAIN_ID="${FEDERATION_DOMAIN}"
    if [ -f /etc/ntari/cyclonedds-federation.xml ]; then
        export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds-federation.xml"
    fi

    ros2 topic pub --once "${FED_TOPIC}" std_msgs/msg/String \
        "{data: '${DATA}'}" >> "${LOG_FILE}" 2>&1 || true
}

# ── Bridge incoming federation topics → local domain ─────────────────────────
# Reads /ntari/cooperative/* from federation domain and re-publishes
# as /ntari/peers/<uuid>/* on local domain so the globe bridge sees peers.
_bridge_topics_in() {
    _setup_ros2_env

    # List topics on federation domain
    export ROS_DOMAIN_ID="${FEDERATION_DOMAIN}"
    if [ -f /etc/ntari/cyclonedds-federation.xml ]; then
        export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds-federation.xml"
    fi

    FED_TOPICS=$(timeout 3 ros2 topic list 2>/dev/null \
                 | grep "^/ntari/cooperative/" || echo "")

    if [ -z "${FED_TOPICS}" ]; then
        return 0
    fi

    for fed_topic in ${FED_TOPICS}; do
        # /ntari/cooperative/<peer-uuid>/dns/health
        # → /ntari/peers/<peer-uuid>/dns/health  (on local domain)
        LOCAL_PEER_TOPIC=$(echo "${fed_topic}" | sed 's|/ntari/cooperative/|/ntari/peers/|')

        MSG=$(timeout 2 ros2 topic echo --once "${fed_topic}" 2>/dev/null \
              | awk '/data:/{found=1} found{print}' | head -5 || echo "")

        [ -z "${MSG}" ] && continue

        DATA=$(echo "${MSG}" | awk '/^data:/{print substr($0, index($0,$2))}' | head -1)
        [ -z "${DATA}" ] && continue

        export ROS_DOMAIN_ID="${LOCAL_DOMAIN}"
        if [ -f /etc/ntari/cyclonedds.xml ]; then
            export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds.xml"
        fi

        ros2 topic pub --once "${LOCAL_PEER_TOPIC}" std_msgs/msg/String \
            "{data: '${DATA}'}" >> "${LOG_FILE}" 2>&1 || true
    done
}

# ── Check WireGuard tunnel health ─────────────────────────────────────────────
_check_tunnel() {
    if ! ip link show "${WG_IFACE}" >/dev/null 2>&1; then
        log "WARN: WireGuard interface ${WG_IFACE} not found — federation inactive"
        return 1
    fi
    PEER_COUNT=$(wg show "${WG_IFACE}" peers 2>/dev/null | wc -l || echo "0")
    if [ "${PEER_COUNT}" -eq 0 ]; then
        log "WARN: No WireGuard peers configured on ${WG_IFACE}"
        return 1
    fi
    # Check at least one peer has received a handshake recently (< 3 minutes)
    LATEST_HS=$(wg show "${WG_IFACE}" latest-handshakes 2>/dev/null \
                | awk '{print $2}' | sort -n | tail -1 || echo "0")
    NOW=$(date +%s 2>/dev/null || echo "0")
    AGE=$(( NOW - LATEST_HS ))
    if [ "${AGE}" -gt 180 ]; then
        log "WARN: Latest WireGuard handshake was ${AGE}s ago (>3min) — tunnel may be stale"
    fi
    return 0
}

# ── Main bridge loop ──────────────────────────────────────────────────────────
_bridge_loop() {
    UUID=$(_local_uuid)
    log "Federation bridge loop started (UUID: ${UUID})"
    log "  Local domain:      ${LOCAL_DOMAIN}"
    log "  Federation domain: ${FEDERATION_DOMAIN}"
    log "  Bridge interval:   ${BRIDGE_INTERVAL}s"
    log "  WireGuard iface:   ${WG_IFACE}"

    # Publish our presence on the federation domain
    _setup_ros2_env
    export ROS_DOMAIN_ID="${FEDERATION_DOMAIN}"
    if [ -f /etc/ntari/cyclonedds-federation.xml ]; then
        export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds-federation.xml"
    fi
    HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
    ros2 topic pub --once "/ntari/cooperative/${UUID}/presence" std_msgs/msg/String \
        "{data: '{\"uuid\":\"${UUID}\",\"hostname\":\"${HOSTNAME}\",\"joined\":\"$(ts)\"}'}" \
        >> "${LOG_FILE}" 2>&1 || true
    log "Presence published to /ntari/cooperative/${UUID}/presence"

    while true; do
        if _check_tunnel; then
            # Outbound: local health → federation
            for topic in ${BRIDGE_TOPICS}; do
                _bridge_topic_out "${topic}" "${UUID}"
            done

            # Inbound: peer federation health → local
            _bridge_topics_in

            # Publish bridge heartbeat on local domain so globe shows federation status
            _setup_ros2_env
            export ROS_DOMAIN_ID="${LOCAL_DOMAIN}"
            if [ -f /etc/ntari/cyclonedds.xml ]; then
                export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds.xml"
            fi
            FED_PEER_COUNT=$(wg show "${WG_IFACE}" peers 2>/dev/null | wc -l || echo "0")
            ros2 topic pub --once "/ntari/federation/health" std_msgs/msg/String \
                "{data: 'healthy'}" >> "${LOG_FILE}" 2>&1 || true
            ros2 topic pub --once "/ntari/federation/status" std_msgs/msg/String \
                "{data: '{\"uuid\":\"${UUID}\",\"peers\":${FED_PEER_COUNT},\"domain\":${FEDERATION_DOMAIN},\"ts\":\"$(ts)\"}'}" \
                >> "${LOG_FILE}" 2>&1 || true
        else
            # Tunnel not ready — publish degraded state locally
            _setup_ros2_env
            export ROS_DOMAIN_ID="${LOCAL_DOMAIN}"
            ros2 topic pub --once "/ntari/federation/health" std_msgs/msg/String \
                "{data: 'degraded'}" >> "${LOG_FILE}" 2>&1 || true
        fi

        sleep "${BRIDGE_INTERVAL}"
    done
}

# ── Subcommands ───────────────────────────────────────────────────────────────
SUBCOMMAND="${1:-start}"
shift || true

case "${SUBCOMMAND}" in
    start)
        mkdir -p "${PID_DIR}"
        mkdir -p /var/log/ntari
        _setup_ros2_env

        log "NTARI Federation Bridge starting"

        # Start federation-domain daemon
        _start_federation_daemon

        # Write federation-domain Cyclone DDS config (unicast, no multicast)
        # Inline — no multicast, bound to WireGuard interface, static peer IPs
        if [ ! -f /etc/ntari/cyclonedds-federation.xml ]; then
            log "Writing federation Cyclone DDS config"
            WG_PEERS=""
            if command -v wg >/dev/null 2>&1 && ip link show "${WG_IFACE}" >/dev/null 2>&1; then
                WG_PEERS=$(wg show "${WG_IFACE}" allowed-ips 2>/dev/null \
                           | awk '{print $2}' | sed 's|/.*||' \
                           | while read -r ip; do
                               echo "          <Peer address=\"${ip}\"/>"
                             done)
            fi
            cat > /etc/ntari/cyclonedds-federation.xml <<FEDXML_EOF
<?xml version="1.0" encoding="UTF-8" ?>
<CycloneDDS>
  <Domain id="any">
    <General>
      <Interfaces>
        <NetworkInterface name="${WG_IFACE}" multicast="false" />
      </Interfaces>
      <AllowMulticast>false</AllowMulticast>
    </General>
    <Discovery>
      <EnableTopicDiscoveryEndpoints>true</EnableTopicDiscoveryEndpoints>
      <Peers>
${WG_PEERS}
        <!-- Add peers manually: <Peer address="10.99.0.X"/> -->
      </Peers>
    </Discovery>
    <Internal>
      <DeliveryQueueMaxSamples>256</DeliveryQueueMaxSamples>
      <MaxMessageSize>65500B</MaxMessageSize>
    </Internal>
    <Tracing>
      <Verbosity>warning</Verbosity>
      <OutputFile>/var/log/ntari/cyclonedds-federation.log</OutputFile>
    </Tracing>
  </Domain>
</CycloneDDS>
FEDXML_EOF
            chmod 640 /etc/ntari/cyclonedds-federation.xml
            log "Federation Cyclone DDS config written"
        fi

        # Start bridge loop (runs in foreground — OpenRC manages as background)
        _bridge_loop
        ;;

    stop)
        log "NTARI Federation Bridge stopping"
        _stop_federation_daemon
        # Kill bridge loop children
        if [ -f "${PID_DIR}/bridge-loop.pid" ]; then
            kill "$(cat "${PID_DIR}/bridge-loop.pid")" 2>/dev/null || true
            rm -f "${PID_DIR}/bridge-loop.pid"
        fi
        ;;

    status)
        _setup_ros2_env
        UUID=$(_local_uuid)
        echo "Federation Bridge Status"
        echo "  UUID:              ${UUID}"
        echo "  WireGuard iface:   ${WG_IFACE}"
        if ip link show "${WG_IFACE}" >/dev/null 2>&1; then
            PEERS=$(wg show "${WG_IFACE}" peers 2>/dev/null | wc -l)
            echo "  WireGuard peers:   ${PEERS}"
        else
            echo "  WireGuard:         interface not found"
        fi
        export ROS_DOMAIN_ID="${FEDERATION_DOMAIN}"
        echo "  Federation domain: ${FEDERATION_DOMAIN}"
        if ros2 daemon status >/dev/null 2>&1; then
            echo "  Federation daemon: running"
            echo "  Peer cooperatives:"
            timeout 3 ros2 topic list 2>/dev/null \
                | grep "^/ntari/cooperative/" \
                | sed 's|/ntari/cooperative/||; s|/.*||' \
                | sort -u \
                | sed 's/^/    /'
        else
            echo "  Federation daemon: not running"
        fi
        ;;

    help|--help|-h)
        cat <<HELP
ntari-federation — NTARI OS Cooperative Federation Bridge

Usage:
  ntari-federation start   — Start the federation bridge (runs in foreground)
  ntari-federation stop    — Stop the federation bridge and federation daemon
  ntari-federation status  — Show tunnel, peer, and domain status

Environment:
  NTARI_FED_DOMAIN   — DDS domain for federation traffic (default: 1)
  NTARI_FED_INTERVAL — Bridge cycle interval in seconds (default: 5)
  NTARI_VPN_IFACE    — WireGuard interface name (default: wg-ntari)
  ROS_DOMAIN_ID      — Local DDS domain (default: 0)

Topics bridged (local → federation):
  /ntari/<svc>/health  → /ntari/cooperative/<uuid>/<svc>/health
  /ntari/<svc>/status  → /ntari/cooperative/<uuid>/<svc>/status

Topics bridged (federation → local):
  /ntari/cooperative/<peer-uuid>/* → /ntari/peers/<peer-uuid>/*

Topics published locally:
  /ntari/federation/health  — overall federation health
  /ntari/federation/status  — JSON with peer count, UUID, timestamp
HELP
        ;;

    *)
        echo "[federation] Unknown subcommand: ${SUBCOMMAND}" >&2
        echo "Run: ntari-federation help" >&2
        exit 1
        ;;
esac
