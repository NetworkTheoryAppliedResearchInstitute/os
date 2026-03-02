#!/bin/sh
# NTARI OS Firewall Configuration

set -e

echo "=== Configuring firewall ==="

# Install iptables
apk add --no-cache iptables ip6tables

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (modify port as needed)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow RADIUS
iptables -A INPUT -p udp --dport 1812 -j ACCEPT  # Auth
iptables -A INPUT -p udp --dport 1813 -j ACCEPT  # Accounting

# Allow federation P2P (future)
# iptables -A INPUT -p tcp --dport 9000 -j ACCEPT

# Allow ping
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Save rules
rc-update add iptables
/etc/init.d/iptables save

echo "Firewall configured"
