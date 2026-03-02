#!/bin/sh
ISO="/workspace/build/build-output/ntari-os-1.5.0-x86_64-ros2-20260228.iso"

echo "=== Boot record ==="
xorriso -indev "${ISO}" -end 2>&1 | grep -E "(Boot record|El Torito)" | head -5

echo ""
echo "=== ISO root contents ==="
xorriso -indev "${ISO}" -find / -maxdepth 1 -end 2>&1 \
    | grep -v "^xorriso\|^Drive\|^Media\|^Boot\|^Volume\|^$"

echo ""
echo "=== file command ==="
file "${ISO}"
ls -lh "${ISO}"
