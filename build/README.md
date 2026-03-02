# NTARI OS Build System

**Phase**: 1.1 - Alpine Base System
**Status**: 🔄 60% Complete - ISO Building Ready
**Date**: February 16, 2026

---

## Overview

This directory contains the build system for creating NTARI OS ISO images based on Alpine Linux 3.19.

### Editions

NTARI OS is available in three editions:

1. **Server Edition** (~180MB)
   - Headless, terminal-only
   - Target: Raspberry Pi, servers, infrastructure nodes
   - Packages: Core system + networking + P2P

2. **Desktop Edition** (~1.2GB)
   - XFCE graphical environment
   - Target: Regular users, families, small businesses
   - Packages: Server Edition + XFCE + applications

3. **Lite Edition** (~400MB)
   - Minimal LXQt GUI
   - Target: Old computers, low-RAM devices
   - Packages: Server Edition + LXQt + minimal apps

---

## Quick Start

### Prerequisites

- **Docker** (for building on Windows/Mac/Linux)
- OR **Alpine Linux** (for native building)

### Build Process (Using Docker - Recommended)

```bash
# 1. Navigate to ntari-os directory
cd ntari-os/build

# 2. Run build setup (creates package lists, Dockerfile)
chmod +x build-alpine.sh
./build-alpine.sh

# 3. Build ISO using Docker wrapper
chmod +x docker-build.sh
./docker-build.sh server    # For Server Edition
./docker-build.sh desktop   # For Desktop Edition
./docker-build.sh lite      # For Lite Edition
```

### Build Process (Native Alpine Linux)

```bash
# 1. Install build dependencies
apk add alpine-sdk xorriso squashfs-tools grub grub-efi syslinux mtools dosfstools

# 2. Run build setup
./build-alpine.sh

# 3. Build ISO directly
chmod +x build-iso.sh
./build-iso.sh server       # For Server Edition
./build-iso.sh desktop      # For Desktop Edition
./build-iso.sh lite         # For Lite Edition
```

---

## Build Output

After running `./build/build-alpine.sh`, the following files are created:

### Directory Structure

```
build-output/
├── Dockerfile              # Docker build environment
├── ntari-build.conf        # Build configuration
├── packages-server.txt     # Server Edition package list
├── packages-desktop.txt    # Desktop Edition package list
├── packages-lite.txt       # Lite Edition package list
├── work/                   # Build working directory
├── iso/                    # Output ISO files
└── root/                   # Root filesystem
```

### Package Lists

Each edition has a detailed package list with categories:

**Server Edition** (`packages-server.txt`):
- Core System (Alpine base, kernel, utilities)
- Networking (NetworkManager, WiFi, SSH)
- P2P Networking (Avahi, UPnP, DDS support)
- Storage (filesystem tools, encryption, SMART)
- Development Tools (compilers, Python, Node.js, Rust)
- Security (iptables, GnuPG, SSL)
- Monitoring (htop, rsyslog)
- Utilities (text editors, rsync, time sync)

**Desktop Edition** (`packages-desktop.txt`):
- Everything from Server Edition
- XFCE Desktop Environment
- X11 Server with GPU drivers (Intel, AMD, NVIDIA)
- Audio (ALSA, PulseAudio)
- Printers & Scanners (CUPS, SANE)
- Bluetooth
- Disk Tools (GParted, GNOME Disks)
- Applications (Firefox, Thunar, text editor, PDF viewer)
- Fonts & Themes
- Multimedia (VLC, GIMP)

**Lite Edition** (`packages-lite.txt`):
- Everything from Server Edition
- LXQt Desktop (lightweight)
- Minimal X11 setup
- Basic ALSA audio
- Lightweight applications (PCManFM, Midori, Leafpad)

---

## Build Configuration

The `ntari-build.conf` file contains:

```ini
# Version info
NTARI_VERSION="1.0.0"
ALPINE_VERSION="3.19"
BUILD_DATE="20260216"

# Architecture
ARCH="x86_64"

# Kernel
KERNEL_FLAVOR="lts"

# Init system
INIT_SYSTEM="openrc"

# Bootloader
BOOTLOADER="grub"

# Default edition
DEFAULT_EDITION="server"

# Build options
ENABLE_COMPRESSION="yes"
COMPRESSION_TYPE="xz"
ISO_LABEL="NTARI_OS"
```

---

## Docker Build Environment

The `Dockerfile` creates an Alpine Linux container with all necessary build tools:

- **alpine-sdk** - Build tools
- **alpine-conf** - Alpine configuration
- **build-base** - GCC, make, etc.
- **apk-tools** - Package manager
- **syslinux** - Bootloader
- **xorriso** - ISO creation
- **squashfs-tools** - Filesystem compression
- **grub** - UEFI bootloader
- **git, rsync** - Version control and file sync

### Using the Docker Environment

```bash
# Build the image
docker build -t ntari-builder -f build-output/Dockerfile .

# Run interactive session
docker run -it -v $(pwd):/build ntari-builder

# Inside container
cd /build
./build/build-alpine.sh --build-iso server
```

---

## Development Status

### ✅ Completed (Phase 1.1)

- [x] Build script framework
- [x] Package lists for all three editions
- [x] Build configuration
- [x] Docker build environment
- [x] Directory structure
- [x] NTARI initialization script
- [x] NTARI CLI tool
- [x] ISO building script (build-iso.sh)
- [x] Docker wrapper script (docker-build.sh)
- [x] GRUB bootloader configuration
- [x] SquashFS root filesystem creation

### 🔄 In Progress

- [ ] ISO testing in QEMU
- [ ] ISO testing in VirtualBox
- [ ] USB boot testing
- [ ] Kernel customization (future enhancement)

### ⏳ Planned (Next Milestones)

- [ ] USB installer tool (Milestone 1.2)
- [ ] Desktop Edition build (Milestone 1.3)
- [ ] First-run wizard (Milestone 1.4)
- [ ] Hardware testing (Milestone 1.5)
- [ ] Documentation (Milestone 1.6)

---

## Files

### Build Scripts

- **build-alpine.sh** - Preparation script
  - Sets up build environment
  - Creates package lists for all three editions
  - Generates build configuration
  - Creates Dockerfile for containerized builds

- **build-iso.sh** - ISO creation script (NEW)
  - Downloads Alpine Linux base system
  - Installs packages from edition-specific lists
  - Installs NTARI components (CLI, init scripts)
  - Configures system settings
  - Creates SquashFS compressed root filesystem
  - Builds bootable ISO with GRUB bootloader
  - Generates SHA256 checksums

- **docker-build.sh** - Docker wrapper script (NEW)
  - Checks Docker installation and status
  - Builds ntari-builder Docker image if needed
  - Runs build-iso.sh inside Alpine container
  - Provides cross-platform build support

### Core System

Located in `../core/`:

- **ntari-init.sh** - First boot initialization
  - Creates NTARI directories
  - Generates node UUID
  - Creates default configuration
  - Enables services

- **ntari-cli.sh** - NTARI CLI tool
  - System status dashboard
  - Network management
  - Hardware information
  - Log viewing

---

## Package Counts

Based on current package lists:

| Edition | Core Packages | Additional Packages | Total Size |
|---------|---------------|---------------------|------------|
| Server  | ~85           | -                   | ~180MB     |
| Desktop | ~85           | ~60                 | ~1.2GB     |
| Lite    | ~85           | ~15                 | ~400MB     |

---

## Testing

### Local Testing (VM)

1. Build ISO
2. Create VM in VirtualBox/QEMU
3. Boot from ISO
4. Test installation
5. Verify NTARI services

### Hardware Testing (Phase 1.5)

Will test on 20+ real computers:
- Dell, HP, Lenovo, ASUS, Acer
- Various ages (2010-2024)
- Different WiFi chipsets
- Multiple GPU types

---

## Troubleshooting

### Build fails with "Permission denied"

```bash
# Fix: Make scripts executable
chmod +x build/build-alpine.sh
```

### Docker build fails

```bash
# Fix: Ensure Docker is running
docker --version
docker ps
```

### Package not found

```bash
# Fix: Update Alpine repositories
apk update
apk search <package-name>
```

---

## Next Steps

1. **Implement ISO building** (this milestone)
   - Add ISO creation to build script
   - Configure bootloader
   - Test in QEMU

2. **Build USB Installer** (Milestone 1.2)
   - Electron + React app
   - Cross-platform builds
   - ISO download and write

3. **Test on Hardware** (Milestone 1.5)
   - 20+ computers
   - WiFi compatibility
   - BIOS screenshots
   - Hardware compatibility list

---

## References

- [Alpine Linux Documentation](https://wiki.alpinelinux.org/)
- [NTARI OS Specification v1.4](../../NTARI_OS_Specification_v1.4.txt)
- [ROADMAP](../ROADMAP.md)
- [Phase 1 Checklist](../../v1.4_IMPLEMENTATION_CHECKLIST.md)

---

## Support

**Questions?** See main project README or CONTRIBUTING.md

**Issues?** File in issue tracker (coming soon)

**Email**: info@ntari.org

---

**Last Updated**: February 16, 2026
**Phase**: 1.1 - Alpine Base System
**Status**: ✅ Build Environment Ready
