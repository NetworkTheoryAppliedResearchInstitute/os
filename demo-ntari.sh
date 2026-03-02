#!/bin/bash
# NTARI OS Interactive Demo
# Simulates the NTARI OS environment without requiring installation

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

show_banner() {
	echo -e "${BLUE}"
	cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              ███╗   ██╗████████╗ █████╗ ██████╗ ██╗         ║
║              ████╗  ██║╚══██╔══╝██╔══██╗██╔══██╗██║         ║
║              ██╔██╗ ██║   ██║   ███████║██████╔╝██║         ║
║              ██║╚██╗██║   ██║   ██╔══██║██╔══██╗██║         ║
║              ██║ ╚████║   ██║   ██║  ██║██║  ██║██║         ║
║              ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝         ║
║                                                              ║
║                  Operating System v1.0.0-alpha              ║
║        Network Theory Applied Research Institute            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
	echo -e "${NC}"
}

show_system_info() {
	echo -e "${CYAN}=== System Information ===${NC}"
	echo ""
	echo -e "${GREEN}OS:${NC}           NTARI OS 1.0.0-alpha"
	echo -e "${GREEN}Base:${NC}         Alpine Linux 3.19"
	echo -e "${GREEN}Kernel:${NC}       Linux 6.6.x (hardened)"
	echo -e "${GREEN}Init:${NC}         OpenRC"
	echo -e "${GREEN}Hostname:${NC}     ntari-node-$(hostname)"
	echo -e "${GREEN}Architecture:${NC} x86_64"
	echo ""
	echo -e "${GREEN}Services:${NC}"
	echo "  • SoHoLINK AAA (RADIUS) - Ready"
	echo "  • Chrony (NTP) - Synchronized"
	echo "  • OpenSSH - Running"
	echo "  • fail2ban - Active"
	echo "  • Firewall - Enabled"
	echo ""
}

show_features() {
	echo -e "${CYAN}=== Key Features ===${NC}"
	echo ""
	echo "✓ Minimal Footprint (<100MB)"
	echo "✓ Offline-First Architecture"
	echo "✓ Security Hardened by Default"
	echo "✓ Federation-Ready (P2P)"
	echo "✓ RADIUS Authentication Server"
	echo "✓ Automated Updates"
	echo "✓ Health Monitoring"
	echo ""
}

show_network_status() {
	echo -e "${CYAN}=== Network Status ===${NC}"
	echo ""
	echo -e "${GREEN}Interface:${NC}    eth0"
	echo -e "${GREEN}IP Address:${NC}  192.168.1.100 (example)"
	echo -e "${GREEN}Gateway:${NC}     192.168.1.1"
	echo -e "${GREEN}DNS:${NC}         1.1.1.1, 8.8.8.8"
	echo ""
	echo -e "${GREEN}Firewall Rules:${NC}"
	echo "  • SSH (22/TCP) - ALLOW"
	echo "  • RADIUS Auth (1812/UDP) - ALLOW"
	echo "  • RADIUS Acct (1813/UDP) - ALLOW"
	echo "  • All others - DROP (default)"
	echo ""
}

show_soholink_status() {
	echo -e "${CYAN}=== SoHoLINK Status ===${NC}"
	echo ""
	echo -e "${GREEN}Service:${NC}      Running"
	echo -e "${GREEN}Database:${NC}     SQLite (/var/lib/soholink/node.db)"
	echo -e "${GREEN}Users:${NC}        0 active users"
	echo -e "${GREEN}Policies:${NC}     Default policies loaded"
	echo -e "${GREEN}Last Auth:${NC}    N/A"
	echo ""
}

show_available_commands() {
	echo -e "${CYAN}=== Available Commands ===${NC}"
	echo ""
	echo -e "${YELLOW}System Management:${NC}"
	echo "  health-check.sh       - Run system health check"
	echo "  ntari-admin.sh        - Interactive admin dashboard"
	echo "  system-update.sh      - Check and apply updates"
	echo ""
	echo -e "${YELLOW}SoHoLINK Management:${NC}"
	echo "  fedaaa status         - Check SoHoLINK status"
	echo "  fedaaa users list     - List RADIUS users"
	echo "  fedaaa users add      - Add new user"
	echo ""
	echo -e "${YELLOW}Network Management:${NC}"
	echo "  setup-firewall.sh     - Configure firewall"
	echo "  setup-time.sh         - Configure NTP sync"
	echo ""
	echo -e "${YELLOW}Security:${NC}"
	echo "  harden-system.sh      - Apply security hardening"
	echo ""
}

show_project_stats() {
	echo -e "${CYAN}=== Project Statistics ===${NC}"
	echo ""

	SCRIPT_COUNT=$(find scripts/ -name "*.sh" -type f 2>/dev/null | wc -l)
	CONFIG_COUNT=$(find config/ -type f 2>/dev/null | wc -l)
	DOC_COUNT=$(find docs/ -name "*.md" -type f 2>/dev/null | wc -l)

	echo -e "${GREEN}Scripts:${NC}        $SCRIPT_COUNT shell scripts"
	echo -e "${GREEN}Configs:${NC}        $CONFIG_COUNT configuration files"
	echo -e "${GREEN}Docs:${NC}           $DOC_COUNT documentation files"
	echo -e "${GREEN}Total Files:${NC}    $(find . -type f 2>/dev/null | wc -l) files"
	echo ""

	if [ -f "STATUS.md" ]; then
		echo -e "${GREEN}Phase 1:${NC}        90% Complete"
		echo -e "${GREEN}Phase 2:${NC}        70% Complete"
		echo -e "${GREEN}Overall:${NC}        Infrastructure Ready"
	fi
	echo ""
}

demo_health_check() {
	echo -e "${CYAN}=== Running Health Check ===${NC}"
	echo ""
	sleep 1

	echo -e "${GREEN}✓${NC} SoHoLINK service is running"
	sleep 0.5
	echo -e "${GREEN}✓${NC} Chrony NTP is synchronized"
	sleep 0.5
	echo -e "${GREEN}✓${NC} SSH daemon is running"
	sleep 0.5
	echo -e "${GREEN}✓${NC} Firewall is active"
	sleep 0.5
	echo -e "${GREEN}✓${NC} Disk usage: 15% (healthy)"
	sleep 0.5
	echo -e "${GREEN}✓${NC} Memory usage: 125MB / 512MB (24%)"
	sleep 0.5
	echo -e "${GREEN}✓${NC} Time synchronized"
	sleep 0.5

	echo ""
	echo -e "${GREEN}All systems operational!${NC}"
	echo ""
}

show_menu() {
	echo -e "${YELLOW}=== NTARI OS Demo Menu ===${NC}"
	echo ""
	echo "1. Show System Information"
	echo "2. Show Network Status"
	echo "3. Show SoHoLINK Status"
	echo "4. Run Health Check"
	echo "5. Show Available Commands"
	echo "6. Show Project Statistics"
	echo "7. View Documentation"
	echo "8. Exit Demo"
	echo ""
	echo -n "Select option (1-8): "
}

view_documentation() {
	echo -e "${CYAN}=== Available Documentation ===${NC}"
	echo ""
	echo "1. README.md - Project Overview"
	echo "2. QUICKSTART.md - Quick Start Guide"
	echo "3. docs/INSTALL.md - Installation Guide"
	echo "4. docs/OPERATIONS.md - Operations Manual"
	echo "5. docs/ARCHITECTURE.md - System Architecture"
	echo "6. STATUS.md - Project Status"
	echo "7. Back to menu"
	echo ""
	echo -n "Select document to view (1-7): "
	read doc_choice

	case $doc_choice in
		1) less README.md || cat README.md | head -50 ;;
		2) less QUICKSTART.md || cat QUICKSTART.md | head -50 ;;
		3) less docs/INSTALL.md || cat docs/INSTALL.md | head -50 ;;
		4) less docs/OPERATIONS.md || cat docs/OPERATIONS.md | head -50 ;;
		5) less docs/ARCHITECTURE.md || cat docs/ARCHITECTURE.md | head -50 ;;
		6) less STATUS.md || cat STATUS.md | head -50 ;;
		7) return ;;
	esac

	echo ""
	read -p "Press Enter to continue..."
}

# Main demo loop
show_banner
echo ""
show_system_info
show_features

while true; do
	echo ""
	show_menu
	read choice
	echo ""

	case $choice in
		1)
			show_system_info
			read -p "Press Enter to continue..."
			;;
		2)
			show_network_status
			read -p "Press Enter to continue..."
			;;
		3)
			show_soholink_status
			read -p "Press Enter to continue..."
			;;
		4)
			demo_health_check
			read -p "Press Enter to continue..."
			;;
		5)
			show_available_commands
			read -p "Press Enter to continue..."
			;;
		6)
			show_project_stats
			read -p "Press Enter to continue..."
			;;
		7)
			view_documentation
			;;
		8)
			echo -e "${GREEN}Thank you for exploring NTARI OS!${NC}"
			echo ""
			echo "Next steps:"
			echo "  • Install Docker Desktop to build the ISO"
			echo "  • Read QUICKSTART.md for build instructions"
			echo "  • Check STATUS.md for project status"
			echo ""
			exit 0
			;;
		*)
			echo -e "${YELLOW}Invalid option. Please select 1-8.${NC}"
			sleep 1
			;;
	esac
done
