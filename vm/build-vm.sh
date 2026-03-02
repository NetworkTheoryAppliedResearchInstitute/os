#!/bin/bash
set -e

echo "=== Building NTARI OS VM Image ==="

cd "$(dirname "$0")"

# Check for Packer
if ! command -v packer &> /dev/null; then
	echo "ERROR: Packer not installed"
	echo "Install from: https://www.packer.io/downloads"
	exit 1
fi

# Validate template
packer validate packer/ntari-os.pkr.hcl

# Build
packer build packer/ntari-os.pkr.hcl

# Convert to VMDK for VMware/VirtualBox
qemu-img convert -f qcow2 -O vmdk \
	../build-output/vm/ntari-os-1.0.0 \
	../build-output/vm/ntari-os-1.0.0.vmdk

echo "=== VM Images Built ==="
echo "QCOW2: build-output/vm/ntari-os-1.0.0 (for QEMU/KVM)"
echo "VMDK:  build-output/vm/ntari-os-1.0.0.vmdk (for VMware/VirtualBox)"
