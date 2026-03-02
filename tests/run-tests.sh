#!/bin/bash
# NTARI OS Test Runner

set -e

echo "=== NTARI OS Test Runner ==="
echo ""

# Run integration tests
if [ -f tests/integration/test-suite.sh ]; then
	echo "Running integration tests..."
	./tests/integration/test-suite.sh
else
	echo "Integration tests not found, skipping..."
fi

echo ""
echo "=== All Tests Complete ==="
