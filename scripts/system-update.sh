#!/bin/sh
# NTARI OS System Update Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== NTARI OS System Update ==="
echo ""

# Check for updates
apk update
UPDATES=$(apk version -l '<' | wc -l)

if [ "$UPDATES" -eq 0 ]; then
	echo -e "${GREEN}System is up to date${NC}"
	exit 0
fi

echo -e "${YELLOW}$UPDATES updates available:${NC}"
echo ""
apk version -l '<'
echo ""

# Ask for confirmation
read -p "Apply updates? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
	echo "Update cancelled"
	exit 0
fi

# Create backup point
echo "Creating system snapshot..."
tar czf "/root/backup-$(date +%Y%m%d-%H%M%S).tar.gz" \
	/etc \
	/var/lib/soholink \
	2>/dev/null || true

# Apply updates
echo "Applying updates..."
apk upgrade

# Check critical services
echo "Verifying services..."
for SERVICE in soholink chronyd sshd; do
	if rc-service "$SERVICE" status > /dev/null 2>&1; then
		echo -e "  ${GREEN}✓${NC} $SERVICE"
	else
		echo -e "  ${RED}✗${NC} $SERVICE - attempting restart"
		rc-service "$SERVICE" restart
	fi
done

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo "Backup saved to: /root/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
echo ""
echo "Review logs and consider rebooting:"
echo "  reboot"
