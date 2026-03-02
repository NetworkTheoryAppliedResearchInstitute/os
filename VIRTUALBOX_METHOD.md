# Build NTARI OS Using VirtualBox (Docker Alternative)

**If Docker isn't working, use VirtualBox instead - it's actually better for testing!**

---

## Why VirtualBox?

- ✅ More stable on Windows
- ✅ Easier to test the ISO
- ✅ Can build AND test in same environment
- ✅ No WSL 2 dependencies
- ✅ Better for hardware compatibility testing

---

## Method 1: Just Test Pre-Built ISO (If Available)

If someone has already built an ISO, you can just test it:

**Download QEMU (Easiest):**

1. Download QEMU for Windows: https://qemu.wintoolkit.com/
2. Install it
3. Run:
   ```bash
   qemu-system-x86_64 -cdrom path/to/ntari-server.iso -m 2048
   ```

---

## Method 2: Build in Alpine Linux VM

This is the "proper" way to build an OS - in a VM!

### Step 1: Install VirtualBox (5 minutes)

1. Download: https://www.virtualbox.org/wiki/Downloads
2. Install "VirtualBox Platform Package"
3. Restart if prompted

### Step 2: Download Alpine Linux (2 minutes)

1. Go to: https://alpinelinux.org/downloads/
2. Download "Standard x86_64" (about 150MB)
   - Current version: Alpine 3.19
   - File: `alpine-standard-3.19.x-x86_64.iso`

### Step 3: Create Alpine VM (10 minutes)

**In VirtualBox:**

1. Click **New**

2. **Settings:**
   - Name: `NTARI-Builder`
   - Type: `Linux`
   - Version: `Other Linux (64-bit)`
   - Memory: `2048 MB`
   - Hard Disk: `20 GB VDI, Dynamically allocated`

3. **Before starting, go to Settings:**
   - System → Processor → CPUs: `2`
   - Storage → Controller: IDE → Add Alpine ISO
   - Network → Adapter 1 → NAT → Enable

4. **Start the VM**

### Step 4: Install Alpine in VM (15 minutes)

**Boot Alpine (login as root, no password):**

```bash
# 1. Setup network
setup-interfaces -a
rc-service networking restart

# 2. Run installer
setup-alpine

# Follow prompts:
# - Keyboard: us
# - Hostname: ntari-builder
# - Network: dhcp (keep defaults)
# - Root password: (set a password you'll remember)
# - Timezone: US/Eastern (or your timezone)
# - Proxy: none
# - Mirror: f (find fastest)
# - SSH: openssh
# - NTP: chrony
# - Disk: sda
# - Mode: sys
# - Erase: y

# 3. Reboot
reboot
```

### Step 5: Transfer NTARI Code to VM (5 minutes)

**On your Windows machine:**

Create a zip of the NTARI OS code:

```bash
cd C:/Users/Jodson\ Graves/Documents/NTARIOS/
tar -czf ntari-os.tar.gz ntari-os/
```

**In Alpine VM:**

```bash
# Login as root

# Install tools
apk add wget nano git

# Option A: If you have GitHub
git clone https://github.com/yourusername/ntari-os.git
cd ntari-os

# Option B: Transfer via HTTP
# (Start a simple HTTP server on Windows, then wget from Alpine)

# Option C: Use VirtualBox Shared Folders
# Settings → Shared Folders → Add folder
# Then mount in Alpine:
mkdir /mnt/shared
mount -t vboxsf shared /mnt/shared
```

### Step 6: Build ISO in Alpine VM (10 minutes)

```bash
# Install build dependencies
apk add alpine-sdk xorriso squashfs-tools grub grub-efi syslinux mtools dosfstools

# Navigate to build directory
cd ntari-os/build

# Run setup
./build-alpine.sh

# Build ISO
./build-iso.sh server

# ISO will be in: build-output/ntari-server-*.iso
```

### Step 7: Test the ISO (Immediate)

**In the same Alpine VM:**

```bash
# Install QEMU in Alpine
apk add qemu-system-x86_64

# Test the ISO
qemu-system-x86_64 \
  -cdrom build-output/ntari-server-*.iso \
  -m 2048 \
  -enable-kvm
```

**Or copy ISO to Windows and test in VirtualBox:**

```bash
# In Alpine VM, copy ISO to shared folder
cp build-output/ntari-server-*.iso /mnt/shared/

# Then create new VM in VirtualBox on Windows and attach the ISO
```

---

## Method 3: Use WSL Ubuntu (Alternative)

If you have WSL (Windows Subsystem for Linux):

```bash
# Open WSL Ubuntu
wsl

# Install Docker in WSL
sudo apt update
sudo apt install docker.io
sudo service docker start

# Navigate to NTARI project
cd /mnt/c/Users/Jodson\ Graves/Documents/NTARIOS/ntari-os/build

# Build with Docker
sudo ./docker-build.sh server
```

---

## Quick Decision Guide

**Choose based on your situation:**

| Method | Time | Difficulty | Best For |
|--------|------|------------|----------|
| QEMU only | 5 min | Easy | Just testing ISO |
| Alpine VM | 45 min | Medium | Full build + test |
| WSL Ubuntu | 20 min | Medium | If WSL works |
| Fix Docker | 10-30 min | Varies | If you prefer Docker |

---

## Recommendation

**For you right now:**

1. **Quick test:** Install VirtualBox + QEMU for testing
2. **Full development:** Create Alpine VM for building

This way you can:
- Test ISOs immediately with QEMU
- Build new ISOs in Alpine VM when needed
- Both tools work together perfectly

---

## Next Steps

Which would you prefer?

**A) Quick QEMU test** (5 minutes)
- Install QEMU
- I'll provide a test ISO or help you build one quickly

**B) Full Alpine VM setup** (45 minutes)
- Create proper build environment
- Build NTARI OS natively
- Professional development setup

**C) Fix Docker** (10-30 minutes)
- Try the fixes in DOCKER_FIX.md
- Use original Docker method

Let me know which path you want to take!
