# NTARI OS Quick Start Guide

Get NTARI OS up and running in minutes!

## Prerequisites

- Docker Desktop installed
- Git installed
- 16GB RAM on your development machine
- VirtualBox, VMware, or QEMU for testing

## 5-Minute Quick Start

### 1. Clone the Repository (or use this directory)

```bash
cd "C:\Users\Jodson Graves\Documents\NTARI OS"
# Or clone from GitHub when available
```

### 2. Build the ISO

```bash
make iso
```

This will:
- Build a Docker container with all build tools
- Download Alpine Linux base ISO
- Apply NTARI customizations
- Create `build-output/ntari-os-1.0.0-x86_64.iso`

Expected time: 10-15 minutes (first run, includes downloads)

### 3. Test in VirtualBox

1. Open VirtualBox
2. Create new VM:
   - Name: NTARI OS Test
   - Type: Linux
   - Version: Other Linux (64-bit)
   - Memory: 512MB
   - Disk: Create new, 4GB
3. Mount the ISO: `build-output/ntari-os-1.0.0-x86_64.iso`
4. Start the VM
5. Login: `root` (no password on live ISO)

### 4. Install to Disk

In the VM:

```bash
setup-alpine
```

Follow prompts:
- Keyboard: `us`
- Hostname: `ntari-test`
- Interface: `eth0`
- IP: `dhcp`
- Root password: (choose strong password)
- Timezone: (your timezone)
- NTP: `chrony`
- Disk: `sda`
- Mode: `sys`

### 5. First Boot Configuration

After reboot and login:

```bash
# Change default password
passwd

# Check system status
/usr/local/bin/health-check.sh

# Configure SoHoLINK
nano /etc/soholink/config.yaml
rc-service soholink start

# Access admin dashboard
/usr/local/bin/ntari-admin.sh
```

## Alternative: QEMU Quick Test

If you have QEMU installed:

```bash
# Build VM image
make vm

# Quick start
./vm/quickstart.sh
```

Access via SSH:
```bash
ssh -p 2222 root@localhost
```

RADIUS test:
```bash
# From host, RADIUS is forwarded to localhost:1812
```

## What's Included

### Services
- **SoHoLINK**: Federated AAA platform (RADIUS)
- **Chrony**: NTP time synchronization
- **OpenSSH**: Remote access
- **fail2ban**: Intrusion prevention
- **iptables**: Firewall

### Admin Tools
- `ntari-admin.sh`: Interactive admin dashboard
- `health-check.sh`: System health verification
- `system-update.sh`: Update management
- `check-updates.sh`: Update checker

### Default Ports
- SSH: 22/TCP
- RADIUS Auth: 1812/UDP
- RADIUS Accounting: 1813/UDP

### Default Credentials
⚠️ **Change immediately in production!**
- Username: `root`
- Password: `ntaripass` (VM images only)

## Next Steps

### Production Deployment

1. Change all default passwords
2. Configure static IP (if needed)
3. Set up RADIUS shared secret
4. Configure firewall rules
5. Set up backups
6. Run security hardening:
   ```bash
   /usr/local/bin/harden-system.sh
   ```

### Learn More

- [Installation Guide](docs/INSTALL.md) - Detailed installation
- [Operations Guide](docs/OPERATIONS.md) - Day-to-day management
- [Architecture](docs/ARCHITECTURE.md) - System design
- [Development Plan](DEVELOPMENT_PLAN.md) - Project roadmap

## Common Commands

```bash
# System status
/usr/local/bin/health-check.sh

# Service management
rc-service soholink status
rc-service soholink restart

# View logs
tail -f /var/log/soholink/soholink.log
tail -f /var/log/messages

# Network config
nano /etc/network/interfaces
rc-service networking restart

# Firewall
iptables -L -n
nano /etc/iptables/rules-save

# Updates
/usr/local/bin/check-updates.sh
/usr/local/bin/system-update.sh
```

## Troubleshooting

### Build Issues

**Problem**: Docker build fails
```bash
# Check Docker is running
docker ps

# Rebuild without cache
docker build --no-cache -t ntari-builder:latest build/
```

**Problem**: ISO build fails
```bash
# Check disk space
df -h

# Clean and retry
make clean
make iso
```

### VM Issues

**Problem**: VM won't boot
- Check VM memory (minimum 512MB)
- Verify ISO is properly mounted
- Try different VM software

**Problem**: Network not working
```bash
# Check interface
ip addr show

# Restart networking
rc-service networking restart

# Test connectivity
ping -c 4 8.8.8.8
```

### Service Issues

**Problem**: SoHoLINK won't start
```bash
# Check logs
tail -f /var/log/soholink/soholink.log

# Verify configuration
/usr/bin/fedaaa status

# Check permissions
ls -la /var/lib/soholink/
chown -R soholink:soholink /var/lib/soholink/
```

## Getting Help

- GitHub Issues: https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os/issues
- Email: contact@ntari.org
- Documentation: `docs/` directory

## Development

To contribute:

```bash
# Make changes
git checkout -b feature/my-feature

# Test changes
make clean
make iso
# Test in VM

# Commit and push
git add .
git commit -m "Description of changes"
git push origin feature/my-feature
```

---

**Welcome to NTARI OS!** 🚀

For full documentation, see the `docs/` directory.
