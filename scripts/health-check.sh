#!/bin/sh
# NTARI OS Health Check

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_service() {
	SERVICE=$1
	if rc-service "$SERVICE" status > /dev/null 2>&1; then
		echo -e "${GREEN}✓${NC} $SERVICE is running"
		return 0
	else
		echo -e "${RED}✗${NC} $SERVICE is NOT running"
		return 1
	fi
}

check_port() {
	PORT=$1
	NAME=$2
	if netstat -tuln | grep -q ":$PORT "; then
		echo -e "${GREEN}✓${NC} $NAME (port $PORT) is listening"
		return 0
	else
		echo -e "${RED}✗${NC} $NAME (port $PORT) is NOT listening"
		return 1
	fi
}

echo "=== NTARI OS Health Check ==="
echo ""

# System info
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Kernel: $(uname -r)"
echo ""

# Service checks
echo "Services:"
check_service soholink
check_service chronyd
check_service sshd
echo ""

# Port checks
echo "Network:"
check_port 22 "SSH"
check_port 1812 "RADIUS Auth"
check_port 1813 "RADIUS Acct"
echo ""

# Disk space
echo "Disk Usage:"
df -h / | tail -1 | awk '{printf "  Root: %s / %s (%s used)\n", $3, $2, $5}'
echo ""

# Memory
echo "Memory:"
free -m | grep Mem | awk '{printf "  %s MB / %s MB (%d%% used)\n", $3, $2, ($3/$2)*100}'
echo ""

# SoHoLINK status
if command -v fedaaa > /dev/null 2>&1; then
	echo "SoHoLINK:"
	fedaaa status 2>/dev/null || echo -e "  ${YELLOW}!${NC} Unable to get status"
	echo ""
fi

# Time sync
echo "Time Synchronization:"
if chronyc tracking 2>/dev/null | grep -q "Leap status.*Normal"; then
	echo -e "  ${GREEN}✓${NC} Time synchronized"
else
	echo -e "  ${YELLOW}!${NC} Time may not be synchronized"
fi
echo ""

echo "=== Health Check Complete ==="
