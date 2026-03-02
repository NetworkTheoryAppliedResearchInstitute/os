# NTARI OS Testing Guide

**Version:** 1.0.0
**Phase:** 1.1 - Alpine Base System
**Status:** Ready for Testing

---

## Overview

This guide covers testing NTARI OS ISOs in various environments, from virtual machines to physical hardware.

---

## Quick Test (QEMU - 5 minutes)

The fastest way to test a NTARI OS ISO:

### Prerequisites

```bash
# Install QEMU
# Ubuntu/Debian:
sudo apt install qemu-system-x86

# Fedora:
sudo dnf install qemu-system-x86

# Arch:
sudo pacman -S qemu

# macOS:
brew install qemu

# Windows:
# Download from https://www.qemu.org/download/
```

### Basic Boot Test

```bash
# Navigate to build output
cd ntari-os/build/build-output

# Boot the ISO (2GB RAM)
qemu-system-x86_64 -cdrom ntari-server-1.0.0-20260216.iso -m 2048

# With KVM acceleration (Linux only - much faster)
qemu-system-x86_64 -cdrom ntari-server-1.0.0-20260216.iso -m 2048 -enable-kvm

# Desktop Edition (needs more RAM)
qemu-system-x86_64 -cdrom ntari-desktop-1.0.0-20260216.iso -m 4096 -enable-kvm
```

### Network Test

```bash
# Boot with network enabled
qemu-system-x86_64 \
  -cdrom ntari-server-1.0.0-20260216.iso \
  -m 2048 \
  -enable-kvm \
  -netdev user,id=net0 \
  -device e1000,netdev=net0
```

### What to Check

✅ **Boot Process:**
- GRUB menu appears
- Kernel loads without errors
- Init system starts (OpenRC messages)
- System reaches login prompt

✅ **Login:**
- Default credentials work (if set)
- Shell is responsive
- Basic commands work (ls, pwd, cd)

✅ **NTARI Components:**
```bash
# After login, test NTARI CLI
ntari

# Check NTARI installation
ls -la /opt/ntari/
cat /etc/ntari/version

# Check services
rc-status
```

✅ **Network:**
```bash
# Check network interfaces
ip link show
ip addr show

# Test connectivity
ping -c 4 8.8.8.8
```

---

## VirtualBox Testing (30 minutes)

More comprehensive testing with full VM capabilities.

### Create VM

1. **Download VirtualBox:** https://www.virtualbox.org/

2. **Create New VM:**
   - Name: NTARI-OS-Test
   - Type: Linux
   - Version: Other Linux (64-bit)
   - Memory:
     - Server: 2048 MB
     - Desktop: 4096 MB
     - Lite: 2048 MB
   - Hard Disk: Create virtual (20 GB, VDI, Dynamically allocated)

3. **VM Settings:**
   - System → Motherboard → Enable EFI
   - System → Processor → 2 CPUs
   - Display → Video Memory → 128 MB
   - Storage → IDE Controller → Add ISO
   - Network → Adapter 1 → NAT or Bridged

4. **Start VM** and boot from ISO

### Test Checklist

**Boot & System:**
- [ ] GRUB menu displays
- [ ] System boots to login
- [ ] Login works
- [ ] NTARI CLI launches (`ntari` command)
- [ ] System information displays correctly

**Network:**
- [ ] Network interface detected
- [ ] DHCP obtains IP address
- [ ] DNS resolution works (`ping google.com`)
- [ ] Can download packages (`apk update`)

**Filesystem:**
- [ ] Can read/write to `/tmp`
- [ ] Can create files and directories
- [ ] Permissions work correctly

**Services:**
- [ ] OpenRC is running (`rc-status`)
- [ ] syslog is logging (`tail /var/log/messages`)
- [ ] chronyd is syncing time

**Desktop Edition Only:**
- [ ] XFCE desktop loads
- [ ] Mouse and keyboard work
- [ ] Window management works
- [ ] Terminal emulator launches
- [ ] File manager works
- [ ] Network manager applet shows
- [ ] Firefox browser launches

---

## Physical Hardware Testing (Phase 1.5)

Testing on real hardware to verify compatibility.

### Creating Bootable USB

#### Linux

```bash
# Find USB device (BE CAREFUL!)
lsblk

# Write ISO to USB (replace /dev/sdX with your USB device)
sudo dd if=ntari-server-1.0.0-20260216.iso of=/dev/sdX bs=4M status=progress
sync

# Verify checksum first!
sha256sum -c ntari-server-1.0.0-20260216.iso.sha256
```

#### Windows

**Option 1: Rufus (Recommended)**
1. Download Rufus: https://rufus.ie/
2. Select ISO file
3. Select USB drive
4. Click START

**Option 2: Etcher**
1. Download Etcher: https://www.balena.io/etcher/
2. Select ISO
3. Select USB drive
4. Flash!

#### macOS

```bash
# Find USB device
diskutil list

# Unmount (replace diskN with your USB)
diskutil unmountDisk /dev/diskN

# Write ISO
sudo dd if=ntari-server-1.0.0-20260216.iso of=/dev/rdiskN bs=4m

# Eject
diskutil eject /dev/diskN
```

### Boot from USB

1. **Insert USB** into test computer
2. **Enter BIOS/UEFI:**
   - Dell: F12
   - HP: F9 or Esc
   - Lenovo: F12 or F1
   - ASUS: F8 or Esc
   - Acer: F12
   - Generic: Del, F2, F10, or F12

3. **Boot Options:**
   - Disable Secure Boot (if enabled)
   - Enable Legacy Boot or UEFI mode
   - Set USB as first boot device

4. **Boot and Test**

### Hardware Testing Checklist

**Phase 1.5 will test on 20+ computers:**

| Brand | Model | RAM | WiFi Chip | GPU | Status |
|-------|-------|-----|-----------|-----|--------|
| Dell | Latitude E6430 | 8GB | Intel | Intel HD | ⏳ |
| HP | EliteBook 840 | 16GB | Intel | Intel HD | ⏳ |
| Lenovo | ThinkPad T460 | 8GB | Intel | Intel HD | ⏳ |
| ASUS | VivoBook | 4GB | Realtek | Intel UHD | ⏳ |
| Acer | Aspire 5 | 8GB | Atheros | AMD Radeon | ⏳ |
| ... | ... | ... | ... | ... | ⏳ |

**For Each Computer, Test:**

- [ ] **Boot:**
  - [ ] BIOS/UEFI access
  - [ ] Boot from USB successful
  - [ ] GRUB menu displays
  - [ ] System boots to prompt

- [ ] **Hardware Detection:**
  - [ ] CPU recognized (`lscpu`)
  - [ ] RAM detected (`free -h`)
  - [ ] Disk recognized (`lsblk`)
  - [ ] Network card detected (`ip link`)

- [ ] **WiFi:**
  - [ ] WiFi adapter detected (`ip link show wlan0` or `iw dev`)
  - [ ] Can scan networks (`iw wlan0 scan`)
  - [ ] Can connect to WiFi
  - [ ] Internet connectivity works

- [ ] **Graphics:**
  - [ ] Display works at correct resolution
  - [ ] GPU driver loads (`lspci -v | grep -A 10 VGA`)
  - [ ] Desktop Edition: GUI renders properly

- [ ] **Peripherals:**
  - [ ] Keyboard works
  - [ ] Touchpad/mouse works
  - [ ] USB ports work
  - [ ] Audio detected (Desktop Edition)
  - [ ] Webcam detected (if present)

- [ ] **Documentation:**
  - [ ] Take photo of BIOS screen (for guide)
  - [ ] Note any driver issues
  - [ ] Record boot time
  - [ ] Note any errors

---

## Automated Testing (Future)

### Boot Test Script

```bash
#!/bin/bash
# test-boot.sh - Automated QEMU boot test

ISO="$1"
TIMEOUT=120  # 2 minutes

if [ -z "$ISO" ]; then
    echo "Usage: $0 <iso-file>"
    exit 1
fi

echo "Testing boot for: $ISO"

# Start QEMU in background
qemu-system-x86_64 \
    -cdrom "$ISO" \
    -m 2048 \
    -enable-kvm \
    -nographic \
    -serial stdio \
    -append "console=ttyS0" \
    &

QEMU_PID=$!

# Wait for boot
sleep $TIMEOUT

# Check if still running
if kill -0 $QEMU_PID 2>/dev/null; then
    echo "✓ Boot successful (process still running)"
    kill $QEMU_PID
    exit 0
else
    echo "✗ Boot failed (process died)"
    exit 1
fi
```

### CI/CD Integration (Future)

```yaml
# .github/workflows/test-iso.yml
name: Test ISO Build

on: [push, pull_request]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y qemu-system-x86 xorriso squashfs-tools

    - name: Build ISO
      run: |
        cd build
        ./build-alpine.sh
        docker build -t ntari-builder -f build-output/Dockerfile ..
        docker run -v $(pwd)/..:/build ntari-builder /build/build/build-iso.sh server

    - name: Test boot
      run: |
        timeout 120 qemu-system-x86_64 \
          -cdrom build/build-output/ntari-server-*.iso \
          -m 2048 \
          -nographic
```

---

## Test Reports

### Template

```markdown
# NTARI OS Test Report

**Tester:** [Your Name]
**Date:** YYYY-MM-DD
**Edition:** Server / Desktop / Lite
**Version:** 1.0.0
**Environment:** QEMU / VirtualBox / Physical Hardware

## System Information

- **Computer:** Dell Latitude E6430
- **CPU:** Intel Core i5-3320M
- **RAM:** 8GB
- **GPU:** Intel HD Graphics 4000
- **WiFi:** Intel Centrino 6205
- **BIOS:** Legacy / UEFI

## Test Results

### Boot Test
- [ ] PASS / [ ] FAIL - GRUB menu displays
- [ ] PASS / [ ] FAIL - Kernel loads
- [ ] PASS / [ ] FAIL - System reaches login
- Time to login: ___ seconds

### Hardware Detection
- [ ] PASS / [ ] FAIL - CPU recognized
- [ ] PASS / [ ] FAIL - RAM detected
- [ ] PASS / [ ] FAIL - Network card detected
- [ ] PASS / [ ] FAIL - WiFi adapter detected
- [ ] PASS / [ ] FAIL - GPU driver loaded

### Network
- [ ] PASS / [ ] FAIL - Ethernet works
- [ ] PASS / [ ] FAIL - WiFi works
- [ ] PASS / [ ] FAIL - DHCP obtains IP
- [ ] PASS / [ ] FAIL - DNS resolution
- [ ] PASS / [ ] FAIL - Internet connectivity

### NTARI Components
- [ ] PASS / [ ] FAIL - `ntari` command works
- [ ] PASS / [ ] FAIL - NTARI CLI dashboard displays
- [ ] PASS / [ ] FAIL - Version info correct
- [ ] PASS / [ ] FAIL - First-boot init completed

### Issues Found

1. Issue description...
   - Severity: Critical / Major / Minor
   - Steps to reproduce...
   - Expected behavior...
   - Actual behavior...

## Photos/Screenshots

[Attach BIOS screen, boot process, errors, etc.]

## Notes

Additional observations...

## Overall Result

✅ PASS - System fully functional
⚠️  PARTIAL - Works with minor issues
❌ FAIL - Critical issues prevent use
```

---

## Known Issues

### Expected Issues in Phase 1.1

1. **No persistence** - Live ISO, changes are lost on reboot
   - Will be fixed in installation system

2. **Manual network setup** - WiFi requires manual configuration
   - Will be improved in first-run wizard

3. **Basic NTARI features only** - P2P networking not yet functional
   - Coming in Phase 2

### Reporting Issues

When you find a bug:

1. **Check** if it's a known issue
2. **Document** with test report template
3. **Create** GitHub issue (coming soon)
4. **Include:**
   - NTARI version
   - Hardware specs
   - Steps to reproduce
   - Expected vs actual behavior
   - Photos/logs if possible

---

## Next Steps After Testing

1. **Milestone 1.1 Complete** - ISO boots successfully
2. **Milestone 1.2** - Build USB Installer tool
3. **Milestone 1.3** - Add Desktop Edition
4. **Milestone 1.4** - Create first-run wizard
5. **Milestone 1.5** - Hardware compatibility testing (20+ machines)
6. **Milestone 1.6** - Create installation documentation

---

## Resources

- **QEMU Documentation:** https://www.qemu.org/docs/master/
- **VirtualBox Manual:** https://www.virtualbox.org/manual/
- **Alpine Linux Wiki:** https://wiki.alpinelinux.org/
- **NTARI Roadmap:** ../ROADMAP.md
- **Build Guide:** build/README.md

---

**Last Updated:** February 16, 2026
**Phase:** 1.1 - Alpine Base System
**Next Milestone:** 1.2 - USB Installer Tool
