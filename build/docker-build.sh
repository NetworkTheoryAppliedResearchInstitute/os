#!/bin/bash
# NTARI OS v1.5 Docker Build Wrapper
# Builds the NTARI OS ISO from Windows/Mac/Linux using Docker.
# Uses Alpine mkimage (proper boot) — not the v1.0 custom SquashFS approach.

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

EDITION="${1:-server}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGE_NAME="ntari-builder:1.5"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       NTARI OS v1.5.0 Docker Build Wrapper          ║${NC}"
echo -e "${GREEN}║       Alpine 3.23 · mkimage · ${EDITION} edition          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Check Docker ─────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo -e "${RED}[✗]${NC} Docker not found."
    echo -e "${YELLOW}    Install Docker Desktop: https://www.docker.com/get-started${NC}"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo -e "${RED}[✗]${NC} Docker is not running. Start Docker Desktop and try again."
    exit 1
fi

echo -e "${GREEN}[✓]${NC} Docker is running"

# ── Build Docker image ────────────────────────────────────
if docker image inspect "${IMAGE_NAME}" &>/dev/null; then
    echo -e "${GREEN}[✓]${NC} Docker image exists: ${IMAGE_NAME}"
else
    echo -e "${BLUE}[→]${NC} Building Docker build environment (Alpine 3.23)..."
    docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}/" || {
        echo -e "${RED}[✗]${NC} Docker build failed"
        exit 1
    }
    echo -e "${GREEN}[✓]${NC} Docker image built: ${IMAGE_NAME}"
fi

# ── Convert path for Docker (Windows/Git Bash compatibility) ──
# MSYS_NO_PATHCONV prevents Git Bash from mangling Windows paths
# We use the Windows-style path (with drive letter) for Docker volume mounts
BUILD_PATH="$(cd "${PROJECT_DIR}" && pwd -W 2>/dev/null || pwd)"
echo -e "${BLUE}[→]${NC} Project path: ${BUILD_PATH}"

mkdir -p "${SCRIPT_DIR}/build-output"

# ── Run build ─────────────────────────────────────────────
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Starting ISO build in Docker container...${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""

# Run as UID 1000 (builder user inside the container).
# Named --user builder:builder fails on Windows (Docker resolves groups on host).
# Numeric UID 1000 resolves inside the container against /etc/passwd, not the host.
# No --cap-add flags: APK 3.x detects DAC_OVERRIDE/SYS_ADMIN as root-equivalent
# and refuses --usermode (needed for non-root package installation into rootfs).
MSYS_NO_PATHCONV=1 docker run --rm --user 1000 \
    -v "${BUILD_PATH}:/workspace" \
    -w /workspace \
    "${IMAGE_NAME}" \
    /workspace/build/build-iso.sh "${EDITION}"

BUILD_STATUS=$?

echo ""
if [ ${BUILD_STATUS} -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Build Successful!                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "ISO files in: ${SCRIPT_DIR}/build-output/"
    ls -lh "${SCRIPT_DIR}/build-output/"*.iso 2>/dev/null || true
    echo ""
else
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║           Build Failed                               ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
    echo "See: ${SCRIPT_DIR}/build-output/build.log"
    exit 1
fi
