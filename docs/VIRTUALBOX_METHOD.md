# Build NTARI OS Using VirtualBox (Docker Alternative)

**If Docker isn't working, use VirtualBox instead — it's actually better for testing!**

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

**Using QEMU:**

```bash
qemu-system-x86_64 -cdrom path/to/ntari-server.iso -m 2048
```

QEMU for Windows: https://qemu.wintoolkit.com/

---

## Method 2: Build in Alpine Linux VM

This is the "proper" way to build an OS — in a VM.

### Step 1: Install VirtualBox (5 minutes)

1. Download: https://www.virtualbox.org/wiki/Downloads
2. Install "VirtualBox Platform Package"
3. Restart if prompted

### Step 2: Download Alpine Linux (2 minutes)

1. Go to: https://alpinelinux.org/downloads/
2. Download "Standard x86_64" (about 150MB)
   - Use Alpine 3.23 (current stable as of v1.5)
   - File: `alpine-standard-3.23.x-x86_64.iso`

### Step 3: Create Alpine VM (10 minutes)

**In VirtualBox:**

1. Click **New**

2. **Settings:**
   - Name: `NTARI-Builder`
   - Type: `Linux`
   - Version: `Other Linux (64-bit)`
   - Memory: `4096 MB` (2GB minimum; 4GB recommended for ROS2 builds)
   - Hard Disk: `50 GB VDI, Dynamically allocated`

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

**Option A: Git clone (recommended)**

```bash
# In Alpine VM
apk add git nano
git clone https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os.git
cd ntari-os
```

**Option B: VirtualBox Shared Folders**

```bash
# Settings → Shared Folders → Add folder (point to your NTARI OS folder)
mkdir /mnt/shared
mount -t vboxsf "NTARI OS" /mnt/shared
```

### Step 6: Build ISO in Alpine VM (10 minutes)

```bash
# Install build dependencies
apk add alpine-sdk xorriso squashfs-tools grub grub-efi syslinux mtools dosfstools

# Navigate to build directory
cd ntari-os/build

# Run setup (generates package lists and Dockerfile)
./build-alpine.sh

# Build ISO
./build-iso.sh server
# or: server | desktop | lite

# ISO will be in: build-output/ntari-server-*.iso
```

### Step 7: Test the ISO

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
cd /mnt/c/Users/Jodson\ Graves/Documents/NTARI\ OS/build

# Build with Docker
sudo ./docker-build.sh server
```

---

## Known Boot Issue (v1.0 Build System)

The v1.0 ISO builder (`build-iso.sh`) uses a custom SquashFS root that doesn't
match Alpine's standard Live CD boot expectations. If the ISO boots to an
initramfs emergency shell with "Mounting boot media failed", this is a known
issue. See [QEMU_BOOT_ISSUES.md](./QEMU_BOOT_ISSUES.md) for full analysis
and solutions. The v1.5 build system (via `make iso`) resolves this by
following Alpine's standard `mkimage`/`alpine-make-vm-image` approach.

---

## Quick Decision Guide

| Method | Time | Difficulty | Best For |
|--------|------|------------|----------|
| QEMU only | 5 min | Easy | Just testing ISO |
| Alpine VM | 45 min | Medium | Full build + test |
| WSL Ubuntu | 20 min | Medium | If WSL works |
| Fix Docker | 10-30 min | Varies | If you prefer Docker |
