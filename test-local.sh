#!/bin/bash
# NTARI OS Local Testing Script
# Tests project structure and scripts without requiring Docker/VMs

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         NTARI OS Local Test Suite                     ║${NC}"
echo -e "${BLUE}║         Testing Project Structure & Scripts           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

test_file() {
	FILE=$1
	DESC=$2

	if [ -f "$FILE" ]; then
		echo -e "${GREEN}✓${NC} $DESC"
		PASSED=$((PASSED + 1))
		return 0
	else
		echo -e "${RED}✗${NC} $DESC (missing: $FILE)"
		FAILED=$((FAILED + 1))
		return 1
	fi
}

test_executable() {
	FILE=$1
	DESC=$2

	if [ -f "$FILE" ] && [ -x "$FILE" ]; then
		echo -e "${GREEN}✓${NC} $DESC (executable)"
		PASSED=$((PASSED + 1))
		return 0
	elif [ -f "$FILE" ]; then
		echo -e "${YELLOW}!${NC} $DESC (exists but not executable)"
		PASSED=$((PASSED + 1))
		return 0
	else
		echo -e "${RED}✗${NC} $DESC (missing: $FILE)"
		FAILED=$((FAILED + 1))
		return 1
	fi
}

test_directory() {
	DIR=$1
	DESC=$2

	if [ -d "$DIR" ]; then
		echo -e "${GREEN}✓${NC} $DESC"
		PASSED=$((PASSED + 1))
		return 0
	else
		echo -e "${RED}✗${NC} $DESC (missing: $DIR)"
		FAILED=$((FAILED + 1))
		return 1
	fi
}

test_syntax() {
	FILE=$1
	DESC=$2

	if [ ! -f "$FILE" ]; then
		echo -e "${RED}✗${NC} $DESC (file not found)"
		FAILED=$((FAILED + 1))
		return 1
	fi

	# Basic syntax check
	if bash -n "$FILE" 2>/dev/null; then
		echo -e "${GREEN}✓${NC} $DESC (syntax valid)"
		PASSED=$((PASSED + 1))
		return 0
	else
		echo -e "${RED}✗${NC} $DESC (syntax error)"
		FAILED=$((FAILED + 1))
		return 1
	fi
}

echo "=== Testing Project Structure ==="
echo ""

# Directory structure
test_directory "build" "Build directory"
test_directory "iso" "ISO directory"
test_directory "scripts" "Scripts directory"
test_directory "config" "Config directory"
test_directory "packages" "Packages directory"
test_directory "vm" "VM directory"
test_directory "docs" "Documentation directory"
test_directory "tests" "Tests directory"

echo ""
echo "=== Testing Build System ==="
echo ""

test_file "build/Dockerfile" "Build Dockerfile"
test_file "build/Makefile" "Build Makefile"
test_executable "build/build-iso.sh" "ISO build script"

echo ""
echo "=== Testing Scripts ==="
echo ""

test_executable "scripts/setup-soholink.sh" "SoHoLINK setup script"
test_executable "scripts/setup-firewall.sh" "Firewall setup script"
test_executable "scripts/setup-time.sh" "Time sync setup script"
test_executable "scripts/harden-system.sh" "System hardening script"
test_executable "scripts/health-check.sh" "Health check script"
test_executable "scripts/ntari-admin.sh" "Admin dashboard script"
test_executable "scripts/check-updates.sh" "Update check script"
test_executable "scripts/system-update.sh" "System update script"

echo ""
echo "=== Testing Configuration Files ==="
echo ""

test_file "config/network/interfaces" "Network interfaces config"
test_file "config/services/chrony.conf" "Chrony NTP config"
test_file "config/services/soholink.initd" "SoHoLINK init script"
test_file "config/services/soholink.confd" "SoHoLINK config"
test_file "packages/soholink/APKBUILD" "SoHoLINK APK build file"

echo ""
echo "=== Testing VM Files ==="
echo ""

test_file "vm/packer/ntari-os.pkr.hcl" "Packer template"
test_executable "vm/build-vm.sh" "VM build script"
test_executable "vm/quickstart.sh" "VM quickstart script"

echo ""
echo "=== Testing Test Suite ==="
echo ""

test_executable "tests/integration/test-suite.sh" "Integration test suite"
test_executable "tests/run-tests.sh" "Test runner"

echo ""
echo "=== Testing Documentation ==="
echo ""

test_file "README.md" "README"
test_file "QUICKSTART.md" "Quick start guide"
test_file "CONTRIBUTING.md" "Contributing guide"
test_file "STATUS.md" "Project status"
test_file "EXECUTION_SUMMARY.md" "Execution summary"
test_file "LICENSE" "License file"
test_file ".gitignore" "Git ignore file"
test_file "docs/INSTALL.md" "Installation guide"
test_file "docs/OPERATIONS.md" "Operations guide"
test_file "docs/ARCHITECTURE.md" "Architecture docs"

echo ""
echo "=== Testing Script Syntax ==="
echo ""

test_syntax "build/build-iso.sh" "ISO build script syntax"
test_syntax "scripts/setup-soholink.sh" "SoHoLINK setup syntax"
test_syntax "scripts/harden-system.sh" "System hardening syntax"
test_syntax "scripts/health-check.sh" "Health check syntax"
test_syntax "scripts/ntari-admin.sh" "Admin dashboard syntax"

echo ""
echo "=== Additional Checks ==="
echo ""

# Check for shebang in scripts
SCRIPT_COUNT=$(find scripts/ -name "*.sh" -type f | wc -l)
SHEBANG_COUNT=$(find scripts/ -name "*.sh" -type f -exec head -1 {} \; | grep -c "^#!/")

if [ "$SCRIPT_COUNT" -eq "$SHEBANG_COUNT" ]; then
	echo -e "${GREEN}✓${NC} All scripts have proper shebang"
	PASSED=$((PASSED + 1))
else
	echo -e "${YELLOW}!${NC} Some scripts may be missing shebang"
fi

# Check for README content
if grep -q "NTARI OS" README.md 2>/dev/null; then
	echo -e "${GREEN}✓${NC} README has project name"
	PASSED=$((PASSED + 1))
else
	echo -e "${RED}✗${NC} README missing project name"
	FAILED=$((FAILED + 1))
fi

# Check Makefile targets
if grep -q "^iso:" build/Makefile 2>/dev/null; then
	echo -e "${GREEN}✓${NC} Makefile has ISO target"
	PASSED=$((PASSED + 1))
else
	echo -e "${RED}✗${NC} Makefile missing ISO target"
	FAILED=$((FAILED + 1))
fi

echo ""
echo "=== Test Results ==="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
	echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
	echo -e "${GREEN}║  ALL TESTS PASSED! ✓                  ║${NC}"
	echo -e "${GREEN}║  Project structure is complete        ║${NC}"
	echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
	exit 0
else
	echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
	echo -e "${YELLOW}║  SOME TESTS FAILED                    ║${NC}"
	echo -e "${YELLOW}║  Review failures above                ║${NC}"
	echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
	exit 1
fi
