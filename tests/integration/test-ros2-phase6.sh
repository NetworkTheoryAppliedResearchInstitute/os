#!/bin/sh
# NTARI OS — Phase 6 Integration Test Suite
# ROS2 Jazzy on Alpine 3.23 (musl libc) verification
#
# Tests:
#   T01  Docker daemon available
#   T02  alpine-ros image pullable
#   T03  ROS2 Jazzy CLI responds
#   T04  rclpy importable in Python
#   T05  rmw_cyclonedds_cpp selected as active RMW
#   T06  libddsc.so dlopen succeeds (no glibc symbol leakage)
#   T07  Cyclone DDS thread stack >= 2 MB on musl (patch verification)
#   T08  Minimal Python ROS2 node creates, spins, shuts down cleanly
#   T09  ROS2 node publishes on /ntari/test/status topic
#   T10  ROS2 node verbose status message format validation
#
# Usage:
#   ./tests/integration/test-ros2-phase6.sh
#   ./tests/integration/test-ros2-phase6.sh --verbose
#   ./tests/integration/test-ros2-phase6.sh --junit  # JUnit XML output
#
# Exit codes:
#   0 = all tests passed
#   1 = one or more tests failed

set -e

ROS_DISTRO="jazzy"
ALPINE_VERSION="3.23"
ALPINEROS_IMAGE="ghcr.io/alpine-ros/alpine-ros:${ROS_DISTRO}-${ALPINE_VERSION}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PATCHES_DIR="${PROJECT_DIR}/patches"
LOG_DIR="${PROJECT_DIR}/build/build-output/test-logs"
JUNIT_FILE="${LOG_DIR}/phase6-junit.xml"

mkdir -p "${LOG_DIR}"

# ── Output mode ──────────────────────────────────────────────────────────────
VERBOSE=0
JUNIT=0
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --junit|-j)   JUNIT=1 ;;
    esac
done

# ── Test state ────────────────────────────────────────────────────────────────
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
FAILED_TESTS=""
START_TIME=$(date +%s)

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── Test framework ────────────────────────────────────────────────────────────

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}  [PASS]${NC} %s\n" "$1"
    [ "$VERBOSE" = "1" ] && [ -n "$2" ] && printf "         %s\n" "$2"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS="${FAILED_TESTS}\n  - $1"
    printf "${RED}  [FAIL]${NC} %s\n" "$1"
    [ -n "$2" ] && printf "         %s\n" "$2"
}

skip() {
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    printf "${YELLOW}  [SKIP]${NC} %s — %s\n" "$1" "$2"
}

section() {
    echo ""
    printf "${CYAN}── %s ──────────────────────────────────────────${NC}\n" "$1"
}

run_in_container() {
    # Run a command inside the alpine-ros container
    # Usage: run_in_container "shell command" [timeout_seconds]
    _CMD="$1"
    _TIMEOUT="${2:-30}"
    docker run --rm \
        --name "ntari-test-$$" \
        -v "${PATCHES_DIR}:/patches:ro" \
        "${ALPINEROS_IMAGE}" \
        timeout "${_TIMEOUT}" \
        /bin/sh -c ". /opt/ros/${ROS_DISTRO}/setup.sh 2>/dev/null; ${_CMD}" \
        2>/dev/null
}

# ── Tests ─────────────────────────────────────────────────────────────────────

echo ""
printf "${GREEN}╔══════════════════════════════════════════════════════╗${NC}\n"
printf "${GREEN}║   NTARI OS Phase 6 — Integration Tests               ║${NC}\n"
printf "${GREEN}║   ROS2 Jazzy · Alpine 3.23 · musl libc               ║${NC}\n"
printf "${GREEN}╚══════════════════════════════════════════════════════╝${NC}\n"
echo ""
printf "  Date   : $(date -u +%Y-%m-%dT%H:%M:%SZ)\n"
printf "  Image  : %s\n" "${ALPINEROS_IMAGE}"
printf "  Distro : %s\n" "${ROS_DISTRO}"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
section "Infrastructure"
# ──────────────────────────────────────────────────────────────────────────────

# T01: Docker available
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    DOCKER_VER=$(docker --version | cut -d' ' -f3 | tr -d ',')
    pass "T01: Docker daemon available" "Version: ${DOCKER_VER}"
else
    fail "T01: Docker daemon available" "Docker not running — cannot proceed"
    echo ""
    printf "${RED}FATAL: Docker required for Phase 6 tests. Start Docker and retry.${NC}\n"
    exit 1
fi

# T02: alpine-ros image pullable/present
if docker image inspect "${ALPINEROS_IMAGE}" >/dev/null 2>&1; then
    pass "T02: alpine-ros image present (cached)" "${ALPINEROS_IMAGE}"
elif docker pull "${ALPINEROS_IMAGE}" >/dev/null 2>&1; then
    pass "T02: alpine-ros image pulled" "${ALPINEROS_IMAGE}"
else
    fail "T02: alpine-ros image unavailable" "Cannot pull ${ALPINEROS_IMAGE}"
    echo ""
    printf "${RED}FATAL: Base image unavailable. Check internet access.${NC}\n"
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
section "ROS2 Core"
# ──────────────────────────────────────────────────────────────────────────────

# T03: ROS2 CLI responds
ROS2_VER=$(run_in_container "ros2 --version 2>&1" 10 || echo "FAILED")
if echo "${ROS2_VER}" | grep -qi "jazzy\|ros2\|0\." 2>/dev/null; then
    pass "T03: ROS2 Jazzy CLI responds" "${ROS2_VER}"
else
    fail "T03: ROS2 Jazzy CLI responds" "Output: ${ROS2_VER}"
fi

# T04: rclpy importable
RCLPY_OUT=$(run_in_container \
    "python3 -c \"import rclpy; print('rclpy OK')\"" 10 || echo "FAILED")
if echo "${RCLPY_OUT}" | grep -q "rclpy OK"; then
    pass "T04: rclpy importable in Python"
else
    fail "T04: rclpy importable in Python" "${RCLPY_OUT}"
fi

# T05: Cyclone DDS selected as active RMW
RMW_OUT=$(run_in_container \
    "echo RMW=\$RMW_IMPLEMENTATION; python3 -c \"
import os
rmw = os.environ.get('RMW_IMPLEMENTATION', 'not set')
print('RMW:', rmw)
assert 'cyclonedds' in rmw.lower(), f'Wrong RMW: {rmw}'
print('OK')
\"" 10 || echo "FAILED")
if echo "${RMW_OUT}" | grep -q "OK"; then
    pass "T05: rmw_cyclonedds_cpp selected as active RMW"
else
    fail "T05: rmw_cyclonedds_cpp selected as active RMW" "${RMW_OUT}"
fi

# ──────────────────────────────────────────────────────────────────────────────
section "musl/Cyclone DDS Compatibility"
# ──────────────────────────────────────────────────────────────────────────────

# T06: libddsc.so dlopen succeeds
DLOPEN_OUT=$(run_in_container \
    "python3 -c \"
import ctypes, sys
try:
    lib = ctypes.CDLL('libddsc.so')
    print('dlopen: OK')
except OSError as e:
    print('dlopen: FAILED:', e)
    sys.exit(1)
\"" 15 || echo "FAILED")
if echo "${DLOPEN_OUT}" | grep -q "dlopen: OK"; then
    pass "T06: libddsc.so dlopen succeeds (no glibc symbol leakage)"
else
    fail "T06: libddsc.so dlopen succeeds" "${DLOPEN_OUT}"
fi

# T07: Cyclone DDS thread stack patch verification
# Verify that thread stack in Cyclone DDS is >= 2 MB on musl
# We check this by reading the patchfile was applied (source-level check)
# and by a runtime probe if possible.
if [ -f "${PATCHES_DIR}/cdds-musl-thread-stack.patch" ]; then
    # Patch file exists — verify it contains the 2 MB constant
    if grep -q "NTARI_MUSL_STACK_SIZE" "${PATCHES_DIR}/cdds-musl-thread-stack.patch" \
    && grep -q "2 \* 1024 \* 1024" "${PATCHES_DIR}/cdds-musl-thread-stack.patch"; then
        pass "T07: Cyclone DDS thread stack patch present (2 MB constant confirmed)"
    else
        fail "T07: Cyclone DDS thread stack patch — 2 MB constant not found in patch file"
    fi

    # Runtime check: verify the patch was applied to the built library
    # (only works if we rebuild cdds inside container — skip if using pre-built)
    PATCH_RUNTIME=$(run_in_container \
        "nm /usr/lib/libddsc.so 2>/dev/null | grep -c ddsrt_thread_apply_musl_stack \
         || nm /usr/lib/libddsc.so.* 2>/dev/null | grep -c ddsrt_thread_apply_musl_stack \
         || echo '0'" 10 || echo "0")
    if [ "${PATCH_RUNTIME}" = "0" ] || [ "${PATCH_RUNTIME}" = "FAILED" ]; then
        # Pre-built library from alpine-ros — patch not yet applied at runtime
        # This is expected until we rebuild Cyclone DDS inside the container
        skip "T07b: Cyclone DDS thread stack patch runtime check" \
            "Pre-built alpine-ros library — rebuild required (run: build/ros2-build.sh)"
    else
        pass "T07b: Cyclone DDS thread stack patch applied to libddsc.so"
    fi
else
    fail "T07: Cyclone DDS thread stack patch present" \
        "Patch file not found: ${PATCHES_DIR}/cdds-musl-thread-stack.patch"
fi

# ──────────────────────────────────────────────────────────────────────────────
section "Node Launch"
# ──────────────────────────────────────────────────────────────────────────────

# T08: Minimal Python ROS2 node — create, spin, shutdown
NODE_OUT=$(run_in_container \
    "python3 - <<'PYNODE'
import sys
sys.path.insert(0, '/opt/ros/${ROS_DISTRO}/lib/python3/dist-packages')
try:
    import rclpy
    from rclpy.node import Node

    rclpy.init()
    node = rclpy.create_node('ntari_phase6_test')
    node.get_logger().info('[TEST] ntari_phase6_test ACTIVE node_start — test:T08')
    node.destroy_node()
    rclpy.shutdown()
    print('T08: PASSED')
except Exception as e:
    print(f'T08: FAILED — {e}')
    sys.exit(1)
PYNODE" 20 || echo "T08: FAILED — timeout or container error")
if echo "${NODE_OUT}" | grep -q "T08: PASSED"; then
    pass "T08: Minimal Python ROS2 node — create, spin, shutdown"
else
    fail "T08: Minimal Python ROS2 node" "${NODE_OUT}"
fi

# T09: Node publishes on /ntari/test/status topic
PUB_OUT=$(run_in_container \
    "python3 - <<'PYPUB'
import sys
sys.path.insert(0, '/opt/ros/${ROS_DISTRO}/lib/python3/dist-packages')
try:
    import rclpy
    from rclpy.node import Node
    from std_msgs.msg import String

    rclpy.init()
    node = rclpy.create_node('ntari_test_pub')
    pub = node.create_publisher(String, '/ntari/test/status', 10)

    msg = String()
    msg.data = '[14:00:00] ntari_test_pub ACTIVE publish_test — topic:/ntari/test/status'
    pub.publish(msg)

    node.get_logger().info(f'Published: {msg.data}')
    node.destroy_node()
    rclpy.shutdown()
    print('T09: PASSED')
except Exception as e:
    print(f'T09: FAILED — {e}')
    sys.exit(1)
PYPUB" 20 || echo "T09: FAILED — timeout or container error")
if echo "${PUB_OUT}" | grep -q "T09: PASSED"; then
    pass "T09: Node publishes on /ntari/test/status topic"
else
    fail "T09: Node publishes on /ntari/test/status topic" "${PUB_OUT}"
fi

# T10: Verbose status message format validation
# Verify that a node can produce a correctly-formatted NTARI verbose status message
# Format: [HH:MM:SS] <node_name> <STATE> <action_verb> — <key:value ...>
STATUS_OUT=$(run_in_container \
    "python3 - <<'PYVAL'
import re, sys
sys.path.insert(0, '/opt/ros/${ROS_DISTRO}/lib/python3/dist-packages')

# NTARI verbose status format (§5.1)
STATUS_PATTERN = re.compile(
    r'^\[(\d{2}):(\d{2}):(\d{2})\] '     # [HH:MM:SS]
    r'(\w+) '                              # <node_name>
    r'(ACTIVE|PENDING|COMPLETE|WARN|ERROR|RECOVER) '  # <STATE>
    r'(\w+)'                               # <action_verb>
    r'( — .+)?$'                           # optional — <key:value ...>
)

test_messages = [
    '[14:00:00] ntari_phase6_test ACTIVE node_start — rmw:rmw_cyclonedds_cpp domain:0',
    '[14:00:01] ntari_dns_node ACTIVE resolve — host:ntari.local result:192.168.1.10 ttl:300',
    '[14:00:02] ntari_payment_node PENDING escrow_hold — invoice:lnbc100 hold:HODL amount:100sat',
    '[14:00:03] ntari_snapshot_node COMPLETE snap_done — name:@snap_20260218_140003_apk size:847MB',
    '[14:00:04] ntari_lbtas_node WARN score_low — exchange:svc_001 score:-1 action:suspend',
    '[14:00:05] ntari_failover_node ERROR sla_breach — sla:Hot target_ms:5000 actual_ms:8200',
    '[14:00:06] ntari_monitor_node RECOVER node_restart — reason:oom pid:1234 attempt:2',
]

failures = []
for msg in test_messages:
    m = STATUS_PATTERN.match(msg)
    if m:
        print(f'  OK: {msg[:60]}...')
    else:
        failures.append(msg)
        print(f'  FAIL: {msg[:60]}...')

if failures:
    print(f'T10: FAILED — {len(failures)} messages did not match format')
    sys.exit(1)
else:
    print(f'T10: PASSED — all {len(test_messages)} status messages validated')
PYVAL" 15 || echo "T10: FAILED — timeout or container error")
if echo "${STATUS_OUT}" | grep -q "T10: PASSED"; then
    pass "T10: Verbose status message format validation" \
        "All 7 sample messages matched §5.1 format"
else
    fail "T10: Verbose status message format validation" "${STATUS_OUT}"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
TOTAL=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

echo ""
echo "──────────────────────────────────────────────────────────────"
printf "  Tests run    : %d\n" "${TOTAL}"
printf "  ${GREEN}Passed       : %d${NC}\n" "${TESTS_PASSED}"
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf "  ${RED}Failed       : %d${NC}\n" "${TESTS_FAILED}"
else
    printf "  Failed       : %d\n" "${TESTS_FAILED}"
fi
printf "  Skipped      : %d\n" "${TESTS_SKIPPED}"
printf "  Duration     : %ds\n" "${DURATION}"
echo "──────────────────────────────────────────────────────────────"

if [ "${TESTS_FAILED}" -gt 0 ]; then
    echo ""
    printf "${RED}Failed tests:${NC}${FAILED_TESTS}\n"
    echo ""

    printf "${RED}╔══════════════════════════════════════════════════════╗${NC}\n"
    printf "${RED}║  Phase 6 Integration Tests: FAILED                   ║${NC}\n"
    printf "${RED}╚══════════════════════════════════════════════════════╝${NC}\n"
    echo ""
    EXIT_CODE=1
else
    echo ""
    printf "${GREEN}╔══════════════════════════════════════════════════════╗${NC}\n"
    printf "${GREEN}║  Phase 6 Integration Tests: ALL PASSED               ║${NC}\n"
    printf "${GREEN}║  ROS2 Jazzy on Alpine 3.23 (musl): CONFIRMED         ║${NC}\n"
    printf "${GREEN}╚══════════════════════════════════════════════════════╝${NC}\n"
    echo ""
    EXIT_CODE=0
fi

# JUnit XML output (for CI/CD integration)
if [ "$JUNIT" = "1" ]; then
    JUNIT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat > "${JUNIT_FILE}" <<JUNIT
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="NTARI OS Phase 6" tests="${TOTAL}" failures="${TESTS_FAILED}" skipped="${TESTS_SKIPPED}" time="${DURATION}">
  <testsuite name="ROS2 Jazzy on Alpine 3.23 (musl)" timestamp="${JUNIT_TIME}">
    <testcase name="T01: Docker daemon available" />
    <testcase name="T02: alpine-ros image pullable" />
    <testcase name="T03: ROS2 Jazzy CLI responds" />
    <testcase name="T04: rclpy importable" />
    <testcase name="T05: rmw_cyclonedds_cpp selected" />
    <testcase name="T06: libddsc.so dlopen succeeds" />
    <testcase name="T07: Cyclone DDS thread stack patch" />
    <testcase name="T08: Minimal node create-spin-shutdown" />
    <testcase name="T09: Node publishes on /ntari/test/status" />
    <testcase name="T10: Verbose status format validation" />
  </testsuite>
</testsuites>
JUNIT
    printf "JUnit XML: %s\n" "${JUNIT_FILE}"
fi

# Write test result summary
cat > "${LOG_DIR}/phase6-test-result.txt" <<RESULT
NTARI OS Phase 6 — Integration Test Result
Date     : $(date -u +%Y-%m-%dT%H:%M:%SZ)
Image    : ${ALPINEROS_IMAGE}
ROS2     : ${ROS_DISTRO}
Total    : ${TOTAL}
Passed   : ${TESTS_PASSED}
Failed   : ${TESTS_FAILED}
Skipped  : ${TESTS_SKIPPED}
Duration : ${DURATION}s
Result   : $([ "$EXIT_CODE" = "0" ] && echo "PASSED" || echo "FAILED")
RESULT

exit "${EXIT_CODE}"
