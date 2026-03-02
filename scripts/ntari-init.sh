#!/bin/sh
# NTARI OS First Boot Initialization Script
# Runs once on first boot to set up NTARI services.
# Edition-aware: detects server vs ros2 and runs appropriate setup.

set -e

NTARI_CONFIG_DIR="/etc/ntari"
NTARI_DATA_DIR="/var/lib/ntari"
NTARI_LOG_DIR="/var/log/ntari"

# Sentinel: if this file exists, init has already run
INIT_DONE_FLAG="${NTARI_DATA_DIR}/.init-complete"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo "${GREEN}[✓]${NC} $*"; }
info() { echo "${BLUE}[→]${NC} $*"; }
warn() { echo "${YELLOW}[!]${NC} $*"; }
err()  { echo "${RED}[✗]${NC} $*"; exit 1; }

echo ""
echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo "${GREEN}  NTARI OS First Boot Initialization${NC}"
echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# ── Detect edition ──────────────────────────────────────────
EDITION="server"
if [ -f "${NTARI_CONFIG_DIR}/version" ]; then
    DETECTED=$(grep "^NTARI_EDITION=" "${NTARI_CONFIG_DIR}/version" | cut -d= -f2)
    if [ -n "${DETECTED}" ]; then
        EDITION="${DETECTED}"
    fi
fi
info "Edition: ${EDITION}"

# ── Guard: skip if already initialized ──────────────────────
if [ -f "${INIT_DONE_FLAG}" ]; then
    log "NTARI OS already initialized (remove ${INIT_DONE_FLAG} to re-run)"
    exit 0
fi

# ── Create NTARI directories ─────────────────────────────────
mkdir -p "${NTARI_CONFIG_DIR}"
mkdir -p "${NTARI_DATA_DIR}"
mkdir -p "${NTARI_LOG_DIR}"
mkdir -p "${NTARI_DATA_DIR}/storage"
mkdir -p "${NTARI_DATA_DIR}/identity"

log "Created NTARI directories"

# ── Generate node UUID ───────────────────────────────────────
if [ ! -f "${NTARI_DATA_DIR}/identity/node-uuid" ]; then
    NODE_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null \
                || tr -dc 'a-f0-9' < /dev/urandom | head -c 32 | \
                   sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')
    echo "${NODE_UUID}" > "${NTARI_DATA_DIR}/identity/node-uuid"
    log "Generated node UUID: ${NODE_UUID}"
fi

NODE_UUID=$(cat "${NTARI_DATA_DIR}/identity/node-uuid")

# ── Create NTARI config ──────────────────────────────────────
if [ ! -f "${NTARI_CONFIG_DIR}/ntari.conf" ]; then
    cat > "${NTARI_CONFIG_DIR}/ntari.conf" <<EOF
# NTARI OS Configuration
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

[node]
uuid = ${NODE_UUID}
hostname = $(hostname)
edition = ${EDITION}

[network]
mdns_enabled = true
web_port = 8080

[ros2]
domain_id = 0
rmw = rmw_cyclonedds_cpp
installed = $([ "${EDITION}" = "ros2" ] && echo "true" || echo "false")

[storage]
data_path = ${NTARI_DATA_DIR}

[logging]
level = info
path = ${NTARI_LOG_DIR}
EOF
    log "Created ${NTARI_CONFIG_DIR}/ntari.conf"
fi

# ── Set permissions ──────────────────────────────────────────
chmod 700 "${NTARI_CONFIG_DIR}"
chmod 700 "${NTARI_DATA_DIR}"
chmod 755 "${NTARI_LOG_DIR}"
log "Set directory permissions"

# ── Enable base OpenRC services ──────────────────────────────
if command -v rc-update >/dev/null 2>&1; then
    for svc in networking chronyd sshd; do
        rc-update add "${svc}" default 2>/dev/null && log "Enabled: ${svc}" || true
    done
fi

# ── ROS2 edition: complete middleware setup ──────────────────
if [ "${EDITION}" = "ros2" ]; then
    echo ""
    echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo "${GREEN}  ROS2 Edition: Running middleware setup               ${NC}"
    echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    SETUP_ROS2="/usr/local/bin/setup-ros2.sh"
    if [ -f "${SETUP_ROS2}" ]; then
        info "Running ${SETUP_ROS2}..."
        # Pass --no-domain-start so OpenRC manages startup, not us
        sh "${SETUP_ROS2}" --no-domain-start
    else
        warn "setup-ros2.sh not found at ${SETUP_ROS2}"
        warn "Run 'setup-ros2' manually to complete ROS2 middleware setup."
        warn "See: /usr/local/share/ntari/ROS2_MUSL_COMPATIBILITY.txt"
    fi
fi

# ── Mark initialization complete ────────────────────────────
date -u +%Y-%m-%dT%H:%M:%SZ > "${INIT_DONE_FLAG}"
log "Initialization complete — flag written: ${INIT_DONE_FLAG}"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo "${GREEN}  NTARI OS Initialized${NC}"
echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "  Node UUID  : ${NODE_UUID}"
echo "  Edition    : ${EDITION}"
echo "  Config     : ${NTARI_CONFIG_DIR}/ntari.conf"
echo "  Data       : ${NTARI_DATA_DIR}"
echo "  Logs       : ${NTARI_LOG_DIR}"
echo ""

if [ "${EDITION}" = "ros2" ]; then
    echo "${BLUE}ROS2 next steps:${NC}"
    echo "  ros2 daemon status        — verify DDS domain is up"
    echo "  ros2 node list            — list active nodes"
    echo "  ros2 topic list           — list active topics"
    echo "  rc-service ros2-domain status"
    echo ""
fi

echo "Run 'ntari-admin' for the admin dashboard."
echo ""
