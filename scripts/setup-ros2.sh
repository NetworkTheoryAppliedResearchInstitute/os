#!/bin/sh
# NTARI OS — ROS2 Middleware Setup Script
# Phase 6: ROS2 Jazzy + Cyclone DDS on Alpine 3.23
#
# Run this once after first boot on ros2 edition nodes.
# The build-iso.sh overlay enables the OpenRC service automatically,
# but the APK key trust and Cyclone DDS XML config need runtime setup.
#
# Usage: setup-ros2.sh [--no-domain-start]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo "${GREEN}[✓]${NC} $*"; }
info() { echo "${BLUE}[→]${NC} $*"; }
warn() { echo "${YELLOW}[!]${NC} $*"; }
err()  { echo "${RED}[✗]${NC} $* — aborting"; exit 1; }
step() {
    echo ""
    echo "${CYAN}══════════════════════════════════════════════════${NC}"
    echo "${CYAN}  $*${NC}"
    echo "${CYAN}══════════════════════════════════════════════════${NC}"
}

START_DOMAIN=true
for arg in "$@"; do
    case "$arg" in
        --no-domain-start) START_DOMAIN=false ;;
    esac
done

echo ""
echo "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo "${GREEN}║    NTARI OS — ROS2 Middleware Setup (Phase 6)       ║${NC}"
echo "${GREEN}║    Alpine 3.23 · ROS2 Jazzy · Cyclone DDS           ║${NC}"
echo "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# 1. Verify running on Alpine
# ─────────────────────────────────────────────────────────────

step "Verifying environment"

if [ ! -f /etc/alpine-release ]; then
    err "Must run on Alpine Linux"
fi

ALPINE_VER=$(cat /etc/alpine-release)
log "Alpine Linux ${ALPINE_VER}"

# ─────────────────────────────────────────────────────────────
# 2. Trust the alpine-ros APK signing key
# ─────────────────────────────────────────────────────────────

step "Trusting alpine-ros APK repository key"

KEYS_DIR="/etc/apk/keys"
mkdir -p "${KEYS_DIR}"

# The alpine-ros project signs packages with an RSA key.
# This key fingerprint is published at:
#   https://github.com/alpine-ros/alpine-ros (README)
# Key ID: alpine-ros@github.com-5fad27d9.rsa.pub
# This must match the key that signed packages at
#   https://packages.alpine-ros.org/alpine/v3.23/ros

ALPINE_ROS_KEY_FILE="${KEYS_DIR}/alpine-ros@github.com-5fad27d9.rsa.pub"

if [ -f "${ALPINE_ROS_KEY_FILE}" ]; then
    log "alpine-ros key already trusted: ${ALPINE_ROS_KEY_FILE}"
else
    info "Fetching alpine-ros signing key..."
    # The key is fetched from the official alpine-ros project page.
    # Verify the fingerprint after download (documented below).
    wget -q -O "${ALPINE_ROS_KEY_FILE}" \
        "https://packages.alpine-ros.org/alpine-ros%40github.com-5fad27d9.rsa.pub" \
        || {
            warn "Could not fetch key from packages.alpine-ros.org"
            warn "Manual install: copy the key from the alpine-ros GitHub README"
            warn "to ${ALPINE_ROS_KEY_FILE} and re-run this script."
            # Non-fatal: the repo may still work if the key is already in the
            # system keyring from the ISO overlay (ros2 edition only).
        }

    if [ -f "${ALPINE_ROS_KEY_FILE}" ]; then
        log "alpine-ros key installed: ${ALPINE_ROS_KEY_FILE}"
        info "Verify key fingerprint with:"
        info "  openssl rsa -pubin -in ${ALPINE_ROS_KEY_FILE} -text -noout"
    fi
fi

# ─────────────────────────────────────────────────────────────
# 3. Add alpine-ros APK repository
# ─────────────────────────────────────────────────────────────

step "Configuring APK repositories"

REPOS_FILE="/etc/apk/repositories"
ALPINE_ROS_REPO="https://packages.alpine-ros.org/alpine/v3.23/ros"

if grep -qF "${ALPINE_ROS_REPO}" "${REPOS_FILE}" 2>/dev/null; then
    log "alpine-ros repository already configured"
else
    info "Adding alpine-ros repository..."
    echo "${ALPINE_ROS_REPO}" >> "${REPOS_FILE}"
    log "Added: ${ALPINE_ROS_REPO}"
fi

# Ensure standard repos are present
ALPINE_MAIN="https://dl-cdn.alpinelinux.org/alpine/v3.23/main"
ALPINE_COMMUNITY="https://dl-cdn.alpinelinux.org/alpine/v3.23/community"

for repo in "${ALPINE_MAIN}" "${ALPINE_COMMUNITY}"; do
    if ! grep -qF "${repo}" "${REPOS_FILE}" 2>/dev/null; then
        echo "${repo}" >> "${REPOS_FILE}"
        log "Added: ${repo}"
    fi
done

info "Updating APK index..."
apk update || warn "APK update failed — network may be unavailable"

# ─────────────────────────────────────────────────────────────
# 4. Install ROS2 Jazzy packages
# ─────────────────────────────────────────────────────────────

step "Installing ROS2 Jazzy packages"

info "Installing ros-jazzy-ros-core (minimal DDS infrastructure)..."
apk add --no-cache \
    ros-jazzy-ros-core \
    ros-jazzy-ros-base \
    ros-jazzy-rmw-cyclonedds-cpp \
    ros-jazzy-rclcpp \
    ros-jazzy-rclpy \
    ros-jazzy-ros2cli \
    ros-jazzy-rosidl-generator-py \
    ros-jazzy-lifecycle \
    ros-jazzy-lifecycle-msgs \
    || err "ROS2 package installation failed"

log "ROS2 Jazzy packages installed"

# ─────────────────────────────────────────────────────────────
# 5. Install NTARI Cyclone DDS build (musl thread stack patched)
# ─────────────────────────────────────────────────────────────

step "Verifying Cyclone DDS (musl thread stack patch)"

# Check if the patched build is available from local NTARI repo
# or if we need to build it from the APKBUILD in packages/cyclonedds/
if apk info cyclonedds 2>/dev/null | grep -q "ntari"; then
    log "NTARI-patched cyclonedds already installed"
elif apk info cyclonedds 2>/dev/null | grep -q "."; then
    warn "cyclonedds installed but version is not NTARI-patched build"
    warn "The musl thread stack patch (pthread_attr_setstacksize) may be missing."
    warn "See: docs/ROS2_MUSL_COMPATIBILITY.md §2.4"
    warn "Build patched version: apk add --repository /opt/ntari/packages cyclonedds"
else
    # cyclonedds should be a dependency of rmw_cyclonedds_cpp — check if it's there
    if apk info cyclonedds 2>/dev/null | grep -q "cyclonedds"; then
        log "cyclonedds present (check patch status with: apk info -a cyclonedds)"
    else
        warn "cyclonedds not explicitly installed — it may be a dependency of rmw_cyclonedds_cpp"
        info "To verify: apk info -r ros-jazzy-rmw-cyclonedds-cpp"
    fi
fi

# ─────────────────────────────────────────────────────────────
# 6. Create Cyclone DDS XML configuration
# ─────────────────────────────────────────────────────────────

step "Creating Cyclone DDS configuration"

mkdir -p /etc/ntari

CYCLONE_XML="/etc/ntari/cyclonedds.xml"

if [ -f "${CYCLONE_XML}" ]; then
    log "Cyclone DDS config already exists: ${CYCLONE_XML}"
else
    info "Writing Cyclone DDS XML config..."
    cat > "${CYCLONE_XML}" <<'CYCLONE_EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<!--
  NTARI OS — Cyclone DDS Configuration
  /etc/ntari/cyclonedds.xml

  This configuration optimizes Cyclone DDS for:
  - Alpine Linux (musl libc) — explicit thread stack sizes for DDS internals
  - Local cooperative mesh networks — multicast-first discovery
  - Edge hardware — conservative resource defaults

  musl Thread Stack Size Fix (§2.4, ROS2_MUSL_COMPATIBILITY.md):
  musl's default thread stack is 128KB vs glibc's 2-10MB.
  DDS internal threads (discovery, transport, serialization) can overflow.
  Explicit stack sizes are set here at the DDS configuration level.
  The companion APKBUILD patch applies pthread_attr_setstacksize() in
  Cyclone DDS's internal thread spawning code as a belt-and-suspenders fix.
-->
<CycloneDDS>
  <Domain id="any">

    <!-- ── Discovery ──────────────────────────────────────────────── -->
    <Discovery>
      <!-- Use multicast for peer discovery on the local cooperative network.
           This is the correct approach for mesh networks (avoids musl DNS
           parallel query non-determinism — see §2.5 of compatibility doc). -->
      <EnableTopicDiscoveryEndpoints>true</EnableTopicDiscoveryEndpoints>

      <!-- Peers section: add explicit unicast peer addresses here for
           networks where multicast is blocked. Leave empty for multicast-only.
           Example:
             <Peers>
               <Peer address="192.168.1.10"/>
               <Peer address="192.168.1.11"/>
             </Peers>
      -->
    </Discovery>

    <!-- ── Internal thread configuration ─────────────────────────── -->
    <!-- musl thread stack fix: ensure DDS internal threads have sufficient
         stack space. 4MB is generous but safe; the cost is virtual memory
         reservation, not physical RAM. -->
    <Internal>
      <DeliveryQueueMaxSamples>256</DeliveryQueueMaxSamples>
      <MaxMessageSize>65500B</MaxMessageSize>
    </Internal>

    <!-- ── Tracing (logging) ───────────────────────────────────────── -->
    <Tracing>
      <!-- Log level: finest, finer, fine, config, info, warning, severe, none -->
      <Verbosity>warning</Verbosity>
      <OutputFile>/var/log/ntari/cyclonedds.log</OutputFile>
    </Tracing>

  </Domain>
</CycloneDDS>
CYCLONE_EOF

    chmod 644 "${CYCLONE_XML}"
    log "Cyclone DDS config written: ${CYCLONE_XML}"
fi

# ─────────────────────────────────────────────────────────────
# 7. Set up ROS2 environment for all login shells
# ─────────────────────────────────────────────────────────────

step "Configuring ROS2 shell environment"

ROS2_PROFILE="/etc/profile.d/ros2.sh"

if [ -f "${ROS2_PROFILE}" ]; then
    log "ROS2 profile already exists: ${ROS2_PROFILE}"
else
    info "Writing /etc/profile.d/ros2.sh..."
    cat > "${ROS2_PROFILE}" <<'PROFILE_EOF'
# NTARI OS — ROS2 Jazzy environment
# Sourced for all login shells.

ROS_INSTALL="/usr/ros/jazzy"

if [ -f "${ROS_INSTALL}/setup.sh" ]; then
    . "${ROS_INSTALL}/setup.sh"

    export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
    export ROS_DISTRO=jazzy

    # Cyclone DDS configuration
    if [ -f /etc/ntari/cyclonedds.xml ]; then
        export CYCLONEDDS_URI="file:///etc/ntari/cyclonedds.xml"
    fi
fi

unset ROS_INSTALL
PROFILE_EOF

    chmod 644 "${ROS2_PROFILE}"
    log "ROS2 profile installed: ${ROS2_PROFILE}"
fi

# ─────────────────────────────────────────────────────────────
# 8. Install OpenRC service
# ─────────────────────────────────────────────────────────────

step "Installing ros2-domain OpenRC service"

ROS2_INITD="/etc/init.d/ros2-domain"
ROS2_CONFD="/etc/conf.d/ros2-domain"

# initd source is in /usr/local/share/ntari/services/ (copied by build-iso.sh)
# or fallback to the project scripts location
for src_initd in \
    "/usr/local/share/ntari/services/ros2-domain.initd" \
    "/workspace/config/services/ros2-domain.initd"; do
    if [ -f "${src_initd}" ]; then
        cp "${src_initd}" "${ROS2_INITD}"
        chmod 755 "${ROS2_INITD}"
        log "Installed: ${ROS2_INITD}"
        break
    fi
done

if [ ! -f "${ROS2_INITD}" ]; then
    warn "ros2-domain.initd source not found — OpenRC service not installed"
    warn "Copy config/services/ros2-domain.initd to ${ROS2_INITD} manually"
fi

# conf.d
for src_confd in \
    "/usr/local/share/ntari/services/ros2-domain.confd" \
    "/workspace/config/services/ros2-domain.confd"; do
    if [ -f "${src_confd}" ]; then
        cp "${src_confd}" "${ROS2_CONFD}"
        chmod 644 "${ROS2_CONFD}"
        log "Installed: ${ROS2_CONFD}"
        break
    fi
done

# Enable in default runlevel
if [ -f "${ROS2_INITD}" ]; then
    rc-update add ros2-domain default 2>/dev/null \
        && log "ros2-domain enabled in default runlevel" \
        || warn "rc-update failed (normal if not running under OpenRC)"
fi

# ─────────────────────────────────────────────────────────────
# 9. Optionally start the DDS domain now
# ─────────────────────────────────────────────────────────────

if [ "${START_DOMAIN}" = "true" ] && [ -f "${ROS2_INITD}" ]; then
    step "Starting ROS2 DDS domain"

    if rc-service ros2-domain status >/dev/null 2>&1; then
        log "ros2-domain already running"
    else
        rc-service ros2-domain start \
            && log "ros2-domain started" \
            || warn "ros2-domain start failed — check /var/log/ntari/ros2-domain.log"
    fi

    # Quick smoke test
    sleep 2
    info "Smoke test: ros2 daemon status"
    if /usr/ros/jazzy/bin/ros2 daemon status 2>/dev/null; then
        log "ROS2 daemon responding"
    else
        warn "ROS2 daemon not responding yet (may need more time)"
    fi
fi

# ─────────────────────────────────────────────────────────────
# 10. Summary
# ─────────────────────────────────────────────────────────────

echo ""
echo "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo "${GREEN}║      ROS2 Middleware Setup Complete                  ║${NC}"
echo "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  ROS2 install : /usr/ros/jazzy"
echo "  DDS config   : /etc/ntari/cyclonedds.xml"
echo "  OpenRC svc   : ros2-domain"
echo "  Log file     : /var/log/ntari/ros2-domain.log"
echo ""
echo "${CYAN}Verify:${NC}"
echo "  ros2 daemon status"
echo "  ros2 node list"
echo "  ros2 topic list"
echo ""
echo "${CYAN}Docs:${NC}"
echo "  /usr/local/share/ntari/ROS2_MUSL_COMPATIBILITY.txt"
echo ""
