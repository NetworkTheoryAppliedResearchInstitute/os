#!/bin/sh
# NTARI OS Command Line Interface
# Main CLI tool for NTARI OS management

VERSION="1.0.0"
NTARI_CONFIG="/etc/ntari/ntari.conf"
NTARI_DATA="/var/lib/ntari"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Box drawing characters
BOX_TL="╔"
BOX_TR="╗"
BOX_BL="╚"
BOX_BR="╝"
BOX_H="═"
BOX_V="║"

# Functions
show_header() {
    clear
    echo "${GREEN}${BOX_TL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_TR}${NC}"
    echo "${GREEN}${BOX_V} NTARI OS v${VERSION}                    $(hostname)    [⚙ Settings]  ${BOX_V}${NC}"
    echo "${GREEN}${BOX_BL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_BR}${NC}"
    echo ""
}

show_status() {
    show_header

    # Get node UUID
    if [ -f "${NTARI_DATA}/identity/node-uuid" ]; then
        NODE_UUID=$(cat "${NTARI_DATA}/identity/node-uuid")
    else
        NODE_UUID="Not initialized"
    fi

    # Get uptime
    UPTIME=$(uptime -p 2>/dev/null || echo "unknown")

    # Check services
    check_service_status "ntari-network" NETWORK_STATUS
    check_service_status "ntari-storage" STORAGE_STATUS

    echo "${BLUE}● ONLINE${NC}  ${UPTIME}"
    echo "Node UUID: ${NODE_UUID:0:8}...${NODE_UUID:24:12}"
    echo ""
    echo "${YELLOW}Services:${NC}"
    echo "  Network Daemon: ${NETWORK_STATUS}"
    echo "  Storage Daemon: ${STORAGE_STATUS}"
    echo ""
    echo "${YELLOW}Resources:${NC}"

    # CPU
    CPU_COUNT=$(nproc 2>/dev/null || echo "1")
    LOAD_AVG=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "0.0")
    echo "  CPU: ${CPU_COUNT} cores, load: ${LOAD_AVG}"

    # Memory
    MEM_INFO=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}' || echo "unknown")
    echo "  RAM: ${MEM_INFO}"

    # Disk
    DISK_INFO=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}' || echo "unknown")
    echo "  Disk: ${DISK_INFO}"

    echo ""
    echo "${YELLOW}Quick Actions:${NC}"
    echo "  [S]tatus  [N]etwork  [J]obs  [H]ardware  [L]ogs  [Q]uit"
    echo ""
}

check_service_status() {
    service_name=$1
    if rc-service "${service_name}" status >/dev/null 2>&1; then
        eval "$2='${GREEN}● Running${NC}'"
    else
        eval "$2='${RED}○ Stopped${NC}'"
    fi
}

show_network_status() {
    show_header
    echo "${YELLOW}Network Status${NC}"
    echo "────────────────────────────────────────────────────────"
    echo ""

    # Network interfaces
    echo "${BLUE}Interfaces:${NC}"
    ip -brief addr show 2>/dev/null || echo "  Unable to query interfaces"
    echo ""

    # P2P status
    echo "${BLUE}P2P Network:${NC}"
    if [ -f "${NTARI_DATA}/p2p/peers.json" ]; then
        PEER_COUNT=$(cat "${NTARI_DATA}/p2p/peers.json" | grep -c "peer_id" 2>/dev/null || echo "0")
        echo "  Connected Peers: ${PEER_COUNT}"
    else
        echo "  Not connected (daemon not running)"
    fi
    echo ""

    # Internet connectivity
    echo "${BLUE}Internet:${NC}"
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo "  ${GREEN}✓${NC} Connected"
    else
        echo "  ${RED}✗${NC} No connection"
    fi
    echo ""

    read -p "Press Enter to continue..."
}

show_hardware() {
    show_header
    echo "${YELLOW}Hardware Information${NC}"
    echo "────────────────────────────────────────────────────────"
    echo ""

    # CPU
    echo "${BLUE}CPU:${NC}"
    if [ -f /proc/cpuinfo ]; then
        grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*/  /'
        echo "  Cores: $(nproc)"
    fi
    echo ""

    # Memory
    echo "${BLUE}Memory:${NC}"
    free -h | awk 'NR==2 {print "  Total: " $2 ", Used: " $3 ", Free: " $4}'
    echo ""

    # Storage
    echo "${BLUE}Storage:${NC}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null | head -10 || echo "  Unable to query storage"
    echo ""

    read -p "Press Enter to continue..."
}

show_logs() {
    show_header
    echo "${YELLOW}Recent Logs${NC}"
    echo "────────────────────────────────────────────────────────"
    echo ""

    if [ -d "${NTARI_DATA}/../log/ntari" ]; then
        tail -n 20 /var/log/ntari/*.log 2>/dev/null || echo "  No logs found"
    else
        echo "  Log directory not found"
    fi
    echo ""

    read -p "Press Enter to continue..."
}

show_help() {
    cat <<EOF
NTARI OS Command Line Interface v${VERSION}

Usage: ntari [command] [options]

Commands:
  status              Show system status dashboard (default)
  network             Show network status and P2P connections
  network test        Test internet connectivity
  network diagnose    Run full network diagnostics
  jobs                Show available jobs and marketplace
  hardware            Show hardware information
  logs                View recent system logs
  version             Show version information
  help                Show this help message

Dashboard Controls (when running 'ntari status'):
  S - Status          Refresh status
  N - Network         Network status
  J - Jobs            Job marketplace
  H - Hardware        Hardware info
  L - Logs            View logs
  Q - Quit            Exit

Examples:
  ntari                    # Launch interactive dashboard
  ntari status             # Show status and exit
  ntari network test       # Test connectivity
  ntari logs               # View logs

Configuration: ${NTARI_CONFIG}
Data Directory: ${NTARI_DATA}

For more information: https://ntari.org/docs
EOF
}

show_version() {
    echo "NTARI OS v${VERSION}"
    echo "Alpine Linux $(cat /etc/alpine-release 2>/dev/null || echo 'unknown')"
    if [ -f "${NTARI_DATA}/identity/node-uuid" ]; then
        echo "Node UUID: $(cat ${NTARI_DATA}/identity/node-uuid)"
    fi
}

# Main command dispatcher
case "${1}" in
    status|"")
        show_status
        ;;
    network)
        case "${2}" in
            test)
                echo "Testing network connectivity..."
                ping -c 4 8.8.8.8
                ;;
            diagnose)
                echo "Running full network diagnostics..."
                echo "This feature will be implemented in Phase 2"
                ;;
            *)
                show_network_status
                ;;
        esac
        ;;
    hardware)
        show_hardware
        ;;
    logs)
        show_logs
        ;;
    version)
        show_version
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "${RED}Error:${NC} Unknown command: ${1}"
        echo "Run 'ntari help' for usage information"
        exit 1
        ;;
esac
