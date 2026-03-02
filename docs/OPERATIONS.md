# NTARI OS Operations Guide

This guide covers day-to-day operation and maintenance of NTARI OS.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [User Management](#user-management)
3. [SoHoLINK Management](#soholink-management)
4. [Network Management](#network-management)
5. [Monitoring](#monitoring)
6. [Backup and Recovery](#backup-and-recovery)
7. [Updates](#updates)
8. [Troubleshooting](#troubleshooting)

## Daily Operations

### System Status Check

Check overall system health:

```bash
/usr/local/bin/health-check.sh
```

### Admin Dashboard

Access the interactive admin menu:

```bash
/usr/local/bin/ntari-admin.sh
```

### Service Management

Check service status:

```bash
rc-service soholink status
rc-service chronyd status
rc-service sshd status
```

Restart a service:

```bash
rc-service soholink restart
```

## User Management

### System Users

Create a new system user:

```bash
adduser username
```

Add user to admin group:

```bash
adduser username wheel
```

Change user password:

```bash
passwd username
```

Delete a user:

```bash
deluser username
```

### SSH Key Management

Add SSH key for a user:

```bash
# As the user
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## SoHoLINK Management

### Check SoHoLINK Status

```bash
fedaaa status
```

### User Management

Add a RADIUS user:

```bash
fedaaa users add <username>
```

List all users:

```bash
fedaaa users list
```

Revoke a user:

```bash
fedaaa users revoke <username>
```

### Policy Management

Policies are stored in `/etc/soholink/policies/`

Add a new policy:

```bash
nano /etc/soholink/policies/my-policy.yaml
```

Reload policies:

```bash
rc-service soholink reload
```

### View Logs

Real-time logs:

```bash
tail -f /var/log/soholink/soholink.log
```

Search logs:

```bash
grep "authentication" /var/log/soholink/soholink.log
```

### Configuration

Edit main configuration:

```bash
nano /etc/soholink/config.yaml
rc-service soholink restart
```

## Network Management

### Check Network Status

View interfaces:

```bash
ip addr show
```

View routing table:

```bash
ip route show
```

Test connectivity:

```bash
ping -c 4 8.8.8.8
```

### Change IP Address

Edit network configuration:

```bash
nano /etc/network/interfaces
```

Apply changes:

```bash
rc-service networking restart
```

### Firewall Management

View current rules:

```bash
iptables -L -n -v
```

Edit firewall rules:

```bash
nano /etc/iptables/rules-save
rc-service iptables restart
```

Add a temporary rule:

```bash
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

Save permanent rule:

```bash
/etc/init.d/iptables save
```

### DNS Configuration

Edit DNS servers:

```bash
nano /etc/resolv.conf
```

Test DNS resolution:

```bash
nslookup google.com
dig google.com
```

## Monitoring

### System Resources

Check CPU and memory:

```bash
top
```

Check disk usage:

```bash
df -h
```

Check disk I/O:

```bash
iostat
```

### Network Traffic

View active connections:

```bash
netstat -tuln
```

Monitor network traffic:

```bash
iftop  # If installed
```

### Logs

System logs:

```bash
tail -f /var/log/messages
```

Authentication logs:

```bash
tail -f /var/log/secure
```

RADIUS logs:

```bash
tail -f /var/log/soholink/soholink.log
```

### Time Synchronization

Check NTP status:

```bash
chronyc tracking
chronyc sources
```

Force time sync:

```bash
chronyc makestep
```

## Backup and Recovery

### What to Backup

Critical directories:
- `/etc/` - System configuration
- `/var/lib/soholink/` - SoHoLINK database and data
- `/home/` - User data (if applicable)

### Manual Backup

Create a backup:

```bash
tar czf /root/backup-$(date +%Y%m%d).tar.gz \
    /etc \
    /var/lib/soholink \
    /home
```

Copy to external storage:

```bash
scp /root/backup-*.tar.gz user@backup-server:/backups/
```

### Automated Backup

Create backup script:

```bash
nano /usr/local/bin/backup.sh
```

```bash
#!/bin/sh
BACKUP_DIR="/root/backups"
mkdir -p $BACKUP_DIR

tar czf $BACKUP_DIR/backup-$(date +%Y%m%d).tar.gz \
    /etc \
    /var/lib/soholink

# Keep only last 7 days
find $BACKUP_DIR -name "backup-*.tar.gz" -mtime +7 -delete
```

Schedule with cron:

```bash
crontab -e
# Add: 0 2 * * * /usr/local/bin/backup.sh
```

### Recovery

Restore from backup:

```bash
cd /
tar xzf /path/to/backup-20260213.tar.gz
rc-service soholink restart
```

## Updates

### Check for Updates

Manual check:

```bash
/usr/local/bin/check-updates.sh
```

View available updates:

```bash
apk version -l '<'
```

### Apply Updates

Automated update script:

```bash
/usr/local/bin/system-update.sh
```

Manual update:

```bash
apk update
apk upgrade
```

### Update Specific Package

```bash
apk add --upgrade package-name
```

### Security Updates Only

```bash
apk upgrade --available
```

### Post-Update

Verify services:

```bash
/usr/local/bin/health-check.sh
```

Consider rebooting:

```bash
reboot
```

## Troubleshooting

### Common Issues

#### SoHoLINK Not Starting

Check logs:
```bash
tail -f /var/log/soholink/soholink.log
```

Verify configuration:
```bash
/usr/bin/fedaaa status
```

Check database permissions:
```bash
ls -la /var/lib/soholink/
chown -R soholink:soholink /var/lib/soholink/
```

#### Network Issues

Check interface status:
```bash
ip link show
ip addr show
```

Restart networking:
```bash
rc-service networking restart
```

Check firewall:
```bash
iptables -L -n
```

#### Time Sync Issues

Check chronyd status:
```bash
chronyc tracking
```

Restart chronyd:
```bash
rc-service chronyd restart
```

Force sync:
```bash
chronyc makestep
```

#### High CPU/Memory Usage

Identify process:
```bash
top
ps aux | sort -k 3 -r | head -10  # CPU
ps aux | sort -k 4 -r | head -10  # Memory
```

#### Disk Full

Check usage:
```bash
df -h
du -sh /* | sort -h
```

Clean old logs:
```bash
find /var/log -name "*.log" -mtime +30 -delete
```

### Emergency Recovery

#### Boot Issues

1. Boot from installation media
2. Mount root partition:
   ```bash
   mount /dev/sda3 /mnt
   ```
3. Chroot:
   ```bash
   chroot /mnt
   ```
4. Fix issue and reboot

#### Reset Root Password

1. Boot to single-user mode (add `single` to kernel parameters)
2. Change password:
   ```bash
   passwd root
   ```
3. Reboot

#### Factory Reset

Reinstall from ISO or restore from clean backup.

## Performance Tuning

### Optimize for Low Memory

Edit `/etc/sysctl.conf`:

```
vm.swappiness = 10
vm.vfs_cache_pressure = 50
```

Apply:
```bash
sysctl -p
```

### Optimize Network

For high-throughput scenarios:

```
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

## Best Practices

1. **Regular Backups**: Daily automated backups
2. **Monitor Logs**: Check logs regularly for anomalies
3. **Update Schedule**: Weekly update checks, monthly application
4. **Health Checks**: Daily system health verification
5. **Documentation**: Document all custom configurations
6. **Testing**: Test updates in staging before production
7. **Security**: Regular security audits with AIDE
8. **Monitoring**: Set up log forwarding for centralized monitoring

## Getting Help

- Documentation: `/usr/share/doc/ntari-os/`
- Logs: `/var/log/`
- Health Check: `/usr/local/bin/health-check.sh`
- GitHub Issues: https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os/issues
- Email: contact@ntari.org

---

For installation instructions, see [INSTALL.md](INSTALL.md).
For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
