#!/bin/sh
# NTARI OS Admin Dashboard

show_menu() {
	clear
	cat << EOF
╔════════════════════════════════════════╗
║         NTARI OS Admin Panel          ║
║  Network Theory Applied Research      ║
║         Institute Operating System     ║
╚════════════════════════════════════════╝

1. System Status
2. Network Configuration
3. User Management
4. Logs Viewer
5. System Update
6. Reboot
7. Shutdown
0. Exit

Enter choice:
EOF
}

system_status() {
	clear
	echo "=== System Status ==="
	echo ""
	uptime
	echo ""
	free -h
	echo ""
	df -h /
	echo ""
	read -p "Press Enter to continue..."
}

# Main loop
while true; do
	show_menu
	read choice

	case $choice in
		1) system_status ;;
		2) nano /etc/network/interfaces ; rc-service networking restart ;;
		3) adduser ;;
		4) tail -f /var/log/messages ;;
		5) apk update && apk upgrade ; read -p "Press Enter..." ;;
		6) reboot ;;
		7) poweroff ;;
		0) exit 0 ;;
		*) echo "Invalid choice" ; sleep 1 ;;
	esac
done
