# Quick Testing Guide for NTARI OS

**Get your NTARI OS ISO running in 10 minutes!**

---

## Prerequisites

You need ONE of these:
- ✅ **Docker** (already installed!)
- ⏳ **QEMU** (optional - for fast testing)
- ⏳ **VirtualBox** (optional - for full VM testing)

---

## Step 1: Build the ISO (5 minutes)

```bash
# Navigate to build directory
cd ntari-os/build

# Build server edition (smallest, fastest)
./docker-build.sh server

# OR build desktop edition (has GUI)
./docker-build.sh desktop

# OR build lite edition (minimal)
./docker-build.sh lite
```

**What this does:**
- Creates Docker container with Alpine Linux
- Compiles NTARI OS components
- Builds bootable ISO file
- Output: `build/build-output/ntari-{edition}-*.iso`

---

## Step 2: Choose Your Testing Method

### Option A: QEMU (Fastest - 5 minutes)

**Install QEMU:**

```bash
# Windows (Git Bash/MSYS2):
pacman -S mingw-w64-x86_64-qemu

# Or download from: https://www.qemu.org/download/#windows
```

**Test the ISO:**

```bash
# Go back to main directory
cd ..

# Run test script
./test-vm.sh server
```

**Manual QEMU command:**

```bash
# Server edition
qemu-system-x86_64 \
  -cdrom build/build-output/ntari-server-*.iso \
  -m 2048 \
  -boot d

# Desktop edition (needs more RAM)
qemu-system-x86_64 \
  -cdrom build/build-output/ntari-desktop-*.iso \
  -m 4096 \
  -boot d
```

---

### Option B: VirtualBox (Full-Featured - 15 minutes)

**Install VirtualBox:**
1. Download: https://www.virtualbox.org/wiki/Downloads
2. Install VirtualBox Platform Package
3. Restart if prompted

**Automated VM Creation:**

```bash
# Run test script (creates VM automatically)
./test-vm.sh server
```

**Manual VM Creation:**

1. **Open VirtualBox**

2. **New VM:**
   - Name: `NTARI-OS-Test`
   - Type: `Linux`
   - Version: `Other Linux (64-bit)`
   - Memory:
     - Server/Lite: `2048 MB`
     - Desktop: `4096 MB`
   - Create virtual hard disk: `20 GB, VDI, Dynamic`

3. **Settings:**
   - System → Motherboard → Enable EFI: ✅
   - System → Processor → CPUs: `2`
   - Display → Video Memory: `128 MB`
   - Storage → Controller: IDE → Add ISO file
   - Network → Adapter 1 → NAT ✅

4. **Start VM**

---

## Step 3: Test the System

### Boot Checklist

Watch for these during boot:

✅ **GRUB Menu** appears
✅ **Kernel loads** (Linux boot messages)
✅ **Init system** starts (OpenRC)
✅ **Login prompt** appears

**Default credentials:**
- Username: `root`
- Password: (check build output or leave blank)

### Basic Tests

```bash
# 1. Check NTARI installation
ntari

# 2. Check version
cat /etc/ntari/version

# 3. Check services
rc-status

# 4. Check network
ip addr show
ping -c 4 8.8.8.8

# 5. Check disk space
df -h

# 6. Check memory
free -h

# 7. Check processes
ps aux

# 8. Test package manager
apk update
apk list | head
```

### Desktop Edition Tests

If testing Desktop edition:

✅ XFCE desktop loads automatically
✅ Mouse and keyboard work
✅ Open terminal: `xfce4-terminal`
✅ Open file manager: `thunar`
✅ Test Firefox: Click Firefox icon

---

## Common Issues & Solutions

### Issue: ISO not found

```bash
# Check if ISO was built
ls -lh build/build-output/*.iso

# If empty, rebuild:
cd build
./docker-build.sh server
```

### Issue: QEMU command not found

```bash
# Windows - Install via MSYS2
pacman -S mingw-w64-x86_64-qemu

# Or use VirtualBox instead
./test-vm.sh server
```

### Issue: VirtualBox won't boot

**Solutions:**
1. Enable virtualization in BIOS (VT-x/AMD-V)
2. Disable Hyper-V on Windows:
   ```powershell
   # Run as Administrator
   bcdedit /set hypervisorlaunchtype off
   # Restart computer
   ```
3. Try Legacy BIOS instead of EFI in VM settings

### Issue: Black screen after GRUB

**Try:**
- Wait 30 seconds (might be loading)
- Press Enter at GRUB menu
- Add `nomodeset` to kernel parameters in GRUB

### Issue: Network not working

```bash
# Check interface
ip link show

# Bring up interface
ip link set eth0 up

# Get DHCP address
udhcpc -i eth0

# Check again
ip addr show
```

---

## Performance Expectations

### Server Edition
- **Boot time:** 15-30 seconds
- **RAM usage:** ~200 MB
- **Disk usage:** ~500 MB
- **Services:** Basic networking, syslog, cron

### Desktop Edition
- **Boot time:** 30-60 seconds
- **RAM usage:** ~600 MB
- **Disk usage:** ~1.5 GB
- **Services:** GUI, Firefox, file manager, terminal

### Lite Edition
- **Boot time:** 10-20 seconds
- **RAM usage:** ~100 MB
- **Disk usage:** ~300 MB
- **Services:** Minimal core only

---

## What to Test

### Critical Features
- [ ] System boots to login
- [ ] Can log in
- [ ] Network connectivity works
- [ ] NTARI CLI works (`ntari` command)
- [ ] Services are running (`rc-status`)

### NTARI-Specific
- [ ] `/opt/ntari/` directory exists
- [ ] `/etc/ntari/version` shows correct version
- [ ] NTARI initialization completed
- [ ] Can access NTARI dashboard

### System Health
- [ ] No kernel errors in `dmesg`
- [ ] No service failures in `rc-status`
- [ ] Disk has free space
- [ ] Time is synchronized (Desktop edition)

---

## Taking Screenshots

### In QEMU:
- Press `Ctrl+Alt+Shift+3` (Linux/Mac)
- Or use host OS screenshot tool

### In VirtualBox:
- View → Take Screenshot
- Or `Host+E` (default: Right Ctrl + E)

---

## Stopping the VM

### QEMU:
```bash
# Graceful shutdown (from inside VM)
poweroff

# Force quit
Ctrl+A, then X
```

### VirtualBox:
```bash
# Graceful shutdown (from inside VM)
poweroff

# From VirtualBox Manager
# Right-click VM → Close → Power Off
```

---

## Next Steps

After successful testing:

1. **Report results:** Document what worked and what didn't
2. **Test on real hardware:** Create bootable USB (see `TESTING.md`)
3. **Try installation:** Test installer (Phase 1.2)
4. **Test all editions:** Server, Desktop, and Lite
5. **Join development:** See `CONTRIBUTING.md`

---

## Quick Reference Commands

```bash
# Build ISO
cd build && ./docker-build.sh server

# Test with QEMU
qemu-system-x86_64 -cdrom build/build-output/ntari-*.iso -m 2048

# Test with VirtualBox
./test-vm.sh server

# Inside VM - Basic health check
ntari && rc-status && ip addr && free -h

# Inside VM - Shutdown
poweroff
```

---

## Getting Help

- **Full Testing Guide:** `TESTING.md`
- **Build Guide:** `build/README.md`
- **Roadmap:** `ROADMAP.md`
- **Issues:** (GitHub issues - coming soon)

---

**Ready to test? Let's go!**

```bash
# One command to build and test:
cd build && ./docker-build.sh server && cd .. && ./test-vm.sh server
```

---

**Last Updated:** February 16, 2026
**Phase:** 1.1 - Alpine Base System
**Status:** Ready for Testing
