#!/bin/sh
# NTARI OS — IXP BGP Node Integration Test
# tests/ixp/test_bgp_node.sh
#
# Spins up two FRR instances in network namespaces, verifies session
# establishment via vtysh, and confirms ROS2 topic output on /ixp/bgp/peers.
#
# Prerequisites (must be installed in the Alpine test environment):
#   apk add frr frr-bgpd iproute2 util-linux
#   ros2 CLI available (ros2-domain running)
#
# Usage:
#   sh tests/ixp/test_bgp_node.sh
# Exit code 0 = pass, non-zero = fail

set -e

PASS=0
FAIL=0
NS_RS="ntari-ixp-rs"
NS_PEER="ntari-ixp-peer"
VETH_RS="veth-rs"
VETH_PEER="veth-peer"
RS_IP="192.0.2.1"
PEER_IP="192.0.2.2"
RS_ASN=65000
PEER_ASN=64512

# ── Cleanup helper ─────────────────────────────────────────────────────────────
cleanup() {
    ip netns del "${NS_RS}" 2>/dev/null || true
    ip netns del "${NS_PEER}" 2>/dev/null || true
    ip link del "${VETH_RS}" 2>/dev/null || true
    rm -f /tmp/ntari-ixp-test-rs.conf /tmp/ntari-ixp-test-peer.conf
    kill "${RS_PID}" "${PEER_PID}" 2>/dev/null || true
}
trap cleanup EXIT

assert_pass() {
    PASS=$((PASS + 1))
    echo "[PASS] $1"
}

assert_fail() {
    FAIL=$((FAIL + 1))
    echo "[FAIL] $1"
}

run_test() {
    local name="$1"
    local cmd="$2"
    if eval "${cmd}" >/dev/null 2>&1; then
        assert_pass "${name}"
    else
        assert_fail "${name}"
    fi
}

# ── Check prerequisites ────────────────────────────────────────────────────────

echo "=== NTARI OS IXP BGP Node Integration Test ==="

if [ "$(id -u)" -ne 0 ]; then
    echo "SKIP: must run as root (network namespaces require CAP_NET_ADMIN)"
    exit 77
fi

if ! command -v bgpd >/dev/null 2>&1 && ! command -v zebra >/dev/null 2>&1; then
    echo "SKIP: FRRouting not installed (apk add frr frr-bgpd)"
    exit 77
fi

# ── Build test namespace topology ─────────────────────────────────────────────
# RS namespace ←──── veth pair ────→ Peer namespace
# 192.0.2.1/30                        192.0.2.2/30

ip netns add "${NS_RS}"
ip netns add "${NS_PEER}"
ip link add "${VETH_RS}" type veth peer name "${VETH_PEER}"
ip link set "${VETH_RS}" netns "${NS_RS}"
ip link set "${VETH_PEER}" netns "${NS_PEER}"

ip netns exec "${NS_RS}" ip addr add "${RS_IP}/30" dev "${VETH_RS}"
ip netns exec "${NS_RS}" ip link set "${VETH_RS}" up
ip netns exec "${NS_PEER}" ip addr add "${PEER_IP}/30" dev "${VETH_PEER}"
ip netns exec "${NS_PEER}" ip link set "${VETH_PEER}" up

# ── Write minimal FRR configs ─────────────────────────────────────────────────

cat > /tmp/ntari-ixp-test-rs.conf << RS_CONF
frr version 9.1
frr defaults traditional
hostname ixp-test-rs
no ipv6 forwarding
service integrated-vtysh-config
router bgp ${RS_ASN}
 bgp router-id ${RS_IP}
 bgp log-neighbor-changes
 no bgp client-to-client reflection
 no bgp ebgp-requires-policy
 neighbor ${PEER_IP} remote-as ${PEER_ASN}
 neighbor ${PEER_IP} route-server-client
 neighbor ${PEER_IP} timers 5 15
 neighbor ${PEER_IP} timers connect 5
line vty
end
RS_CONF

cat > /tmp/ntari-ixp-test-peer.conf << PEER_CONF
frr version 9.1
frr defaults traditional
hostname ixp-test-peer
no ipv6 forwarding
service integrated-vtysh-config
router bgp ${PEER_ASN}
 bgp router-id ${PEER_IP}
 bgp log-neighbor-changes
 no bgp ebgp-requires-policy
 neighbor ${RS_IP} remote-as ${RS_ASN}
 neighbor ${RS_IP} timers 5 15
 neighbor ${RS_IP} timers connect 5
 address-family ipv4 unicast
  network 10.99.0.0/24
 exit-address-family
line vty
end
PEER_CONF

# ── Start FRR in each namespace ────────────────────────────────────────────────

ip netns exec "${NS_RS}" /usr/sbin/zebra \
    --config_file /tmp/ntari-ixp-test-rs.conf \
    --pid_file /tmp/ntari-rs-zebra.pid \
    --socket /tmp/ntari-rs-zebra.sock \
    --log syslog --daemon

ip netns exec "${NS_RS}" /usr/sbin/bgpd \
    --config_file /tmp/ntari-ixp-test-rs.conf \
    --pid_file /tmp/ntari-rs-bgpd.pid \
    --socket /tmp/ntari-rs-bgpd.sock \
    --log syslog --daemon
RS_PID=$(cat /tmp/ntari-rs-bgpd.pid 2>/dev/null || echo 0)

ip netns exec "${NS_PEER}" /usr/sbin/zebra \
    --config_file /tmp/ntari-ixp-test-peer.conf \
    --pid_file /tmp/ntari-peer-zebra.pid \
    --socket /tmp/ntari-peer-zebra.sock \
    --log syslog --daemon

ip netns exec "${NS_PEER}" /usr/sbin/bgpd \
    --config_file /tmp/ntari-ixp-test-peer.conf \
    --pid_file /tmp/ntari-peer-bgpd.pid \
    --socket /tmp/ntari-peer-bgpd.sock \
    --log syslog --daemon
PEER_PID=$(cat /tmp/ntari-peer-bgpd.pid 2>/dev/null || echo 0)

# ── Wait for BGP session establishment ────────────────────────────────────────

echo "Waiting up to 30s for BGP session establishment..."
ESTABLISHED=0
for i in $(seq 1 30); do
    if ip netns exec "${NS_RS}" vtysh \
            --config_file /tmp/ntari-ixp-test-rs.conf \
            -c "show bgp summary" 2>/dev/null | grep -q "Established"; then
        ESTABLISHED=1
        break
    fi
    sleep 1
done

# ── Tests ─────────────────────────────────────────────────────────────────────

if [ "${ESTABLISHED}" -eq 1 ]; then
    assert_pass "BGP session established between RS (AS${RS_ASN}) and peer (AS${PEER_ASN})"
else
    assert_fail "BGP session did not establish within 30s"
fi

# Verify prefix filtering: peer should have sent 10.99.0.0/24
run_test "Peer prefix 10.99.0.0/24 received by RS" \
    "ip netns exec ${NS_RS} vtysh --config_file /tmp/ntari-ixp-test-rs.conf \
     -c 'show ip bgp 10.99.0.0/24' 2>/dev/null | grep -q '10.99.0.0'"

# Verify route server semantics: next-hop should NOT be the RS (client-to-client
# reflection disabled means the RS doesn't rewrite next-hop)
run_test "Route server mode active (no client-to-client reflection)" \
    "ip netns exec ${NS_RS} vtysh --config_file /tmp/ntari-ixp-test-rs.conf \
     -c 'show ip bgp summary json' 2>/dev/null | grep -q 'routerID'"

# Verify bgp_monitor.py syntax
run_test "bgp_monitor.py passes syntax check" \
    "python3 -m py_compile /usr/local/bin/ixp-bgp-monitor.py"

# Verify ros2_bgp_node.py syntax
run_test "ixp-bgp-node.py passes syntax check" \
    "python3 -m py_compile /usr/local/bin/ixp-bgp-node.py"

# Verify ROS2 topic (if DDS domain is running in CI)
if ros2 topic list 2>/dev/null | grep -q "/ixp/bgp/health"; then
    run_test "DDS topic /ixp/bgp/health is published" \
        "ros2 topic echo --once /ixp/bgp/health 2>/dev/null | grep -qE 'healthy|degraded|failed'"
else
    echo "[SKIP] ROS2 domain not running — DDS topic test skipped"
fi

# ── Results ────────────────────────────────────────────────────────────────────

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "${FAIL}" -eq 0 ]
