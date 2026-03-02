#!/bin/sh
# NTARI OS ISO Builder — v1.5
# Uses Alpine's native mkimage approach for proper bootable ISOs.
# Replaces the v1.0 custom SquashFS method which caused initramfs boot failure.
#
# Requires: busybox ash (Alpine) — set -o pipefail supported.
# MUST run inside Alpine Linux 3.23 (in Docker or a native Alpine VM).
# See: docs/VIRTUALBOX_METHOD.md for setup instructions.

set -e
set -o pipefail

# ─────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────

NTARI_VERSION="1.5.0"
ALPINE_VERSION="3.23"
ALPINE_BRANCH="3.23-stable"          # aports git branch name
ALPINE_URL_PATH="v${ALPINE_VERSION}" # CDN URL path (v3.23, not 3.23-stable)
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
BUILD_DATE=$(date +%Y%m%d)
ARCH="${ARCH:-x86_64}"
EDITION="${1:-server}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${SCRIPT_DIR}/build-output"
PROFILE_DIR="${SCRIPT_DIR}/mkimage-profiles"
# APORTS_DIR, WORK_DIR, and OVERLAY_DIR live in /tmp (not the Windows-mounted
# volume). Docker Desktop on Windows mounts volumes with UID 0 ownership;
# builder (UID 1000) cannot write there. /tmp is inside the container and
# always writable by builder. OUTPUT_ISO and OVERLAY_TGZ are written back to
# BUILD_DIR (mounted volume) at the end, so artifacts are accessible on the host.
APORTS_DIR="/tmp/aports"
WORK_DIR="/tmp/work-${EDITION}"
OVERLAY_DIR="/tmp/overlay-${EDITION}"

ISO_NAME="ntari-os-${NTARI_VERSION}-${ARCH}-${EDITION}-${BUILD_DATE}.iso"

# ─────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────

log()  { echo "${GREEN}[✓]${NC} $*"; }
info() { echo "${BLUE}[→]${NC} $*"; }
warn() { echo "${YELLOW}[!]${NC} $*"; }
err()  { echo "${RED}[✗]${NC} $*"; exit 1; }
step() {
    echo ""
    echo "${CYAN}══════════════════════════════════════════════════${NC}"
    echo "${CYAN}  $*${NC}"
    echo "${CYAN}══════════════════════════════════════════════════${NC}"
}

# ─────────────────────────────────────────────────────────
# 1. Environment check
# ─────────────────────────────────────────────────────────

check_environment() {
    step "Checking build environment"

    # Must be Alpine
    if [ ! -f /etc/alpine-release ]; then
        err "Must run on Alpine Linux. Use: docker run --rm -it --privileged \\
  -v \$(pwd):/build alpine:3.23 /build/build/build-iso.sh ${EDITION}"
    fi

    ALPINE_CURRENT=$(cat /etc/alpine-release)
    log "Alpine Linux ${ALPINE_CURRENT}"

    # Check Alpine version is 3.23+
    case "$ALPINE_CURRENT" in
        3.2[3-9]*|3.[3-9][0-9]*)
            log "Alpine version OK (${ALPINE_CURRENT})" ;;
        *)
            warn "Expected Alpine 3.23+, got ${ALPINE_CURRENT}. Continuing..." ;;
    esac

    # Validate edition
    case "$EDITION" in
        server)  log "Edition: server (headless, minimal, no ROS2)" ;;
        ros2)    log "Edition: ros2 (server + ROS2 Jazzy + Cyclone DDS)" ;;
        *)
            err "Invalid edition '${EDITION}'. Supported: server, ros2"
            ;;
    esac

    # Install required tools (sudo needed — container runs as builder UID 1000)
    step "Installing build tools"
    sudo apk add --no-cache \
        alpine-sdk \
        apk-tools \
        alpine-conf \
        xorriso \
        squashfs-tools \
        mtools \
        dosfstools \
        grub \
        grub-bios \
        grub-efi \
        syslinux \
        abuild \
        git \
        bash \
        wget \
        curl \
        sudo \
        openssl \
        || err "Failed to install build tools"

    log "Build tools installed"
}

# ─────────────────────────────────────────────────────────
# 1b. Trust alpine-ros APK key in build environment (ros2 edition only)
# ─────────────────────────────────────────────────────────
# mkimage.sh installs packages into the ISO rootfs using apk.
# For the ros2 edition, it pulls from the alpine-ros APK repo.
# The build container must trust the alpine-ros signing key BEFORE mkimage
# runs — otherwise apk will refuse unsigned packages from that repo.

trust_ros2_repos() {
    step "Verifying alpine-ros APK key in build environment"

    ALPINE_ROS_KEY_PATH="/etc/apk/keys/builder@alpine-ros-experimental.rsa.pub"

    # The key is baked into the Docker image at build time (see Dockerfile).
    # This function verifies it's present and the repo is indexed.
    if [ -f "${ALPINE_ROS_KEY_PATH}" ]; then
        log "alpine-ros APK key present: ${ALPINE_ROS_KEY_PATH}"
    else
        warn "alpine-ros APK key not found — ROS2 packages will fail signature check."
        warn "Rebuild the Docker image: docker build -t ntari-builder:1.5 build/"
    fi

    if grep -q "seqsense.org" /etc/apk/repositories 2>/dev/null; then
        log "alpine-ros repository present in build environment"
    else
        warn "alpine-ros repo missing from /etc/apk/repositories — ROS2 packages unavailable."
    fi
}

# ─────────────────────────────────────────────────────────
# 2. Clone aports (Alpine package tree)
# ─────────────────────────────────────────────────────────

setup_aports() {
    step "Setting up Alpine aports (package tree)"

    mkdir -p "${BUILD_DIR}"

    if [ -d "${APORTS_DIR}/.git" ]; then
        info "Updating existing aports clone..."
        git -C "${APORTS_DIR}" fetch --depth=1 origin "${ALPINE_BRANCH}" \
            && git -C "${APORTS_DIR}" checkout "${ALPINE_BRANCH}" \
            || warn "aports update failed; using existing"
    else
        info "Cloning Alpine aports (branch ${ALPINE_BRANCH})..."
        git clone --depth=1 --branch="${ALPINE_BRANCH}" \
            https://gitlab.alpinelinux.org/alpine/aports.git \
            "${APORTS_DIR}" \
            || err "Failed to clone aports"
    fi

    log "aports ready at ${APORTS_DIR}"
}

# ─────────────────────────────────────────────────────────
# 3. Create mkimage profile for NTARI OS
# ─────────────────────────────────────────────────────────

create_profile() {
    step "Creating NTARI OS mkimage profile"

    PROFILE_SCRIPTS="${APORTS_DIR}/scripts"
    NTARI_PROFILE="${PROFILE_SCRIPTS}/mkimg.ntari.sh"

    cat > "${NTARI_PROFILE}" <<'PROFILE'
#!/bin/sh
# NTARI OS mkimage profile — v1.5
# Network-first cooperative infrastructure OS built on Alpine 3.23
# Profiles: ntari_server (base), ntari_ros2 (base + ROS2 Jazzy)

# ── Shared base package set ───────────────────────────────────────────────
# Reused by both profiles to keep them in sync.
_ntari_base_apks="
    alpine-base
    openrc
    busybox
    linux-lts
    linux-firmware-none

    openssh
    openssl
    chrony
    iptables
    ip6tables
    nftables

    bash
    curl
    wget
    git
    nano
    htop
    lsof
    bind-tools
    jq

    python3
    py3-pip
    py3-yaml

    btrfs-progs
    f2fs-tools
    e2fsprogs
    xfsprogs
    lvm2
    cryptsetup

    avahi
    dbus
"

# ── Profile 1: ntari_server ───────────────────────────────────────────────
# Minimal headless server — no ROS2. Equivalent to v1.5.0 initial ISO.
profile_ntari_server() {
    profile_standard
    title="NTARI OS Server"
    desc="NTARI OS v1.5 — Network-First Cooperative Infrastructure (Server Edition)"
    image_ext="iso"
    output_format="iso"
    arch="x86_64"
    kernel_flavors="lts"
    boot_addons="amd-ucode intel-ucode"

    apks="$_ntari_base_apks"

    initfs_cmdline="modules=loop,squashfs,sd-mod,usb-storage"
}

# ── Profile 2: ntari_ros2 ────────────────────────────────────────────────
# Server + ROS2 Jazzy + Cyclone DDS (Phase 6 target ISO)
#
# ROS2 packages are installed from the alpine-ros APK repository
# maintained by the alpine-ros/alpine-ros community project:
#   https://github.com/alpine-ros/alpine-ros
#
# The NTARI-patched Cyclone DDS APK replaces the unpatched version
# from the alpine-ros repo to apply the musl thread stack fix.
profile_ntari_ros2() {
    profile_standard
    title="NTARI OS ROS2"
    desc="NTARI OS v1.5 — Network-First Cooperative Infrastructure (ROS2 Jazzy Edition)"
    image_ext="iso"
    output_format="iso"
    arch="x86_64"
    kernel_flavors="lts"
    boot_addons="amd-ucode intel-ucode"

    apks="
        $_ntari_base_apks
        ros-jazzy-ros-core
        ros-jazzy-ros-base
        ros-jazzy-rmw-cyclonedds-cpp
        ros-jazzy-rclcpp
        ros-jazzy-rclpy
        ros-jazzy-ros2cli
        ros-jazzy-rosidl-generator-py
        cmake
        dnsmasq
        redis
        caddy
        kea
        wireguard-tools
        samba
        openldap-server
        pciutils
        iptables
        iproute2
        bird
    "

    # Additional APK repos added to the ISO's /etc/apk/repositories
    # These are appended to the standard Alpine repos.
    # Format: <repo_url>[@<tag>]
    # alpine-ros key must be pre-trusted via /etc/apk/keys/
    repos="
        https://dl-cdn.alpinelinux.org/alpine/v3.23/main
        https://dl-cdn.alpinelinux.org/alpine/v3.23/community
        https://dl-cdn.alpinelinux.org/alpine/edge/testing
        https://alpine-ros.seqsense.org/v3.23/backports
        https://alpine-ros.seqsense.org/v3.23/ros/jazzy
    "

    initfs_cmdline="modules=loop,squashfs,sd-mod,usb-storage"
}
PROFILE

    chmod +x "${NTARI_PROFILE}"
    log "Created mkimg.ntari.sh profile"
}

# ─────────────────────────────────────────────────────────
# 4. Create NTARI overlay (custom files injected into ISO)
# ─────────────────────────────────────────────────────────

create_overlay() {
    step "Creating NTARI OS overlay files"

    # OVERLAY_DIR is set globally to /tmp/overlay-${EDITION}
    rm -rf "${OVERLAY_DIR}"
    mkdir -p "${OVERLAY_DIR}"

    # ── /etc/ntari/ ─────────────────────────────────────
    mkdir -p "${OVERLAY_DIR}/etc/ntari"
    cat > "${OVERLAY_DIR}/etc/ntari/version" <<EOF
NTARI_VERSION=${NTARI_VERSION}
NTARI_EDITION=${EDITION}
BUILD_DATE=${BUILD_DATE}
ALPINE_VERSION=${ALPINE_VERSION}
ARCH=${ARCH}
EOF

    # ROS2 config depends on edition
    ROS2_ENABLED="false"
    if [ "$EDITION" = "ros2" ]; then
        ROS2_ENABLED="true"
    fi

    cat > "${OVERLAY_DIR}/etc/ntari/config" <<EOF
# NTARI OS v1.5 Configuration
# Network-First Operating System
# Edition: ${EDITION}

# ROS2 settings
ROS_DOMAIN_ID=0
RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ROS2_INSTALLED=${ROS2_ENABLED}

# Network
NTARI_HOSTNAME=ntari-node
NTARI_MDNS=true

# Services (Core Tier — enabled by default)
NTARI_DNS=true
NTARI_NTP=true
NTARI_SSH=true
NTARI_FIREWALL=true

# Globe interface (Phase 7 — requires ROS2 + web node)
NTARI_GLOBE=false
EOF

    # ── /etc/motd ────────────────────────────────────────
    cat > "${OVERLAY_DIR}/etc/motd" <<'EOF'

  _   _ _____  _    ____  ___    ___  ____
 | \ | |_   _|/ \  |  _ \|_ _|  / _ \/ ___|
 |  \| | | | / _ \ | |_) || |  | | | \___ \
 | |\  | | |/ ___ \|  _ < | |  | |_| |___) |
 |_| \_| |_/_/   \_\_| \_\___|  \___/|____/

 NTARI OS v1.5.0 — Network-First Cooperative Infrastructure
 ──────────────────────────────────────────────────────────
 Hostname : ntari-node
 Globe UI : http://ntari.local  (after ROS2 + globe setup)
 Admin    : ntari-admin
 Docs     : /usr/local/share/ntari/

 Type 'ntari-admin' for the admin dashboard.
 Type 'ntari-init' for first-boot setup.

EOF

    # ── /etc/hostname ────────────────────────────────────
    echo "ntari-node" > "${OVERLAY_DIR}/etc/hostname"

    # ── /etc/network/interfaces ──────────────────────────
    # Brings up loopback and first Ethernet NIC via DHCP at boot.
    # Alpine 'networking' OpenRC service reads this file.
    mkdir -p "${OVERLAY_DIR}/etc/network"
    cat > "${OVERLAY_DIR}/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    hostname ntari-node
EOF

    # ── /etc/hosts ───────────────────────────────────────
    cat > "${OVERLAY_DIR}/etc/hosts" <<'EOF'
127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain
127.0.1.1   ntari-node ntari.local
EOF

    # ── /etc/apk/repositories ────────────────────────────
    mkdir -p "${OVERLAY_DIR}/etc/apk"
    cat > "${OVERLAY_DIR}/etc/apk/repositories" <<EOF
${ALPINE_MIRROR}/${ALPINE_URL_PATH}/main
${ALPINE_MIRROR}/${ALPINE_URL_PATH}/community
EOF

    # ── /etc/profile.d/ntari.sh ──────────────────────────
    mkdir -p "${OVERLAY_DIR}/etc/profile.d"
    cat > "${OVERLAY_DIR}/etc/profile.d/ntari.sh" <<'EOF'
# NTARI OS environment
export NTARI_VERSION="1.5.0"

# ROS2 (sourced when installed — Phase 6)
if [ -f /usr/ros/jazzy/setup.sh ]; then
    . /usr/ros/jazzy/setup.sh
    export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
    export ROS_DISTRO=jazzy
    if [ -f /etc/ntari/cyclonedds.xml ]; then
        export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds.xml"
    fi
fi

# PATH additions
export PATH="/usr/local/bin:${PATH}"
EOF

    # ── NTARI admin scripts ──────────────────────────────
    mkdir -p "${OVERLAY_DIR}/usr/local/bin"

    # Copy scripts from project
    for script in ntari-admin.sh ntari-init.sh health-check.sh harden-system.sh \
                  setup-ros2.sh ros2-node-health.sh \
                  ntari-hw-profile.sh ntari-node-policy.sh \
                  ntari-scheduler.sh; do
        SRC="${PROJECT_DIR}/scripts/${script}"
        if [ -f "${SRC}" ]; then
            cp "${SRC}" "${OVERLAY_DIR}/usr/local/bin/"
            chmod +x "${OVERLAY_DIR}/usr/local/bin/${script}"
            log "Included script: ${script}"
        else
            warn "Script not found (skipping): ${SRC}"
        fi
    done

    # Create ntari-admin symlink without .sh extension
    ln -sf /usr/local/bin/ntari-admin.sh        "${OVERLAY_DIR}/usr/local/bin/ntari-admin"
    ln -sf /usr/local/bin/ntari-init.sh         "${OVERLAY_DIR}/usr/local/bin/ntari-init"
    ln -sf /usr/local/bin/setup-ros2.sh         "${OVERLAY_DIR}/usr/local/bin/setup-ros2"
    ln -sf /usr/local/bin/ros2-node-health.sh   "${OVERLAY_DIR}/usr/local/bin/ros2-node-health"
    ln -sf /usr/local/bin/ntari-hw-profile.sh  "${OVERLAY_DIR}/usr/local/bin/ntari-hw-profile"
    ln -sf /usr/local/bin/ntari-node-policy.sh "${OVERLAY_DIR}/usr/local/bin/ntari-node-policy"
    ln -sf /usr/local/bin/ntari-scheduler.sh   "${OVERLAY_DIR}/usr/local/bin/ntari-scheduler"

    # ── /usr/local/share/ntari/ (docs) ───────────────────
    mkdir -p "${OVERLAY_DIR}/usr/local/share/ntari"
    cat > "${OVERLAY_DIR}/usr/local/share/ntari/README.txt" <<EOF
NTARI OS v${NTARI_VERSION} — Server Edition
Built: ${BUILD_DATE}

Documentation:
  Architecture : /usr/local/share/ntari/ARCHITECTURE.txt
  Quick Start  : /usr/local/share/ntari/QUICKSTART.txt
  Version      : /etc/ntari/version

Web (after globe setup):
  http://ntari.local

Source:
  https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os
EOF

    # Embed key docs (text-only for ISO space efficiency)
    if [ -f "${PROJECT_DIR}/docs/ARCHITECTURE.md" ]; then
        cp "${PROJECT_DIR}/docs/ARCHITECTURE.md" \
           "${OVERLAY_DIR}/usr/local/share/ntari/ARCHITECTURE.txt"
    fi
    if [ -f "${PROJECT_DIR}/docs/INSTALL.md" ]; then
        cp "${PROJECT_DIR}/docs/INSTALL.md" \
           "${OVERLAY_DIR}/usr/local/share/ntari/INSTALL.txt"
    fi
    if [ -f "${PROJECT_DIR}/docs/OPERATIONS.md" ]; then
        cp "${PROJECT_DIR}/docs/OPERATIONS.md" \
           "${OVERLAY_DIR}/usr/local/share/ntari/OPERATIONS.txt"
    fi

    # ── /etc/ssh/sshd_config (hardened) ──────────────────
    mkdir -p "${OVERLAY_DIR}/etc/ssh"
    cat > "${OVERLAY_DIR}/etc/ssh/sshd_config" <<'EOF'
# NTARI OS hardened SSH config
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowTcpForwarding no
Banner /etc/motd
PrintMotd yes
EOF

    # ── OpenRC service enables ────────────────────────────
    mkdir -p "${OVERLAY_DIR}/etc/runlevels/default"
    mkdir -p "${OVERLAY_DIR}/etc/runlevels/boot"
    mkdir -p "${OVERLAY_DIR}/etc/runlevels/sysinit"

    # These are symlink targets — actual init.d files come from packages
    # They will be activated when the ISO boots and services are available
    for svc in networking chronyd sshd; do
        touch "${OVERLAY_DIR}/etc/runlevels/default/.keep_${svc}"
    done

    # ── ntari-modloop: Alpine modloop nesting fix (all editions) ─────────────
    # Installed into the sysinit runlevel so it runs before networking on every
    # boot and corrects the /lib/modules path before NIC drivers are loaded.
    MODLOOP_INITD="${PROJECT_DIR}/config/services/ntari-modloop.initd"
    if [ -f "${MODLOOP_INITD}" ]; then
        mkdir -p "${OVERLAY_DIR}/etc/init.d"
        cp "${MODLOOP_INITD}" "${OVERLAY_DIR}/etc/init.d/ntari-modloop"
        chmod 755 "${OVERLAY_DIR}/etc/init.d/ntari-modloop"
        mkdir -p "${OVERLAY_DIR}/etc/runlevels/sysinit"
        ln -sf /etc/init.d/ntari-modloop \
            "${OVERLAY_DIR}/etc/runlevels/sysinit/ntari-modloop"
        log "ntari-modloop enabled in sysinit runlevel (all editions)"
    else
        warn "ntari-modloop.initd not found at ${MODLOOP_INITD} — skipping"
    fi

    # ── ROS2 edition extras ──────────────────────────────
    if [ "$EDITION" = "ros2" ]; then
        log "Adding ROS2 edition overlay..."

        # Embed the alpine-ros APK signing key (SEQSENSE) inline.
        # Key: builder@alpine-ros-experimental.rsa.pub
        # Included in the ISO so the booted system can install ROS2 packages.
        mkdir -p "${OVERLAY_DIR}/etc/apk/keys"
        ALPINE_ROS_KEY="${OVERLAY_DIR}/etc/apk/keys/builder@alpine-ros-experimental.rsa.pub"
        cat > "${ALPINE_ROS_KEY}" <<'ROSKEY'
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnSO+a+rIaTorOowj3c8e
5St89puiGJ54QmOW9faDsTcIWhycl4bM5lftp8IdcpKadcnaihwLtMLeaHNJvMIP
XrgEEoaPzEuvLf6kF4IN8HJoFGDhmuW4lTuJNfsOIDWtLBH0EN+3lPuCPmNkULeo
iS3Sdjz10eB26TYiM9pbMQnm7zPnDSYSLm9aCy+gumcoyCt1K1OY3A9E3EayYdk1
9nk9IQKA3vgdPGCEh+kjAjnmVxwV72rDdEwie0RkIyJ/al3onRLAfN4+FGkX2CFb
a17OJ4wWWaPvOq8PshcTZ2P3Me8kTCWr/fczjzq+8hB0MNEqfuENoSyZhmCypEuy
ewIDAQAB
-----END PUBLIC KEY-----
ROSKEY
        log "alpine-ros APK key embedded in overlay"

        # Add alpine-ros repos to the ISO's repositories file
        cat >> "${OVERLAY_DIR}/etc/apk/repositories" <<EOF
https://alpine-ros.seqsense.org/v3.23/backports
https://alpine-ros.seqsense.org/v3.23/ros/jazzy
EOF
        log "alpine-ros repository added to overlay repositories"

        # Install ros2-domain OpenRC service files
        mkdir -p "${OVERLAY_DIR}/etc/init.d"
        mkdir -p "${OVERLAY_DIR}/etc/conf.d"

        ROS2_INITD_SRC="${PROJECT_DIR}/config/services/ros2-domain.initd"
        ROS2_CONFD_SRC="${PROJECT_DIR}/config/services/ros2-domain.confd"

        if [ -f "${ROS2_INITD_SRC}" ]; then
            cp "${ROS2_INITD_SRC}" "${OVERLAY_DIR}/etc/init.d/ros2-domain"
            chmod 755 "${OVERLAY_DIR}/etc/init.d/ros2-domain"
            log "Included: ros2-domain OpenRC service"
        else
            warn "ros2-domain.initd not found at ${ROS2_INITD_SRC}"
        fi

        if [ -f "${ROS2_CONFD_SRC}" ]; then
            cp "${ROS2_CONFD_SRC}" "${OVERLAY_DIR}/etc/conf.d/ros2-domain"
            log "Included: ros2-domain conf.d"
        else
            warn "ros2-domain.confd not found at ${ROS2_CONFD_SRC}"
        fi

        # Enable ros2-domain in default runlevel.
        # OpenRC runlevel activation via overlay: create a symlink
        # pointing from the runlevel dir to the init.d script.
        # Alpine initramfs applies the overlay before OpenRC runs,
        # so this symlink is visible to rc on first boot.
        mkdir -p "${OVERLAY_DIR}/etc/runlevels/default"
        ln -sf /etc/init.d/ros2-domain \
            "${OVERLAY_DIR}/etc/runlevels/default/ros2-domain"
        log "ros2-domain enabled in default runlevel"

        # ── Phase 7: Services Layer ──────────────────────────────────────────
        # Install OpenRC service files for all Phase 7 nodes.
        # Each service wraps a standard daemon and publishes health/status
        # topics to the DDS graph via ros2-node-health.
        #
        # Core tier (auto-enabled):    ntari-dns ntari-ntp ntari-web ntari-cache ntari-dhcp
        # High-priority tier (enabled, requires per-node config before use):
        #   ntari-vpn        — WireGuard federation tunnel (needs wg-ntari.conf)
        #   ntari-identity   — OpenLDAP (slapd) identity server
        #   ntari-files      — Samba cooperative file sharing
        # Phase 10 tier:
        #   ntari-hw-profile  — hardware detection → /ntari/node/capabilities
        #   ntari-node-policy — contribution policy UI → /ntari/node/policy
        # Phase 11 tier:
        #   ntari-scheduler   — cooperative role assignment from policy bounds
        # Phase 12 tier:
        #   ntari-wan         — WAN internet connectivity + NAT masquerade

        for svc in ntari-dns ntari-ntp ntari-web ntari-cache ntari-dhcp \
                   ntari-vpn ntari-identity ntari-files \
                   ntari-hw-profile ntari-node-policy \
                   ntari-scheduler \
                   ntari-wan; do
            SVC_INITD="${PROJECT_DIR}/config/services/${svc}.initd"
            SVC_CONFD="${PROJECT_DIR}/config/services/${svc}.confd"

            if [ -f "${SVC_INITD}" ]; then
                cp "${SVC_INITD}" "${OVERLAY_DIR}/etc/init.d/${svc}"
                chmod 755 "${OVERLAY_DIR}/etc/init.d/${svc}"
                log "Included: ${svc} OpenRC service"
            else
                warn "${svc}.initd not found at ${SVC_INITD}"
            fi

            if [ -f "${SVC_CONFD}" ]; then
                cp "${SVC_CONFD}" "${OVERLAY_DIR}/etc/conf.d/${svc}"
                log "Included: ${svc} conf.d"
            else
                warn "${svc}.confd not found at ${SVC_CONFD}"
            fi

            # Enable in default runlevel
            if [ -f "${OVERLAY_DIR}/etc/init.d/${svc}" ]; then
                ln -sf "/etc/init.d/${svc}" \
                    "${OVERLAY_DIR}/etc/runlevels/default/${svc}"
                log "${svc} enabled in default runlevel"
            fi
        done

        # Create directory structure for Phase 7–10 service runtime data
        # Core tier (Phase 7)
        mkdir -p "${OVERLAY_DIR}/var/lib/ntari/dns"
        mkdir -p "${OVERLAY_DIR}/var/lib/ntari/redis"
        mkdir -p "${OVERLAY_DIR}/var/lib/ntari/interface"
        mkdir -p "${OVERLAY_DIR}/var/lib/ntari/caddy"
        # High-priority tier (Phase 7)
        mkdir -p "${OVERLAY_DIR}/var/lib/ntari/ldap"       # OpenLDAP data (replaced kanidm)
        mkdir -p "${OVERLAY_DIR}/var/lib/ntari/shares"
        mkdir -p "${OVERLAY_DIR}/etc/ntari/wireguard"
        chmod 700 "${OVERLAY_DIR}/etc/ntari/wireguard" 2>/dev/null || true
        mkdir -p "${OVERLAY_DIR}/var/log/ntari"
        # Phase 10
        mkdir -p "${OVERLAY_DIR}/ntari/node"
        mkdir -p "${OVERLAY_DIR}/var/lib/ntari/identity"
        # Phase 11
        mkdir -p "${OVERLAY_DIR}/ntari/scheduler"
        # Phase 12
        mkdir -p "${OVERLAY_DIR}/run/ntari"         # WAN DHCP client + monitor scripts
        mkdir -p "${OVERLAY_DIR}/etc/sysctl.d"      # ip_forward persistence
        mkdir -p "${OVERLAY_DIR}/etc/ntari"         # bird.conf (BGP — written at runtime)

        log "Phase 7–12 service overlay entries complete"

        # Phase 8 (Globe interface) — moved to SoHoLINK.
        # The WebSocket bridge (ntari-globe-bridge) and Globe UI are SoHoLINK
        # application components. NTARI OS exposes the DDS graph; SoHoLINK
        # visualises it. See SoHoLINK/ui/globe-interface/ and
        # SoHoLINK/ntari-os-services/ntari-globe-bridge.initd.

        # ── Phase 9: Cooperative Federation ──────────────────────────────────
        # Install the federation bridge script and its OpenRC service.

        FED_SCRIPT="${PROJECT_DIR}/scripts/ntari-federation.sh"
        if [ -f "${FED_SCRIPT}" ]; then
            cp "${FED_SCRIPT}" "${OVERLAY_DIR}/usr/local/bin/ntari-federation.sh"
            chmod +x "${OVERLAY_DIR}/usr/local/bin/ntari-federation.sh"
            ln -sf /usr/local/bin/ntari-federation.sh \
                "${OVERLAY_DIR}/usr/local/bin/ntari-federation"
            log "Included: ntari-federation.sh"
        else
            warn "ntari-federation.sh not found at ${FED_SCRIPT}"
        fi

        FED_INITD="${PROJECT_DIR}/config/services/ntari-federation.initd"
        FED_CONFD="${PROJECT_DIR}/config/services/ntari-federation.confd"

        if [ -f "${FED_INITD}" ]; then
            cp "${FED_INITD}" "${OVERLAY_DIR}/etc/init.d/ntari-federation"
            chmod 755 "${OVERLAY_DIR}/etc/init.d/ntari-federation"
            log "Included: ntari-federation OpenRC service"
        fi
        if [ -f "${FED_CONFD}" ]; then
            cp "${FED_CONFD}" "${OVERLAY_DIR}/etc/conf.d/ntari-federation"
            log "Included: ntari-federation conf.d"
        fi

        # NOTE: ntari-federation is NOT auto-enabled (requires WireGuard peer config first)
        # Users enable it manually with: rc-update add ntari-federation default
        # This is intentional — federation requires explicit opt-in (see docs/FEDERATION.md)
        log "ntari-federation installed but NOT auto-enabled (requires peer config)"

        # ── Phase 12: ntari-bgp (optional BGP/IXP peering) ───────────────────
        # Installed to the ISO but NOT auto-enabled.
        # Nodes with a public ASN enable it manually after configuring bird.conf.
        BGP_INITD="${PROJECT_DIR}/config/services/ntari-bgp.initd"
        BGP_CONFD="${PROJECT_DIR}/config/services/ntari-bgp.confd"

        if [ -f "${BGP_INITD}" ]; then
            cp "${BGP_INITD}" "${OVERLAY_DIR}/etc/init.d/ntari-bgp"
            chmod 755 "${OVERLAY_DIR}/etc/init.d/ntari-bgp"
            log "Included: ntari-bgp OpenRC service"
        else
            warn "ntari-bgp.initd not found at ${BGP_INITD} — skipping"
        fi
        if [ -f "${BGP_CONFD}" ]; then
            cp "${BGP_CONFD}" "${OVERLAY_DIR}/etc/conf.d/ntari-bgp"
            log "Included: ntari-bgp conf.d"
        fi

        # NOTE: ntari-bgp is NOT auto-enabled (requires ASN + BGP peer config)
        # Enable manually: rc-update add ntari-bgp default
        log "ntari-bgp installed but NOT auto-enabled (requires ASN and peer config)"

        # Install federation documentation
        if [ -f "${PROJECT_DIR}/docs/FEDERATION.md" ]; then
            cp "${PROJECT_DIR}/docs/FEDERATION.md" \
               "${OVERLAY_DIR}/usr/local/share/ntari/FEDERATION.txt"
            log "Included: FEDERATION.md docs"
        fi

        # Runtime directories for Phase 9
        mkdir -p "${OVERLAY_DIR}/run/ntari-federation"
        mkdir -p "${OVERLAY_DIR}/var/lib/ntari/identity"

        log "Phase 9 federation overlay entries complete"

        # Install Cyclone DDS XML configuration
        mkdir -p "${OVERLAY_DIR}/etc/ntari"
        cat > "${OVERLAY_DIR}/etc/ntari/cyclonedds.xml" <<'CYCLONE_EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<!--
  NTARI OS — Cyclone DDS Configuration
  /etc/ntari/cyclonedds.xml

  Optimized for Alpine Linux (musl), local mesh networks, edge hardware.
  See docs/ROS2_MUSL_COMPATIBILITY.md for full rationale.
-->
<CycloneDDS>
  <Domain id="any">
    <Discovery>
      <EnableTopicDiscoveryEndpoints>true</EnableTopicDiscoveryEndpoints>
    </Discovery>
    <Internal>
      <DeliveryQueueMaxSamples>256</DeliveryQueueMaxSamples>
      <MaxMessageSize>65500B</MaxMessageSize>
    </Internal>
    <Tracing>
      <Verbosity>warning</Verbosity>
      <OutputFile>/var/log/ntari/cyclonedds.log</OutputFile>
    </Tracing>
  </Domain>
</CycloneDDS>
CYCLONE_EOF
        log "Cyclone DDS XML config included in overlay"

        # Also copy the ROS2 musl compatibility doc into the ISO
        if [ -f "${PROJECT_DIR}/docs/ROS2_MUSL_COMPATIBILITY.md" ]; then
            cp "${PROJECT_DIR}/docs/ROS2_MUSL_COMPATIBILITY.md" \
               "${OVERLAY_DIR}/usr/local/share/ntari/ROS2_MUSL_COMPATIBILITY.txt"
            log "Included ROS2 musl compatibility doc"
        fi

        # Update MOTD for ROS2 edition
        cat > "${OVERLAY_DIR}/etc/motd" <<'EOF'

  _   _ _____  _    ____  ___    ___  ____
 | \ | |_   _|/ \  |  _ \|_ _|  / _ \/ ___|
 |  \| | | | / _ \ | |_) || |  | | | \___ \
 | |\  | | |/ ___ \|  _ < | |  | |_| |___) |
 |_| \_| |_/_/   \_\_| \_\___|  \___/|____/

 NTARI OS v1.5.0 — ROS2 Jazzy Edition
 ──────────────────────────────────────────────────────────
 Hostname : ntari-node
 DDS      : ros2 node list  (domain 0, Cyclone DDS)
 Globe UI : http://ntari.local  (after globe setup)
 Admin    : ntari-admin
 ROS2     : setup-ros2  (run once after first boot)

 Type 'ntari-admin' for the admin dashboard.
 Type 'ntari-init'  for first-boot setup.
 Type 'setup-ros2'  to complete ROS2 APK setup.

EOF
        log "ROS2 edition MOTD installed"
    fi

    log "Overlay created at ${OVERLAY_DIR}"
}

# ─────────────────────────────────────────────────────────
# 5. Build ISO using Alpine mkimage
# ─────────────────────────────────────────────────────────

build_iso() {
    step "Building ISO with Alpine mkimage"

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${WORK_DIR}"

    SCRIPTS_DIR="${APORTS_DIR}/scripts"
    OUTPUT_ISO="${BUILD_DIR}/${ISO_NAME}"

    # Select profile based on edition
    case "$EDITION" in
        ros2)   NTARI_PROFILE_NAME="ntari_ros2" ;;
        server) NTARI_PROFILE_NAME="ntari_server" ;;
        *)      NTARI_PROFILE_NAME="ntari_server" ;;
    esac

    info "Profile  : ${NTARI_PROFILE_NAME}"
    info "Output   : ${OUTPUT_ISO}"
    info "Work dir : ${WORK_DIR}"

    cd "${SCRIPTS_DIR}"

    # Build repository args.
    # ALPINE_URL_PATH=v3.23 is the correct CDN path; ALPINE_BRANCH=3.23-stable
    # is the git branch name and must NOT be used in HTTP URLs.
    REPO_ARGS="--repository ${ALPINE_MIRROR}/${ALPINE_URL_PATH}/main \
        --repository ${ALPINE_MIRROR}/${ALPINE_URL_PATH}/community"

    if [ "$EDITION" = "ros2" ]; then
        REPO_ARGS="${REPO_ARGS} \
            --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing \
            --repository https://alpine-ros.seqsense.org/v3.23/backports \
            --repository https://alpine-ros.seqsense.org/v3.23/ros/jazzy"
        info "Adding alpine-ros (seqsense.org) APK repositories for ROS2 packages"
    fi

    # mkimage outputs to /tmp/iso-out (builder-writable; mounted volume is UID 0).
    # build.log also goes to /tmp first, then sudo-copied to BUILD_DIR for the host.
    ISO_OUTDIR="/tmp/iso-out"
    mkdir -p "${ISO_OUTDIR}"

    # Run mkimage.sh as builder (UID 1000, no elevated caps).
    # APK 3.x uses --usermode internally for non-root installs into $APKROOT.
    # --usermode requires: (a) UID != 0, and (b) no DAC_OVERRIDE/SYS_ADMIN caps.
    # Docker caps were removed from docker-build.sh for this reason.
    # --hostkeys: copies /etc/apk/keys/* into the rootfs so mkimage can verify
    #             the seqsense APK repo signatures (builder@alpine-ros-experimental.rsa.pub).
    # set +e: capture mkimage exit code manually; set -e re-enabled after log copy.
    cd "${SCRIPTS_DIR}"
    set +e
    sh mkimage.sh \
        --tag "${ALPINE_BRANCH}" \
        --outdir "${ISO_OUTDIR}" \
        --arch "${ARCH}" \
        ${REPO_ARGS} \
        --workdir "${WORK_DIR}" \
        --hostkeys \
        --profile "${NTARI_PROFILE_NAME}" \
        2>&1 | tee /tmp/build.log
    MKIMAGE_EXIT=$?
    set -e

    # Always copy log to mounted volume regardless of success/failure
    sudo cp /tmp/build.log "${BUILD_DIR}/build.log" 2>/dev/null || true

    [ "${MKIMAGE_EXIT}" -eq 0 ] || err "mkimage.sh failed — see ${BUILD_DIR}/build.log"

    # Rename to NTARI versioned name and move to BUILD_DIR.
    # Only accept an ISO that mkimage actually just produced.
    MKIMAGE_OUT=$(ls "${ISO_OUTDIR}"/alpine-${NTARI_PROFILE_NAME}-*.iso 2>/dev/null | head -1)
    if [ -n "${MKIMAGE_OUT}" ] && [ -f "${MKIMAGE_OUT}" ]; then
        sudo cp "${MKIMAGE_OUT}" "${OUTPUT_ISO}"
        log "Copied to ${ISO_NAME}"
    else
        err "mkimage.sh did not produce alpine-${NTARI_PROFILE_NAME}-*.iso in ${ISO_OUTDIR}. Build failed."
    fi

    # Checksum (use sudo for the write to BUILD_DIR)
    CKSUM=$(sha256sum "${MKIMAGE_OUT}" | awk '{print $1}')
    echo "${CKSUM}  ${ISO_NAME}" | sudo tee "${OUTPUT_ISO}.sha256" > /dev/null
    log "SHA256: ${CKSUM}"
}

# ─────────────────────────────────────────────────────────
# 6. Apply overlay to ISO
# ─────────────────────────────────────────────────────────

apply_overlay() {
    step "Applying NTARI overlay to ISO"

    # OVERLAY_DIR is set globally to /tmp/overlay-${EDITION}
    OUTPUT_ISO="${BUILD_DIR}/${ISO_NAME}"

    if [ ! -d "${OVERLAY_DIR}" ]; then
        warn "No overlay directory found, skipping overlay step"
        return
    fi

    # Package overlay as .apkovl.tar.gz in /tmp (builder-writable).
    # BUILD_DIR is on the Windows-mounted volume (root-owned); builder
    # cannot write there directly — use /tmp then sudo cp.
    OVERLAY_TGZ_TMP="/tmp/ntari-overlay.apkovl.tar.gz"
    OVERLAY_TGZ="${BUILD_DIR}/ntari-overlay.apkovl.tar.gz"
    info "Packaging overlay as apkovl..."
    (cd "${OVERLAY_DIR}" && tar -czf "${OVERLAY_TGZ_TMP}" .)
    sudo cp "${OVERLAY_TGZ_TMP}" "${OVERLAY_TGZ}"
    log "Overlay packaged: ${OVERLAY_TGZ}"

    # Inject overlay into ISO using xorriso (no mount/root required).
    # Copy ISO to /tmp for modification (OUTPUT_ISO is on root-owned mount).
    # xorriso -dev modifies the ISO in-place while preserving hybrid boot sectors.
    ISO_WORK="/tmp/ntari-work.iso"
    info "Copying ISO for overlay injection..."
    cp "${OUTPUT_ISO}" "${ISO_WORK}" 2>/dev/null || {
        warn "Cannot copy ISO for overlay injection — skipping"
        return
    }

    # Inject overlay using xorriso -indev/-outdev.
    # -boot_image any replay: replays El-Torito AND system area (MBR/GPT) from indev.
    #   Works because mkimage ISOs have El-Torito; replay copies both El-Torito and
    #   system area into outdev (confirmed by xorriso NOTE: "Copying to System Area").
    # -map: adds overlay file (also provides the filesystem modification needed to
    #   trigger xorriso to write outdev — without any file change, -commit is a no-op).
    # -abort_on FAILURE: allows SORRY (32) which is normal for hybrid boot warnings.
    # NOTE: -system_area 2 is NOT a valid native xorriso 1.5.x command — use replay.
    ISO_OUT="/tmp/ntari-with-overlay.iso"
    info "Injecting overlay into ISO with xorriso (replay El-Torito + system area)..."
    set +e
    xorriso \
        -abort_on FAILURE \
        -indev "${ISO_WORK}" \
        -outdev "${ISO_OUT}" \
        -boot_image any replay \
        -map "${OVERLAY_TGZ_TMP}" "/ntari-overlay.apkovl.tar.gz" \
        -commit \
        -end 2>&1
    XORRISO_EXIT=$?
    set -e
    # Exit 0 = success; 32 = SORRY (minor warnings, acceptable)
    if [ "${XORRISO_EXIT}" -eq 0 ] || [ "${XORRISO_EXIT}" -eq 32 ]; then
        sudo cp "${ISO_OUT}" "${OUTPUT_ISO}"
        CKSUM=$(sha256sum "${ISO_OUT}" | awk '{print $1}')
        echo "${CKSUM}  ${ISO_NAME}" | sudo tee "${OUTPUT_ISO}.sha256" > /dev/null
        log "Overlay injected into ISO (El-Torito + hybrid boot preserved)"
    else
        warn "xorriso injection failed (exit ${XORRISO_EXIT}) — keeping original ISO without overlay"
        sudo cp "${ISO_WORK}" "${OUTPUT_ISO}"
    fi
    rm -f "${ISO_WORK}" "${ISO_OUT}" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────
# 7. Summary
# ─────────────────────────────────────────────────────────

show_summary() {
    step "Build Complete"

    OUTPUT_ISO="${BUILD_DIR}/${ISO_NAME}"
    SIZE=$(du -h "${OUTPUT_ISO}" 2>/dev/null | cut -f1 || echo "unknown")

    echo ""
    echo "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║         NTARI OS v1.5.0 ISO Build Successful!        ║${NC}"
    echo "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  ISO     : ${ISO_NAME}"
    echo "  Size    : ${SIZE}"
    echo "  Edition : ${EDITION}"
    echo "  Alpine  : ${ALPINE_VERSION}"
    echo "  Arch    : ${ARCH}"
    echo "  Output  : ${BUILD_DIR}/"
    echo ""
    echo "${CYAN}Test in VirtualBox:${NC}"
    echo "  1. Open VirtualBox → New VM"
    echo "  2. Type: Linux / Other Linux (64-bit)"
    echo "  3. RAM: 2048 MB minimum"
    echo "  4. Settings → Storage → Add optical drive → select ISO"
    echo "  5. Start VM"
    echo ""
    echo "${CYAN}Test with QEMU (Linux/WSL2 with KVM):${NC}"
    echo "  qemu-system-x86_64 -drive file=${OUTPUT_ISO},format=raw,readonly=on -m 2048 -enable-kvm"
    echo "  (Use -drive format=raw to engage MBR hybrid boot; overlay-injected ISOs lose El-Torito)"
    echo ""
    echo "${CYAN}SHA256:${NC}"
    cat "${OUTPUT_ISO}.sha256" 2>/dev/null || echo "  (checksum file missing)"
    echo ""
}

# ─────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────

main() {
    echo ""
    echo "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║        NTARI OS v1.5.0 ISO Builder                  ║${NC}"
    echo "${GREEN}║        Alpine ${ALPINE_VERSION} · mkimage method               ║${NC}"
    echo "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_environment
    [ "$EDITION" = "ros2" ] && trust_ros2_repos
    setup_aports
    create_profile
    create_overlay
    build_iso
    apply_overlay
    show_summary
}

main "$@"
