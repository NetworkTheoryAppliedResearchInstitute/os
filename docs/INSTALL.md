# NTARI OS Installation Guide

This guide covers installing NTARI OS in various deployment scenarios.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [VM Installation](#vm-installation)
3. [Bare Metal Installation](#bare-metal-installation)
4. [First Boot Configuration](#first-boot-configuration)
5. [Post-Installation](#post-installation)

## System Requirements

### Minimum Requirements

- **CPU**: x86_64 or ARM64 (aarch64)
- **RAM**: 512MB
- **Disk**: 4GB
- **Network**: Ethernet or WiFi adapter

### Recommended Requirements

- **CPU**: x86_64 dual-core or ARM64 quad-core
- **RAM**: 1GB
- **Disk**: 8GB
- **Network**: Gigabit Ethernet

## VM Installation

### VirtualBox

1. Download the NTARI OS ISO or VMDK image
2. Create a new VM:
   - Type: Linux
   - Version: Other Linux (64-bit)
   - Memory: 512MB minimum (1GB recommended)
   - Disk: Use existing VMDK or create 4GB disk
3. Mount the ISO in the optical drive
4. Start the VM
5. Follow the [First Boot Configuration](#first-boot-configuration) steps

### QEMU/KVM

Using the provided QCOW2 image:

```bash
qemu-system-x86_64 \
  -m 512 \
  -smp 1 \
  -drive file=ntari-os-1.0.0.qcow2,format=qcow2 \
  -net nic -net user,hostfwd=tcp::2222-:22,hostfwd=udp::1812-:1812
```

Or use the quickstart script:

```bash
./vm/quickstart.sh
```

### VMware

1. Import the VMDK file
2. Configure VM settings:
   - Guest OS: Other Linux 5.x or later kernel 64-bit
   - Memory: 512MB
   - Network: Bridged or NAT
3. Power on the VM

## Bare Metal Installation

### Preparation

1. Download the NTARI OS ISO
2. Create a bootable USB drive:

   ```bash
   # Linux/Mac
   dd if=ntari-os-1.0.0-x86_64.iso of=/dev/sdX bs=4M status=progress

   # Windows (use Rufus or similar tool)
   ```

3. Boot from the USB drive

### Installation Process

1. Boot from the installation media
2. Login as `root` (no password on live ISO)
3. Run the installation:

   ```bash
   setup-alpine
   ```

4. Follow the prompts:
   - Keyboard layout: `us` (or your preference)
   - Hostname: `ntari-node` (or your preference)
   - Network: Configure your interface (DHCP recommended)
   - Root password: Set a strong password
   - Timezone: Select your timezone
   - NTP client: `chrony` (recommended)
   - Disk: Select your installation disk
   - Mode: `sys` (full installation)

5. After installation completes, reboot

## First Boot Configuration

After the first boot, configure NTARI OS:

### 1. Login

Default credentials (VM only):
- Username: `root`
- Password: `ntaripass`

**IMPORTANT**: Change the default password immediately:

```bash
passwd
```

### 2. Network Configuration

For DHCP (automatic):

```bash
# Already configured by default
rc-service networking restart
```

For static IP:

```bash
nano /etc/network/interfaces
```

Edit the eth0 section:

```
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 1.1.1.1 8.8.8.8
```

Apply changes:

```bash
rc-service networking restart
```

### 3. Configure SoHoLINK

Edit the configuration:

```bash
nano /etc/soholink/config.yaml
```

Key settings to configure:
- Node name
- RADIUS shared secret (change from default!)
- Database path
- Policy directories

Start SoHoLINK:

```bash
rc-service soholink start
```

### 4. Configure Firewall

The firewall is preconfigured but you can customize it:

```bash
nano /etc/iptables/rules-save
rc-service iptables restart
```

## Post-Installation

### System Updates

Check for updates:

```bash
/usr/local/bin/check-updates.sh
```

Apply updates:

```bash
/usr/local/bin/system-update.sh
```

### Security Hardening

Run the hardening script:

```bash
/usr/local/bin/harden-system.sh
```

### Health Check

Verify system status:

```bash
/usr/local/bin/health-check.sh
```

### Admin Dashboard

Access the admin interface:

```bash
/usr/local/bin/ntari-admin.sh
```

### Create Additional Users

Create a non-root user:

```bash
adduser username
adduser username wheel  # Add to sudo group
```

### Configure SSH

For key-based authentication:

```bash
# On your local machine
ssh-copy-id username@ntari-node-ip

# On NTARI OS
nano /etc/ssh/sshd_config.d/ntari.conf
# Set: PasswordAuthentication no
rc-service sshd restart
```

## Troubleshooting

### Network Issues

Check interface status:

```bash
ip addr show
ip route show
```

Test connectivity:

```bash
ping -c 4 8.8.8.8
```

### SoHoLINK Issues

Check service status:

```bash
rc-service soholink status
```

View logs:

```bash
tail -f /var/log/soholink/soholink.log
```

### Boot Issues

If the system doesn't boot:

1. Boot from installation media
2. Mount the root partition
3. Chroot into the system
4. Fix the issue
5. Update bootloader if needed

## Next Steps

- Read [OPERATIONS.md](OPERATIONS.md) for day-to-day management
- Configure federation settings for P2P networking
- Set up backup and monitoring
- Review security policies

---

For additional help, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) or contact support.
