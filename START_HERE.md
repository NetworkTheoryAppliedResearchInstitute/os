# 🎯 START HERE - NTARI OS Testing

**Welcome! Let's get NTARI OS running in minutes.**

---

## ⚡ Super Quick Start (Pick One)

### Method A: QEMU (Fastest - 10 minutes total)

1. **Install QEMU:**
   - Download: https://www.qemu.org/download/#windows
   - Run installer
   - Or if using MSYS2: `pacman -S mingw-w64-x86_64-qemu`

2. **Build & Test:**
   ```bash
   cd build
   ./docker-build.sh server
   cd ..
   qemu-system-x86_64 -cdrom build/build-output/ntari-server-*.iso -m 2048
   ```

### Method B: VirtualBox (Full VM - 20 minutes total)

1. **Install VirtualBox:**
   - Download: https://www.virtualbox.org/wiki/Downloads
   - Install and restart if needed

2. **Build & Test (PowerShell):**
   ```powershell
   .\test-build.ps1 server
   ```

---

## 📋 What You Need

**Already Installed:**
- ✅ Docker (version 29.2.0)

**Choose One to Install:**
- ⏳ QEMU (for quick testing)
- ⏳ VirtualBox (for full VM testing)

---

## 🚀 Detailed Steps

### Step 1: Choose Your Tool

**QEMU** - Best for:
- Quick testing
- Multiple rapid tests
- Less disk space
- Faster startup

**VirtualBox** - Best for:
- Full VM experience
- Persistence between sessions
- Easier snapshots
- More features

### Step 2: Build the ISO

```bash
# Navigate to the project
cd ntari-os/build

# Build Server Edition (smallest, ~180MB)
./docker-build.sh server

# This will:
# - Create Docker build environment
# - Download Alpine Linux base
# - Compile NTARI components
# - Package into bootable ISO
# - Takes 3-5 minutes first time
```

**Output:** `build/build-output/ntari-server-1.0.0-YYYYMMDD.iso`

### Step 3: Test the ISO

**With QEMU:**
```bash
qemu-system-x86_64 \
  -cdrom build/build-output/ntari-server-*.iso \
  -m 2048 \
  -boot d
```

**With VirtualBox (PowerShell):**
```powershell
.\test-build.ps1 server
```

**With VirtualBox (Manual):**
- See detailed instructions in `TEST_NOW.md`

---

## 🎮 Controls

### QEMU
- **Release mouse:** Ctrl+Alt+G
- **Fullscreen:** Ctrl+Alt+F
- **Quit:** Ctrl+Alt+2, then type `quit`

### VirtualBox
- **Release mouse:** Right Ctrl
- **Fullscreen:** Right Ctrl+F
- **Screenshot:** Right Ctrl+E

---

## ✅ First Boot Checklist

Once the VM boots, you should see:

1. **GRUB Menu** (blue screen with menu)
   - Press Enter or wait 5 seconds

2. **Boot Messages** (scrolling text)
   - Linux kernel loading
   - Services starting

3. **Login Prompt:**
   ```
   NTARI OS 1.0.0 (Server Edition)
   ntari-server login: _
   ```

**Login:**
- Username: `root`
- Password: (try blank first)

4. **Test Commands:**
   ```bash
   # Quick health check
   ntari
   rc-status
   ip addr
   ping -c 2 8.8.8.8
   free -h
   ```

All should work! ✅

---

## 🐛 Common Issues

### "Docker is not running"
- Start Docker Desktop from Start Menu
- Wait for Docker icon in system tray to show "running"

### "Permission denied" on scripts
```bash
chmod +x build/*.sh test-vm.sh
```

### "QEMU not found"
- Install QEMU first (see Method A above)
- Or use VirtualBox instead

### "VirtualBox won't start"
- Enable Virtualization in BIOS
- Disable Hyper-V (Windows):
  ```powershell
  # Run as Administrator
  bcdedit /set hypervisorlaunchtype off
  # Restart
  ```

### Network not working in VM
```bash
# Inside the VM
ip link set eth0 up
udhcpc -i eth0
ping 8.8.8.8
```

---

## 📚 Documentation

- **Detailed Testing:** `TEST_NOW.md` ← You are here!
- **Quick Guide:** `QUICK_TEST.md`
- **Full Testing:** `TESTING.md`
- **Build Details:** `build/README.md`

---

## 🎯 After First Successful Boot

1. Test all the commands in the checklist
2. Try the other editions:
   ```bash
   ./docker-build.sh desktop  # GUI version
   ./docker-build.sh lite     # Minimal GUI
   ```
3. Report what works and what doesn't
4. Try creating bootable USB (see `TESTING.md`)

---

## 💡 Tips

- **Faster builds:** Docker caches, so rebuilds take 1-2 minutes
- **Disk space:** Each ISO is 180MB-1.5GB depending on edition
- **Testing:** Test in VM before trying on real hardware
- **Backups:** VirtualBox snapshots let you save VM state

---

## 🆘 Need Help?

1. Check `TEST_NOW.md` for detailed troubleshooting
2. Check `TESTING.md` for full testing procedures
3. Review build logs in `build/build-output/`

---

## 🎬 Quick Command Cheat Sheet

```bash
# Build
cd build && ./docker-build.sh server

# Test with QEMU
qemu-system-x86_64 -cdrom build/build-output/ntari-server-*.iso -m 2048

# Test with VirtualBox (PowerShell)
.\test-build.ps1 server

# Inside VM - quick test
ntari && rc-status && ping -c 2 8.8.8.8

# Shutdown VM
poweroff
```

---

**Ready? Pick Method A or B above and let's boot NTARI OS! 🚀**

*Questions? See TEST_NOW.md for detailed instructions.*
