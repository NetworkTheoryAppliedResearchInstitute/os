#!/bin/sh
# NTARI OS Security Hardening Script

set -e

echo "=== Security Hardening ==="

# Remove unnecessary packages
apk del --purge \
	alpine-installer \
	alpine-mirrors

# Update system
apk update
apk upgrade

# Install security tools
apk add --no-cache \
	sudo \
	fail2ban \
	aide \
	logrotate

# Configure sudo (no password for wheel group)
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Secure SSH
cat > /etc/ssh/sshd_config.d/ntari.conf <<EOF
# NTARI OS SSH Security Configuration
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/ssh/sftp-server
EOF

# Secure kernel parameters
cat > /etc/sysctl.d/99-ntari-security.conf <<EOF
# NTARI OS Kernel Security Parameters

# Network hardening
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# IPv6 (disable if not used)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Kernel hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

sysctl -p /etc/sysctl.d/99-ntari-security.conf

# Configure fail2ban for SSH
cat > /etc/fail2ban/jail.d/ntari.conf <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/messages
EOF

rc-update add fail2ban default
rc-service fail2ban start

# File permissions
chmod 700 /root

# Audit logging
cat > /etc/aide/aide.conf <<EOF
# NTARI OS File Integrity Monitoring
database_in=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
database_new=file:/var/lib/aide/aide.db.new
gzip_dbout=yes

# Critical system files
/etc p+i+n+u+g+s+b+m+c+md5+sha256
/bin p+i+n+u+g+s+b+m+c+md5+sha256
/sbin p+i+n+u+g+s+b+m+c+md5+sha256
/usr/bin p+i+n+u+g+s+b+m+c+md5+sha256
/usr/sbin p+i+n+u+g+s+b+m+c+md5+sha256
/var/lib/soholink p+i+n+u+g+s+b+m+c+md5+sha256
EOF

# Initialize AIDE database
aide --init
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

echo "=== Security hardening complete ==="
