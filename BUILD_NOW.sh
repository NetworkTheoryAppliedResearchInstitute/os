#!/bin/bash
# Quick build script for NTARI OS
# Run this from the NTARIOS directory

set -e

echo "╔════════════════════════════════════════════════════╗"
echo "║         NTARI OS - Quick Build Script             ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Navigate to build directory
cd "ntari-os/build"

echo "Step 1: Building ISO with Docker..."
echo "This will take 3-5 minutes on first run..."
echo ""

# Run Docker build
./docker-build.sh server

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║              Build Complete!                       ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "ISO Location:"
ls -lh build-output/*.iso 2>/dev/null || echo "ISO files:"
find build-output -name "*.iso" -exec ls -lh {} \;

echo ""
echo "Next steps:"
echo ""
echo "Option 1: Test with QEMU (if installed):"
echo "  qemu-system-x86_64 -cdrom build-output/ntari-server-*.iso -m 2048"
echo ""
echo "Option 2: Test with VirtualBox:"
echo "  1. Open VirtualBox"
echo "  2. Create new VM (Linux, Other 64-bit)"
echo "  3. Attach ISO from: $(pwd)/build-output/"
echo "  4. Start VM"
echo ""
