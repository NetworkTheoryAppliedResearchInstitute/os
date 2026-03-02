# Installing Docker Desktop on Windows

**Purpose:** Enable building NTARI OS ISOs on Windows
**Time Required:** 15-20 minutes
**System:** Windows 10/11 (64-bit)

---

## Step 1: Download Docker Desktop

1. **Visit Docker's Website:**
   - Open browser to: https://www.docker.com/products/docker-desktop/
   - Or direct download: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe

2. **Download the Installer:**
   - Click "Download for Windows"
   - Save `Docker Desktop Installer.exe`

---

## Step 2: Install Docker Desktop

1. **Run the Installer:**
   - Double-click `Docker Desktop Installer.exe`
   - Click "Yes" if User Account Control prompts

2. **Configuration:**
   - ✅ **Check:** "Use WSL 2 instead of Hyper-V" (recommended)
   - ✅ **Check:** "Add shortcut to desktop"
   - Click "OK"

3. **Installation:**
   - Wait for installation to complete (5-10 minutes)
   - Click "Close and restart" when prompted
   - **Your computer will restart**

---

## Step 3: First Launch

1. **Start Docker Desktop:**
   - After restart, Docker Desktop should launch automatically
   - If not, click the Docker icon on your desktop

2. **Accept Terms:**
   - Read and accept the Docker Subscription Service Agreement
   - Click "Accept"

3. **Skip Tutorial (Optional):**
   - You can skip the tutorial or go through it
   - We'll use Docker from command line

4. **Wait for Docker to Start:**
   - You'll see "Docker Desktop is starting..."
   - Wait until it says "Docker Desktop is running"
   - This may take 2-3 minutes on first launch

---

## Step 4: Verify Installation

1. **Open Git Bash or PowerShell:**
   ```bash
   # Check Docker version
   docker --version

   # Expected output:
   # Docker version 24.x.x, build xxxxxxx
   ```

2. **Test Docker is Running:**
   ```bash
   docker info

   # Should show system information (not an error)
   ```

3. **Run Test Container:**
   ```bash
   docker run hello-world

   # Expected output:
   # "Hello from Docker!"
   # "This message shows that your installation appears to be working correctly."
   ```

---

## Step 5: Configure Docker (Optional but Recommended)

### Increase Resources (for faster builds)

1. **Open Docker Desktop**
2. Click **Settings** (gear icon)
3. Go to **Resources**
4. Adjust settings:
   - **CPUs:** 4 (if you have 8+ cores)
   - **Memory:** 8 GB (if you have 16+ GB RAM)
   - **Swap:** 2 GB
   - **Disk image size:** 60 GB
5. Click **Apply & Restart**

### Enable File Sharing

1. In Settings, go to **Resources → File Sharing**
2. Ensure `C:\` is checked
3. Click **Apply & Restart**

---

## Step 6: Build NTARI OS ISO

Now you're ready to build!

```bash
# Navigate to NTARI OS build directory
cd "C:\Users\Jodson Graves\Documents\NTARIOS\ntari-os\build"

# Make scripts executable
chmod +x build-alpine.sh docker-build.sh build-iso.sh

# Run build preparation
./build-alpine.sh

# Build Server Edition ISO (this will take 10-20 minutes first time)
./docker-build.sh server
```

**Expected Output:**
```
═══════════════════════════════════════════════════════
  NTARI OS Docker Build System
  Edition: server
═══════════════════════════════════════════════════════

✓ Docker found
✓ Docker is running

[STEP] Building Docker image (this may take a few minutes)...
────────────────────────────────────────────────────────
Sending build context to Docker daemon...
Step 1/8 : FROM alpine:3.19
 ---> Pulling image...
✓ Docker image built successfully

[STEP] Starting ISO build in Docker container...
────────────────────────────────────────────────────────

[STEP] Checking build environment
────────────────────────────────────────────────────────
✓ Running on Alpine Linux 3.19.x

[STEP] Downloading Alpine Linux base system
────────────────────────────────────────────────────────
Downloading alpine-minirootfs-3.19.0-x86_64.tar.gz...
✓ Downloaded Alpine minirootfs

[STEP] Installing packages for server edition
────────────────────────────────────────────────────────
Installing 85 packages...
✓ Installed 85 packages

[STEP] Installing NTARI OS components
────────────────────────────────────────────────────────
✓ Installed ntari-cli.sh
✓ Installed ntari-init.sh
✓ Created version file
✓ Created 'ntari' command symlink

[STEP] Creating SquashFS root filesystem
────────────────────────────────────────────────────────
Compressing root filesystem to SquashFS...
✓ Created rootfs.squashfs (180M)

[STEP] Building ISO image
────────────────────────────────────────────────────────
Creating ntari-server-1.0.0-20260216.iso...
✓ Created ntari-server-1.0.0-20260216.iso (180M)

╔════════════════════════════════════════════════════╗
║           Docker Build Successful!                ║
╚════════════════════════════════════════════════════╝

ISO files are in: C:\Users\Jodson Graves\Documents\NTARIOS\ntari-os\build\build-output\
```

---

## Troubleshooting

### "Docker is not running"

**Solution:**
1. Open Docker Desktop application
2. Wait for it to fully start (green icon in system tray)
3. Try again

### "WSL 2 installation is incomplete"

**Solution:**
1. Open PowerShell as Administrator
2. Run: `wsl --install`
3. Restart computer
4. Launch Docker Desktop again

### "Virtualization is not enabled"

**Solution:**
1. Restart computer
2. Enter BIOS/UEFI (usually F2, F10, or Del during boot)
3. Find and enable:
   - Intel: "Intel VT-x" or "Virtualization Technology"
   - AMD: "AMD-V" or "SVM Mode"
4. Save and exit BIOS
5. Boot Windows and try Docker again

### "Access denied" or permission errors

**Solution:**
1. Make sure Docker Desktop is running
2. Right-click Git Bash/Terminal and "Run as Administrator"
3. Try the build command again

### Build is very slow

**Solution:**
1. First build takes longer (downloading Alpine image)
2. Subsequent builds are faster (uses cache)
3. Increase Docker resources (see Step 5 above)
4. Make sure your antivirus isn't scanning the Docker files

---

## What's Next?

Once Docker is installed and you've built the ISO:

1. **Test in QEMU** (fastest):
   ```bash
   # Install QEMU for Windows
   # Download from: https://qemu.weilnetz.de/w64/

   # Boot test
   qemu-system-x86_64 -cdrom build-output/ntari-server-*.iso -m 2048
   ```

2. **Test in VirtualBox** (more thorough):
   - Download VirtualBox: https://www.virtualbox.org/
   - Create new Linux VM
   - Mount ISO and boot

3. **Create bootable USB** (real hardware):
   - Use Rufus: https://rufus.ie/
   - Select ISO and USB drive
   - Write and test on real computer

---

## Quick Reference

```bash
# Check if Docker is running
docker info

# Build NTARI OS Server Edition
cd "C:\Users\Jodson Graves\Documents\NTARIOS\ntari-os\build"
./docker-build.sh server

# Build Desktop Edition
./docker-build.sh desktop

# Build Lite Edition
./docker-build.sh lite

# Check build output
ls -lh build-output/*.iso
```

---

## Support Links

- **Docker Desktop Download:** https://www.docker.com/products/docker-desktop/
- **Docker Documentation:** https://docs.docker.com/desktop/install/windows-install/
- **WSL 2 Installation:** https://docs.microsoft.com/en-us/windows/wsl/install
- **NTARI Testing Guide:** See `TESTING.md`

---

**Installation Guide Version:** 1.0
**Last Updated:** February 16, 2026
**For:** Windows 10/11 64-bit
