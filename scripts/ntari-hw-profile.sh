#!/bin/sh
# NTARI OS — Hardware Profile Detection Script
# Phase 10: Hardware Config
#
# Detects hardware capabilities and writes structured JSON to
# /ntari/node/capabilities for consumption by ntari-node-policy
# and the DDS graph.
#
# Output: /ntari/node/capabilities (JSON)
#
# Dependencies: /proc, /sys, uname — no external tools required.
# Optional: lspci (pciutils), ethtool — enhances GPU/NIC detection.
#
# JSON escape helper (no jq, no external deps)

set -e

OUTPUT_FILE="${NTARI_HW_CAPABILITIES:-/ntari/node/capabilities}"
UUID_FILE="/var/lib/ntari/identity/node-uuid"
LOG_PREFIX="[ntari-hw-profile]"

log()  { printf '%s %s\n' "${LOG_PREFIX}" "$*"; }
warn() { printf '%s WARN: %s\n' "${LOG_PREFIX}" "$*" >&2; }

# JSON string escape: replace backslash, double-quote, control chars
json_str() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

# ── Ensure output directory exists ───────────────────────────────────────────
mkdir -p "$(dirname "${OUTPUT_FILE}")"

# ── Node UUID ─────────────────────────────────────────────────────────────────
if [ -f "${UUID_FILE}" ]; then
    NODE_UUID=$(cat "${UUID_FILE}")
else
    NODE_UUID="unknown"
    warn "Node UUID not found at ${UUID_FILE}"
fi

# ── Timestamp ─────────────────────────────────────────────────────────────────
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

# ── CPU Detection ─────────────────────────────────────────────────────────────
log "Detecting CPU..."
CPU_MODEL=$(grep "^model name" /proc/cpuinfo 2>/dev/null | head -1 \
            | sed 's/^model name[[:space:]]*:[[:space:]]*//' \
            | sed 's/[[:space:]]*$//')
# Busybox grep fallback
[ -z "${CPU_MODEL}" ] && CPU_MODEL=$(grep "^Model name" /proc/cpuinfo 2>/dev/null | head -1 \
            | sed 's/^Model name[[:space:]]*:[[:space:]]*//' | sed 's/[[:space:]]*$//')
[ -z "${CPU_MODEL}" ] && CPU_MODEL=$(grep "^Hardware" /proc/cpuinfo 2>/dev/null | head -1 \
            | sed 's/^Hardware[[:space:]]*:[[:space:]]*//')
[ -z "${CPU_MODEL}" ] && CPU_MODEL="unknown"

CPU_CORES=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
CPU_MHZ=$(grep "^cpu MHz" /proc/cpuinfo 2>/dev/null | head -1 \
          | sed 's/^cpu MHz[[:space:]]*:[[:space:]]*//' | cut -d. -f1 | sed 's/[[:space:]]//g')
[ -z "${CPU_MHZ}" ] && CPU_MHZ="0"
CPU_ARCH=$(uname -m 2>/dev/null || echo "unknown")

# ── RAM Detection ─────────────────────────────────────────────────────────────
log "Detecting RAM..."
RAM_TOTAL_MB=$(awk '/^MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "0")
RAM_AVAILABLE_MB=$(awk '/^MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "0")

# ── Storage Detection ─────────────────────────────────────────────────────────
log "Detecting storage..."
# Build JSON array of block devices.
# Read /sys/block/ directly — works on all Alpine/busybox, no lsblk -o ROTA needed.
STORAGE_JSON="["
STORAGE_SEP=""
for dev_path in /sys/block/*/; do
    dev=$(basename "${dev_path}")
    # Skip loop, ram, and dm devices
    case "${dev}" in
        loop*|ram*|dm-*|sr*) continue ;;
    esac

    # Size: /sys/block/<dev>/size in 512-byte sectors
    SIZE_SECTORS=$(cat "/sys/block/${dev}/size" 2>/dev/null || echo "0")
    SIZE_GB=$(( SIZE_SECTORS / 2 / 1024 / 1024 ))

    # Rotation: 0 = SSD/NVMe, 1 = HDD
    ROTATIONAL=$(cat "/sys/block/${dev}/queue/rotational" 2>/dev/null || echo "1")
    if [ "${ROTATIONAL}" = "0" ]; then
        case "${dev}" in
            nvme*) DISK_TYPE="nvme" ;;
            *)     DISK_TYPE="ssd"  ;;
        esac
    else
        DISK_TYPE="hdd"
    fi

    STORAGE_JSON="${STORAGE_JSON}${STORAGE_SEP}"
    STORAGE_JSON="${STORAGE_JSON}{\"device\":\"/dev/${dev}\",\"size_gb\":${SIZE_GB},\"type\":\"${DISK_TYPE}\"}"
    STORAGE_SEP=","
done
STORAGE_JSON="${STORAGE_JSON}]"

# ── Network Detection ─────────────────────────────────────────────────────────
log "Detecting network interfaces..."
NET_JSON="["
NET_SEP=""
# Iterate /sys/class/net/, skip lo and virtual bridges
for iface_path in /sys/class/net/*/; do
    iface=$(basename "${iface_path}")
    [ "${iface}" = "lo" ] && continue
    # Skip purely virtual interfaces (no device symlink)
    [ ! -e "/sys/class/net/${iface}/device" ] && continue

    # Operational state
    STATE=$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null || echo "unknown")

    # Speed (Mbps) — from ethtool if available, else from /sys
    SPEED_MBPS=$(cat "/sys/class/net/${iface}/speed" 2>/dev/null || echo "-1")
    # Negative speeds indicate link-down or unknown; normalise to 0
    case "${SPEED_MBPS}" in
        -*)  SPEED_MBPS="0" ;;
        ''*) SPEED_MBPS="0" ;;
    esac

    # Driver name from /sys/class/net/<iface>/device/driver -> symlink -> basename
    DRIVER=$(basename "$(readlink "/sys/class/net/${iface}/device/driver" 2>/dev/null)" 2>/dev/null || echo "unknown")

    NET_JSON="${NET_JSON}${NET_SEP}"
    NET_JSON="${NET_JSON}{\"interface\":\"${iface}\",\"driver\":\"${DRIVER}\",\"state\":\"${STATE}\",\"speed_mbps\":${SPEED_MBPS}}"
    NET_SEP=","
done
NET_JSON="${NET_JSON}]"

# ── GPU Detection (optional via lspci) ────────────────────────────────────────
log "Detecting GPU..."
GPU_JSON="null"
if command -v lspci >/dev/null 2>&1; then
    GPU_LINE=$(lspci 2>/dev/null | grep -iE "VGA|3D Controller|Display Controller" | head -1 || true)
    if [ -n "${GPU_LINE}" ]; then
        GPU_MODEL=$(printf '%s' "${GPU_LINE}" | sed 's/^[^ ]* //' )
        GPU_MODEL_ESCAPED=$(json_str "${GPU_MODEL}")
        GPU_JSON="{\"model\":\"${GPU_MODEL_ESCAPED}\",\"detected_via\":\"lspci\"}"
    fi
else
    # Fallback: check /sys/class/drm for any display devices
    DRM_CARD=$(ls /sys/class/drm/ 2>/dev/null | grep "^card" | head -1 || true)
    if [ -n "${DRM_CARD}" ]; then
        GPU_JSON="{\"model\":\"unknown\",\"detected_via\":\"drm\",\"device\":\"${DRM_CARD}\"}"
    fi
fi

# ── Assemble final JSON ───────────────────────────────────────────────────────
log "Writing capabilities to ${OUTPUT_FILE}"

CPU_MODEL_ESC=$(json_str "${CPU_MODEL}")

cat > "${OUTPUT_FILE}" <<CAPS_EOF
{
  "schema_version": "1.0",
  "node_uuid": "$(json_str "${NODE_UUID}")",
  "hostname": "$(json_str "$(hostname 2>/dev/null || echo unknown)")",
  "timestamp": "${TIMESTAMP}",
  "hardware": {
    "cpu": {
      "model": "${CPU_MODEL_ESC}",
      "cores": ${CPU_CORES},
      "mhz": ${CPU_MHZ},
      "architecture": "$(json_str "${CPU_ARCH}")"
    },
    "ram": {
      "total_mb": ${RAM_TOTAL_MB},
      "available_mb": ${RAM_AVAILABLE_MB}
    },
    "storage": ${STORAGE_JSON},
    "network": ${NET_JSON},
    "gpu": ${GPU_JSON}
  }
}
CAPS_EOF

chmod 644 "${OUTPUT_FILE}"
log "Hardware profile written to ${OUTPUT_FILE}"
log "CPU: ${CPU_MODEL} (${CPU_CORES} cores @ ${CPU_MHZ} MHz, ${CPU_ARCH})"
log "RAM: ${RAM_TOTAL_MB} MB total, ${RAM_AVAILABLE_MB} MB available"
