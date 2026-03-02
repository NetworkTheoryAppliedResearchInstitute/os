#!/bin/bash
# Quick start NTARI OS in QEMU

set -e

IMAGE="${1:-../build-output/vm/ntari-os-1.0.0}"

if [ ! -f "$IMAGE" ]; then
	echo "ERROR: VM image not found: $IMAGE"
	exit 1
fi

echo "Starting NTARI OS..."
echo "Login: root / ntaripass"
echo "Press Ctrl+Alt+G to release mouse"

qemu-system-x86_64 \
	-m 512 \
	-smp 1 \
	-drive file="$IMAGE",format=qcow2 \
	-net nic -net user,hostfwd=tcp::2222-:22,hostfwd=udp::1812-:1812 \
	-display gtk
