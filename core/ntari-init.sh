#!/bin/sh
# NTARI OS First Boot Initialization Script
# Runs once on first boot to set up NTARI services

set -e

NTARI_CONFIG_DIR="/etc/ntari"
NTARI_DATA_DIR="/var/lib/ntari"
NTARI_LOG_DIR="/var/log/ntari"
NTARI_BIN_DIR="/usr/bin"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo "${GREEN}  NTARI OS First Boot Initialization${NC}"
echo "${GREEN}═══════════════════════════════════════════════════════${NC}"

# Create NTARI directories
mkdir -p "${NTARI_CONFIG_DIR}"
mkdir -p "${NTARI_DATA_DIR}"
mkdir -p "${NTARI_LOG_DIR}"
mkdir -p "${NTARI_DATA_DIR}/storage"
mkdir -p "${NTARI_DATA_DIR}/p2p"
mkdir -p "${NTARI_DATA_DIR}/identity"

echo "${GREEN}✓${NC} Created NTARI directories"

# Generate node UUID
if [ ! -f "${NTARI_DATA_DIR}/identity/node-uuid" ]; then
    NODE_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "${NODE_UUID}" > "${NTARI_DATA_DIR}/identity/node-uuid"
    echo "${GREEN}✓${NC} Generated node UUID: ${NODE_UUID}"
fi

# Create default configuration
if [ ! -f "${NTARI_CONFIG_DIR}/ntari.conf" ]; then
    cat > "${NTARI_CONFIG_DIR}/ntari.conf" <<EOF
# NTARI OS Configuration
# Generated: $(date)

[node]
uuid = $(cat ${NTARI_DATA_DIR}/identity/node-uuid)
hostname = $(hostname)
edition = server

[network]
p2p_enabled = true
p2p_port = 9000
web_dashboard_port = 8080

[storage]
tier1_enabled = true
tier2_enabled = true
tier3_enabled = false
tier1_path = ${NTARI_DATA_DIR}/storage/tier1
tier2_path = ${NTARI_DATA_DIR}/storage/tier2

[logging]
level = info
path = ${NTARI_LOG_DIR}
EOF
    echo "${GREEN}✓${NC} Created default configuration"
fi

# Set permissions
chmod 700 "${NTARI_CONFIG_DIR}"
chmod 700 "${NTARI_DATA_DIR}"
chmod 755 "${NTARI_LOG_DIR}"

echo "${GREEN}✓${NC} Set directory permissions"

# Enable NTARI services
if command -v rc-update >/dev/null 2>&1; then
    # OpenRC
    rc-update add ntari-network default || true
    rc-update add ntari-storage default || true
    echo "${GREEN}✓${NC} Enabled NTARI services"
fi

echo ""
echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo "${GREEN}  NTARI OS Initialized${NC}"
echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Node UUID: $(cat ${NTARI_DATA_DIR}/identity/node-uuid)"
echo "Configuration: ${NTARI_CONFIG_DIR}/ntari.conf"
echo "Data Directory: ${NTARI_DATA_DIR}"
echo ""
echo "Run 'ntari status' to check system status"
echo ""
