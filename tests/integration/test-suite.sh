#!/bin/bash
# NTARI OS Integration Test Suite

set -e

PASSED=0
FAILED=0

test_case() {
	NAME=$1
	shift
	echo -n "Testing: $NAME ... "

	if "$@" > /dev/null 2>&1; then
		echo "✓ PASS"
		PASSED=$((PASSED + 1))
	else
		echo "✗ FAIL"
		FAILED=$((FAILED + 1))
	fi
}

echo "=== NTARI OS Integration Tests ==="
echo ""

# System tests
test_case "System boots" true
test_case "Network available" ping -c 1 8.8.8.8
test_case "Time synchronized" chronyc tracking

# SoHoLINK tests
test_case "SoHoLINK service running" rc-service soholink status
test_case "RADIUS port listening" netstat -tuln | grep -q ":1812"
test_case "Database exists" test -f /var/lib/soholink/node.db
test_case "Config valid" /usr/bin/fedaaa status

# Security tests
test_case "Firewall active" iptables -L > /dev/null
test_case "Root login disabled" ! grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config
test_case "Fail2ban running" rc-service fail2ban status

# Update tests
test_case "Update check works" /usr/local/bin/check-updates.sh
test_case "Health check works" /usr/local/bin/health-check.sh

echo ""
echo "=== Test Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
	exit 1
fi
