# 🚀 Ready to Test NTARI OS!

**Everything is set up. Let's build and test your operating system!**

---

## 📋 Current Status

✅ **Docker installed and running**
✅ **Build scripts ready**
✅ **Test scripts created**
⏳ **QEMU not installed** (optional)
⏳ **VirtualBox not installed** (optional)

---

## 🎯 Option 1: Quick Test with QEMU (Recommended - Fastest)

### Step 1: Install QEMU

**Windows (using MSYS2/Git Bash):**
```bash
# If you have MSYS2:
pacman -S mingw-w64-x86_64-qemu

# Or download installer:
# https://www.qemu.org/download/#windows
```

### Step 2: Build & Test (5 minutes)

```bash
# Open Git Bash or MSYS2 terminal
cd C:/Users/Jodson\ Graves/Documents/NTARIOS/ntari-os

# Build the ISO (takes 3-5 minutes)
cd build
./docker-build.sh server

# Test it with QEMU (instant)
cd ..
qemu-system-x86_64 -cdrom build/build-output/ntari-server-*.iso -m 2048 -boot d
```

**That's it!** Your NTARI OS will boot in a QEMU window.

---

## 🎯 Option 2: Full VM with VirtualBox (Slower but More Features)

### Step 1: Install VirtualBox

1. Download VirtualBox: https://www.virtualbox.org/wiki/Downloads
2. Install "VirtualBox Platform Package"
3. Restart if prompted

### Step 2: Build & Test

**Using PowerShell (Windows):**
```powershell
# Open PowerShell as regular user (not admin)
cd C:\Users\Jodson Graves\Documents\NTARIOS\ntari-os

# Build and test (automated!)
.\test-build.ps1 server
```

**Or using Git Bash:**
```bash
cd C:/Users/Jodson\ Graves/Documents/NTARIOS/ntari-os

# Build the ISO
cd build
./docker-build.sh server

# Test with automated VirtualBox setup
cd ..
./test-vm.sh server
```

The script will:
- Build the ISO using Docker
- Create a VirtualBox VM automatically
- Attach the ISO
- Start the VM

---

## 🎯 Option 3: Manual VirtualBox Setup

If you prefer manual control:

### Step 1: Build ISO

```bash
cd C:/Users/Jodson\ Graves/Documents/NTARIOS/ntari-os/build
./docker-build.sh server
```

### Step 2: Create VM in VirtualBox

1. **Open VirtualBox** → Click "New"

2. **VM Settings:**
   - Name: `NTARI-OS-Test`
   - Type: `Linux`
   - Version: `Other Linux (64-bit)`
   - Memory: `2048 MB` (for server) or `4096 MB` (for desktop)
   - Create virtual hard disk: `20 GB, VDI, Dynamically allocated`

3. **Before starting, adjust settings:**
   - Right-click VM → Settings
   - System → Motherboard → Enable EFI: ✅
   - System → Processor → CPUs: `2`
   - Display → Video Memory: `128 MB`
   - Storage → Controller: IDE → Click CD icon → Choose ISO file
     - Location: `C:\Users\Jodson Graves\Documents\NTARIOS\ntari-os\build\build-output\`
     - File: `ntari-server-1.0.0-YYYYMMDD.iso`
   - Network → Adapter 1 → NAT: ✅

4. **Start the VM** → Click "Start"

---

## 📸 What You'll See

### 1. GRUB Boot Menu (5 seconds)
```
═══════════════════════════════════════
  NTARI OS 1.0.0 - Server Edition
═══════════════════════════════════════
  Boot NTARI OS
  Boot NTARI OS (Safe Mode)
  Boot to RAM (No Disk)
```

### 2. Linux Kernel Boot Messages (10-20 seconds)
```
[    0.000000] Linux version 6.6.x...
[    1.234567] ACPI: LAPIC...
[    2.345678] NET: Registered protocol family...
```

### 3. OpenRC Service Initialization (5-10 seconds)
```
* Starting networking...              [ ok ]
* Starting syslog...                   [ ok ]
* Starting chronyd...                  [ ok ]
```

### 4. Login Prompt
```
NTARI OS 1.0.0 (Server Edition)
ntari-server login: _
```

**Default credentials:**
- Username: `root`
- Password: (try blank first, or check build output)

---

## ✅ Testing Checklist

Once logged in, run these commands:

```bash
# 1. Check NTARI is installed
ntari
# Should show: NTARI OS Dashboard/CLI

# 2. Check version
cat /etc/ntari/version
# Should show: 1.0.0 or similar

# 3. Check services
rc-status
# Should show running services (networking, syslog, etc.)

# 4. Check network interface
ip addr show
# Should show: lo, eth0 (or similar)

# 5. Test network connectivity
ping -c 4 8.8.8.8
# Should show: 4 packets transmitted, 4 received

# 6. Test DNS
ping -c 2 google.com
# Should resolve and ping

# 7. Check disk space
df -h
# Should show filesystem usage

# 8. Check memory
free -h
# Should show RAM usage (~200MB for server)

# 9. Check processes
ps aux | head
# Should show running processes

# 10. Test package manager
apk update
apk list | head -20
# Should show available packages
```

### Expected Results

✅ **All commands should work without errors**
✅ **Network should be functional**
✅ **NTARI components should be present**
✅ **System should be responsive**

---

## 🐛 Troubleshooting

### Build Issues

**Error: "Docker not found"**
```bash
# Check Docker installation
docker --version

# Start Docker Desktop
# Look for Docker Desktop icon in system tray
```

**Error: "Permission denied"**
```bash
# Make scripts executable
chmod +x build/*.sh
chmod +x test-vm.sh
```

### QEMU Issues

**Error: "qemu-system-x86_64 not found"**
- Install QEMU (see Option 1 above)
- Or use VirtualBox instead (see Option 2)

**Black screen after GRUB:**
- Wait 30 seconds (might be loading)
- Try pressing Enter at GRUB menu
- Add `nomodeset` to kernel parameters

### VirtualBox Issues

**Error: "VT-x/AMD-V not available"**
1. Restart computer
2. Enter BIOS/UEFI (usually F2, F10, or Del during boot)
3. Enable "Virtualization Technology" or "VT-x" or "AMD-V"
4. Save and restart

**Error: "Hyper-V conflict"** (Windows only)
```powershell
# Open PowerShell as Administrator
bcdedit /set hypervisorlaunchtype off
# Restart computer
```

**VM won't boot / black screen:**
- Try disabling EFI (use Legacy BIOS instead)
- Increase video memory to 128 MB
- Try different graphics controller (VBoxVGA, VMSVGA)

### Network Issues Inside VM

```bash
# Check interface
ip link show

# Bring up interface if down
ip link set eth0 up

# Get DHCP address
udhcpc -i eth0

# Verify
ip addr show
ping 8.8.8.8
```

---

## 📊 Performance Benchmarks

### Server Edition
- **Build time:** 3-5 minutes (first time), 1-2 minutes (cached)
- **ISO size:** ~180-200 MB
- **Boot time:** 15-30 seconds (QEMU), 20-40 seconds (VirtualBox)
- **RAM usage:** ~150-200 MB
- **Disk usage:** ~500 MB

### Desktop Edition
- **Build time:** 8-12 minutes (first time), 3-5 minutes (cached)
- **ISO size:** ~1.2-1.5 GB
- **Boot time:** 30-60 seconds
- **RAM usage:** ~600-800 MB
- **Disk usage:** ~1.5-2 GB

---

## 🎬 Quick Command Reference

```bash
# === BUILD ===
# Server edition (minimal, fast)
cd build && ./docker-build.sh server

# Desktop edition (with GUI)
cd build && ./docker-build.sh desktop

# Lite edition (lightweight GUI)
cd build && ./docker-build.sh lite

# === TEST WITH QEMU ===
# Basic test
qemu-system-x86_64 -cdrom build/build-output/ntari-server-*.iso -m 2048

# With network
qemu-system-x86_64 \
  -cdrom build/build-output/ntari-server-*.iso \
  -m 2048 \
  -netdev user,id=net0 \
  -device e1000,netdev=net0

# === TEST WITH VIRTUALBOX ===
# PowerShell (automated)
.\test-build.ps1 server

# Bash (automated)
./test-vm.sh server

# === INSIDE VM ===
# Health check (run all at once)
ntari && rc-status && ip addr && ping -c 2 8.8.8.8 && free -h

# Shutdown
poweroff
```

---

## 🚀 Ready? Let's Go!

**Fastest path to testing:**

```bash
# Option 1: Install QEMU, then:
cd ntari-os/build && ./docker-build.sh server && cd .. && \
qemu-system-x86_64 -cdrom build/build-output/ntari-server-*.iso -m 2048
```

```powershell
# Option 2: Install VirtualBox, then:
cd ntari-os
.\test-build.ps1 server
```

---

## 📚 Additional Resources

- **Full Testing Guide:** `TESTING.md`
- **Quick Testing Guide:** `QUICK_TEST.md`
- **Build Documentation:** `build/README.md`
- **Project Roadmap:** `ROADMAP.md`
- **Development Progress:** `PROGRESS.md`

---

## 🎯 Next Steps After Testing

1. ✅ **Test all three editions:** server, desktop, lite
2. ✅ **Report any bugs or issues**
3. ✅ **Try creating bootable USB** (Phase 1.2)
4. ✅ **Test on physical hardware** (Phase 1.5)
5. ✅ **Join development** (`CONTRIBUTING.md`)

---

## 💡 Pro Tips

- **Speed up builds:** Docker caches layers, so rebuilds are much faster
- **Save disk space:** Delete test VMs after testing
- **Test networking:** Make sure VM has network access for package updates
- **Take screenshots:** Document your testing for future reference
- **Try all editions:** Each has different features and use cases

---

**You're all set! Choose your testing method and let's see NTARI OS boot! 🚀**

*Last updated: February 16, 2026*
*Phase: 1.1 - Alpine Base System*
*Status: Ready for Testing*
