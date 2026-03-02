#!/bin/sh
# NTARI OS Alpine Linux Build Script
# Phase 1, Milestone 1.1: Alpine Base System
# Version: 1.0.0
#
# NOTE: This script generates package lists and Docker build environments.
# It is part of the v1.0/v1.4 build system. For v1.5 Alpine 3.23 + ROS2
# builds, see build-iso.sh and the Makefile.

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NTARI_VERSION="1.0.0"
ALPINE_VERSION="3.19"
BUILD_DATE=$(date +%Y%m%d)
ISO_NAME="ntari-server-${NTARI_VERSION}-${BUILD_DATE}.iso"

# Directories
BUILD_DIR="$(pwd)/build-output"
WORK_DIR="${BUILD_DIR}/work"
ISO_DIR="${BUILD_DIR}/iso"
ROOT_DIR="${BUILD_DIR}/root"

echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo "${GREEN}  NTARI OS Alpine Linux Build System${NC}"
echo "${GREEN}  Version: ${NTARI_VERSION}${NC}"
echo "${GREEN}  Alpine: ${ALPINE_VERSION}${NC}"
echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Function: Print step
step() {
    echo ""
    echo "${YELLOW}[STEP]${NC} $1"
    echo "────────────────────────────────────────────────────────"
}

# Function: Check prerequisites
check_prerequisites() {
    step "Checking prerequisites"

    # Check if running on Alpine Linux
    if [ -f /etc/alpine-release ]; then
        echo "${GREEN}✓${NC} Running on Alpine Linux $(cat /etc/alpine-release)"
    else
        echo "${RED}✗${NC} Not running on Alpine Linux"
        echo "${YELLOW}Note:${NC} For Windows development, we'll use Docker"
        echo "${YELLOW}Note:${NC} For now, this script will prepare the build configuration"
        return 0
    fi

    # Check for required tools
    REQUIRED_TOOLS="apk git"
    for tool in $REQUIRED_TOOLS; do
        if command -v $tool >/dev/null 2>&1; then
            echo "${GREEN}✓${NC} $tool found"
        else
            echo "${RED}✗${NC} $tool not found"
            exit 1
        fi
    done
}

# Function: Setup directories
setup_directories() {
    step "Setting up build directories"

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${WORK_DIR}"
    mkdir -p "${ISO_DIR}"
    mkdir -p "${ROOT_DIR}"

    echo "${GREEN}✓${NC} Build directory: ${BUILD_DIR}"
    echo "${GREEN}✓${NC} Working directory: ${WORK_DIR}"
    echo "${GREEN}✓${NC} ISO directory: ${ISO_DIR}"
    echo "${GREEN}✓${NC} Root filesystem: ${ROOT_DIR}"
}

# Function: Create package list for Server Edition
create_server_package_list() {
    step "Creating Server Edition package list"

    cat > "${BUILD_DIR}/packages-server.txt" <<'EOF'
# NTARI OS Server Edition Package List
# Base: Alpine Linux 3.19
# Target: Headless servers, Raspberry Pi, infrastructure nodes
# Size Target: ~180MB

# ═══════════════════════════════════════════════════════
# CORE SYSTEM
# ═══════════════════════════════════════════════════════

# Base system
alpine-base
alpine-conf
alpine-baselayout

# Init system
openrc

# Kernel
linux-lts
linux-firmware

# System utilities
busybox
util-linux
coreutils
findutils

# ═══════════════════════════════════════════════════════
# NETWORKING
# ═══════════════════════════════════════════════════════

# Network management
networkmanager
networkmanager-cli
networkmanager-tui
iproute2
iputils
dhcpcd

# WiFi support
wpa_supplicant
wireless-tools
iw

# DNS
dnsmasq

# SSH server
openssh-server

# ═══════════════════════════════════════════════════════
# P2P NETWORKING (NTARI Core)
# ═══════════════════════════════════════════════════════

# P2P libraries (will be built separately)
# libp2p - installed via custom build
# cyclone-dds - installed via custom build

# Network utilities for P2P
avahi
avahi-tools
nss-mdns

# NAT traversal
miniupnpc

# ═══════════════════════════════════════════════════════
# STORAGE
# ═══════════════════════════════════════════════════════

# Filesystem tools
e2fsprogs
xfsprogs
btrfs-progs
dosfstools
ntfs-3g

# Disk management
parted
lvm2
cryptsetup

# SMART monitoring
smartmontools

# ═══════════════════════════════════════════════════════
# DEVELOPMENT & BUILD TOOLS
# ═══════════════════════════════════════════════════════

# Compilers
build-base
gcc
g++
make
cmake

# Version control
git

# Scripting
python3
py3-pip
nodejs
npm

# Rust (for NTARI core services)
rust
cargo

# ═══════════════════════════════════════════════════════
# SECURITY
# ═══════════════════════════════════════════════════════

# Firewall
iptables
ip6tables

# Encryption
gnupg
openssl

# Security scanning
lynis

# ═══════════════════════════════════════════════════════
# MONITORING & LOGGING
# ═══════════════════════════════════════════════════════

# System monitoring
htop
iotop
iftop

# Logging
rsyslog

# ═══════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════

# Text editors
nano
vim

# File utilities
rsync
wget
curl
tar
gzip
bzip2
xz

# Process management
supervisor

# Time synchronization
chrony

# Hardware detection
pciutils
usbutils
dmidecode

# ═══════════════════════════════════════════════════════
# CONTAINER SUPPORT (for compute jobs)
# ═══════════════════════════════════════════════════════

# Podman (preferred over Docker for v1.5+)
# podman

# ═══════════════════════════════════════════════════════
# TOTAL ESTIMATED SIZE: ~180MB
# ═══════════════════════════════════════════════════════
EOF

    echo "${GREEN}✓${NC} Server Edition package list created"
    echo "   Packages: $(grep -v '^#' ${BUILD_DIR}/packages-server.txt | grep -v '^$' | wc -l)"
}

# Function: Create package list for Desktop Edition
create_desktop_package_list() {
    step "Creating Desktop Edition package list"

    cat > "${BUILD_DIR}/packages-desktop.txt" <<'EOF'
# NTARI OS Desktop Edition Package List
# Base: Server Edition + Desktop Environment
# Target: Regular users, families, small businesses
# Size Target: ~1.2GB

# ═══════════════════════════════════════════════════════
# BASE (includes all Server Edition packages)
# ═══════════════════════════════════════════════════════
# @SERVER_EDITION

# ═══════════════════════════════════════════════════════
# DESKTOP ENVIRONMENT - XFCE
# ═══════════════════════════════════════════════════════

# X11 server
xorg-server
xf86-video-intel
xf86-video-amd
xf86-video-nouveau
xf86-input-libinput

# XFCE desktop
xfce4
xfce4-terminal
xfce4-screensaver
xfce4-taskmanager
xfce4-power-manager
xfce4-notifyd
xfce4-pulseaudio-plugin

# Display manager
lightdm
lightdm-gtk-greeter

# ═══════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════

# Audio system
alsa-utils
alsa-plugins-pulse
pulseaudio
pulseaudio-alsa
pavucontrol

# ═══════════════════════════════════════════════════════
# PRINTER & SCANNER SUPPORT
# ═══════════════════════════════════════════════════════

# Printing
cups
cups-filters
hplip
gutenprint
system-config-printer

# Scanning
sane
sane-backends
simple-scan

# ═══════════════════════════════════════════════════════
# BLUETOOTH
# ═══════════════════════════════════════════════════════

bluez
blueman

# ═══════════════════════════════════════════════════════
# DISK TOOLS (GUI)
# ═══════════════════════════════════════════════════════

gparted
gnome-disk-utility

# ═══════════════════════════════════════════════════════
# APPLICATIONS
# ═══════════════════════════════════════════════════════

# File manager
thunar
thunar-volman
thunar-archive-plugin

# Web browser
firefox-esr

# Text editor
mousepad

# Image viewer
ristretto

# PDF viewer
evince

# Archive manager
xarchiver

# Calculator
galculator

# ═══════════════════════════════════════════════════════
# FONTS
# ═══════════════════════════════════════════════════════

ttf-dejavu
font-noto
font-noto-emoji

# ═══════════════════════════════════════════════════════
# THEMES & ICONS
# ═══════════════════════════════════════════════════════

arc-theme
papirus-icon-theme

# ═══════════════════════════════════════════════════════
# MULTIMEDIA
# ═══════════════════════════════════════════════════════

# Video player
vlc

# Image editor (lightweight)
gimp

# ═══════════════════════════════════════════════════════
# NETWORK TOOLS (GUI)
# ═══════════════════════════════════════════════════════

network-manager-applet
nm-connection-editor

# ═══════════════════════════════════════════════════════
# TOTAL ESTIMATED SIZE: ~1.2GB
# ═══════════════════════════════════════════════════════
EOF

    echo "${GREEN}✓${NC} Desktop Edition package list created"
    echo "   Additional packages: $(grep -v '^#' ${BUILD_DIR}/packages-desktop.txt | grep -v '^$' | wc -l)"
}

# Function: Create package list for Lite Edition
create_lite_package_list() {
    step "Creating Lite Edition package list"

    cat > "${BUILD_DIR}/packages-lite.txt" <<'EOF'
# NTARI OS Lite Edition Package List
# Base: Server Edition + Minimal GUI
# Target: Old computers, low-RAM devices
# Size Target: ~400MB

# ═══════════════════════════════════════════════════════
# BASE (includes all Server Edition packages)
# ═══════════════════════════════════════════════════════
# @SERVER_EDITION

# ═══════════════════════════════════════════════════════
# MINIMAL DESKTOP - LXDE/LXQt
# ═══════════════════════════════════════════════════════

# X11 server (minimal)
xorg-server
xf86-video-fbdev
xf86-input-libinput

# LXQt desktop (lightweight)
lxqt-base
lxqt-config
lxqt-panel
lxqt-runner
lxqt-session
openbox

# Display manager (lightweight)
lxdm

# ═══════════════════════════════════════════════════════
# AUDIO (minimal)
# ═══════════════════════════════════════════════════════

alsa-utils

# ═══════════════════════════════════════════════════════
# APPLICATIONS (minimal)
# ═══════════════════════════════════════════════════════

# File manager (lightweight)
pcmanfm-qt

# Web browser (lightweight)
midori

# Text editor
leafpad

# Terminal
lxterminal

# ═══════════════════════════════════════════════════════
# FONTS (minimal)
# ═══════════════════════════════════════════════════════

ttf-dejavu

# ═══════════════════════════════════════════════════════
# TOTAL ESTIMATED SIZE: ~400MB
# ═══════════════════════════════════════════════════════
EOF

    echo "${GREEN}✓${NC} Lite Edition package list created"
    echo "   Additional packages: $(grep -v '^#' ${BUILD_DIR}/packages-lite.txt | grep -v '^$' | wc -l)"
}

# Function: Create build configuration
create_build_config() {
    step "Creating build configuration"

    cat > "${BUILD_DIR}/ntari-build.conf" <<EOF
# NTARI OS Build Configuration
# Generated: $(date)

# Version info
NTARI_VERSION="${NTARI_VERSION}"
ALPINE_VERSION="${ALPINE_VERSION}"
BUILD_DATE="${BUILD_DATE}"

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

# Directories
BUILD_DIR="${BUILD_DIR}"
WORK_DIR="${WORK_DIR}"
ISO_DIR="${ISO_DIR}"
ROOT_DIR="${ROOT_DIR}"
EOF

    echo "${GREEN}✓${NC} Build configuration created: ${BUILD_DIR}/ntari-build.conf"
}

# Function: Create Dockerfile for build environment
create_dockerfile() {
    step "Creating Docker build environment"

    cat > "${BUILD_DIR}/Dockerfile" <<'EOF'
# NTARI OS Build Environment
# Based on Alpine Linux for building NTARI OS

FROM alpine:3.19

# Install build dependencies
RUN apk add --no-cache \
    alpine-sdk \
    alpine-conf \
    build-base \
    apk-tools \
    alpine-baselayout \
    busybox \
    fakeroot \
    syslinux \
    xorriso \
    squashfs-tools \
    grub \
    grub-efi \
    mtools \
    dosfstools \
    git \
    rsync

# Create build user
RUN adduser -D -G abuild builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Setup abuild
USER builder
RUN abuild-keygen -a -i -n

# Working directory
WORKDIR /build

# Default command
CMD ["/bin/sh"]
EOF

    echo "${GREEN}✓${NC} Dockerfile created for build environment"
    echo "   To use: docker build -t ntari-builder -f ${BUILD_DIR}/Dockerfile ."
}

# Function: Summary
show_summary() {
    step "Build Environment Ready"

    echo ""
    echo "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║  NTARI OS Build Environment - Phase 1.1 Complete  ║${NC}"
    echo "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Created:"
    echo "  ${GREEN}✓${NC} Server Edition package list ($(grep -v '^#' ${BUILD_DIR}/packages-server.txt | grep -v '^$' | wc -l) packages)"
    echo "  ${GREEN}✓${NC} Desktop Edition package list ($(grep -v '^#' ${BUILD_DIR}/packages-desktop.txt | grep -v '^$' | wc -l) packages)"
    echo "  ${GREEN}✓${NC} Lite Edition package list ($(grep -v '^#' ${BUILD_DIR}/packages-lite.txt | grep -v '^$' | wc -l) packages)"
    echo "  ${GREEN}✓${NC} Build configuration"
    echo "  ${GREEN}✓${NC} Docker build environment"
    echo ""
    echo "Next Steps:"
    echo "  1. Build Docker image: cd build && docker build -t ntari-builder -f build-output/Dockerfile ."
    echo "  2. Run build container: docker run -it -v \$(pwd):/build ntari-builder"
    echo "  3. Build ISO: ./build-iso.sh server"
    echo ""
    echo "Build output directory: ${BUILD_DIR}"
    echo ""
}

# ═══════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════

main() {
    check_prerequisites
    setup_directories
    create_server_package_list
    create_desktop_package_list
    create_lite_package_list
    create_build_config
    create_dockerfile
    show_summary
}

# Run main function
main "$@"
